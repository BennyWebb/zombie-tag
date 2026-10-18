import * as THREE from 'three';
import { CONFIG } from './config.js';
import {
  clearPads, endFrame, givePad, padsFound, pollPads, setTwoSticks, takeMouseX,
  unownedPadsFired, wasPressed,
} from './input.js';
import { buildWorld } from './world.js';
import { THEMES } from './themes.js';
import { Zombie } from './zombie.js';
import { Player } from './player.js';
import { Effects } from './effects.js';
import { Coins } from './coins.js';
import { SPLASH_COLOURS, Shots } from './weapons.js';
import { ShopMenu } from './shop.js';
import { GymMenu } from './gym.js';
import { Hud } from './hud.js';
import { Creator } from './creator.js';
import { loadSave, writeSave } from './save.js';
import { getVolumes, loudness, music, setVolume, sfx } from './audio.js';

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false; // drawn once a frame, even when the screen is split
document.getElementById('game').appendChild(renderer.domElement);

const $ = (id) => document.getElementById(id);
const screens = {
  title: $('title'), who: $('who'), remove: $('remove'), create: $('creator'), difficulty: $('difficulty'),
  levels: $('levels'), paused: $('paused'), won: $('won'), party: $('party'), gameover: $('gameover'),
};

const scene = new THREE.Scene();
const effects = new Effects(scene);
const coins = new Coins(scene);
const shots = new Shots(scene);

let levelIndex = 0; // which level (0 is level 1)
let level = null; // its settings from config.js
let world = null; // its park, school, beach...

// Both heroes always exist; in 1-player mode only the first one plays.
// Each player picks the keyboard (with the mouse, if mouse controls are on) or a joypad on
// "Who's playing?". Two players can also share the keyboard (left half and right half).
const KEYBOARD = CONFIG.keys.keyboard;
const DEVICE_KEYS = { keyboard: KEYBOARD, keysLeft: CONFIG.keys.left, keysRight: CONFIG.keys.right };
// the mouse goes with the whole keyboard, or with the left half when sharing
const usesMouse = (p) => p.device === 'keyboard' || p.device === 'keysLeft';
const padKeys = (n) => ({
  forward: [`Pad${n}Up`], back: [`Pad${n}Down`], left: [`Pad${n}Left`], right: [`Pad${n}Right`], attack: [`Pad${n}A`],
});
// menus anyone can use: the keyboard, or any joypad
const menu = {};
for (const [dir, pad] of [['forward', 'Up'], ['back', 'Down'], ['left', 'Left'], ['right', 'Right']]) {
  menu[dir] = [...KEYBOARD[dir], `Pad1${pad}`, `Pad2${pad}`, `PadAny${pad}`];
}
const players = CONFIG.heroes.map((look, i) => new Player(KEYBOARD, scene, look, i));
const huds = players.map((p, i) => new Hud($('hud'), p, i + 1));
const menus = players.map((p, i) => ({
  shop: new ShopMenu(huds[i].inner, p, null),
  gym: new GymMenu(huds[i].inner, p, null),
}));
for (const m of menus) m.shop.onGive = flyCoins;
const creator = new Creator($('creator'));
// a camera for close-ups: the character creator's hero, and the party at the end
const showCamera = new THREE.PerspectiveCamera(40, 1, 0.1, 300);
showCamera.layers.enable(3);
showCamera.layers.enable(4);

let state = 'title';
let playerCount = 1;
let titleChoice = 0; // 0: 1 player, 1: 2 players
let levelChoice = 0; // the level picked on the level select screen
let profiles = []; // every saved hero, from the "Who's playing?" screen
let chosen = []; // the profile id playing as Player 1 and Player 2 last time
let whoSlot = 0; // which player is choosing on "Who's playing?"
let whoChoice = 0; // the row she's on
let editLooks = false; // pressing C on the start screen lets heroes change how they look
let removing = null; // the profile the "Delete?" screen is asking about
const difficultyIds = Object.keys(CONFIG.difficulties);
let difficultyId = 'easy';
let gameOverIn = 0; // Hardcore: counts down to the game over screen once everyone is tagged
let active = [players[0]]; // the heroes playing right now
let zombies = [];
let regulars = 0; // zombies that arrive in waves this level
let levelZombies = 0; // zombies to pop this level (goes up when slime splits or the King calls for help)
let spawned = 0;
let popped = 0;
let boss = null; // the Zombie King, once he arrives
let friends = []; // the zombies at the party
let pauseRow = 0; // which row of the pause menu is chosen: music, sounds, Player 1's controls or joypads
const PAUSE_ROWS = 4;
const CONTROLS_KEY = 'zombie-tag-controls';
const PADS_KEY = 'zombie-tag-joypads';
let mouseLook = false; // Player 1 uses the mouse to turn (the browser remembers this choice)
let twoSticks = false; // joypads use the right stick to turn, instead of the simple left stick
try {
  mouseLook = localStorage.getItem(CONTROLS_KEY) === 'mouse';
  twoSticks = localStorage.getItem(PADS_KEY) === 'twoSticks';
} catch {
  // no saved choice: simple keyboard and joypad controls
}
setTwoSticks(twoSticks);
let lockLostAt = -1; // when the mouse was last let go, so the same Esc doesn't pause and unpause
let coinStreak = 0; // coins picked up one after another go up in pitch
let lastCoin = 0;
let lastGroan = 0;

// The sound a hit makes, by kind of shot (swinging weapons go "boing").
const HIT_SOUNDS = { slime: 'splat', bubble: 'bloop', snowball: 'poof', banana: 'bonk' };

function show(name) {
  state = name;
  for (const [key, el] of Object.entries(screens)) el.classList.toggle('hidden', key !== name);
  $('hud').classList.toggle('hidden', !['playing', 'paused', 'won'].includes(name));
  for (const p of active) {
    p.hand.visible = (name === 'playing' || name === 'paused') && !p.inside && !p.tagged;
  }
  if (name !== 'playing') huds.forEach((h) => h.clearToast());
  if (name !== 'playing' && document.pointerLockElement) document.exitPointerLock();
  if (name === 'title') drawTitle();
  if (name === 'who') drawWho();
  if (name === 'remove') drawRemove();
  if (name === 'difficulty') drawDifficulty();
  if (name === 'levels') drawLevels();
  if (name === 'paused') drawVolume();
  if (['title', 'who', 'remove', 'difficulty', 'levels', 'create', 'gameover'].includes(name)) music('title');
}

