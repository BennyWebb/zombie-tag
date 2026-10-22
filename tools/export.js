// Exports everything the Godot version needs from the browser game, into the godot folder:
//
//   godot/models/levels/   each level's scenery as a .glb (merged into a few big meshes)
//   godot/models/          the shop, gym, gate, zombies, heroes, hand and weapons, shots, coin
//   godot/sounds/          every sound effect and tune as a .wav (the tunes loop by themselves)
//   godot/data/levels/     each level's colliders, start, gate, lights and drifting floaters
//   godot/data/models.json what's in each model: part names, recolourable materials, hidden parts
//
// Run with: npm run export:godot (it opens this page). The page builds things with the game's own
// code, so the Godot version looks and sounds the same. tools/vite.export.config.js saves the files.

import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { CONFIG } from '../src/config.js';
import { THEMES } from '../src/themes.js';
import { BUILDING_SPOTS, GYM_LOOK, SHOP_LOOK, buildWorld, makeBuilding, makeGate } from '../src/world.js';
import { LOOKS, SHIRTS, SKINS, makeZombieMesh } from '../src/zombie.js';
import { makeHeroBody } from '../src/hero.js';
import { Player } from '../src/player.js';
import { SHOT_LOOKS, SPLASH_COLOURS } from '../src/weapons.js';
import { coinGeo, coinMats } from '../src/coins.js';
import { SONG_IDS, SOUND_NAMES, recordSong, recordSound } from '../src/audio.js';

const SAMPLE_RATE = 24000; // plenty for the game's beeps and boings, and keeps the files small
const TILE = 20; // scenery is merged in squares this big, so Godot can skip the ones out of view

const logEl = document.getElementById('log');
const log = (text, cls) => {
  const line = document.createElement('div');
  line.textContent = text;
  if (cls) line.className = cls;
  logEl.append(line);
  window.scrollTo(0, document.body.scrollHeight);
};

// Sends a file to the dev server, which writes it into the godot folder.
async function save(path, data) {
  const res = await fetch(`/__export/${path}`, { method: 'POST', body: data });
  if (!res.ok) throw new Error(`Couldn't save ${path}: ${await res.text()}`);
}
const saveJson = (path, value) => save(path, `${JSON.stringify(value, null, 2)}\n`);

// The game's matt Lambert materials as glTF ones. (Left as they are, the exporter would leave out
// how metallic they are, and glTF then makes them fully metal, which looks dark.)
const asStandard = new Map();
function standardMaterial(m) {
  if (!m.isMeshLambertMaterial) return m;
  if (!asStandard.has(m)) {
    const s = new THREE.MeshStandardMaterial({
      name: m.name, color: m.color, emissive: m.emissive, map: m.map, vertexColors: m.vertexColors,
      transparent: m.transparent, opacity: m.opacity, side: m.side, metalness: 0, roughness: 1,
    });
    asStandard.set(m, s);
  }
  return asStandard.get(m);
}

const exporter = new GLTFExporter();
async function saveModel(path, object) {
  object.traverse((o) => {
    // Nothing else in userData is needed (and some can't be saved). What is saved shows up in Godot
    // as the node's "extras" metadata.
    o.userData = o.isMesh && !o.castShadow ? { noShadow: true } : {};
    if (o.isMesh) o.material = Array.isArray(o.material) ? o.material.map(standardMaterial) : standardMaterial(o.material);
  });
  const glb = await exporter.parseAsync(object, { binary: true, onlyVisible: false });
  await save(path, glb);
}

const round = (n) => Math.round(n * 1000) / 1000;
const hex = (c) => `#${c.getHexString()}`;

// The names of the parts that start hidden, so Godot can hide them too
// (glTF files can't say that something is hidden).
function hiddenParts(root) {
  const names = [];
  root.traverse((o) => { if (!o.visible && o !== root) names.push(o.name || '(unnamed)'); });
  return names;
}

// ---------- level scenery ----------

