import * as THREE from 'three';
import { CONFIG } from './config.js';
import { isDown, wasPressed } from './input.js';
import { resolveCollisions } from './world.js';
import { Beam, WEAPON_MODELS } from './weapons.js';
import { clothesColour, makeHeroBody } from './hero.js';

// Each player's camera sees the world (layer 0), their own hand (layer 1 or 2)
// and the other player's body (layer 3 or 4), but never their own body.
const HAND_LAYER = 1;
const BODY_LAYER = 3;

export class Player {
  constructor(keys, scene, look, index) {
    this.keys = keys;
    this.index = index;
    this.scene = scene;
    this.look = { ...look }; // name, skin, hair and clothes colour, from the character creator
    this.outfits = []; // cool outfits you own
    this.wearing = []; // the ones you have on
    this.created = false; // true once you've been through the character creator
    this.taggedTime = CONFIG.player.taggedTime; // main sets the 2-player time
    this.radius = CONFIG.player.radius;
    this.speedLevel = CONFIG.player.startSpeed;
    this.strengthLevel = CONFIG.player.startStrength;
    this.pos = new THREE.Vector3();
    this.yaw = 0;
    this.walkPhase = 0;

    this.camera = new THREE.PerspectiveCamera(70, 1, 0.05, 300);
    scene.add(this.camera);

    // first-person hand holding the weapon, fixed to the camera
    this.hand = new THREE.Group();
    this.hand.position.set(0.38, -0.42, -0.65);
    this.skinMat = new THREE.MeshLambertMaterial();
    this.sleeveMat = new THREE.MeshLambertMaterial();
    const fist = new THREE.Mesh(new THREE.SphereGeometry(0.09, 12, 10), this.skinMat);
    const sleeve = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.4, 10), this.sleeveMat);
    sleeve.rotation.x = Math.PI / 2;
    sleeve.position.set(0.02, -0.03, 0.22);
    this.hand.add(fist, sleeve);
    this.models = {};
    for (const [id, make] of Object.entries(WEAPON_MODELS)) {
      const model = make();
      if (CONFIG.weapons[id].kind === 'swing') {
        model.position.y = -0.15;
        model.rotation.x = -0.25;
      }
      model.visible = false;
      this.hand.add(model);
      this.models[id] = model;
    }
    this.camera.add(this.hand);
    this.hand.traverse((o) => o.layers.set(HAND_LAYER + index));
    this.camera.layers.enable(HAND_LAYER + index);
    this.camera.layers.enable(BODY_LAYER + (1 - index));

    // your whole body, which only the other player sees
    this.body = null;
    this.rebuildBody();
    this.lastPos = new THREE.Vector3();

    this.swing = 0; // counts down while swinging
    this.swingHit = false;
    this.cooldown = 0; // time until a shooting weapon can fire again
    this.recoil = 0;
    this.thrown = null; // the boomerang banana while it's flying
    this.beam = new Beam(scene); // the Sparkle Star Laser Gun's beam

    // kept between levels and when you play again
    this.tagBux = 0;
    this.weapons = []; // every weapon you own, newest last
    this.weapon = null; // the one in your hand
    this.inside = false;
    this.giveStick();

    this.bests = {}; // fastest gym times, for "PERSONAL BEST!"
    this.armour = []; // armour you own; only the best one counts
    this.shields = 0; // hits your armour can still block this level
    this.hearts = CONFIG.player.hearts;
    this.safe = 0; // counts down while you can't be hurt
    this.tagged = 0; // counts down while you're tagged, before going back to the start
    this.shake = 0;
  }

  // A zombie touch. Returns false if you couldn't be hurt, 'shield' if your armour blocked it,
  // or 'heart' if it cost you hearts.
  hurt(amount) {
    if (this.safe > 0 || this.tagged > 0 || this.inside) return false;
    this.safe = CONFIG.player.safeTime;
    this.shake = 0.3;
    if (this.shields > 0) {
      this.shields -= 1;
      return 'shield';
    }
    this.hearts = Math.max(0, this.hearts - amount);
    if (this.hearts === 0) {
      this.tagged = this.taggedTime;
      this.hand.visible = false;
    }
    return 'heart';
  }

  get bestArmour() {
    let best = null;
    for (const id of this.armour) {
      if (!best || CONFIG.armour[id].blocks > best.blocks) best = { id, ...CONFIG.armour[id] };
    }
    return best;
  }

  refillShields() {
    this.shields = this.bestArmour ? this.bestArmour.blocks : 0;
  }

  addArmour(id) {
    this.armour.push(id);
    this.refillShields();
  }

  // Back to the start with full hearts, keeping Tag Bux, weapons and training.
  respawn(start) {
    this.reset(start);
    this.hearts = CONFIG.player.hearts;
    this.refillShields();
    this.tagged = 0;
    this.safe = CONFIG.player.safeTime;
    this.hand.visible = true;
  }

  get moveSpeed() {
    return CONFIG.player.baseSpeed * (1 + CONFIG.player.speedPerLevel * (this.speedLevel - 1));
  }

  get damageMultiplier() {
    return 1 + CONFIG.player.strengthPerLevel * (this.strengthLevel - 1);
  }

  get name() {
    return this.look.name;
  }

  // Makes your body (and the hand you see) match your look and outfits.
  rebuildBody() {
    const visible = this.body ? this.body.root.visible : false;
    if (this.body) this.scene.remove(this.body.root);
    this.body = makeHeroBody(this.look, this.wearing);
    this.body.root.traverse((o) => o.layers.set(BODY_LAYER + this.index));
    this.body.root.visible = visible;
    this.scene.add(this.body.root);
    this.skinMat.color.set(this.look.skin);
    this.sleeveMat.color.set(clothesColour(this.look, this.wearing));
  }

  setLook(look) {
    this.look = { ...this.look, ...look };
    this.rebuildBody();
  }

  // Put on an outfit you own, taking off anything it covers.
  wear(id) {
    const covers = CONFIG.outfits[id].covers;
    this.wearing = this.wearing.filter((w) => !CONFIG.outfits[w].covers.some((c) => covers.includes(c)));
    this.wearing.push(id);
    this.rebuildBody();
  }

  takeOff(id) {
    this.wearing = this.wearing.filter((w) => w !== id);
    this.rebuildBody();
  }

  // Moves and animates your body for the other player to see.
  updateBody(dt, show) {
    const b = this.body;
    b.root.visible = show && !this.inside && !this.tagged;
    if (!b.root.visible) return;
    const moved = Math.hypot(this.pos.x - this.lastPos.x, this.pos.z - this.lastPos.z) / Math.max(dt, 0.001);
    this.lastPos.copy(this.pos);
    b.root.position.set(this.pos.x, 0, this.pos.z);
    b.root.rotation.y = this.yaw;
    const swing = moved > 0.5 ? Math.sin(this.walkPhase) * 0.6 : 0;
    b.legs[0].rotation.x = swing;
    b.legs[1].rotation.x = -swing;
    b.arms[0].rotation.x = -swing * 0.7;
    // the weapon arm chops down when you attack
    b.arms[1].rotation.x = this.swing > 0 || this.recoil > 0.3 ? -1.4 : swing * 0.7;
    if (b.cape) b.cape.rotation.x = -0.12 - Math.min(0.6, moved * 0.08) - Math.sin(performance.now() / 150) * 0.05;
  }

  reset(start) {
    this.pos.set(start.x, 0, start.z);
    this.yaw = start.yaw;
    this.swing = 0;
    this.attackQueued = false;
    this.cooldown = 0;
    this.inside = false;
    this.shake = 0;
    this.hand.rotation.set(0, 0, 0);
  }

  owns(id) {
    return this.weapons.some((w) => w.id === id);
  }

  // A new weapon goes straight into your hand.
  addWeapon(id) {
    const w = { id, ...CONFIG.weapons[id] };
    if (w.maxHits) w.hitsLeft = w.maxHits;
    this.weapons.push(w);
    this.hold(id);
  }

  giveStick() {
    this.addWeapon('spikyStick');
  }

  hold(id) {
    this.weapon = this.weapons.find((w) => w.id === id) || null;
    this.attackQueued = false;
    this.swing = 0;
    this.hand.rotation.set(0, 0, 0);
    for (const [key, model] of Object.entries(this.models)) model.visible = key === id;
  }

  get forward() {
    return new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
  }

  // Holding a gun: a kick back when it fires, and a little sway as you walk.
  aimPose(move) {
    this.hand.rotation.set(this.recoil * 0.15 + Math.sin(this.walkPhase * 0.5) * 0.03 * (move ? 1 : 0), 0, 0);
    this.hand.position.z = -0.65 + this.recoil * 0.06;
  }

  // Every zombie roughly in front of you and in reach (for the Rubber Chicken Hammer).
  findTargets(zombies) {
    const w = this.weapon;
    const cosLimit = Math.cos(THREE.MathUtils.degToRad(w.aimAngle));
    return zombies.filter((z) => {
      if (!z.alive) return false;
      const to = new THREE.Vector3(z.pos.x - this.pos.x, 0, z.pos.z - this.pos.z);
      if (to.length() - z.radius > w.range) return false;
      return to.length() < 0.001 || to.normalize().dot(this.forward) >= cosLimit;
    });
  }

  // Aim help: the nearest zombie roughly in front of you and in reach.
  findTarget(zombies) {
    const w = this.weapon;
    const cosLimit = Math.cos(THREE.MathUtils.degToRad(w.aimAngle));
    const fwd = this.forward;
    let best = null;
    let bestDist = Infinity;
    for (const z of zombies) {
      if (!z.alive) continue;
      const to = new THREE.Vector3(z.pos.x - this.pos.x, 0, z.pos.z - this.pos.z);
      const d = to.length() - z.radius;
      if (d > w.range || d >= bestDist) continue;
      if (to.length() > 0.001 && to.normalize().dot(fwd) < cosLimit) continue;
      best = z;
      bestDist = d;
    }
    return best;
  }

  // Returns the hits landed this frame: [{ zombie, weapon, by, push }]
  update(dt, world, zombies, shots) {
    const k = this.keys;
    let turn = 0;
    if (isDown(k.left)) turn += 1;
    if (isDown(k.right)) turn -= 1;
    this.yaw += turn * CONFIG.player.turnSpeed * dt;

    let move = 0;
    if (isDown(k.forward)) move += 1;
    if (isDown(k.back)) move -= 0.7;
    if (move !== 0) {
      this.pos.addScaledVector(this.forward, move * this.moveSpeed * dt);
      this.walkPhase += dt * this.moveSpeed * 2.2;
    }
    resolveCollisions(this.pos, this.radius, world);
    for (const z of zombies) {
      if (!z.alive) continue;
      const dx = this.pos.x - z.pos.x;
      const dz = this.pos.z - z.pos.z;
      const d = Math.hypot(dx, dz);
      const min = this.radius + z.radius;
      if (d < min && d > 0.0001) {
        this.pos.x = z.pos.x + (dx / d) * min;
        this.pos.z = z.pos.z + (dz / d) * min;
      }
    }

    // camera with a little head bob
    const bob = move !== 0 ? Math.sin(this.walkPhase) * 0.05 : 0;
    this.camera.position.set(this.pos.x, CONFIG.player.eyeHeight + bob, this.pos.z);
    // a little wobble when a zombie tags you
    this.shake = Math.max(0, this.shake - dt);
    if (this.shake > 0) {
      this.camera.position.x += (Math.random() - 0.5) * this.shake * 0.5;
      this.camera.position.y += (Math.random() - 0.5) * this.shake * 0.5;
    }
    // blink your hand while you can't be hurt
    this.safe = Math.max(0, this.safe - dt);
    this.hand.visible = this.safe <= 0 || Math.floor(this.safe * 8) % 2 === 0;
    this.camera.rotation.set(0, this.yaw, 0);

    // ---- attack ----
    const hits = [];
    const w = this.weapon;
    // a press during a swing is remembered, so mashing Space never feels ignored
    if (wasPressed(k.attack)) this.attackQueued = true;
    this.cooldown -= dt;
    this.recoil = Math.max(0, this.recoil - dt * 8);

    // where shots and the laser come out: just in front of the gun in your hand
    const fwd = this.forward;
    const right = new THREE.Vector3(-fwd.z, 0, fwd.x);
    const muzzle = this.pos.clone().addScaledVector(fwd, 0.9).addScaledVector(right, 0.3).setY(1.2);

    if (w && w.kind === 'beam') {
      // hold Space for a laser that hits whatever it's pointing at, again and again
      if (isDown(k.attack) || this.attackQueued) {
        this.attackQueued = false;
        const target = this.findTarget(zombies);
        const end = target ? target.centre : muzzle.clone().addScaledVector(fwd, w.range);
        this.beam.show(muzzle, end);
        if (this.cooldown <= 0 && target) {
          this.cooldown = w.fireInterval;
          hits.push({ zombie: target, weapon: w, by: this, push: fwd, at: target.centre });
        }
        this.recoil = 0.4;
      } else this.beam.hide();
      this.beam.update(dt, w.starsPerSecond);
      this.aimPose(move);
      return hits;
    }
    this.beam.hide();
    this.beam.update(dt, 0);

    if (w && w.kind === 'throw') {
      // the banana leaves your hand until it comes back
      this.models[w.id].visible = !this.thrown;
      if (this.attackQueued && !this.thrown) {
        this.attackQueued = false;
        const target = this.findTarget(zombies);
        const dir = target ? target.centre.sub(muzzle).setY(0).normalize() : fwd.clone();
        shots.fire(muzzle, dir, w, this, null);
      }
      this.aimPose(move);
      return hits;
    }

    if (w && w.kind === 'shoot') {
      // hold Space to keep shooting
      if ((this.attackQueued || isDown(k.attack)) && this.cooldown <= 0) {
        this.attackQueued = false;
        this.cooldown = w.fireInterval;
        this.recoil = 1;
        const target = this.findTarget(zombies);
        const dir = target ? target.centre.sub(muzzle).normalize() : fwd.clone();
        shots.fire(muzzle, dir, w, this, target ? target.centre : null);
      }
      this.aimPose(move);
      return hits;
    }
    this.hand.position.z = -0.65;

    if (this.attackQueued && w && this.swing <= 0) {
      this.attackQueued = false;
      this.swing = w.swingTime;
      this.swingHit = false;
    }
    if (this.swing > 0) {
      this.swing -= dt;
      const t = 1 - Math.max(0, this.swing) / w.swingTime; // 0 → 1
      if (!this.swingHit && t >= 0.45) {
        this.swingHit = true;
        const targets = w.hitsAll ? this.findTargets(zombies) : [this.findTarget(zombies)].filter(Boolean);
        for (const target of targets) hits.push({ zombie: target, weapon: w, by: this, push: this.forward });
        if (targets.length && w.maxHits) w.hitsLeft -= 1;
      }
      // wind up, chop down towards the middle of the screen, then come back up
      let x, z;
      if (t < 0.25) {
        const u = t / 0.25;
        x = 0.5 * u;
        z = -0.2 * u;
      } else if (t < 0.55) {
        const u = (t - 0.25) / 0.3;
        x = 0.5 - 1.9 * u;
        z = -0.2 + 0.9 * u;
      } else {
        const u = 1 - (t - 0.55) / 0.45;
        x = -1.4 * u;
        z = 0.7 * u;
      }
      this.hand.rotation.set(x, 0, z);
      if (this.swing <= 0) {
        this.hand.rotation.set(0, 0, 0);
        if (w.maxHits && w.hitsLeft <= 0) {
          // it broke: hold your newest other weapon, if you have one
          this.weapons = this.weapons.filter((o) => o !== w);
          const next = this.weapons[this.weapons.length - 1];
          this.hold(next ? next.id : null);
          this.justBroke = true;
        }
      }
    } else {
      this.hand.rotation.set(Math.sin(this.walkPhase * 0.5) * 0.04 * (move ? 1 : 0), 0, 0);
    }
    return hits;
  }
}