// The pause menu's music and sound volume bars, and Player 1's controls.
function drawVolume() {
  const v = getVolumes();
  const bar = (n) => '▮'.repeat(n) + '<span class="off">' + '▮'.repeat(10 - n) + '</span>';
  $('volume').innerHTML = [['music', '🎵 Music'], ['sounds', '🔊 Sounds']].map(([key, label], i) => (
    `<div class="vol${i === pauseRow ? ' selected' : ''}"><span>${label}</span><b>${bar(v[key])}</b></div>`
  )).join('') + `<div class="vol${pauseRow === 2 ? ' selected' : ''}"><span>🖱️ Keyboard</span>`
    + `<b class="mode">${mouseLook ? 'Mouse' : 'Simple keys'}</b></div>`
    + `<div class="vol${pauseRow === 3 ? ' selected' : ''}"><span>🎮 Joypads</span>`
    + `<b class="mode">${twoSticks ? 'Two sticks' : 'Simple'}</b></div>`;
}

// Simple joypads: the left stick walks and turns. Two sticks: the right stick turns.
function setPadMode(on) {
  twoSticks = on;
  setTwoSticks(on);
  try {
    localStorage.setItem(PADS_KEY, on ? 'twoSticks' : 'simple');
  } catch {
    // the browser won't let us remember it
  }
}

// Simple keys: A/D turn. Mouse: A/D step sideways, the mouse turns, click to attack.
function setMouseLook(on) {
  mouseLook = on;
  for (const p of players) p.mouseLook = on && usesMouse(p);
  try {
    localStorage.setItem(CONTROLS_KEY, on ? 'mouse' : 'keys');
  } catch {
    // the browser won't let us remember it; it still works until the page closes
  }
  if (!on && document.pointerLockElement) document.exitPointerLock();
}

// Mouse controls hide the pointer while you play, so the mouse can turn you all the way round.
function lockMouse() {
  if (!mouseLook || state !== 'playing' || document.pointerLockElement) return;
  try {
    const p = renderer.domElement.requestPointerLock();
    if (p && p.catch) p.catch(() => {}); // too soon after Esc: clicking the game tries again
  } catch {
    // no pointer lock here; turning still works while the pointer is over the game
  }
}
renderer.domElement.addEventListener('mousedown', lockMouse);
document.addEventListener('pointerlockchange', () => {
  // Esc lets go of the mouse; treat that as pausing
  if (!document.pointerLockElement && state === 'playing') {
    lockLostAt = clock.elapsedTime;
    show('paused');
  }
});

const toastAll = (text, seconds) => active.forEach((p) => huds[p.index].toast(text, seconds));

// ---------- saving ----------

const difficulty = () => CONFIG.difficulties[difficultyId];

// Each hero playing is saved into her own profile.
function saveGame() {
  for (const p of active) {
    if (!p.created || !p.profileId) continue;
    const i = profiles.findIndex((d) => d.id === p.profileId);
    if (i >= 0) profiles[i] = p.toSave();
    else profiles.push(p.toSave());
  }
  chosen = active.map((p) => p.profileId);
  writeSave({ profiles, chosen, playerCount, difficulty: difficultyId });
}

function restoreSave() {
  const data = loadSave();
  if (!data) return;
  profiles = (data.profiles || []).filter((d) => d && d.id && d.created);
  chosen = data.chosen || [];
  playerCount = data.playerCount || 1;
  titleChoice = playerCount - 1;
  if (CONFIG.difficulties[data.difficulty]) difficultyId = data.difficulty;
  // put last time's heroes back in their slots
  chosen.forEach((id, i) => {
    const d = profiles.find((x) => x.id === id);
    if (d && players[i]) players[i].fromSave(d);
  });
  const names = chosen.map((id) => profiles.find((d) => d.id === id)).filter(Boolean).map((d) => d.look.name);
  if (names.length) $('welcome').textContent = `Welcome back, ${names.join(' and ')}!`;
}

// The levels the heroes playing can pick: in 2-player mode, the furthest either has reached.
const unlockedNow = () => Math.max(1, ...active.map((p) => p.unlocked));
const finishedNow = (i) => active.some((p) => p.finished.has(i));

// ---------- the start screen and level select ----------

function drawTitle() {
  document.querySelectorAll('#title .choice').forEach((el, i) => el.classList.toggle('selected', i === titleChoice));
  $('p1-keys').innerHTML = '<div class="who-keys">⌨️ Keyboard</div>' + (mouseLook
    ? '<div><kbd>W</kbd> <kbd>S</kbd> walk, <kbd>A</kbd> <kbd>D</kbd> step</div><div>🖱️ mouse turns</div><div>click bonk!</div>'
    : '<div><kbd>W</kbd> <kbd>S</kbd> walk</div><div><kbd>A</kbd> <kbd>D</kbd> turn</div><div><kbd>Space</kbd> bonk!</div>');
  $('controls-mode').textContent = mouseLook ? 'with the mouse' : 'simple keys';
  $('pads-mode').textContent = `${twoSticks ? 'two sticks' : 'simple'} (${padsFound()} found)`;
}

function drawLevels() {
  const d = difficulty();
  $('levels-mode').textContent = `${d.icon} ${d.name}`;
  $('levels').querySelector('.level-grid').innerHTML = CONFIG.levels.map((l, i) => {
    const locked = i >= unlockedNow();
    return `<div class="tile${locked ? ' locked' : ''}${i === levelChoice ? ' selected' : ''}">`
      + `${finishedNow(i) ? '<span class="badge-done">⭐</span>' : ''}`
      + `<div class="big">${locked ? '🔒' : l.icon}</div><div class="num">Level ${i + 1}</div>`
      + `<div class="nm">${l.name}</div></div>`;
  }).join('');
}

