// Generates an original, license-free ambient tone used as MWB sample audio.
// Usage: node tool/generate_sample_tone.js assets/audio/sample_reflection_tone.wav
const fs = require('fs');
const rate = 16000, secs = 48, n = rate * secs;
const data = Buffer.alloc(n * 2);
const chord = [196.0, 246.94, 293.66, 392.0]; // G major pad
for (let i = 0; i < n; i++) {
  const t = i / rate;
  let s = 0;
  chord.forEach((f, k) => { s += Math.sin(2 * Math.PI * f * t + k) * (0.5 + 0.5 * Math.sin(2 * Math.PI * (0.05 + k * 0.02) * t)); });
  s /= chord.length;
  const env = Math.min(1, t / 3) * Math.min(1, (secs - t) / 3);
  data.writeInt16LE(Math.round(s * env * 0.35 * 32767), i * 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8); h.write('fmt ', 12);
h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(rate, 24);
h.writeUInt32LE(rate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(data.length, 40);
fs.writeFileSync(process.argv[2], Buffer.concat([h, data]));
console.log('wrote', process.argv[2]);
