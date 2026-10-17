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

const level = CONFIG.levels[0];

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.getElementById('game').appendChild(renderer.domElement);

const scene = new THREE.Scene();
const world = buildWorld(scene, level);
const effects = new Effects(scene);
const coins = new Coins(scene);
const shots = new Shots(scene);
const player = new Player(CONFIG.keys.p1, scene);
const shop = new ShopMenu(document.getElementById('hud'), player, world.shop);
const gym = new GymMenu(document.getElementById('hud'), player, world.gym);
// walk through a door to go in
const buildings = [{ door: world.shop.door, menu: shop }, { door: world.gym.door, menu: gym }];

const $ = (id) => document.getElementById(id);
const screens = { title: $('title'), paused: $('paused'), won: $('won') };

let state = 'title';
let zombies = [];
let spawned = 0;
let popped = 0;
let wonTimer = 0;
let toastTimer = 0;
let heartsShown = -1;
let shieldsShown = '';

function show(name) {
  state = name;
  for (const [key, el] of Object.entries(screens)) el.classList.toggle('hidden', key !== name);
  $('hud').classList.toggle('hidden', name === 'title');
  player.hand.visible = (name === 'playing' || name === 'paused') && !player.inside && !player.tagged;
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
  coins.clear();
  shots.clear();
  if (player.inside) player.menu.close();
  // Tag Bux and weapons are kept when you play again
  player.respawn(world.playerStart);
  $('tagged').classList.add('hidden');
  if (!player.weapon) player.giveStick();
  show('playing');
  toast('Bonk all the zombies!<br>Spend Tag Bux at the 🛍️ shop<br>Get strong at the 💪 gym', 3.5);
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
  if (player.statUp && !player.inside) {
    // the badge for the stat you just trained does a little jump
    const el = $(`stat-${player.statUp}`).parentElement;
    el.classList.remove('bump');
    void el.offsetWidth;
    el.classList.add('bump');
    player.statUp = null;
  }
  if ($('bux-count').textContent !== String(player.tagBux)) $('bux-count').textContent = player.tagBux;
  if (player.hearts !== heartsShown) {
    // the heart you just lost (or got back) does a little jump
    const changed = player.hearts < heartsShown ? player.hearts : heartsShown;
    let html = '';
    for (let i = 0; i < CONFIG.player.hearts; i++) {
      const jump = heartsShown >= 0 && i === changed ? ' lost' : '';
      html += `<span class="heart${i < player.hearts ? '' : ' empty'}${jump}"></span>`;
    }
    $('hearts').innerHTML = html;
    heartsShown = player.hearts;
    shieldsShown = '';
  }
  // blue armour shields go after the hearts
  const armour = player.bestArmour;
  const shieldKey = `${player.shields}/${armour ? armour.blocks : 0}`;
  if (shieldKey !== shieldsShown) {
    const old = shieldsShown ? Number(shieldsShown.split('/')[0]) : player.shields;
    $('hearts').querySelectorAll('.shield').forEach((el) => el.remove());
    for (let i = 0; i < (armour ? armour.blocks : 0); i++) {
      const el = document.createElement('span');
      el.className = `shield${i < player.shields ? '' : ' empty'}${i === player.shields && old > player.shields ? ' lost' : ''}`;
      $('hearts').appendChild(el);
    }
    shieldsShown = shieldKey;
  }
  $('hearts').classList.toggle('blink', player.safe > 0 && !player.tagged && !player.inside);
  const w = player.weapon;
  $('weapon').classList.toggle('hidden', player.inside || player.tagged > 0);
  $('weapon').classList.toggle('empty', !w);
  let text = 'No weapon! Get a free Spiky Stick at the 🛍️ shop';
  if (w) text = `${w.icon} ${w.name}`;
  if (w && w.maxHits) text += ` · ${w.hitsLeft} ${w.hitsLeft === 1 ? 'hit' : 'hits'} left`;
  if ($('weapon').innerHTML !== text) $('weapon').innerHTML = text;
}