// ---------- who's playing, the character creator and difficulty ----------

// After choosing 1 or 2 players, each picks her saved hero (or a new one) in turn.
// `everyone` (the C key) lets heroes who already exist change how they look.
function beginGame(everyone) {
  editLooks = everyone;
  active = players.slice(0, playerCount);
  clearPads(); // each joypad goes to whoever presses fire on it on "Who's playing?"
  for (const p of players) p.device = null;
  startWho(0);
}

// Whether the keyboard is still free for the player choosing now, or who has it.
const keyboardOwner = () => players.slice(0, whoSlot).find((p) => p.device === 'keyboard');
const keyboardFree = () => !keyboardOwner();

// Gives a player the keyboard (and the mouse), half the keyboard, or the joypad(s) she pressed fire on.
function setDevice(p, device, pads = []) {
  p.device = device;
  p.keys = DEVICE_KEYS[device] || padKeys(p.index + 1);
  p.mouseLook = mouseLook && usesMouse(p);
  for (const pad of pads) givePad(pad, p.index);
}

function startWho(slot) {
  whoSlot = slot;
  const rows = whoRows();
  // start on the hero who played in this slot last time
  whoChoice = Math.max(0, rows.findIndex((r) => r.profile && r.profile.id === chosen[slot] && !r.taken));
  if (rows[whoChoice].taken) whoChoice = Math.max(0, rows.findIndex((r) => !r.taken));
  show('who');
}

// Every saved hero, then "New hero" if there's room.
function whoRows() {
  const takenBy = players.slice(0, whoSlot).map((p) => p.profileId);
  const rows = profiles.map((profile) => ({ profile, taken: takenBy.includes(profile.id) }));
  if (profiles.length + whoSlot < CONFIG.maxProfiles) rows.push({ newHero: true });
  return rows;
}

function drawWho() {
  const p = players[whoSlot];
  const hex = (c) => `#${c.toString(16).padStart(6, '0')}`;
  const badge = $('who').querySelector('.who-badge');
  badge.className = `who-badge p${whoSlot + 1}`;
  badge.textContent = playerCount === 2 ? `Player ${whoSlot + 1}` : '';
  badge.classList.toggle('hidden', playerCount === 1);
  $('who').querySelector('.hero-list').innerHTML = whoRows().map((r, i) => {
    const sel = i === whoChoice ? ' selected' : '';
    if (r.newHero) return `<div class="hero-card new${sel}"><span class="dot">➕</span><b>New hero</b></div>`;
    const d = r.profile;
    const stars = (d.finished || []).length;
    return `<div class="hero-card${sel}${r.taken ? ' taken' : ''}">`
      + `<span class="dot" style="background:${hex(d.look.outfit)}"></span><b>${d.look.name}</b>`
      + `<small>${r.taken ? 'Playing as Player 1' : `⭐ ${stars} &nbsp; <span class="coin">T</span> ${d.tagBux}`}</small></div>`;
  }).join('');
  // the button you pick with decides what you play with
  $('who-keys').innerHTML = keyboardFree()
    ? '<kbd>Space</kbd> to play with the ⌨️ keyboard, or 🎮 fire to play with a joypad'
    : '🎮 fire to play with a joypad, or <kbd>Enter</kbd> to share the ⌨️ keyboard'
      + '<br><small style="font-size: 0.7em">Sharing: Player 1 uses <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> + <kbd>Space</kbd>,'
      + ' Player 2 uses the arrows + <kbd>Enter</kbd></small>';
}

function chooseWho(device, pads) {
  const rows = whoRows();
  const r = rows[whoChoice];
  const p = players[whoSlot];
  if (r.taken) {
    sfx('nope');
    return;
  }
  sfx('select');
  // sharing: whoever had the whole keyboard moves over to the left half
  if (device === 'keysRight') setDevice(keyboardOwner(), 'keysLeft');
  setDevice(p, device, pads);
  if (r.newHero) p.blank(`hero${Date.now().toString(36)}${whoSlot}`);
  else p.fromSave(r.profile);
  if (whoSlot + 1 < playerCount) {
    startWho(whoSlot + 1);
    return;
  }
  // make any new heroes (or let everyone change how they look), then pick how hard
  const heroes = active.filter((h) => editLooks || !h.created);
  const next = () => {
    saveGame();
    show('difficulty');
  };
  if (!heroes.length) {
    next();
    return;
  }
  show('create');
  creator.start(heroes, next);
}

function drawRemove() {
  $('remove-name').textContent = `Delete ${removing.look.name}?`;
}

function drawDifficulty() {
  const d = CONFIG.difficulties;
  $('difficulty').querySelector('.choices').innerHTML = difficultyIds.map((id) => (
    `<div class="choice mode${id === difficultyId ? ' selected' : ''}"><b>${d[id].icon} ${d[id].name}</b><small>${d[id].about}</small></div>`
  )).join('');
}

// ---------- levels ----------

// Builds a level's world (the shop and gym go in new random spots every time).
function loadLevel(i) {
  if (world) {
    scene.remove(world.group);
    world.group.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) [].concat(o.material).forEach((m) => { if (m.map) m.map.dispose(); m.dispose(); });
    });
  }
  levelIndex = i;
  level = { ...CONFIG.levels[i], number: i + 1 };
  world = buildWorld(scene, level, THEMES[level.theme]);
  for (const m of menus) {
    m.shop.building = world.shop;
    m.gym.building = world.gym;
    m.gym.levelIndex = i;
  }
}

// Where each hero begins: side by side in 2-player mode.
function startFor(p) {
  const s = world.playerStart;
  const side = playerCount === 2 ? (p.index === 0 ? -1.5 : 1.5) : 0;
  return { x: s.x + side, z: s.z, yaw: s.yaw };
}

function clearZombies() {
  for (const z of zombies) scene.remove(z.root);
  zombies = [];
  for (const f of friends) scene.remove(f.root);
  friends = [];
}

