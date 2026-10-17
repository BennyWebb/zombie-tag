// Tracks which keys are held down by event.code, so two players can press keys at the same time.

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

export const isDown = (codes) => codes.some((c) => down.has(c));
export const wasPressed = (codes) => codes.some((c) => pressed.has(c));
export const endFrame = () => pressed.clear();

// How a key is shown on screen, e.g. KeyW → W
const KEY_NAMES = { Space: 'Space', Enter: 'Enter', Numpad0: '0', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };
export const keyName = (code) => KEY_NAMES[code] || code.replace(/^Key/, '');
