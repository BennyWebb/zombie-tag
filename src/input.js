import { CONFIG } from './config.js';

// Tracks which keys are held down by event.code, so two players can press keys at the same time.
// Joypads and the mouse are turned into pretend keys too (Pad1Up, Pad2A, Mouse0...), so every menu
// works with them without knowing the difference.

const down = new Set();
const pressed = new Set(); // keys pressed since the last endFrame()

const GAME_KEYS = new Set([
  'Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter', 'NumpadEnter', 'Numpad0',
]);

window.addEventListener('keydown', (e) => {
  if (GAME_KEYS.has(e.code)) e.preventDefault(); // stop the page scrolling
  if (!e.repeat) pressed.add(e.code);
  down.add(e.code);
});
window.addEventListener('keyup', (e) => down.delete(e.code));
window.addEventListener('blur', () => down.clear());

// ---------- the mouse (Player 1's mouse controls) ----------

let mouseX = 0; // how far the mouse has moved sideways since it was last read
window.addEventListener('mousemove', (e) => {
  mouseX += e.movementX || 0;
});
window.addEventListener('mousedown', (e) => {
  if (e.button !== 0) return;
  pressed.add('Mouse0');
  down.add('Mouse0');
});
window.addEventListener('mouseup', (e) => {
  if (e.button === 0) down.delete('Mouse0');
});

export function takeMouseX() {
  const x = mouseX;
  mouseX = 0;
  return x;
}

// ---------- joypads ----------

// Buttons on a standard joypad (Xbox layout). All four face buttons and the right trigger fire.
const B = { rt: 7, select: 8, start: 9, up: 12, down: 13, left: 14, right: 15 };
const FIRE = [0, 1, 2, 3, B.rt];
let padDown = new Set(); // pretend keys held on joypads this frame
let padPressed = false; // any joypad button pressed this frame (sound starts on it, like on a key)
let padSticks = [null, null]; // each player's sticks: { move, strafe, turn }, from -1 to 1

const stick = (v) => (Math.abs(v) < CONFIG.controls.deadzone ? 0 : v);

// Simple joypads: the left stick (or d-pad) walks and turns, like the arrow keys.
// Two sticks: the left stick walks and steps sideways, the right stick turns.
let twoSticks = false;
export function setTwoSticks(on) {
  twoSticks = on;
}

// Which player each joypad belongs to, by the browser's joypad number. A joypad belongs to whoever
// presses fire on it when it's her turn on "Who's playing?". Until then it only works the menus
// (as PadAny...), so it never moves a hero by mistake.
const padOwner = new Map();
let firedPads = []; // joypads nobody owns that pressed fire this frame
// (one controller can show up as two joypads, e.g. with Steam running, so they're claimed together)
const firing = new Set(); // joypads holding fire last frame

export function clearPads() {
  padOwner.clear();
}

export function givePad(pad, player) {
  padOwner.set(pad, player);
}

export const unownedPadsFired = () => firedPads;
export const playerHasPad = (player) => [...padOwner.values()].includes(player);
export const padsFound = () => [...(navigator.getGamepads ? navigator.getGamepads() : [])].filter((p) => p && p.connected).length;

// Some joypads (often ones with only a d-pad) report the d-pad as a "hat": one axis that goes round
// in eighths, from -1 (up) clockwise to 1 (up-left), and rests at about 1.29. An axis seen resting
// above 1 is a hat, as no stick goes past 1.
const hats = new Map(); // joypad number -> which axis is its hat
const HAT_DIRS = [['up'], ['up', 'right'], ['right'], ['down', 'right'], ['down'], ['down', 'left'], ['left'], ['up', 'left']];
function readHat(pad) {
  if (!hats.has(pad.index)) {
    const i = pad.axes.findIndex((v) => v > 1.1);
    if (i < 0) return [];
    hats.set(pad.index, i);
  }
  const v = pad.axes[hats.get(pad.index)];
  if (v === undefined || Math.abs(v) > 1.05) return []; // resting
  return HAT_DIRS[Math.round(((v + 1) * 7) / 2)] || [];
}

