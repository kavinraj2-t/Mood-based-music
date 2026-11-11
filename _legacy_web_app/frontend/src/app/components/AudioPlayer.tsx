"use client";

import { useEffect, useRef, useState } from "react";

type Props = {
  src: string;
  title: string;
  artist: string;
};

export default function AudioPlayer({ src, title, artist }: Props) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);

  const togglePlay = () => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
    } else {
      audioRef.current.play();
    }
    setIsPlaying(!isPlaying);
  };

  const updateProgress = () => {
    if (!audioRef.current) return;
    const value = (audioRef.current.currentTime / audioRef.current.duration) * 100;
    setProgress(value || 0);
  };

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!audioRef.current || !audioRef.current.duration) return;
    const seekTime =
      (parseFloat(e.target.value) / 100) * audioRef.current.duration;
    audioRef.current.currentTime = seekTime;
    setProgress(parseFloat(e.target.value));
  };

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    audio.addEventListener("timeupdate", updateProgress);

    return () => {
      audio.removeEventListener("timeupdate", updateProgress);
    };
  }, []);

  return (
    <div className="bg-white/30 p-3 rounded-lg shadow-md">
      <p className="text-white font-semibold">{title}</p>
      <p className="text-sm text-gray-200">{artist}</p>
      <div className="flex items-center gap-2 mt-2">
        <button
          onClick={togglePlay}
          className="bg-yellow-400 text-black px-3 py-1 rounded-lg font-bold hover:bg-yellow-300"
        >
          {isPlaying ? "⏸️ Pause" : "▶️ Play"}
        </button>
        <input
          type="range"
          min="0"
          max="100"
          value={progress}
          onChange={handleSeek}
          className="flex-1"
        />
      </div>
      <audio ref={audioRef} src={src} preload="auto" />
    </div>
  );
}