// Makes the Tag Bux counter jump when coins go in.
function bumpBux() {
  const el = $('bux');
  el.classList.remove('bump');
  void el.offsetWidth; // restart the animation
  el.classList.add('bump');
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

// A zombie touched you: lose a heart, flash, and bump the zombie back.
function zombieTouch(zombie) {
  const hurt = player.hurt(zombie.type.touchHearts);
  if (!hurt) return;
  const away = new THREE.Vector3(zombie.pos.x - player.pos.x, 0, zombie.pos.z - player.pos.z).normalize();
  zombie.knock(away, zombie.type.bounceBack);
  zombie.dizzy = zombie.type.dizzyTime;
  const el = $('hurt');
  el.classList.toggle('shield', hurt === 'shield'); // blue for armour, pink for a lost heart
  el.classList.add('show');
  void el.offsetWidth;
  el.classList.remove('show'); // fades back out
  if (player.tagged) {
    $('tagged').classList.remove('hidden');
    toastTimer = 0;
    $('toast').classList.remove('show');
  } else if (hurt === 'shield') {
    toast('Your armour blocked it! 🛡️<br>Run away!', 1.5);
  } else {
    toast(player.hearts === 1 ? 'Ouch! Last heart! 💔<br>Run away!' : 'Ouch! 💔 Run away!', 1.5);
  }
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

  if (player.tagged || player.inside) {
    // no laser while you're tagged or inside, but let its stars fade away
    player.beam.hide();
    player.beam.update(dt, 0);
  }
  if (player.tagged) {
    player.tagged -= dt;
    $('tagged-count').textContent = Math.max(1, Math.ceil(player.tagged));
    if (player.tagged <= 0) {
      player.respawn(world.playerStart);
      $('tagged').classList.add('hidden');
      toast('Back at the start with 3 hearts! ❤️❤️❤️', 2);
    }
  } else if (player.inside) {
    if (player.menu.update(dt)) {
      player.menu.close();
      toast('See you soon! 👋', 1.5);
    }
  } else {
    for (const hit of player.update(dt, world, zombies, shots)) hitZombie(hit);
    if (player.justBroke) {
      player.justBroke = false;
      toast(player.weapon
        ? `Your stick broke! 🪵💥<br>Now holding the ${player.weapon.name}`
        : 'Your stick broke! 🪵💥<br>Get a free one at the 🛍️ shop');
    }
    for (const { door, menu } of buildings) {
      if (Math.hypot(player.pos.x - door.x, player.pos.z - door.z) < player.radius + CONFIG.shop.enterDistance) {
        player.menu = menu;
        menu.open();
        toastTimer = 0;
        $('toast').classList.remove('show');
      }
    }
  }
  for (const hit of shots.update(dt, zombies)) hitZombie(hit);

  const cleared = popped >= level.zombies;
  if (coins.update(dt, [player], world, cleared).length) bumpBux();

  for (const z of zombies) {
    if (!z.alive) continue;
    z.update(dt, player, world, zombies, player.camera);
    const d = Math.hypot(z.pos.x - player.pos.x, z.pos.z - player.pos.z);
    if (z.canTag && d < z.radius + player.radius + CONFIG.player.touchDistance) zombieTouch(z);
  }
  zombies = zombies.filter((z) => z.alive);

  if (cleared) {
    // wait for the last coins to fly into your pocket
    wonTimer += dt;
    if ((wonTimer > 1.5 && coins.list.length === 0) || wonTimer > 5) {
      $('won-bux').innerHTML = `You've got <span class="coin">T</span> ${player.tagBux} Tag Bux to spend at the shop!`;
      show('won');
    }
  }
}

const clock = new THREE.Clock();
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  update(dt);
  if (state !== 'paused') effects.update(dt);
  for (const { menu } of buildings) {
    menu.el.classList.toggle('hidden', !player.inside || player.menu !== menu || state !== 'playing');
  }
  world.shop.sign.rotation.y += dt * 1.2;
  world.gym.sign.rotation.y += dt * 1.2;

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
window.game = {
  player, world, shop, gym, coins, shots,
  get zombies() { return zombies; },
  get state() { return state; },
};