// Reads the joypads once a frame.
export function pollPads() {
  const pads = [...(navigator.getGamepads ? navigator.getGamepads() : [])].filter((p) => p && p.connected);
  const now = new Set();
  firedPads = [];
  padSticks = [null, null];
  for (const pad of pads) {
    const hat = readHat(pad);
    // the d-pad's buttons, or its hat
    const held = (b) => !!(pad.buttons[b] && pad.buttons[b].pressed)
      || (b === B.up && hat.includes('up')) || (b === B.down && hat.includes('down'))
      || (b === B.left && hat.includes('left')) || (b === B.right && hat.includes('right'));
    const [lx = 0, ly = 0, rx = 0] = pad.axes;
    // A joypad without a right stick (often a d-pad that shows up as the left stick) always plays
    // Simple, so left and right turn even when joypads are set to Two sticks.
    const sticks2 = twoSticks && pad.axes.length >= 4 && !hats.has(pad.index);
    const owner = padOwner.get(pad.index);
    const n = owner === undefined ? 'Any' : owner + 1;
    // the d-pad or the left stick choose things in menus
    if (held(B.up) || ly < -0.5) now.add(`Pad${n}Up`);
    if (held(B.down) || ly > 0.5) now.add(`Pad${n}Down`);
    if (held(B.left) || lx < -0.5) now.add(`Pad${n}Left`);
    if (held(B.right) || lx > 0.5) now.add(`Pad${n}Right`);
    const fire = FIRE.some(held);
    if (fire) now.add(`Pad${n}A`);
    if (fire && !firing.has(pad.index) && owner === undefined) firedPads.push(pad.index);
    if (fire) firing.add(pad.index);
    else firing.delete(pad.index);
    if (held(B.start)) now.add('PadStart');
    if (held(B.select)) now.add('PadSelect'); // Back / View / Share / Select
    if (owner === undefined) continue;
    // in the game the d-pad always walks and turns
    const dpad = (plus, minus) => (held(plus) ? 1 : 0) - (held(minus) ? 1 : 0);
    const sticks = {
      move: -stick(ly) + dpad(B.up, B.down),
      strafe: sticks2 ? stick(lx) : 0,
      turn: -stick(sticks2 ? rx : lx) + dpad(B.left, B.right),
    };
    // a player with two joypads (one controller showing up twice) gets whichever is pushed
    const had = padSticks[owner];
    const bigger = (a, b) => (Math.abs(a) > Math.abs(b) ? a : b);
    padSticks[owner] = had
      ? { move: bigger(had.move, sticks.move), strafe: bigger(had.strafe, sticks.strafe), turn: bigger(had.turn, sticks.turn) }
      : sticks;
  }
  padPressed = false;
  for (const code of now) {
    if (padDown.has(code)) continue;
    pressed.add(code);
    padPressed = true;
  }
  // Start pauses, like Esc
  if (now.has('PadStart') && !padDown.has('PadStart')) pressed.add('Escape');
  padDown = now;
}

export const padFor = (index) => padSticks[index];
export const anyPadPressed = () => padPressed;
// Pretends a key was pressed, e.g. Escape for the TV remote's Back button.
export const pressKey = (code) => pressed.add(code);

export const isDown = (codes) => codes.some((c) => down.has(c) || padDown.has(c));
export const wasPressed = (codes) => codes.some((c) => pressed.has(c));
export const endFrame = () => pressed.clear();

// How a key is shown on screen, e.g. KeyW → W, Pad2Up → 🎮↑
const KEY_NAMES = { Space: 'Space', Enter: 'Enter', Numpad0: '0', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };
const PAD_NAMES = { Up: '🎮↑', Down: '🎮↓', Left: '🎮←', Right: '🎮→', A: '🎮 fire' };
export const keyName = (code) => {
  const pad = code.match(/^Pad(?:\d|Any)(Up|Down|Left|Right|A)$/);
  if (pad) return PAD_NAMES[pad[1]];
  return KEY_NAMES[code] || code.replace(/^Key/, '');
};
