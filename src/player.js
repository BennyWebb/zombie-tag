import * as THREE from 'three';
import { CONFIG } from './config.js';
import { isDown, wasPressed } from './input.js';
import { resolveCollisions } from './world.js';

const skinMat = new THREE.MeshLambertMaterial({ color: 0xf1c27d });
const sleeveMat = new THREE.MeshLambertMaterial({ color: 0xff6fae });

function makeSpikyStick() {
  const stick = new THREE.Group();
  const wood = new THREE.MeshLambertMaterial({ color: 0x8b5a2b });
  const spikeMat = new THREE.MeshLambertMaterial({ color: 0xd9c27a });
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.05, 0.9, 8), wood);
  pole.position.y = 0.45;
  stick.add(pole);
  // spikes round the top end
  for (let i = 0; i < 10; i++) {
    const spike = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.12, 6), spikeMat);
    const a = i * 2.4;
    const y = 0.6 + (i / 10) * 0.3;
    spike.position.set(Math.cos(a) * 0.05, y, Math.sin(a) * 0.05);
    spike.rotation.set(Math.sin(a) * Math.PI / 2, 0, -Math.cos(a) * Math.PI / 2);
    stick.add(spike);
  }
  return stick;
}

export class Player {
  constructor(keys, scene) {
    this.keys = keys;
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
    const fist = new THREE.Mesh(new THREE.SphereGeometry(0.09, 12, 10), skinMat);
    const sleeve = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.4, 10), sleeveMat);
    sleeve.rotation.x = Math.PI / 2;
    sleeve.position.set(0.02, -0.03, 0.22);
    this.hand.add(fist, sleeve);
    this.stickMesh = makeSpikyStick();
    this.stickMesh.position.y = -0.15;
    this.stickMesh.rotation.x = -0.25;
    this.hand.add(this.stickMesh);
    this.camera.add(this.hand);

    this.swing = 0; // counts down while swinging
    this.swingHit = false;
  }

  get moveSpeed() {
    return CONFIG.player.baseSpeed * (1 + CONFIG.player.speedPerLevel * (this.speedLevel - 1));
  }

  get damageMultiplier() {
    return 1 + CONFIG.player.strengthPerLevel * (this.strengthLevel - 1);
  }

  reset(start) {
    this.pos.set(start.x, 0, start.z);
    this.yaw = start.yaw;
    this.swing = 0;
    this.attackQueued = false;
    this.hand.rotation.set(0, 0, 0);
    this.giveStick();
  }

  giveStick() {
    this.weapon = { ...CONFIG.weapons.spikyStick, hitsLeft: CONFIG.weapons.spikyStick.maxHits };
    this.attackQueued = false;
    this.stickMesh.visible = true;
  }

  get forward() {
    return new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
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

  // Returns the zombie that got bonked this frame, if any.
  update(dt, world, zombies) {
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
    this.camera.rotation.set(0, this.yaw, 0);

    // ---- attack ----
    let bonked = null;
    // a press during a swing is remembered, so mashing Space never feels ignored
    if (wasPressed(k.attack)) this.attackQueued = true;
    if (this.attackQueued && this.weapon && this.swing <= 0) {
      this.attackQueued = false;
      this.swing = this.weapon.swingTime;
      this.swingHit = false;
    }
    if (this.swing > 0) {
      this.swing -= dt;
      const t = 1 - Math.max(0, this.swing) / this.weapon.swingTime; // 0 → 1
      if (!this.swingHit && t >= 0.45) {
        this.swingHit = true;
        const target = this.findTarget(zombies);
        if (target) {
          bonked = target;
          this.weapon.hitsLeft -= 1;
        }
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
        if (this.weapon.hitsLeft <= 0) {
          this.weapon = null;
          this.stickMesh.visible = false;
          this.justBroke = true;
        }
      }
    } else {
      this.hand.rotation.set(Math.sin(this.walkPhase * 0.5) * 0.04 * (move ? 1 : 0), 0, 0);
    }
    return bonked;
  }
}