// Things that move (the carousel, the Ferris wheel...): run the level's animations for a moment
// and see which objects' positions or turns changed. Returns the top ones, with what they hold.
function findMovingParts(world) {
  const before = new Map();
  world.group.traverse((o) => before.set(o, [...o.position.toArray(), ...o.quaternion.toArray(), ...o.scale.toArray()]));
  for (let i = 0; i < 4; i++) world.update(0.25);
  const moved = new Set();
  for (const [o, was] of before) {
    const now = [...o.position.toArray(), ...o.quaternion.toArray(), ...o.scale.toArray()];
    if (now.some((v, i) => Math.abs(v - was[i]) > 1e-6)) moved.add(o);
  }
  // put everything back where it started
  for (const [o, was] of before) {
    o.position.fromArray(was, 0);
    o.quaternion.fromArray(was, 3);
    o.scale.fromArray(was, 7);
  }
  const movedAbove = (o) => { for (let p = o.parent; p && p !== world.group; p = p.parent) if (moved.has(p)) return true; return false; };
  return [...moved].filter((o) => o !== world.group && !movedAbove(o));
}

// A level's colours as little squares in one small picture. Each merged mesh points at its colour's
// square, so the colours come through as an ordinary texture. (Colours stored in the mesh's corners
// would be smaller, but some Godot versions need a setting switched on before they show them.)
const SQUARE = 8; // pixels
const PALETTE_SIZE = 128; // pixels across and down: room for 256 colours
class Palette {
  constructor() {
    this.colours = new Map(); // colour -> where its square is
  }

  // The texture coordinates of the middle of a colour's square.
  uv(colour) {
    const key = colour.getHex();
    if (!this.colours.has(key)) {
      const n = this.colours.size;
      if (n >= (PALETTE_SIZE / SQUARE) ** 2) throw new Error('Too many colours for one palette');
      this.colours.set(key, { colour, x: (n % (PALETTE_SIZE / SQUARE)) * SQUARE, y: Math.floor(n / (PALETTE_SIZE / SQUARE)) * SQUARE });
    }
    const { x, y } = this.colours.get(key);
    // (three.js counts v up from the bottom of the picture; the exporter turns it round for glTF)
    return [(x + SQUARE / 2) / PALETTE_SIZE, 1 - (y + SQUARE / 2) / PALETTE_SIZE];
  }

  texture() {
    const canvas = document.createElement('canvas');
    canvas.width = PALETTE_SIZE;
    canvas.height = PALETTE_SIZE;
    const ctx = canvas.getContext('2d');
    for (const { colour, x, y } of this.colours.values()) {
      ctx.fillStyle = `#${colour.getHexString()}`;
      ctx.fillRect(x, y, SQUARE, SQUARE);
    }
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    // each triangle only ever looks at the middle of one square, so no blending is needed
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    tex.generateMipmaps = false;
    return tex;
  }
}

// Meshes with the same kind of material can share one, painted from the level's palette.
function materialKind(m) {
  const lit = !m.isMeshBasicMaterial;
  const parts = [lit ? 'lit' : 'glow'];
  if (m.transparent) parts.push(`see-through ${round(m.opacity)}`);
  if (m.side === THREE.DoubleSide) parts.push('two-sided');
  if (lit && m.emissive && m.emissive.getHex() !== 0) parts.push(`emissive ${hex(m.emissive)}`);
  if (m.fog === false) parts.push('no fog');
  return parts.join(', ');
}

function kindMaterial(m, name, map) {
  const options = {
    color: 0xffffff, map, transparent: m.transparent, opacity: m.opacity, side: m.side,
  };
  const out = m.isMeshBasicMaterial
    ? new THREE.MeshBasicMaterial(options)
    : new THREE.MeshLambertMaterial({ ...options, emissive: m.emissive ? m.emissive.clone() : 0 });
  out.name = name;
  return out;
}