function startLevel(i) {
  for (const p of players) if (p.inside) p.menu.close();
  loadLevel(i);
  clearZombies();
  spawned = 0;
  popped = 0;
  boss = null;
  coins.clear();
  shots.clear();
  gameOverIn = 0;

  const two = playerCount === 2;
  active = players.slice(0, playerCount);
  regulars = Math.round(level.zombies * (two ? CONFIG.twoPlayerZombies : 1) * (difficulty().zombies || 1));
  levelZombies = regulars + (level.boss ? 1 : 0);
  $('hud').classList.toggle('split', two);
  huds[1].el.classList.toggle('hidden', !two);
  for (const p of active) {
    // Tag Bux, weapons, armour and training are all kept from level to level
    p.taggedTime = two ? CONFIG.player.taggedTimeTwoPlayers : CONFIG.player.taggedTime;
    p.respawn(startFor(p)); // full hearts, and armour shields filled up
    huds[p.index].showTagged(false);
    if (!p.weapon) p.giveStick();
    menus[p.index].shop.partner = two ? players[1 - p.index] : null;
  }
  saveGame(); // progress saves at the start of each level
  show('playing');
  music(level.theme);
  const d = difficulty();
  toastAll(`Level ${level.number}: ${level.name} ${level.icon} &nbsp; ${d.icon} ${d.name}`
    + '<br>Pop all the zombies, then find the exit gate!', 4);
  if (mouseLook) {
    lockMouse();
    huds[0].toast('🖱️ Click the game to turn with the mouse', 3);
  }
}

function addZombie(kind, x, z) {
  const zombie = new Zombie(kind, level.healthMultiplier, x, z);
  zombies.push(zombie);
  scene.add(zombie.root);
  return zombie;
}

// Picks a kind of zombie for this level, more often the ones with a bigger number in `mix`.
function pickKind() {
  const kinds = Object.entries(level.mix);
  let roll = Math.random() * kinds.reduce((sum, [, n]) => sum + n, 0);
  for (const [kind, n] of kinds) {
    roll -= n;
    if (roll < 0) return kind;
  }
  return kinds[0][0];
}

// A clear spot away from the heroes.
function spawnSpot(radius) {
  const a = CONFIG.arena;
  for (let tries = 0; tries < 100; tries++) {
    const x = (Math.random() - 0.5) * (a.size - 6);
    const z = (Math.random() - 0.5) * (a.size - 6);
    if (active.some((p) => Math.hypot(x - p.pos.x, z - p.pos.z) < a.spawnAway)) continue;
    if (world.isClear(x, z, radius)) return { x, z };
  }
  return null;
}

function spawnWave() {
  const count = Math.min(CONFIG.arena.waveSize * (difficulty().zombies || 1), regulars - spawned);
  for (let i = 0; i < count; i++) {
    const kind = pickKind();
    const spot = spawnSpot(CONFIG.zombies[kind].radius + 0.5);
    if (!spot) break;
    addZombie(kind, spot.x, spot.z);
    spawned++;
  }
}

// The final battle: once every other zombie is popped, the Zombie King arrives at the exit gate
// end of his castle. On Hard and Hardcore he's tougher, faster and tags you in one go.
function spawnBoss() {
  boss = addZombie(level.boss, world.gate.x, world.gate.z + 8);
  const king = difficulty().king;
  if (king) {
    boss.type = { ...boss.type, ...king };
    boss.maxHealth = king.health * level.healthMultiplier;
    boss.health = boss.maxHealth;
  }
  // his guards arrive with him, in a ring round him
  const guards = boss.type.guards * (difficulty().zombies || 1);
  for (let i = 0; i < guards; i++) {
    const a = (i / guards) * Math.PI * 2;
    const x = boss.pos.x + Math.cos(a) * 4;
    const z = boss.pos.z + Math.sin(a) * 4;
    if (!world.isClear(x, z, 0.8)) continue;
    addZombie(pickKind(), x, z);
    levelZombies++;
  }
  sfx('king');
  toastAll(king && king.instantTag
    ? '👑 THE ZOMBIE KING IS HERE! 👑<br>Don\'t let him touch you, he tags you in one go!'
    : '👑 The Zombie King is here! The final battle!<br>He keeps calling Shufflers to help him!', 4);
}

// The King calls in a few Shufflers. They count as zombies to pop.
function callHelpers(king) {
  king.callingHelp = false;
  const t = king.type;
  const helpersAlive = zombies.filter((z) => z.alive && z.helper).length;
  const n = Math.min(t.helpers, t.maxHelpers - helpersAlive);
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2;
    const x = king.pos.x + Math.cos(a) * 3;
    const z = king.pos.z + Math.sin(a) * 3;
    if (!world.isClear(x, z, 0.6)) continue;
    addZombie('shuffler', x, z).helper = true;
    levelZombies++;
  }
  if (n > 0) sfx('help');
  if (n > 0) effects.floatText(king.centre.add(new THREE.Vector3(0, 2.5, 0)), 'HELP!', '#ff8ad8', 2);
}

// ---------- hits and touches ----------

// Coins fly across the screen from the giver's shop to her sister's Tag Bux counter.
function flyCoins(giver, receiver) {
  const from = huds[giver.index].q('.shop-bux').getBoundingClientRect();
  const to = huds[receiver.index].q('.bux').getBoundingClientRect();
  for (let i = 0; i < 5; i++) {
    const c = document.createElement('span');
    c.className = 'coin flying';
    c.textContent = 'T';
    c.style.left = `${from.left + from.width / 2}px`;
    c.style.top = `${from.top + from.height / 2}px`;
    document.body.appendChild(c);
    setTimeout(() => {
      c.style.transform = `translate(${to.left + to.width / 2 - from.left - from.width / 2}px, `
        + `${to.top + to.height / 2 - from.top - from.height / 2}px)`;
    }, 30 + i * 90);
    setTimeout(() => {
      c.remove();
      huds[receiver.index].bumpBux();
    }, 30 + i * 90 + 800);
  }
}

