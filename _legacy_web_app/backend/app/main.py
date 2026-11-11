import os
import requests
import cv2
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# CORS for frontend (Vercel)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can restrict to your Vercel domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Spotify Auth
CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID")
CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET")

def get_spotify_token():
    auth_response = requests.post(
        "https://accounts.spotify.com/api/token",
        {
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        },
    )
    return auth_response.json()["access_token"]

# Lazy load detector
detector = None

def detect_emotion(img_path: str):
    global detector
    if detector is None:
        from fer import FER
        detector = FER(mtcnn=True)
    img = cv2.imread(img_path)
    if img is None:
        return "no_face"
    result = detector.detect_emotions(img)
    if result and len(result) > 0:
        # Pick the dominant emotion
        emotions = result[0]["emotions"]
        return max(emotions, key=emotions.get)
    return "neutral"

# Health check
@app.get("/")
def health():
    return {"status": "running"}

@app.post("/detect-emotion/")
async def detect(file: UploadFile = File(...)):
    with open("temp.jpg", "wb") as buffer:
        buffer.write(await file.read())
    emotion = detect_emotion("temp.jpg")
    return {"emotion": emotion}

@app.get("/recommend/{emotion}")
async def recommend(emotion: str, language: str = "english", genre: str = "pop"):
    token = get_spotify_token()
    headers = {"Authorization": f"Bearer {token}"}

    query = f"{emotion} {language} {genre}"
    url = f"https://api.spotify.com/v1/search?q={query}&type=track&limit=5"

    res = requests.get(url, headers=headers).json()
    tracks = []

    if "tracks" in res and "items" in res["tracks"]:
        for item in res["tracks"]["items"]:
            tracks.append({
                "name": item["name"],
                "artist": item["artists"][0]["name"],
                "url": item["external_urls"]["spotify"],
                "preview_url": item.get("preview_url")  # for audio player
            })

    return {
        "emotion": emotion,
        "language": language,
        "genre": genre,
        "tracks": tracks
    }