// A copy of a mesh's shape, moved to where it is in the world and pointing at its colour's square.
function bakedGeometry(mesh, palette) {
  const g = mesh.geometry.clone();
  for (const name of Object.keys(g.attributes)) if (name !== 'position' && name !== 'normal') g.deleteAttribute(name);
  if (!g.index) g.setIndex([...Array(g.attributes.position.count).keys()]);
  g.applyMatrix4(mesh.matrixWorld);
  if (mesh.matrixWorld.determinant() < 0) {
    // mirrored: turn the triangles round so they still face outwards
    const idx = g.index.array;
    for (let i = 0; i < idx.length; i += 3) [idx[i + 1], idx[i + 2]] = [idx[i + 2], idx[i + 1]];
  }
  const [u, v] = palette.uv(mesh.material.color);
  const uvs = new Float32Array(g.attributes.position.count * 2);
  for (let i = 0; i < uvs.length; i += 2) uvs.set([u, v], i);
  g.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  return g;
}

async function exportLevel(level, i) {
  const theme = THEMES[level.theme];
  const scene = new THREE.Scene();
  const world = buildWorld(scene, level, theme, { forExport: true });
  const group = world.group;
  const out = new THREE.Group();
  out.name = `level${i + 1}`;

  // record the lights and floaters, then take them out (Godot makes its own)
  const pointLights = [];
  const floaters = [];
  const removed = [];
  group.updateMatrixWorld(true);
  group.traverse((o) => {
    if (o.isPointLight) {
      const p = o.getWorldPosition(new THREE.Vector3());
      pointLights.push({ x: round(p.x), y: round(p.y), z: round(p.z), colour: o.color.getHex(), intensity: o.intensity, range: o.distance });
      removed.push(o);
    } else if (o.isLight) {
      removed.push(o);
    } else if (o.isPoints) {
      floaters.push(o.userData.floaters);
      removed.push(o);
    }
  });
  for (const o of removed) o.removeFromParent();

  // moving things and the gate stay as they are, so Godot can move them
  const moving = findMovingParts(world);
  const gate = group.getObjectByName('gate');
  group.updateMatrixWorld(true);
  for (const o of [...moving, gate]) {
    if (!o.name) o.name = `moving${moving.indexOf(o) + 1}`;
    out.attach(o);
  }

  // everything else is still: merge it into one mesh per square of ground and kind of material
  const buckets = new Map();
  const kinds = new Map(); // kind -> an example of its material
  const palette = new Palette();
  let meshes = 0;
  group.updateMatrixWorld(true);
  group.traverse((o) => {
    if (!o.isMesh) return;
    meshes++;
    // (things that don't cast a shadow in the game, like clouds, are kept apart)
    const kind = `${materialKind(o.material)}${o.castShadow ? '' : ', no shadow'}`;
    if (!kinds.has(kind)) kinds.set(kind, o.material);
    o.geometry.computeBoundingSphere();
    const sphere = o.geometry.boundingSphere.clone().applyMatrix4(o.matrixWorld);
    // big things (the ground, the wall, the sea) go together instead of in a square
    const square = sphere.radius > TILE ? 'big' : `${Math.floor(sphere.center.x / TILE)},${Math.floor(sphere.center.z / TILE)}`;
    const key = `${square}|${kind}`;
    if (!buckets.has(key)) buckets.set(key, { square, kind, geos: [] });
    buckets.get(key).geos.push(bakedGeometry(o, palette));
  });
  const paletteTexture = palette.texture();
  for (const [kind, example] of kinds) kinds.set(kind, kindMaterial(example, kind, paletteTexture));
  const scenery = new THREE.Group();
  scenery.name = 'scenery';
  out.add(scenery);
  for (const { square, kind, geos } of buckets.values()) {
    const merged = new THREE.Mesh(mergeGeometries(geos), kinds.get(kind));
    merged.name = `${square === 'big' ? 'big' : `square ${square}`} (${kind})`;
    merged.castShadow = !kind.endsWith('no shadow');
    scenery.add(merged);
  }

  const file = `${String(i + 1).padStart(2, '0')}-${level.theme}`;
  await saveModel(`models/levels/${file}.glb`, out);

  // where things are, for the Godot version's code
  const colliders = world.colliders
    .filter((c) => !c.building) // the shop and gym's, which Godot adds where it puts them
    .map((c) => (c.r !== undefined
      ? { x: round(c.x), z: round(c.z), r: round(c.r), ...(c.small ? { small: true } : {}) }
      : { x: round(c.x), z: round(c.z), hw: round(c.hw), hd: round(c.hd), ...(c.small ? { small: true } : {}) }));
  await saveJson(`data/levels/${file}.json`, {
    number: i + 1,
    name: level.name,
    theme: level.theme,
    model: `models/levels/${file}.glb`,
    music: level.theme,
    sky: theme.sky,
    night: !!theme.night,
    fog: { start: theme.fog[0], end: theme.fog[1] },
    light: theme.light,
    sunPosition: { x: 30, y: 50, z: 20 },
    wall: theme.wall,
    bounds: world.bounds,
    playerStart: world.playerStart,
    gate: { x: world.gate.x, z: world.gate.z },
    buildingSpots: BUILDING_SPOTS.map(([x, z]) => ({ x, z })),
    buildingSize: { halfWidth: 4, halfDepth: 3 },
    colliders,
    pointLights,
    floaters,
    movingParts: moving.map((o) => o.name),
  });
  const extra = moving.length ? `, plus ${moving.map((o) => o.name).join(' and ')}` : '';
  log(`  ${level.name}: ${meshes} meshes merged into ${scenery.children.length}, then the gate${extra}`);
}

