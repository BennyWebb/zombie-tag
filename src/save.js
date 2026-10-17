// Saves progress in the browser, so the girls can stop and carry on another day.
// Every hero has her own saved profile (looks, Tag Bux, weapons, training, levels reached).
// It saves at the start of each level, after shopping or training, and when you get tagged.

const KEY = 'zombie-tag-save';

// Version 1 had one save for Player 1 and Player 2. Turn their heroes into profiles,
// each with the levels they'd reached together, so nobody loses anything.
function fromVersion1(data) {
  const profiles = [];
  const chosen = [];
  (data.players || []).forEach((p, i) => {
    if (!p || !p.created) return;
    const id = `hero${i + 1}`;
    profiles.push({ ...p, id, unlocked: data.unlocked || 1, finished: data.finished || [], trained: {} });
    chosen[i] = id;
  });
  return { version: 2, profiles, chosen, playerCount: data.playerCount || 1, difficulty: 'easy' };
}

export function loadSave() {
  try {
    const data = JSON.parse(localStorage.getItem(KEY));
    if (data && data.version === 1) return fromVersion1(data);
    return data && data.version === 2 ? data : null;
  } catch {
    return null; // no save yet, or the browser won't let us read it
  }
}

export function writeSave(data) {
  try {
    localStorage.setItem(KEY, JSON.stringify({ version: 2, ...data }));
  } catch {
    // the browser won't let us save (private window); the game still works
  }
}
