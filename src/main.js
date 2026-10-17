import * as THREE from 'three';
import { CONFIG } from './config.js';
import { endFrame, wasPressed } from './input.js';
import { buildWorld } from './world.js';
import { Zombie } from './zombie.js';
import { Player } from './player.js';
import { Effects } from './effects.js';
import { Coins } from './coins.js';
import { SPLASH_COLOURS, Shots } from './weapons.js';
import { ShopMenu } from './shop.js';
import { GymMenu } from './gym.js';
import { Hud } from './hud.js';

const level = CONFIG.levels[0];

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false; // drawn once a frame, even when the screen is split
document.getElementById('game').appendChild(renderer.domElement);

const $ = (id) => document.getElementById(id);
const screens = { title: $('title'), paused: $('paused'), won: $('won') };

const scene = new THREE.Scene();
const world = buildWorld(scene, level);
const effects = new Effects(scene);
const coins = new Coins(scene);
const shots = new Shots(scene);

// Both heroes always exist; in 1-player mode only the first one plays.
const players = CONFIG.heroes.map((look, i) => new Player(i === 0 ? CONFIG.keys.p1 : CONFIG.keys.p2, scene, look, i));
const huds = players.map((p, i) => new Hud($('hud'), p, i + 1));
const menus = players.map((p, i) => ({
  shop: new ShopMenu(huds[i].inner, p, world.shop),
  gym: new GymMenu(huds[i].inner, p, world.gym),
}));
for (const m of menus) m.shop.onGive = flyCoins;
// walk through a door to go in
const buildings = [{ door: world.shop.door, menu: 'shop' }, { door: world.gym.door, menu: 'gym' }];

let state = 'title';
let playerCount = 1;
let titleChoice = 0; // 0: 1 player, 1: 2 players
let active = [players[0]]; // the heroes playing right now
let zombies = [];
let levelZombies = level.zombies;
let spawned = 0;
let popped = 0;
let wonTimer = 0;

function show(name) {
  state = name;
  for (const [key, el] of Object.entries(screens)) el.classList.toggle('hidden', key !== name);
  $('hud').classList.toggle('hidden', name === 'title');
  for (const p of active) {
    p.hand.visible = (name === 'playing' || name === 'paused') && !p.inside && !p.tagged;
  }
  if (name !== 'playing') huds.forEach((h) => h.clearToast());
  if (name === 'title') drawTitle();
}

const toastAll = (text, seconds) => active.forEach((p) => huds[p.index].toast(text, seconds));

function drawTitle() {
  document.querySelectorAll('#title .choice').forEach((el, i) => el.classList.toggle('selected', i === titleChoice));
  $('p2-keys').classList.toggle('hidden', titleChoice === 0);
}

// Where each hero begins: side by side in 2-player mode.
function startFor(p) {
  const s = world.playerStart;
  const side = playerCount === 2 ? (p.index === 0 ? -1.5 : 1.5) : 0;
  return { x: s.x + side, z: s.z, yaw: s.yaw };
}

function startLevel() {
  for (const z of zombies) scene.remove(z.root);
  zombies = [];
  spawned = 0;
  popped = 0;
  wonTimer = 0;
  coins.clear();
  shots.clear();
  for (const p of players) if (p.inside) p.menu.close();

  const two = playerCount === 2;
  active = players.slice(0, playerCount);
  levelZombies = Math.round(level.zombies * (two ? CONFIG.twoPlayerZombies : 1));
  $('hud').classList.toggle('split', two);
  huds[1].el.classList.toggle('hidden', !two);
  for (const p of active) {
    // Tag Bux, weapons, armour and training are all kept when you play again
    p.taggedTime = two ? CONFIG.player.taggedTimeTwoPlayers : CONFIG.player.taggedTime;
    p.respawn(startFor(p));
    huds[p.index].showTagged(false);
    if (!p.weapon) p.giveStick();
    menus[p.index].shop.partner = two ? players[1 - p.index] : null;
  }
  show('playing');
  toastAll('Bonk all the zombies!<br>Spend Tag Bux at the 🛍️ shop<br>Get strong at the 💪 gym', 3.5);
}

function spawnWave() {
  const count = Math.min(level.waveSize, levelZombies - spawned);
  for (let i = 0; i < count; i++) {
    for (let tries = 0; tries < 100; tries++) {
      const x = (Math.random() - 0.5) * (level.size - 6);
      const z = (Math.random() - 0.5) * (level.size - 6);
      // not too close to any hero
      if (active.some((p) => Math.hypot(x - p.pos.x, z - p.pos.z) < 22)) continue;
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
    effects.floatText(at.clone().setY(at.y + 1.2), weapon.word, '#ff8a1f', 1.8);
    return;
  }
  if (!zombie.alive) return;
  if (weapon.shot && at) effects.splash(at, 12, SPLASH_COLOURS[weapon.shot]);
  zombie.weaponEffects(weapon);
  if (weapon.knockback && push) zombie.knock(push, weapon.knockback);
  const popping = zombie.hit(weapon.damage * by.damageMultiplier);
  const word = weapon.word || 'BONK!';
  // the chicken squawks on every hit, even ones that pop
  if (weapon.id === 'chickenHammer') {
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, popping ? 2 : 0.8, 0)), word, '#ffe066', 1.3);
  }
  if (popping) {
    effects.confetti(zombie.centre);
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, 1, 0)), 'POP!', '#9cff57', 1.4);
    coins.burst(zombie.centre, zombie.type.tagBux);
    scene.remove(zombie.root);
    popped++;
  } else if (weapon.id !== 'chickenHammer' && !(zombie.wordTime > clock.elapsedTime - 0.6)) {
    // fast weapons hit so often that they only say their word now and then
    zombie.wordTime = clock.elapsedTime;
    effects.floatText(zombie.centre.add(new THREE.Vector3(0, 0.8, 0)), word, '#ffe066', 1.1);
  }
}