// ---------- characters, buildings and things ----------

const models = {};

function nameZombie(z, kind) {
  z.root.name = kind;
  z.body.name = 'body';
  const [torso, head] = z.body.children;
  torso.name = 'torso';
  head.name = 'head';
  ['eyeL', 'eyeR'].forEach((n, i) => {
    z.eyes[i].name = n;
    z.eyes[i].userData.pupil.name = 'pupil';
  });
  ['armL', 'armR'].forEach((n, i) => { z.arms[i].name = n; });
  ['legL', 'legR'].forEach((n, i) => { z.legs[i].name = n; });
  z.bar.name = 'healthBar';
  z.barFill.name = 'healthFill';
  z.stars.name = 'stars';
  z.bubble.name = 'bubble';
  z.ice.name = 'ice';
  for (const [key, part] of Object.entries(z.extras)) part.name = key;
  ['skin', 'shirt', 'trousers'].forEach((n, i) => { z.flashMats[i].name = n; });
}

async function exportZombies() {
  const kinds = Object.keys(CONFIG.zombies);
  for (const kind of kinds) {
    const z = makeZombieMesh(kind);
    nameZombie(z, kind);
    z.root.scale.setScalar(CONFIG.zombies[kind].size);
    models[`zombies/${kind}`] = {
      file: `models/zombies/${kind}.glb`,
      recolour: { skin: 'skin', shirt: 'shirt', trousers: 'trousers' },
      hidden: hiddenParts(z.root),
      animated: ['body', 'armL', 'armR', 'legL', 'legR', 'pupil', 'stars', ...Object.keys(z.extras)],
    };
    await saveModel(`models/zombies/${kind}.glb`, z.root);
  }
  log(`  ${kinds.length} kinds of zombie`);
}

function nameHero(parts, look) {
  parts.root.name = 'hero';
  parts.head.name = 'head';
  parts.torso.name = 'torso';
  ['armL', 'armR'].forEach((n, i) => { parts.arms[i].name = n; });
  ['legL', 'legR'].forEach((n, i) => { parts.legs[i].name = n; });
  for (const [key, part] of Object.entries(parts)) if (part && part.isObject3D && !part.name) part.name = key;
  // the materials Godot recolours from the character creator's choices
  const skin = parts.head.children[0].material;
  const clothes = parts.torso.material;
  const trousers = parts.legs[0].children[0].material;
  parts.root.traverse((o) => {
    if (!o.isMesh) return;
    if (o.material === skin) o.material.name = 'skin';
    else if (o.material === clothes) o.material.name = 'clothes';
    else if (o.material === trousers) o.material.name = 'trousers';
    else if (o.material.color && o.material.color.getHex() === look.hair) o.material.name = 'hair';
  });
  // the name tag is drawn by Godot (a Label3D)
  for (const o of [...parts.root.children]) if (o.isSprite) o.removeFromParent();
}

