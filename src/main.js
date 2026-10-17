import * as THREE from 'three';
import { CONFIG } from './config.js';
import { endFrame, wasPressed } from './input.js';
import { buildWorld } from './world.js';
import { Zombie } from './zombie.js';
import { Player } from './player.js';
import { Effects } from './effects.js';

const level = CONFIG.levels[0];

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.getElementById('game').appendChild(renderer.domElement);

const scene = new THREE.Scene();
const world = buildWorld(scene, level);
const effects = new Effects(scene);
const player = new Player(CONFIG.keys.p1, scene);

const $ = (id) => document.getElementById(id);
const screens = { title: $('title'), paused: $('paused'), won: $('won') };

let state = 'title';
let zombies = [];
let spawned = 0;
let popped = 0;
let wonTimer = 0;
let toastTimer = 0;

function show(name) {
  state = name;
  for (const [key, el] of Object.entries(screens)) el.classList.toggle('hidden', key !== name);
  $('hud').classList.toggle('hidden', name === 'title');
  player.hand.visible = name === 'playing' || name === 'paused';
  if (name !== 'playing') {
    toastTimer = 0;
    $('toast').classList.remove('show');
  }
}

function toast(text, seconds = 2.5) {
  $('toast').innerHTML = text;
  $('toast').classList.add('show');
  toastTimer = seconds;
}

function startLevel() {
  for (const z of zombies) scene.remove(z.root);
  zombies = [];
  spawned = 0;
  popped = 0;
  wonTimer = 0;
  player.reset(world.playerStart);
  show('playing');
  toast('Bonk all the zombies!');
}

function spawnWave() {
  const count = Math.min(level.waveSize, level.zombies - spawned);
  for (let i = 0; i < count; i++) {
    for (let tries = 0; tries < 100; tries++) {
      const x = (Math.random() - 0.5) * (level.size - 6);
      const z = (Math.random() - 0.5) * (level.size - 6);
      if (Math.hypot(x - player.pos.x, z - player.pos.z) < 22) continue; // not too close to the hero
      if (!world.isClear(x, z, 1)) continue;
      const type = CONFIG.zombies[level.zombieTypes[0]];
      const zombie = new Zombie(type, level.healthMultiplier, x, z);
      zombies.push(zombie);
      scene.add(zombie.root);
      spawned++;
      break;
    }
  }
}

function updateHud() {
  const left = level.zombies - popped;
  $('zombies-left').textContent = left === 1 ? '1 zombie left' : `${left} zombies left`;
  $('stat-speed').textContent = player.speedLevel;
  $('stat-strength').textContent = player.strengthLevel;
  const w = player.weapon;
  $('weapon').classList.toggle('empty', !w);
  $('weapon').innerHTML = w
    ? `🪵 ${w.name} · ${w.hitsLeft} ${w.hitsLeft === 1 ? 'hit' : 'hits'} left`
    : 'No stick! Get a free one from the ⭐ barrel';
}

function update(dt) {
  if (wasPressed(['Escape']) && (state === 'playing' || state === 'paused')) {
    show(state === 'playing' ? 'paused' : 'playing');
    return;
  }
  if (state === 'title' || state === 'won') {
    if (wasPressed(CONFIG.keys.p1.attack) || wasPressed(['Enter'])) startLevel();
    return;
  }
  if (state !== 'playing') return;

  const alive = zombies.filter((z) => z.alive).length;
  if (spawned < level.zombies && alive <= level.nextWaveWhenLeft) spawnWave();

  const bonked = player.update(dt, world, zombies);
  if (bonked) {
    const popping = bonked.hit(player.weapon ? player.weapon.damage * player.damageMultiplier : 1);
    if (popping) {
      effects.confetti(bonked.centre);
      effects.floatText(bonked.centre.add(new THREE.Vector3(0, 1, 0)), 'POP!', '#9cff57', 1.4);
      scene.remove(bonked.root);
      popped++;
    } else {
      effects.floatText(bonked.centre.add(new THREE.Vector3(0, 0.8, 0)), 'BONK!', '#ffe066', 1.1);
    }
  }
  if (player.justBroke) {
    player.justBroke = false;
    toast('Your stick broke! 🪵💥<br>Get a free one from the ⭐ barrel at the start');
  }

  // walk up to the barrel to grab a new stick
  const b = world.stickBarrel;
  if (!player.weapon && Math.hypot(player.pos.x - b.x, player.pos.z - b.z) < b.r + player.radius + 0.6) {
    player.giveStick();
    toast('New Spiky Stick! 🪵');
  }

  for (const z of zombies) if (z.alive) z.update(dt, player, world, zombies, player.camera);
  zombies = zombies.filter((z) => z.alive);

  if (popped >= level.zombies) {
    wonTimer += dt;
    if (wonTimer > 1.5) show('won');
  }
}

const clock = new THREE.Clock();
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  update(dt);
  if (state !== 'paused') effects.update(dt);
  world.stickBarrel.star.rotation.y += dt * 1.5;

  if (toastTimer > 0) {
    toastTimer -= dt;
    if (toastTimer <= 0) $('toast').classList.remove('show');
  }
  updateHud();

  // The title screen shows the park slowly turning behind it.
  if (state === 'title') {
    const t = clock.elapsedTime * 0.08;
    player.camera.position.set(Math.sin(t) * 30, 8, Math.cos(t) * 30);
    player.camera.lookAt(0, 2, 0);
  }

  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  player.camera.aspect = w / h;
  player.camera.updateProjectionMatrix();
  renderer.render(scene, player.camera);

  endFrame();
  requestAnimationFrame(frame);
}

show('title');
player.reset(world.playerStart);
frame();

// handy for testing from the browser console
window.game = { player, get zombies() { return zombies; }, get state() { return state; } };