function hitZombie({ zombie, weapon, by, push, at, splat }) {
  if (splat) {
    // a pumpkin landed: a big orange splat
    effects.splash(at, 60, SPLASH_COLOURS.pumpkin, 2.5);
    sfx('splat', { pitch: 2 });
    effects.floatText(at.clone().setY(at.y + 1.2), weapon.word, '#ff8a1f', 1.8);
    return;
  }
  if (!zombie.alive) return;
  if (weapon.shot && at) effects.splash(at, 12, SPLASH_COLOURS[weapon.shot]);
  zombie.weaponEffects(weapon);
  if (weapon.knockback && push) zombie.knock(push, weapon.knockback);
  const wobble = 0.9 + Math.random() * 0.25; // so the same sound twice doesn't sound robotic
  if (weapon.id === 'chickenHammer') sfx('squawk', { pitch: wobble });
  else if (weapon.kind === 'swing') sfx('bonk', { pitch: wobble });
  else if (HIT_SOUNDS[weapon.shot]) sfx(HIT_SOUNDS[weapon.shot], { pitch: wobble * (weapon.shot === 'banana' ? 1.3 : 1) });
  const popping = zombie.hit(weapon.damage * by.damageMultiplier);
  const word = weapon.word || 'BONK!';
  // the chicken squawks on every hit, even ones that pop
  if (weapon.id === 'chickenHammer') {
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, popping ? 2 : 0.8, 0)), word, '#ffe066', 1.3);
  }
  if (popping) popZombie(zombie);
  else if (weapon.id !== 'chickenHammer' && !(zombie.wordTime > clock.elapsedTime - 0.6)) {
    // fast weapons hit so often that they only say their word now and then
    zombie.wordTime = clock.elapsedTime;
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, 0.8, 0)), word, '#ffe066', 1.1);
  }
}

function popZombie(zombie) {
  const t = zombie.type;
  effects.confetti(zombie.centre, t.boss ? 300 : 70);
  effects.floatText(zombie.centre.add(new THREE.Vector3(0, 1 * t.size, 0)), 'POP!', '#9cff57', 1.4 * t.size);
  coins.burst(zombie.centre, t.tagBux);
  sfx('pop', { pitch: (0.95 + Math.random() * 0.2) / t.size });
  scene.remove(zombie.root);
  popped++;
  if (t.splitsInto) {
    // a Slime Zombie splits into two little Shufflers
    for (const side of [-1, 1]) {
      const x = zombie.pos.x + side * Math.cos(zombie.yaw) * 0.9;
      const z = zombie.pos.z - side * Math.sin(zombie.yaw) * 0.9;
      addZombie(t.splitsInto, x, z);
      levelZombies++;
    }
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, 2, 0)), 'SPLIT!', '#7dff4f', 1.4);
    sfx('split');
  }
  if (t.boss) {
    sfx('fanfare');
    toastAll('👑 You popped the Zombie King! 👑', 4);
  }
}

// A zombie touched a hero: lose a shield or a heart, flash, and bump the zombie back.
function zombieTouch(zombie, p) {
  const instant = zombie.type.instantTag; // the Zombie King on Hard and Hardcore
  const hurt = p.hurt(instant ? CONFIG.player.hearts : zombie.type.touchHearts, instant);
  if (!hurt) return;
  const hud = huds[p.index];
  const away = new THREE.Vector3(zombie.pos.x - p.pos.x, 0, zombie.pos.z - p.pos.z).normalize();
  zombie.knock(away, zombie.type.bounceBack);
  zombie.dizzy = zombie.type.dizzyTime;
  hud.flash(hurt);
  sfx(p.tagged ? 'tagged' : hurt === 'shield' ? 'clang' : 'ouch');
  if (p.tagged) gotTagged(p);
  else if (hurt === 'shield') hud.toast('Your armour blocked it! 🛡️<br>Run away!', 1.5);
  else if (zombie.type.touchHearts > 1) hud.toast(`${zombie.type.name} took ${zombie.type.touchHearts} hearts! 💔<br>Run away!`, 1.5);
  else hud.toast(p.hearts === 1 ? 'Ouch! Last heart! 💔<br>Run away!' : 'Ouch! 💔 Run away!', 1.5);
}

// Out of hearts. Easy keeps everything; Hard takes your weapons and armour; Hardcore is game over
// and takes your Tag Bux too. Saved straight away, so reloading the page doesn't undo it.
function gotTagged(p) {
  const d = difficulty();
  if (d.oneLife) {
    p.out = true;
    p.tagged = Infinity; // out until the level ends; zombies leave her alone
    p.freshRun(); // her Hardcore game starts again from nothing (outfits are kept)
    if (active.every((h) => h.out)) gameOverIn = 3;
  } else if (d.loseItems) p.loseItems();
  huds[p.index].showTagged(true, d);
  saveGame();
}

// One hero's turn: counting down when tagged, using a menu inside, or out in the park.
function updatePlayer(p, dt) {
  const hud = huds[p.index];
  if (p.tagged || p.inside) {
    // no laser while you're tagged or inside, but let its stars fade away
    p.beam.hide();
    p.beam.update(dt, 0);
  }
  if (p.tagged) {
    p.tagged -= dt;
    if (p.tagged <= 0) {
      p.respawn(startFor(p));
      hud.showTagged(false);
      hud.toast('Back at the start with 3 hearts! ❤️❤️❤️', 2);
    }
  } else if (p.inside) {
    if (p.menu.update(dt)) {
      p.menu.close();
      sfx('select');
      saveGame(); // keep what you bought or trained
      hud.toast('See you soon! 👋', 1.5);
    }
  } else {
    for (const hit of p.update(dt, world, zombies, shots)) hitZombie(hit);
    if (p.justBroke) {
      p.justBroke = false;
      hud.toast(p.weapon
        ? `Your stick broke! 🪵💥<br>Now holding the ${p.weapon.name}`
        : 'Your stick broke! 🪵💥<br>Get a free one at the 🛍️ shop');
    }
    const buildings = [{ door: world.shop.door, menu: 'shop' }, { door: world.gym.door, menu: 'gym' }];
    for (const { door, menu } of buildings) {
      if (Math.hypot(p.pos.x - door.x, p.pos.z - door.z) < p.radius + CONFIG.shop.enterDistance) {
        p.menu = menus[p.index][menu];
        p.menu.open();
        hud.clearToast();
      }
    }
  }
}

