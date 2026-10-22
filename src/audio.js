// All the sounds and music, made in code with the Web Audio API (no sound files needed).
//
//   sfx('pop')              play a sound effect
//   sfx('groan', { volume: 0.4, pitch: 1.2 })
//   music('park')           switch to a level's tune (or 'title', 'party')
//
// Browsers only allow sound after a key press, so nothing plays until the first key
// (or joypad button, which main.js passes on to wakeSound()).

import { CONFIG } from './config.js';

let ctx = null;
let master;
let musicGain;
let sfxGain;
let noiseBuffer;
let wantedSong = null;
let meter = null; // measures how loud it is, for testing
let random = Math.random; // for the noise (recordings use a fixed sequence, so they come out the same)
const VOLUME_KEY = 'zombie-tag-volume';
const volumes = { music: CONFIG.sound.music, sounds: CONFIG.sound.sounds }; // 0 to 10

try {
  Object.assign(volumes, JSON.parse(localStorage.getItem(VOLUME_KEY)) || {});
} catch {
  // no saved volume yet
}

function start() {
  if (ctx) return;
  ctx = new AudioContext();
  master = ctx.createGain();
  master.connect(ctx.destination);
  meter = ctx.createAnalyser();
  master.connect(meter);
  musicGain = ctx.createGain();
  sfxGain = ctx.createGain();
  musicGain.connect(master);
  sfxGain.connect(master);
  applyVolumes();
  noiseBuffer = makeNoise(ctx);
  setInterval(scheduleMusic, 25);
  if (wantedSong) music(wantedSong);
}

