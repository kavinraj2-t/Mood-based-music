import cv2
import json
import os
import sys
import time
import threading
from collections import Counter

# Suppress TF logs
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
feed_img = os.path.join(project_dir, "temp_live_feed.jpg")
info_json = os.path.join(project_dir, "temp_live_info.json")
stop_flag = os.path.join(project_dir, "stop_camera.flag")

if os.path.exists(stop_flag):
    try:
        os.remove(stop_flag)
    except:
        pass

print("[camera_service] Opening webcam immediately...")
cap = None
# Try index 0 and index 1 with and without DirectShow
for idx in [0, 1]:
    for api in [cv2.CAP_DSHOW, cv2.CAP_ANY]:
        c = cv2.VideoCapture(idx, api)
        if c.isOpened():
            ret, test_frame = c.read()
            if ret and test_frame is not None:
                cap = c
                print(f"[camera_service] Successfully opened camera index {idx} with backend {api}")
                break
            else:
                c.release()
        else:
            c.release()
    if cap is not None:
        break

if cap is None or not cap.isOpened():
    print("[camera_service] ERROR: Could not open any physical webcam.")
    sys.exit(1)

# Set resolution to 640x480 for fast performance
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

# Instant OpenCV Haar Cascade for zero-latency face detection
cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
face_cascade = cv2.CascadeClassifier(cascade_path) if os.path.exists(cascade_path) else None

# Background FER neural network loader
detector = None
fer_status = "loading"

def load_fer_worker():
    global detector, fer_status
    try:
        print("[camera_service] Initializing FER neural network in background...")
        from fer.fer import FER
        detector = FER(mtcnn=False)
        fer_status = "ready"
        print("[camera_service] FER loaded successfully and ready!")
    except Exception as e:
        fer_status = f"error: {e}"
        print(f"[camera_service] Error loading FER: {e}")

fer_thread = threading.Thread(target=load_fer_worker, daemon=True)
fer_thread.start()

last_detect_time = 0.0
current_emotion = "neutral"
current_bbox = []
emotion_scores = {}
emotion_history = []

print("[camera_service] Continuous streaming active.")

try:
    while True:
        if os.path.exists(stop_flag):
            print("[camera_service] Stop signal received. Exiting.")
            break

        ret, frame = cap.read()
        if not ret or frame is None:
            time.sleep(0.01)
            continue

        now = time.time()

        # If FER is ready, detect deep emotions every 0.35s
        if fer_status == "ready" and detector is not None and (now - last_detect_time) > 0.35:
            last_detect_time = now
            try:
                results = detector.detect_emotions(frame)
                if results and len(results) > 0:
                    best_face = max(results, key=lambda f: f["box"][2] * f["box"][3])
                    current_bbox = [int(v) for v in best_face["box"]] # [x, y, w, h]
                    emotions = best_face["emotions"]
                    emotion_scores = emotions

                    # High sensitivity calibration: boost sad (2.20x) and suppress neutral bias (0.60x)
                    weights = {
                        "happy": 1.05,
                        "sad": 2.20,
                        "surprise": 1.30,
                        "angry": 1.40,
                        "neutral": 0.60,
                        "fear": 1.20,
                        "disgust": 1.20
                    }
                    weighted = {k: emotions.get(k, 0.0) * weights.get(k, 1.0) for k in emotions}
                    detected = max(weighted, key=weighted.get)

                    emotion_history.append(detected)
                    if len(emotion_history) > 3:
                        emotion_history.pop(0)

                    current_emotion = Counter(emotion_history).most_common(1)[0][0]
                else:
                    current_bbox = []
            except Exception:
                pass
        elif fer_status != "ready" and face_cascade is not None and (now - last_detect_time) > 0.2:
            # While AI model is loading, use instant Haar cascade for face box
            last_detect_time = now
            try:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, 1.3, 5, minSize=(60, 60))
                if len(faces) > 0:
                    faces_sorted = sorted(faces, key=lambda b: b[2] * b[3], reverse=True)
                    current_bbox = [int(v) for v in faces_sorted[0]]
                else:
                    current_bbox = []
            except Exception:
                pass

        # Draw bounding box and label
        display_frame = frame.copy()
        if current_bbox and len(current_bbox) == 4:
            x, y, w, h = current_bbox
            cv2.rectangle(display_frame, (x, y), (x + w, y + h), (0, 255, 255), 2)
            if fer_status == "ready":
                label = current_emotion.upper()
            else:
                label = "DETECTING..."
            cv2.putText(display_frame, label, (x, max(25, y - 10)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 255, 255), 2)

        # Write live frame atomically
        tmp_feed = feed_img + ".tmp.jpg"
        cv2.imwrite(tmp_feed, display_frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        try:
            if os.path.exists(feed_img):
                os.replace(tmp_feed, feed_img)
            else:
                os.rename(tmp_feed, feed_img)
        except Exception:
            pass

        # Write detection info
        data = {
            "emotion": current_emotion if fer_status == "ready" else "detecting",
            "bbox": current_bbox,
            "scores": emotion_scores,
            "ai_ready": (fer_status == "ready"),
            "timestamp": now
        }
        tmp_info = info_json + ".tmp.json"
        with open(tmp_info, "w") as f:
            json.dump(data, f)
        try:
            if os.path.exists(info_json):
                os.replace(tmp_info, info_json)
            else:
                os.rename(tmp_info, info_json)
        except Exception:
            pass

        time.sleep(0.02)

finally:
    if cap is not None:
        cap.release()
    print("[camera_service] Camera released.")