async function exportHeroes() {
  const look = CONFIG.heroes[0];
  const hero = (hairStyle, wearing, file) => {
    const parts = makeHeroBody({ ...look, hairStyle }, wearing);
    nameHero(parts, look);
    models[`heroes/${file}`] = {
      file: `models/heroes/${file}.glb`,
      recolour: { skin: 'skin', clothes: 'clothes', trousers: 'trousers', hair: 'hair' },
      hidden: hiddenParts(parts.root),
    };
    return saveModel(`models/heroes/${file}.glb`, parts.root);
  };
  for (const { id } of CONFIG.creator.hairStyles) await hero(id, [], `hair-${id}`);
  for (const id of Object.keys(CONFIG.outfits)) await hero(look.hairStyle, [id], `outfit-${id}`);
  log(`  heroes: ${CONFIG.creator.hairStyles.length} hair styles and ${Object.keys(CONFIG.outfits).length} outfits`);
}

async function exportHand() {
  // the first-person hand, holding every weapon (Godot shows the one you're holding)
  const p = new Player(CONFIG.keys.keyboard, new THREE.Scene(), CONFIG.heroes[0], 0);
  const hand = p.hand;
  hand.removeFromParent();
  hand.position.set(0, 0, 0);
  hand.name = 'hand';
  const [fist, sleeve] = hand.children;
  fist.name = 'fist';
  sleeve.name = 'sleeve';
  p.skinMat.name = 'skin';
  p.sleeveMat.name = 'clothes';
  for (const [id, model] of Object.entries(p.models)) model.name = id;
  models.hand = {
    file: 'models/hand.glb',
    note: 'Sits at (0.38, -0.42, -0.65) from the camera. Show only the weapon being held.',
    recolour: { skin: 'skin', clothes: 'clothes' },
    weapons: Object.keys(p.models),
    hidden: hiddenParts(hand),
  };
  await saveModel('models/hand.glb', hand);
  log(`  the hand, with ${Object.keys(p.models).length} weapons`);
}

async function exportBuildings() {
  for (const [name, look] of [['shop', SHOP_LOOK], ['gym', GYM_LOOK]]) {
    const b = makeBuilding(look);
    b.group.name = name;
    b.group.traverse((o) => { if (o.isLight) o.removeFromParent(); });
    models[name] = {
      file: `models/${name}.glb`,
      note: 'The door faces +z. The sign spins (1.2 radians a second) and glows; it had a point light '
        + `(colour ${look.glow}, energy 25, range 16).`,
      animated: ['sign'],
    };
    await saveModel(`models/${name}.glb`, b.group);
  }
  const gate = makeGate();
  gate.group.name = 'gate';
  models.gate = {
    file: 'models/gate.glb',
    note: "Closed: 'bars' showing. Open: hide 'bars', show 'open', spin 'beam' and pulse 'glow'.",
    hidden: hiddenParts(gate.group),
    animated: ['bars', 'open', 'beam', 'glow'],
  };
  await saveModel('models/gate.glb', gate.group);
  log('  shop, gym and gate');
}

async function exportThings() {
  for (const [kind, make] of Object.entries(SHOT_LOOKS)) {
    const shot = make();
    shot.name = kind;
    models[`shots/${kind}`] = { file: `models/shots/${kind}.glb`, splashColours: SPLASH_COLOURS[kind] };
    await saveModel(`models/shots/${kind}.glb`, shot);
  }
  const coin = new THREE.Mesh(coinGeo, coinMats);
  coin.name = 'coin';
  models.coin = { file: 'models/coin.glb', note: 'Spins round its y axis and bobs up and down.' };
  await saveModel('models/coin.glb', coin);
  log(`  ${Object.keys(SHOT_LOOKS).length} kinds of shot and the coin`);
}