// one second of white noise, for whooshes, splats and drums
function makeNoise(c) {
  const buffer = c.createBuffer(1, c.sampleRate, c.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = random() * 2 - 1;
  return buffer;
}

export function wakeSound() {
  start();
  if (ctx.state === 'suspended') ctx.resume();
}
window.addEventListener('keydown', wakeSound);

function applyVolumes() {
  if (!ctx) return;
  musicGain.gain.value = (volumes.music / 10) * 0.32;
  sfxGain.gain.value = (volumes.sounds / 10) * 0.9;
}

// How loud the game is right now (0 is silent), for test scripts.
export function loudness() {
  if (!meter) return 0;
  const data = new Float32Array(meter.fftSize);
  meter.getFloatTimeDomainData(data);
  return Math.sqrt(data.reduce((sum, v) => sum + v * v, 0) / data.length);
}

export function getVolumes() {
  return { ...volumes };
}

export function setVolume(which, value) {
  volumes[which] = Math.max(0, Math.min(10, value));
  applyVolumes();
  try {
    localStorage.setItem(VOLUME_KEY, JSON.stringify(volumes));
  } catch {
    // can't save it; it still works until the page closes
  }
}

// ---------- building blocks ----------

const midi = (n) => 440 * 2 ** ((n - 69) / 12);

// A note: an oscillator with a quick fade in and out, sliding and wobbling if asked.
function tone(freq, when, dur, o = {}) {
  const osc = ctx.createOscillator();
  osc.type = o.type || 'sine';
  osc.frequency.setValueAtTime(freq, when);
  if (o.slideTo) osc.frequency.exponentialRampToValueAtTime(o.slideTo, when + dur);
  if (o.vibrato) {
    const lfo = ctx.createOscillator();
    const depth = ctx.createGain();
    lfo.frequency.value = o.vibrato.rate;
    depth.gain.value = o.vibrato.depth;
    lfo.connect(depth).connect(osc.frequency);
    lfo.start(when);
    lfo.stop(when + dur + 0.05);
  }
  const gain = ctx.createGain();
  const vol = o.vol ?? 0.2;
  gain.gain.setValueAtTime(0.0001, when);
  gain.gain.exponentialRampToValueAtTime(vol, when + (o.attack ?? 0.008));
  gain.gain.exponentialRampToValueAtTime(0.0001, when + dur);
  let node = osc;
  if (o.filter) {
    const f = ctx.createBiquadFilter();
    f.type = o.filter.type;
    f.frequency.value = o.filter.freq;
    f.Q.value = o.filter.Q ?? 1;
    node = node.connect(f);
  }
  node.connect(gain).connect(o.out || sfxGain);
  osc.start(when);
  osc.stop(when + dur + 0.05);
}

// A burst of filtered noise: whooshes, splats, snares and hi-hats.
function noise(when, dur, o = {}) {
  const src = ctx.createBufferSource();
  src.buffer = noiseBuffer;
  src.loop = true;
  const f = ctx.createBiquadFilter();
  f.type = o.type || 'bandpass';
  f.frequency.setValueAtTime(o.freq || 1000, when);
  if (o.slideTo) f.frequency.exponentialRampToValueAtTime(o.slideTo, when + dur);
  f.Q.value = o.Q ?? 1;
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(0.0001, when);
  gain.gain.exponentialRampToValueAtTime(o.vol ?? 0.2, when + 0.005);
  gain.gain.exponentialRampToValueAtTime(0.0001, when + dur);
  src.connect(f).connect(gain).connect(o.out || sfxGain);
  src.start(when, random() * 0.5);
  src.stop(when + dur + 0.05);
}

const arpeggio = (notes, when, step, o) => notes.forEach((n, i) => tone(midi(n), when + i * step, step * 1.8, o));

// ---------- sound effects ----------

const SOUNDS = {
  // hits
  bonk: (t, p) => tone(420 * p, t, 0.28, { slideTo: 180 * p, vibrato: { rate: 28, depth: 50 }, vol: 0.35 }), // boing!
  swing: (t) => noise(t, 0.14, { freq: 700, slideTo: 2200, Q: 2, vol: 0.12 }),
  squawk: (t, p) => {
    tone(760 * p, t, 0.32, {
      type: 'sawtooth', slideTo: 430 * p, vibrato: { rate: 38, depth: 140 }, vol: 0.5,
      filter: { type: 'bandpass', freq: 1300, Q: 3 },
    });
  },
  squirt: (t) => noise(t, 0.09, { type: 'highpass', freq: 2500, vol: 0.12 }),
  splat: (t, p) => noise(t, 0.25 * p, { type: 'lowpass', freq: 900, slideTo: 150, vol: 0.4 }),
  bloop: (t) => {
    tone(320, t, 0.12, { slideTo: 720, vol: 0.25 });
    tone(520, t + 0.08, 0.12, { slideTo: 980, vol: 0.2 });
  },
  poof: (t) => {
    noise(t, 0.16, { type: 'lowpass', freq: 1800, vol: 0.25 });
    tone(1568, t + 0.05, 0.25, { type: 'triangle', vol: 0.1 });
  },
  pew: (t) => tone(1500, t, 0.13, { type: 'square', slideTo: 260, vol: 0.06 }),
  whoosh: (t) => noise(t, 0.35, { freq: 400, slideTo: 1800, Q: 3, vol: 0.18 }),
  thump: (t) => tone(140, t, 0.25, { slideTo: 50, vol: 0.5 }),
  crack: (t) => {
    noise(t, 0.12, { freq: 1600, Q: 0.7, vol: 0.45 });
    tone(220, t, 0.08, { type: 'square', slideTo: 90, vol: 0.12 });
  },
  // popping zombies and Tag Bux
  pop: (t, p) => {
    tone(260 * p, t, 0.1, { slideTo: 950 * p, vol: 0.35 });
    noise(t, 0.06, { type: 'highpass', freq: 3000, vol: 0.15 });
  },
  split: (t) => {
    noise(t, 0.2, { type: 'lowpass', freq: 700, vol: 0.35 });
    tone(650, t, 0.25, { slideTo: 160, vol: 0.2 });
  },
  coin: (t, p) => {
    tone(988 * p, t, 0.07, { type: 'square', vol: 0.07 });
    tone(1319 * p, t + 0.06, 0.2, { type: 'square', vol: 0.07 });
  },
  kaching: (t) => {
    noise(t, 0.08, { type: 'highpass', freq: 4000, vol: 0.15 });
    arpeggio([84, 88, 91, 96], t + 0.04, 0.06, { type: 'square', vol: 0.06 });
  },
  // getting hurt
  ouch: (t) => {
    tone(523, t, 0.15, { type: 'triangle', vol: 0.3 });
    tone(392, t + 0.15, 0.3, { type: 'triangle', vol: 0.3 });
  },
  clang: (t) => {
    tone(1800, t, 0.4, { type: 'triangle', vol: 0.15 });
    tone(2650, t, 0.3, { type: 'sine', vol: 0.1 });
  },
  tagged: (t) => {
    [392, 370, 349].forEach((f, i) => tone(f, t + i * 0.28, 0.26, { type: 'square', vol: 0.08 }));
    tone(330, t + 0.84, 0.7, { type: 'square', vol: 0.08, vibrato: { rate: 7, depth: 12 } }); // wah wah wahhh
  },
  groan: (t, p) => tone(115 * p, t, 0.9, {
    type: 'sawtooth', slideTo: 85 * p, vibrato: { rate: 6, depth: 9 }, vol: 0.14, attack: 0.15,
    filter: { type: 'lowpass', freq: 650, Q: 4 },
  }),
  // menus, the shop and the gym
  tick: (t) => tone(1250, t, 0.035, { vol: 0.06 }),
  select: (t) => tone(800, t, 0.09, { slideTo: 1300, vol: 0.12 }),
  nope: (t) => {
    tone(180, t, 0.13, { type: 'square', vol: 0.08 });
    tone(150, t + 0.15, 0.18, { type: 'square', vol: 0.08 });
  },
  step: (t, p) => tone(220 * p, t, 0.06, { type: 'triangle', vol: 0.18 }),
  lift: (t, p) => tone(260 * p, t, 0.07, { type: 'triangle', vol: 0.16 }),
  levelUp: (t) => arpeggio([72, 76, 79, 84, 88], t, 0.09, { type: 'square', vol: 0.08 }),
  aww: (t) => tone(392, t, 0.6, { type: 'triangle', slideTo: 220, vol: 0.2 }),
  // levels
  gate: (t) => [84, 88, 91, 93, 96, 100, 103, 108].forEach((n, i) => tone(midi(n), t + i * 0.07, 0.3, { type: 'triangle', vol: 0.09 })),
  fanfare: (t) => {
    arpeggio([67, 72, 76, 79], t, 0.13, { type: 'square', vol: 0.08 });
    tone(midi(84), t + 0.55, 0.7, { type: 'square', vol: 0.08 });
    tone(midi(76), t + 0.55, 0.7, { type: 'triangle', vol: 0.12 });
  },
  king: (t) => [43, 48, 52].forEach((n, i) => tone(midi(n), t + i * 0.18, 1.1, {
    type: 'sawtooth', vol: 0.12, filter: { type: 'lowpass', freq: 900 },
  })),
  help: (t) => {
    tone(620, t, 0.15, { type: 'square', slideTo: 420, vol: 0.08 });
    tone(620, t + 0.2, 0.2, { type: 'square', slideTo: 380, vol: 0.08 });
  },
  yay: (t, p) => tone(900 * p, t, 0.35, { slideTo: 2000 * p, vol: 0.12 }),
};

// Plays a sound effect. opts: volume (0 to 1), pitch (1 is normal).
export function sfx(name, opts = {}) {
  if (!ctx || ctx.state !== 'running' || !SOUNDS[name]) return;
  const t = ctx.currentTime + 0.005;
  if (opts.volume !== undefined && opts.volume < 1) {
    // play quieter by sending it through its own gain
    const g = ctx.createGain();
    g.gain.value = Math.max(0, opts.volume);
    g.connect(sfxGain);
    const real = sfxGain;
    sfxGain = g;
    SOUNDS[name](t, opts.pitch || 1);
    sfxGain = real;
    return;
  }
  SOUNDS[name](t, opts.pitch || 1);
}

// ---------- music ----------
//
// Each tune is made from a few settings and a seed, so every place sounds different:
// a chord pattern, a bouncy tune over the chords, a bass line and drums.
// Spooky tunes are slower, in a minor key, with a wobbly lead and no snare.

const SONGS = {
  title: { bpm: 126, root: 60, minor: false, seed: 1, lead: 'square' },
  park: { bpm: 120, root: 60, minor: false, seed: 2, lead: 'square' },
  school: { bpm: 128, root: 62, minor: false, seed: 3, lead: 'triangle' },
  carPark: { bpm: 124, root: 57, minor: false, seed: 4, lead: 'square' },
  beach: { bpm: 112, root: 65, minor: false, seed: 5, lead: 'triangle' },
  funfair: { bpm: 140, root: 60, minor: false, seed: 6, lead: 'square' },
  snow: { bpm: 108, root: 64, minor: false, seed: 7, lead: 'triangle', bells: true },
  toys: { bpm: 132, root: 67, minor: false, seed: 8, lead: 'square', bells: true },
  forest: { bpm: 100, root: 57, minor: true, seed: 9, lead: 'triangle', spooky: true },
  graveyard: { bpm: 92, root: 55, minor: true, seed: 10, lead: 'sine', spooky: true },
  castle: { bpm: 104, root: 50, minor: true, seed: 11, lead: 'sawtooth', spooky: true },
  party: { bpm: 146, root: 62, minor: false, seed: 12, lead: 'square' },
};

const MAJOR = [0, 2, 4, 5, 7, 9, 11];
const MINOR = [0, 2, 3, 5, 7, 8, 10];

function makeRandom(seed) {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
}

// Turns a song's settings into 8 bars of notes, 16 steps a bar.
function compose(song) {
  const rand = makeRandom(song.seed * 9973);
  const scale = song.minor ? MINOR : MAJOR;
  const chords = song.minor ? [0, 5, 2, 6] : [[0, 4, 5, 3], [0, 3, 4, 4], [0, 5, 3, 4]][song.seed % 3];
  const noteIn = (degree, octave) => song.root + octave * 12 + scale[((degree % 7) + 7) % 7] + 12 * Math.floor(degree / 7);
  // one bar's rhythm, used all through the tune so it's catchy
  const rhythm = [];
  for (let s = 0; s < 16; s++) rhythm.push(s % 4 === 0 || rand() < (song.spooky ? 0.2 : 0.38));
  const bars = [];
  let last = 0;
  for (let b = 0; b < 8; b++) {
    const chord = chords[b % 4];
    const steps = [];
    for (let s = 0; s < 16; s++) {
      let lead = null;
      if (rhythm[s]) {
        // mostly notes from the chord, stepping up and down
        const options = [chord, chord + 2, chord + 4, chord + 7, last + 1, last - 1];
        last = options[Math.floor(rand() * options.length)];
        if (b >= 4 && b % 4 === 3 && s >= 12) last = chord; // land on the chord at the end
        lead = noteIn(last, 1);
      }
      steps.push({ lead, bass: s % 4 === 0 ? noteIn(chord, -1) : null, chord: s === 0 ? chord : null });
    }
    bars.push(steps);
  }
  // the second half repeats the first, so you can hum along
  for (let b = 4; b < 7; b++) bars[b] = bars[b - 4];
  return { bars, noteIn };
}

let song = null;
let tune = null;
let step = 0;
let nextTime = 0;

export function music(id) {
  wantedSong = id;
  if (!ctx || (song && song.id === id)) return;
  song = { id, ...SONGS[id] };
  tune = compose(song);
  step = 0;
  nextTime = ctx.currentTime + 0.1;
}

function scheduleMusic() {
  if (!song || ctx.state !== 'running') return;
  const stepTime = 60 / song.bpm / 4;
  while (nextTime < ctx.currentTime + 0.15) {
    playStep(song, tune, step, nextTime);
    nextTime += stepTime;
    step++;
  }
}

// Plays one step of a tune (a sixteenth of a bar) at time t.
function playStep(song, tune, step, t) {
  const stepTime = 60 / song.bpm / 4;
  const bar = Math.floor(step / 16) % 8;
  const s = step % 16;
  const n = tune.bars[bar][s];
  const out = musicGain;
  if (n.lead) {
    const o = { type: song.lead, vol: song.lead === 'sine' ? 0.22 : 0.09, out };
    if (song.spooky) o.vibrato = { rate: 5, depth: 6 };
    tone(midi(n.lead), t, stepTime * (song.spooky ? 3 : 1.6), o);
    if (song.bells) tone(midi(n.lead + 12), t, stepTime * 2, { type: 'sine', vol: 0.04, out });
  }
  if (n.bass) tone(midi(n.bass), t, stepTime * 3, { type: 'triangle', vol: 0.28, out });
  if (n.chord !== null && song.spooky) {
    // a soft spooky "ooo" chord under everything
    for (const d of [0, 2, 4]) tone(midi(tune.noteIn(n.chord + d, 0)), t, stepTime * 15, { type: 'sine', vol: 0.05, attack: 0.4, out });
  }
  // drums
  if (s % 8 === 0) tone(150, t, 0.18, { slideTo: 45, vol: song.spooky ? 0.35 : 0.5, out });
  if (!song.spooky && s % 8 === 4) noise(t, 0.12, { freq: 1800, Q: 0.8, vol: 0.12, out });
  if (s % 2 === 0) noise(t, 0.04, { type: 'highpass', freq: 7000, vol: song.spooky ? 0.025 : 0.05, out });
}

// ---------- recording, for the Godot version ----------
// tools/export.js records every sound and tune to a file. These play them into an
// OfflineAudioContext instead of the speakers, mixed as the game does at full volume.

export const SOUND_NAMES = Object.keys(SOUNDS);
export const SONG_IDS = Object.keys(SONGS);

function record(seconds, sampleRate, play) {
  const saved = { ctx, musicGain, sfxGain, noiseBuffer, random };
  random = makeRandom(1);
  const offline = new OfflineAudioContext(1, Math.ceil(seconds * sampleRate), sampleRate);
  ctx = offline;
  sfxGain = offline.createGain();
  sfxGain.gain.value = 0.9;
  sfxGain.connect(offline.destination);
  musicGain = offline.createGain();
  musicGain.gain.value = 0.32;
  musicGain.connect(offline.destination);
  noiseBuffer = makeNoise(offline);
  try {
    play();
  } finally {
    ({ ctx, musicGain, sfxGain, noiseBuffer, random } = saved);
  }
  return offline.startRendering();
}

// Records a sound effect (2.5 seconds, the longest is under 2). Resolves to an AudioBuffer.
export function recordSound(name, sampleRate) {
  return record(2.5, sampleRate, () => SOUNDS[name](0.01, 1));
}

// Records one loop of a tune that joins up with itself: it plays the tune twice and keeps the
// second time round, which already has the end of the first time's notes ringing into it.
// Resolves to { buffer, loopStart, loopLength } (in samples).
export async function recordSong(id, sampleRate) {
  const s = { id, ...SONGS[id] };
  const t = compose(s);
  const steps = 8 * 16;
  const stepTime = 60 / s.bpm / 4;
  const buffer = await record(steps * stepTime * 2, sampleRate, () => {
    for (let i = 0; i < steps * 2; i++) playStep(s, t, i, i * stepTime);
  });
  return { buffer, loopStart: Math.round(steps * stepTime * sampleRate), loopLength: Math.round(steps * stepTime * sampleRate) };
}
