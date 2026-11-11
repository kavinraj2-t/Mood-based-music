"use client";
import Link from "next/link";

export default function Home() {
  return (
    <main className="flex flex-col items-center justify-center h-screen bg-gray-100">
      <h1 className="text-3xl font-bold mb-6">Emotion-Based Music Player</h1>
      <Link href="/player">
        <button className="px-6 py-3 bg-blue-600 text-white rounded-lg shadow">
          Start
        </button>
      </Link>
    </main>
  );
}
