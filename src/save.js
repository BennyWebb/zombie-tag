// Saves progress in the browser, so the girls can stop and carry on another day.
// One save slot. It saves at the start of each level (and after shopping or training).

const KEY = 'zombie-tag-save';

export function loadSave() {
  try {
    const data = JSON.parse(localStorage.getItem(KEY));
    return data && data.version === 1 ? data : null;
  } catch {
    return null; // no save yet, or the browser won't let us read it
  }
}

export function writeSave(data) {
  try {
    localStorage.setItem(KEY, JSON.stringify({ version: 1, ...data }));
  } catch {
    // the browser won't let us save (private window); the game still works
  }
}

export function clearSave() {
  try {
    localStorage.removeItem(KEY);
  } catch {
    // nothing to clear
  }
}
