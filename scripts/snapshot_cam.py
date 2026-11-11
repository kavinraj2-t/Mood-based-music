import cv2, sys

out_path = sys.argv[1] if len(sys.argv) > 1 else "cam_frame.jpg"

cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
if not cap.isOpened():
    cap = cv2.VideoCapture(0)

if cap.isOpened():
    cap.read()  # warm up auto-exposure
    ret, frame = cap.read()
    cap.release()
    if ret and frame is not None:
        cv2.imwrite(out_path, frame)
        sys.exit(0)

sys.exit(1)
