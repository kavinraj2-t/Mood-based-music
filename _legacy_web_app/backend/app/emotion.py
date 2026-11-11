from deepface import DeepFace

def detect_emotion(image_path: str) -> str:
    try:
        result = DeepFace.analyze(img_path=image_path, actions=["emotion"], enforce_detection=False)
        if isinstance(result, list):
            result = result[0]
        return result["dominant_emotion"]
    except Exception as e:
        return f"error: {str(e)}"
