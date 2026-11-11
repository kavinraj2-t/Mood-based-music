"use client";
import { useEffect, useRef } from "react";

export default function CameraCapture({ onCapture }: { onCapture: (blob: Blob) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    navigator.mediaDevices.getUserMedia({ video: true }).then((stream) => {
      if (videoRef.current) videoRef.current.srcObject = stream;
    });
  }, []);

  const capture = () => {
    const canvas = document.createElement("canvas");
    const video = videoRef.current!;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d")?.drawImage(video, 0, 0);
    canvas.toBlob((blob) => {
      if (blob) onCapture(blob);
    }, "image/jpeg");
  };

  return (
    <div className="flex flex-col items-center">
      <video ref={videoRef} autoPlay className="w-72 h-56 rounded-lg border" />
      <button onClick={capture} className="mt-4 px-4 py-2 bg-green-600 text-white rounded">
        Detect Emotion
      </button>
    </div>
  );
}
