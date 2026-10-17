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

// Buttons on a standard joypad (Xbox layout; PlayStation's ✕ is A).
const B = { a: 0, b: 1, rt: 7, start: 9, up: 12, down: 13, left: 14, right: 15 };
let padDown = new Set(); // pretend keys held on joypads this frame
const padSticks = [null, null]; // each player's sticks: { move, strafe, turn }, from -1 to 1

const stick = (v) => (Math.abs(v) < CONFIG.controls.deadzone ? 0 : v);

// Reads the joypads once a frame. With 2 players and only one joypad, the joypad is Player 2's,
// so Player 1 can stay on the keyboard (or mouse).
export function pollPads(playerCount) {
  const pads = [...(navigator.getGamepads ? navigator.getGamepads() : [])].filter((p) => p && p.connected);
  const slots = playerCount === 2 && pads.length === 1 ? [null, pads[0]] : [pads[0], pads[1]];
  const now = new Set();
  slots.forEach((pad, i) => {
    padSticks[i] = null;
    if (!pad) return;
    const held = (b) => !!(pad.buttons[b] && pad.buttons[b].pressed);
    const [lx = 0, ly = 0, rx = 0] = pad.axes;
    const n = i + 1;
    // the d-pad or the left stick choose things in menus
    if (held(B.up) || ly < -0.5) now.add(`Pad${n}Up`);
    if (held(B.down) || ly > 0.5) now.add(`Pad${n}Down`);
    if (held(B.left) || lx < -0.5) now.add(`Pad${n}Left`);
    if (held(B.right) || lx > 0.5) now.add(`Pad${n}Right`);
    if (held(B.a) || held(B.rt)) now.add(`Pad${n}A`);
    if (held(B.start)) now.add('PadStart');
    // in the game: left stick walks and steps sideways, right stick turns; the d-pad walks and turns
    const dpad = (plus, minus) => (held(plus) ? 1 : 0) - (held(minus) ? 1 : 0);
    padSticks[i] = {
      move: -stick(ly) + dpad(B.up, B.down),
      strafe: stick(lx),
      turn: -stick(rx) + dpad(B.left, B.right),
    };
  });
  for (const code of now) if (!padDown.has(code)) pressed.add(code);
  // Start pauses, like Esc
  if (now.has('PadStart') && !padDown.has('PadStart')) pressed.add('Escape');
  padDown = now;
}

export const padFor = (index) => padSticks[index];

export const isDown = (codes) => codes.some((c) => down.has(c) || padDown.has(c));
export const wasPressed = (codes) => codes.some((c) => pressed.has(c));
export const endFrame = () => pressed.clear();

// How a key is shown on screen, e.g. KeyW → W
const KEY_NAMES = { Space: 'Space', Enter: 'Enter', Numpad0: '0', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };
export const keyName = (code) => KEY_NAMES[code] || code.replace(/^Key/, '');