// ---------- finishing a level, and the party ----------

function levelDone() {
  for (const p of active) {
    if (p.out) continue; // tagged on Hardcore: her game has already started again
    p.finished.add(levelIndex);
    p.unlocked = Math.max(p.unlocked, Math.min(CONFIG.levels.length, levelIndex + 2));
  }
  levelChoice = Math.min(levelIndex + 1, CONFIG.levels.length - 1);
  saveGame();
  sfx('fanfare');
  if (level.boss) {
    startParty();
    return;
  }
  const coin = '<span class="coin">T</span>';
  const next = CONFIG.levels[levelIndex + 1];
  $('won-place').textContent = `${level.name} is safe again! ${level.icon}`;
  $('won-bux').innerHTML = playerCount === 1
    ? `You've got ${coin} ${players[0].tagBux} Tag Bux to spend`
    : active.map((p) => `${p.name}: ${coin} ${p.tagBux}`).join(' &nbsp; ');
  $('won-next').innerHTML = `Press <kbd>Space</kbd> for level ${levelIndex + 2}: ${next.name} ${next.icon}`;
  show('won');
}

// You beat the Zombie King: all the zombies become your friends and there's a big party.
function startParty() {
  clearZombies();
  coins.clear();
  shots.clear();
  const kinds = ['shuffler', 'speedySid', 'bouncyBob', 'bigBertha', 'slimeZombie', 'smallShuffler'];
  const hatColours = [0xff4f8b, 0xffd23f, 0x4fc3f7, 0x7dff4f, 0xb28dff];
  for (let i = 0; i < 18; i++) {
    const a = (i / 18) * Math.PI * 2;
    const f = new Zombie(kinds[i % kinds.length], 1, Math.cos(a) * 11, Math.sin(a) * 11);
    const hat = new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.5, 12), new THREE.MeshLambertMaterial({ color: hatColours[i % 5] }));
    hat.position.y = 2.35;
    f.body.add(hat);
    f.yaw = -a - Math.PI / 2;
    friends.push(f);
    scene.add(f.root);
  }
  const king = new Zombie('zombieKing', 1, 0, -2);
  friends.push(king);
  scene.add(king.root);
  active.forEach((p, i) => {
    p.pos.set(-1.5 + i * 3, 0, 7);
    p.yaw = 0;
  });
  show('party');
  music('party');
}

function updateParty(dt) {
  const t = clock.elapsedTime;
  friends.forEach((f, i) => {
    f.root.position.set(f.pos.x, Math.abs(Math.sin(t * 5 + i)) * 0.6, f.pos.z);
    f.root.rotation.y = f.yaw + Math.sin(t * 2 + i) * 0.8;
    f.arms[0].rotation.x = 0.2 + Math.sin(t * 8 + i) * 0.5; // arms up, waving
    f.arms[1].rotation.x = 0.2 - Math.sin(t * 8 + i) * 0.5;
    f.body.rotation.z = Math.sin(t * 4 + i) * 0.2;
  });
  for (const p of active) {
    p.updateBody(dt, true);
    p.body.root.position.y = Math.abs(Math.sin(t * 6 + p.index)) * 0.5;
    p.body.arms[0].rotation.x = p.body.arms[1].rotation.x = Math.PI; // arms in the air
  }
  if (Math.random() < dt * 3) {
    const f = friends[Math.floor(Math.random() * friends.length)];
    effects.confetti(f.centre.add(new THREE.Vector3(0, 2, 0)), 40);
    if (Math.random() < 0.4) sfx('yay', { volume: 0.5, pitch: 0.8 + Math.random() * 0.6 });
  }
  showCamera.position.set(Math.sin(t * 0.15) * 20, 8, Math.cos(t * 0.15) * 20);
  showCamera.lookAt(0, 1.5, 0);
}

// ---------- every frame ----------