// ---------- sounds ----------

// 16-bit mono .wav. A tune gets a "smpl" chunk saying to loop the whole thing, which Godot reads.
function wav(samples, sampleRate, loop) {
  const data = samples.length * 2;
  const smpl = loop ? 8 + 36 + 24 : 0;
  const buf = new DataView(new ArrayBuffer(44 + data + smpl));
  const str = (o, s) => [...s].forEach((ch, i) => buf.setUint8(o + i, ch.charCodeAt(0)));
  str(0, 'RIFF');
  buf.setUint32(4, 36 + data + smpl, true);
  str(8, 'WAVE');
  str(12, 'fmt ');
  buf.setUint32(16, 16, true);
  buf.setUint16(20, 1, true); // PCM
  buf.setUint16(22, 1, true); // mono
  buf.setUint32(24, sampleRate, true);
  buf.setUint32(28, sampleRate * 2, true);
  buf.setUint16(32, 2, true);
  buf.setUint16(34, 16, true);
  str(36, 'data');
  buf.setUint32(40, data, true);
  samples.forEach((v, i) => buf.setInt16(44 + i * 2, Math.max(-1, Math.min(1, v)) * 32767, true));
  if (loop) {
    const o = 44 + data;
    str(o, 'smpl');
    buf.setUint32(o + 4, 36 + 24, true);
    buf.setUint32(o + 16, Math.round(1e9 / sampleRate), true); // sample period
    buf.setUint32(o + 20, 60, true); // middle C
    buf.setUint32(o + 36, 1, true); // one loop
    buf.setUint32(o + 52, 0, true); // loop start
    buf.setUint32(o + 56, samples.length, true); // loop end
  }
  return buf.buffer;
}

const peak = (samples) => samples.reduce((m, v) => Math.max(m, Math.abs(v)), 0);

async function exportSounds() {
  let loudest = 0;
  for (const name of SOUND_NAMES) {
    const samples = (await recordSound(name, SAMPLE_RATE)).getChannelData(0);
    // trim the silence at the end
    let end = samples.length;
    while (end > 0 && Math.abs(samples[end - 1]) < 1e-4) end--;
    const trimmed = samples.slice(0, Math.min(samples.length, end + Math.round(SAMPLE_RATE * 0.02)));
    loudest = Math.max(loudest, peak(trimmed));
    await save(`sounds/sfx/${name}.wav`, wav(trimmed, SAMPLE_RATE, false));
  }
  log(`  ${SOUND_NAMES.length} sound effects (loudest peak ${loudest.toFixed(2)})`);
  for (const id of SONG_IDS) {
    const { buffer, loopStart, loopLength } = await recordSong(id, SAMPLE_RATE);
    const samples = buffer.getChannelData(0).slice(loopStart, loopStart + loopLength);
    await save(`sounds/music/${id}.wav`, wav(samples, SAMPLE_RATE, true));
    log(`  tune "${id}": ${(samples.length / SAMPLE_RATE).toFixed(1)} s loop, peak ${peak(samples).toFixed(2)}`);
  }
}

// ---------- go ----------

async function run() {
  log('Levels:');
  // (the game adds each level's number, which its scenery's random numbers start from)
  for (const [i, level] of CONFIG.levels.entries()) await exportLevel({ ...level, number: i + 1 }, i);
  log('Characters and things:');
  await exportZombies();
  await exportHeroes();
  await exportHand();
  await exportBuildings();
  await exportThings();
  await saveJson('data/models.json', {
    about: 'Made by tools/export.js. Colours are numbers like 0xff4f8b; in Godot use Color.hex((c << 8) | 0xff).',
    zombieColours: { default: { skins: SKINS, shirts: SHIRTS }, ...LOOKS },
    models,
  });
  log('Sounds and music:');
  await exportSounds();
  log('Finished! Everything is in the godot folder. You can close this page.', 'done');
  window.exportDone = true;
}

run().catch((e) => {
  log(`Something went wrong: ${e.message}`, 'error');
  console.error(e);
  window.exportError = e.message;
});
