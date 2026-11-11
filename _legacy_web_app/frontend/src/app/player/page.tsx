"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { motion } from "framer-motion";
import AudioPlayer from "../components/AudioPlayer";

// Define proper type for Song
type Song = {
  name: string;
  artist: string;
  url: string;
  preview_url?: string;
};

export default function Player() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [emotion, setEmotion] = useState<string | null>(null);
  const [songs, setSongs] = useState<Song[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastEmotion, setLastEmotion] = useState<string | null>(null);

  // Preferences
  const [language, setLanguage] = useState("english");
  const [genre, setGenre] = useState("pop");

  // Refs to always hold latest values
  const languageRef = useRef(language);
  const genreRef = useRef(genre);

  useEffect(() => {
    languageRef.current = language;
  }, [language]);

  useEffect(() => {
    genreRef.current = genre;
  }, [genre]);

  // Detect function wrapped in useCallback
  const captureAndDetect = useCallback(async () => {
    if (!videoRef.current) return;

    const canvas = document.createElement("canvas");
    canvas.width = videoRef.current.videoWidth;
    canvas.height = videoRef.current.videoHeight;
    const ctx = canvas.getContext("2d");
    if (ctx) {
      ctx.drawImage(videoRef.current, 0, 0, canvas.width, canvas.height);
    }

    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob((b) => resolve(b), "image/jpeg")
    );

    if (!blob) return;

    const formData = new FormData();
    formData.append("file", blob, "frame.jpg");

    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/detect-emotion/`, {
        method: "POST",
        body: formData,
      });
      const data = await res.json();
      setEmotion(data.emotion);

      if (data.emotion !== lastEmotion) {
        setLastEmotion(data.emotion);

        const rec = await fetch(
          `${process.env.NEXT_PUBLIC_BACKEND_URL}/recommend/${data.emotion}?language=${languageRef.current}&genre=${genreRef.current}`
        );
        const recData = await rec.json();
        setSongs(recData.tracks);
      }

      if (loading) setLoading(false);
    } catch (err) {
      console.error("Error detecting emotion:", err);
    }
  }, [lastEmotion, loading]);

  // Start camera once
  useEffect(() => {
    const startCamera = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }

        const interval = setInterval(() => {
          captureAndDetect();
        }, 5000);

        return () => clearInterval(interval);
      } catch (err) {
        console.error("Camera access denied:", err);
        setLoading(false);
      }
    };
    startCamera();
  }, [captureAndDetect]);

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-purple-600 via-pink-500 to-orange-400 flex flex-col items-center justify-start p-6">
      <motion.h1 className="text-4xl md:text-5xl font-extrabold text-white mb-4">
        🎶 Emotion-Based Music Player
      </motion.h1>

      {/* Preferences */}
      <div className="bg-white/20 backdrop-blur-md p-4 rounded-2xl shadow-lg mb-6 text-white w-full max-w-md">
        <h2 className="text-lg font-semibold mb-2">Choose Preferences</h2>

        {/* Language */}
        <div className="mb-3">
          <p className="font-medium">Language:</p>
          <div className="flex gap-4 mt-1">
            {["english", "hindi", "punjabi"].map((lang) => (
              <label key={lang} className="flex items-center gap-1">
                <input
                  type="radio"
                  name="language"
                  value={lang}
                  checked={language === lang}
                  onChange={(e) => setLanguage(e.target.value)}
                  className="accent-yellow-400"
                />
                {lang.charAt(0).toUpperCase() + lang.slice(1)}
              </label>
            ))}
          </div>
        </div>

        {/* Genre */}
        <div>
          <p className="font-medium">Genre:</p>
          <div className="flex flex-wrap gap-4 mt-1">
            {["pop", "rock", "classical", "lofi"].map((g) => (
              <label key={g} className="flex items-center gap-1">
                <input
                  type="radio"
                  name="genre"
                  value={g}
                  checked={genre === g}
                  onChange={(e) => setGenre(e.target.value)}
                  className="accent-yellow-400"
                />
                {g.charAt(0).toUpperCase() + g.slice(1)}
              </label>
            ))}
          </div>
        </div>
      </div>

      {/* Camera */}
      <div className="relative w-full max-w-md">
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          className="rounded-2xl shadow-xl border-4 border-white/30"
        />
        {/* Startup Loading Overlay (only once) */}
        {loading && (
          <div className="absolute inset-0 bg-black/50 flex items-center justify-center rounded-2xl">
            <div className="flex space-x-2">
              <span className="w-3 h-3 bg-white rounded-full animate-bounce"></span>
              <span className="w-3 h-3 bg-white rounded-full animate-bounce delay-150"></span>
              <span className="w-3 h-3 bg-white rounded-full animate-bounce delay-300"></span>
            </div>
          </div>
        )}
      </div>

      {/* Emotion */}
      {emotion && !loading && (
        <motion.div className="mt-6 px-6 py-4 rounded-2xl bg-white/20 backdrop-blur-lg shadow-lg text-white text-lg font-semibold">
          Current Mood: <span className="text-yellow-300 font-bold">{emotion}</span>
        </motion.div>
      )}

      {/* Songs */}
      {songs.length > 0 && (
        <motion.div className="w-full max-w-md mt-8 space-y-4">
          <h2 className="text-2xl font-bold text-white mb-4">Recommended Songs</h2>
          {songs.map((song, idx) => (
            <motion.div
              key={idx}
              className="p-4 bg-white/20 backdrop-blur-md rounded-xl hover:bg-white/30 transition"
            >
              {song.preview_url ? (
                <AudioPlayer
                  src={song.preview_url}
                  title={song.name}
                  artist={song.artist}
                />
              ) : (
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-white font-semibold">{song.name}</p>
                    <p className="text-sm text-gray-200">{song.artist}</p>
                  </div>
                  <a
                    href={song.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="bg-yellow-400 text-black px-3 py-1 rounded-lg font-bold hover:bg-yellow-300"
                  >
                    ▶️ Play on Spotify
                  </a>
                </div>
              )}
            </motion.div>
          ))}
        </motion.div>
      )}
    </div>
  );
}