function update(dt) {
  pollPads();
  // Player 1's mouse turns her (read every frame, so moves made in menus don't pile up)
  const mouseX = takeMouseX();
  const kb = active.find(usesMouse);
  if (mouseLook && state === 'playing' && kb && !kb.inside && !kb.tagged) {
    kb.yaw -= mouseX * CONFIG.controls.mouseTurn;
  }
  const justLetGo = clock.elapsedTime - lockLostAt < 0.3; // the Esc that let go of the mouse already paused
  if (wasPressed(['Escape']) && (state === 'playing' || state === 'paused') && !justLetGo) {
    show(state === 'playing' ? 'paused' : 'playing');
    if (state === 'playing') lockMouse();
    return;
  }
  if (state === 'paused') {
    // W/S (or the arrows) choose a row, A/D (or the arrows) make it louder or quieter or change controls
    const before = pauseRow;
    if (wasPressed([...menu.forward])) pauseRow = Math.max(0, pauseRow - 1);
    if (wasPressed([...menu.back])) pauseRow = Math.min(PAUSE_ROWS - 1, pauseRow + 1);
    const change = (wasPressed([...menu.right]) ? 1 : 0) - (wasPressed([...menu.left]) ? 1 : 0);
    if (change && pauseRow === 2) {
      setMouseLook(!mouseLook);
      sfx('tick');
    } else if (change && pauseRow === 3) {
      setPadMode(!twoSticks);
      sfx('tick');
    } else if (change) {
      const which = pauseRow === 0 ? 'music' : 'sounds';
      setVolume(which, getVolumes()[which] + change);
      sfx('tick');
    }
    if (change || pauseRow !== before) drawVolume();
  }
  if (state === 'paused' && wasPressed(['KeyQ'])) {
    for (const p of players) if (p.inside) p.menu.close();
    saveGame();
    show('title');
    return;
  }
  const go = ['Space', 'Enter', 'NumpadEnter', 'Pad1A', 'Pad2A', 'PadAnyA'];
  if (state === 'title') {
    // choose 1 or 2 players with W/S or the arrows (or just press 1 or 2)
    if (wasPressed([...menu.forward, ...menu.left])) titleChoice = 0;
    if (wasPressed([...menu.back, ...menu.right])) titleChoice = 1;
    if (wasPressed(['Digit1', 'Numpad1'])) titleChoice = 0;
    if (wasPressed(['Digit2', 'Numpad2'])) titleChoice = 1;
    if (titleChoice !== Number($('title').dataset.choice || 0)) sfx('tick');
    $('title').dataset.choice = titleChoice;
    drawTitle();
    if (wasPressed(['KeyM'])) {
      setMouseLook(!mouseLook);
      sfx('tick');
      drawTitle();
    }
    if (wasPressed(['KeyJ'])) {
      setPadMode(!twoSticks);
      sfx('tick');
      drawTitle();
    }
    if (wasPressed([...go, 'Digit1', 'Digit2', 'Numpad1', 'Numpad2', 'KeyC'])) {
      sfx('select');
      playerCount = titleChoice + 1;
      beginGame(wasPressed(['KeyC']));
    }
    return;
  }
  if (state === 'who') {
    // The hero choosing uses the keyboard (if Player 1 hasn't taken it) or any joypad nobody has yet.
    // Picking with Space gives her the keyboard; picking with fire on a joypad gives her that joypad.
    // If Player 1 has the keyboard, Player 2 can share it: she chooses with the arrows and Enter.
    const kbFree = keyboardFree();
    const kb = (keys) => (kbFree ? keys : keys.filter((k) => k.startsWith('Arrow')));
    const n = whoRows().length;
    const before = whoChoice;
    if (wasPressed([...kb(KEYBOARD.forward), ...kb(KEYBOARD.left), 'PadAnyUp', 'PadAnyLeft'])) whoChoice = (whoChoice + n - 1) % n;
    if (wasPressed([...kb(KEYBOARD.back), ...kb(KEYBOARD.right), 'PadAnyDown', 'PadAnyRight'])) whoChoice = (whoChoice + 1) % n;
    if (whoChoice !== before) {
      sfx('tick');
      drawWho();
    }
    const pads = unownedPadsFired();
    if (pads.length) chooseWho('pad', pads);
    else if (wasPressed(KEYBOARD.attack)) {
      if (kbFree) chooseWho('keyboard');
      else if (wasPressed(CONFIG.keys.right.attack)) chooseWho('keysRight');
      else sfx('nope'); // Space is Player 1's
    }
    else if (wasPressed(['KeyX', 'Delete'])) {
      const r = whoRows()[whoChoice];
      if (r.profile && !r.taken) {
        removing = r.profile;
        show('remove');
      } else sfx('nope');
    } else if (wasPressed(['Escape'])) {
      if (whoSlot > 0) {
        // Player 1 chooses again, keyboard or joypad
        clearPads();
        players[0].device = null;
        startWho(0);
      } else show('title');
    }
    return;
  }
  if (state === 'remove') {
    if (wasPressed(['KeyY'])) {
      sfx('select');
      profiles = profiles.filter((d) => d !== removing);
      chosen = chosen.map((id) => (id === removing.id ? null : id));
      for (const p of players) if (p.profileId === removing.id) p.blank(null);
      writeSave({ profiles, chosen, playerCount, difficulty: difficultyId });
      startWho(whoSlot);
    } else if (wasPressed(['KeyN', 'Escape'])) startWho(whoSlot);
    return;
  }
  if (state === 'difficulty') {
    const before = difficultyId;
    let i = difficultyIds.indexOf(difficultyId);
    if (wasPressed([...menu.left, ...menu.forward])) i = Math.max(0, i - 1);
    if (wasPressed([...menu.right, ...menu.back])) i = Math.min(difficultyIds.length - 1, i + 1);
    difficultyId = difficultyIds[i];
    if (difficultyId !== before) {
      sfx('tick');
      drawDifficulty();
    }
    if (wasPressed(go)) {
      sfx('select');
      // Hardcore is a separate game that starts fresh; Easy and Hard share the normal one
      for (const p of active) p.useRun(difficulty().fresh ? 'hardcore' : 'normal');
      saveGame();
      levelChoice = Math.min(unlockedNow(), CONFIG.levels.length) - 1;
      show('levels');
    }
    if (wasPressed(['Escape'])) show('title');
    return;
  }
  if (state === 'gameover') {
    if (wasPressed(go)) show('levels');
    return;
  }
  if (state === 'create') {
    creator.update(dt);
    return;
  }
  if (state === 'levels') {
    // a grid of 5 x 2 levels
    const before = levelChoice;
    const n = CONFIG.levels.length;
    if (wasPressed([...menu.left])) levelChoice = Math.max(0, levelChoice - 1);
    if (wasPressed([...menu.right])) levelChoice = Math.min(n - 1, levelChoice + 1);
    if (wasPressed([...menu.forward])) levelChoice = Math.max(0, levelChoice - 5);
    if (wasPressed([...menu.back])) levelChoice = Math.min(n - 1, levelChoice + 5);
    if (levelChoice !== before) {
      drawLevels();
      sfx('tick');
    }
    if (wasPressed(go)) {
      sfx(levelChoice < unlockedNow() ? 'select' : 'nope');
      if (levelChoice < unlockedNow()) startLevel(levelChoice);
    }
    if (wasPressed(['Escape'])) show('difficulty');
    return;
  }
  if (state === 'won') {
    if (wasPressed(go)) startLevel(levelIndex + 1);
    if (wasPressed(['KeyL'])) show('levels');
    return;
  }
  if (state === 'party') {
    updateParty(dt);
    if (wasPressed(go)) show('levels');
    return;
  }
  if (state !== 'playing') return;

  const alive = zombies.filter((z) => z.alive).length;
  if (spawned < regulars && alive <= CONFIG.arena.nextWaveWhenLeft) spawnWave();
  if (level.boss && !boss && spawned >= regulars && !zombies.some((z) => z.alive)) spawnBoss();
  if (gameOverIn > 0) {
    gameOverIn -= dt;
    if (gameOverIn <= 0) {
      sfx('tagged');
      show('gameover');
      return;
    }
  }

  for (const p of active) updatePlayer(p, dt);
  for (const hit of shots.update(dt, zombies)) hitZombie(hit);

  const cleared = popped >= levelZombies;
  for (const { player } of coins.update(dt, active, world, cleared)) {
    huds[player.index].bumpBux();
    // ka-ching, a little higher for each coin in a row
    const now = clock.elapsedTime;
    coinStreak = now - lastCoin < 0.6 ? coinStreak + 1 : 0;
    if (now - lastCoin > 0.05) sfx('coin', { pitch: 1 + Math.min(coinStreak, 8) * 0.06 });
    lastCoin = now;
  }

  for (const z of zombies) {
    if (!z.alive) continue;
    z.update(dt, active, world, zombies);
    if (z.callingHelp) callHelpers(z);
    // zombies groan now and then, louder when they're close
    z.groanIn = (z.groanIn ?? 2 + Math.random() * 8) - dt;
    if (z.groanIn <= 0) {
      z.groanIn = 6 + Math.random() * 8;
      const d = Math.min(...active.map((p) => Math.hypot(z.pos.x - p.pos.x, z.pos.z - p.pos.z)));
      if (d < 18 && clock.elapsedTime - lastGroan > 1.2) {
        lastGroan = clock.elapsedTime;
        sfx('groan', { volume: (1 - d / 18) * 0.9, pitch: (0.9 + Math.random() * 0.25) / z.type.size });
      }
    }
    for (const p of active) {
      const d = Math.hypot(z.pos.x - p.pos.x, z.pos.z - p.pos.z);
      if (z.canTag && d < z.radius + p.radius + CONFIG.player.touchDistance) zombieTouch(z, p);
    }
  }
  zombies = zombies.filter((z) => z.alive);

  // sisters can't walk through each other
  if (active.length === 2 && !active.some((p) => p.inside || p.tagged)) {
    const [a, b] = active;
    const dx = b.pos.x - a.pos.x;
    const dz = b.pos.z - a.pos.z;
    const d = Math.hypot(dx, dz);
    const min = a.radius + b.radius;
    if (d < min && d > 0.0001) {
      const push = (min - d) / 2;
      a.pos.x -= (dx / d) * push;
      a.pos.z -= (dz / d) * push;
      b.pos.x += (dx / d) * push;
      b.pos.z += (dz / d) * push;
    }
  }

  // every zombie popped: the exit gate opens, and walking through it finishes the level
  if (cleared && !world.gate.isOpen) {
    world.openGate();
    sfx('gate');
    toastAll('All the zombies are popped! ✨<br>Walk through the glowing exit gate', 4);
  }
  if (world.gate.isOpen && active.some((p) => !p.inside && !p.tagged
    && Math.abs(p.pos.x - world.gate.x) < 2.2 && Math.abs(p.pos.z - world.gate.z) < 2)) {
    levelDone();
  }
}