// A zombie touched a hero: lose a shield or a heart, flash, and bump the zombie back.
function zombieTouch(zombie, p) {
  const hurt = p.hurt(zombie.type.touchHearts);
  if (!hurt) return;
  const hud = huds[p.index];
  const away = new THREE.Vector3(zombie.pos.x - p.pos.x, 0, zombie.pos.z - p.pos.z).normalize();
  zombie.knock(away, zombie.type.bounceBack);
  zombie.dizzy = zombie.type.dizzyTime;
  hud.flash(hurt);
  if (p.tagged) hud.showTagged(true);
  else if (hurt === 'shield') hud.toast('Your armour blocked it! 🛡️<br>Run away!', 1.5);
  else hud.toast(p.hearts === 1 ? 'Ouch! Last heart! 💔<br>Run away!' : 'Ouch! 💔 Run away!', 1.5);
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
    for (const { door, menu } of buildings) {
      if (Math.hypot(p.pos.x - door.x, p.pos.z - door.z) < p.radius + CONFIG.shop.enterDistance) {
        p.menu = menus[p.index][menu];
        p.menu.open();
        hud.clearToast();
      }
    }
  }
}

function update(dt) {
  if (wasPressed(['Escape']) && (state === 'playing' || state === 'paused')) {
    show(state === 'playing' ? 'paused' : 'playing');
    return;
  }
  if (state === 'paused' && wasPressed(['KeyQ'])) {
    for (const p of players) if (p.inside) p.menu.close();
    show('title');
    return;
  }
  if (state === 'title') {
    // choose 1 or 2 players with W/S or the arrows (or just press 1 or 2)
    const k = CONFIG.keys;
    if (wasPressed([...k.p1.forward, ...k.p2.forward, ...k.p1.left, ...k.p2.left])) titleChoice = 0;
    if (wasPressed([...k.p1.back, ...k.p2.back, ...k.p1.right, ...k.p2.right])) titleChoice = 1;
    if (wasPressed(['Digit1', 'Numpad1'])) titleChoice = 0;
    if (wasPressed(['Digit2', 'Numpad2'])) titleChoice = 1;
    drawTitle();
    if (wasPressed(['Space', 'Enter', 'NumpadEnter', 'Digit1', 'Digit2', 'Numpad1', 'Numpad2'])) {
      playerCount = titleChoice + 1;
      startLevel();
    }
    return;
  }
  if (state === 'won') {
    if (wasPressed(['Space', 'Enter', 'NumpadEnter'])) startLevel();
    return;
  }
  if (state !== 'playing') return;

  const alive = zombies.filter((z) => z.alive).length;
  if (spawned < levelZombies && alive <= level.nextWaveWhenLeft) spawnWave();

  for (const p of active) updatePlayer(p, dt);
  for (const hit of shots.update(dt, zombies)) hitZombie(hit);

  const cleared = popped >= levelZombies;
  for (const { player } of coins.update(dt, active, world, cleared)) huds[player.index].bumpBux();

  for (const z of zombies) {
    if (!z.alive) continue;
    z.update(dt, active, world, zombies);
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

  if (cleared) {
    // wait for the last coins to fly into your pockets
    wonTimer += dt;
    if ((wonTimer > 1.5 && coins.list.length === 0) || wonTimer > 5) {
      const coin = '<span class="coin">T</span>';
      $('won-bux').innerHTML = playerCount === 1
        ? `You've got ${coin} ${players[0].tagBux} Tag Bux to spend at the shop!`
        : active.map((p) => `${p.name}: ${coin} ${p.tagBux}`).join(' &nbsp; ');
      show('won');
    }
  }
}

const clock = new THREE.Clock();
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  update(dt);
  if (state !== 'paused') effects.update(dt);
  for (const p of players) {
    const m = menus[p.index];
    for (const menu of [m.shop, m.gym]) {
      menu.el.classList.toggle('hidden', !p.inside || p.menu !== menu || state !== 'playing');
    }
    p.updateBody(dt, state !== 'title' && playerCount === 2 && active.includes(p));
  }
  world.shop.sign.rotation.y += dt * 1.2;
  world.gym.sign.rotation.y += dt * 1.2;
  for (const p of active) huds[p.index].update(dt, levelZombies - popped);

  // The title screen shows the park slowly turning behind it.
  const views = state === 'title' ? [players[0]] : active;
  if (state === 'title') {
    const t = clock.elapsedTime * 0.08;
    players[0].camera.position.set(Math.sin(t) * 30, 8, Math.cos(t) * 30);
    players[0].camera.lookAt(0, 2, 0);
  }

  // draw the world once for each player, side by side
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  renderer.shadowMap.needsUpdate = true;
  renderer.setScissorTest(views.length > 1);
  const vw = w / views.length;
  views.forEach((p, i) => {
    p.camera.aspect = vw / h;
    p.camera.updateProjectionMatrix();
    for (const z of zombies) z.updateBar(p.camera);
    renderer.setViewport(i * vw, 0, vw, h);
    renderer.setScissor(i * vw, 0, vw, h);
    renderer.render(scene, p.camera);
  });

  endFrame();
  requestAnimationFrame(frame);
}

show('title');
for (const p of players) p.reset(world.playerStart);
frame();

// handy for testing from the browser console
window.game = {
  players, huds, menus, world, coins, shots,
  player: players[0], shop: menus[0].shop, gym: menus[0].gym,
  get active() { return active; },
  get zombies() { return zombies; },
  get state() { return state; },
};