const clock = new THREE.Clock();
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  update(dt);
  if (state !== 'paused') {
    effects.update(dt);
    world.update(dt);
  }
  for (const p of players) {
    const m = menus[p.index];
    for (const menu of [m.shop, m.gym]) {
      menu.el.classList.toggle('hidden', !p.inside || p.menu !== menu || state !== 'playing');
    }
    const playing = ['playing', 'paused', 'won'].includes(state);
    if (state !== 'party') p.updateBody(dt, playing && playerCount === 2 && active.includes(p));
  }
  const bossShown = boss && boss.alive ? boss : null;
  for (const p of active) {
    p.deviceIcon = p.device === 'pad' ? '🎮' : p.mouseLook ? '🖱️' : '⌨️';
    huds[p.index].update(dt, levelZombies - popped, world.gate.isOpen, bossShown);
  }

  // the start screens show the level slowly turning behind them
  const inGame = ['playing', 'paused', 'won'].includes(state);
  const closeUp = state === 'create' || state === 'party';
  const views = inGame ? active : [players[0]];
  if (!inGame && !closeUp) {
    const t = clock.elapsedTime * 0.08;
    players[0].camera.position.set(Math.sin(t) * 30, 8, Math.cos(t) * 30);
    players[0].camera.lookAt(0, 2, 0);
  }
  if (state === 'create' && creator.player) {
    // the hero being made turns from side to side to show off
    const s = world.playerStart;
    const body = creator.player.body.root;
    body.visible = true;
    body.position.set(s.x, 0, s.z);
    body.rotation.y = Math.sin(clock.elapsedTime * 0.8) * 0.7;
    // looking back at the hero from in front, offset so she stands in the right half of the screen
    showCamera.position.set(s.x + 1.6, 1.5, s.z - 5);
    showCamera.lookAt(s.x + 1.6, 1.25, s.z);
  }

  // draw the world once for each player, side by side
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  renderer.shadowMap.needsUpdate = true;
  renderer.setScissorTest(views.length > 1);
  const vw = w / views.length;
  views.forEach((p, i) => {
    const camera = closeUp ? showCamera : p.camera;
    camera.aspect = vw / h;
    camera.updateProjectionMatrix();
    for (const z of zombies) z.updateBar(camera);
    renderer.setViewport(i * vw, 0, vw, h);
    renderer.setScissor(i * vw, 0, vw, h);
    renderer.render(scene, camera);
  });

  endFrame();
  requestAnimationFrame(frame);
}

restoreSave();
// the start screen shows the furthest level last time's heroes reached
loadLevel(Math.max(0, ...players.map((p) => p.unlocked)) - 1);
show('title');
for (const p of players) p.reset(world.playerStart);
frame();

// handy for testing from the browser console
window.game = {
  players, huds, menus, coins, shots, creator,
  player: players[0], shop: menus[0].shop, gym: menus[0].gym,
  startLevel, levelDone,
  get profiles() { return profiles; },
  get difficulty() { return difficultyId; },
  setDifficulty(id) { difficultyId = id; },
  touchForTest: zombieTouch,
  popForTest(z) { z.alive = false; popZombie(z); },
  addZombie,
  loudness, sfx,
  get world() { return world; },
  get level() { return level; },
  get levelIndex() { return levelIndex; },
  get active() { return active; },
  get zombies() { return zombies; },
  get boss() { return boss; },
  get state() { return state; },
  get popped() { return popped; },
  get levelZombies() { return levelZombies; },
};
