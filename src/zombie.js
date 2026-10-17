import * as THREE from 'three';
import { resolveCollisions } from './world.js';

const SKINS = [0x8fdc5a, 0x6fd0b0, 0x7fb8ff, 0xa6e05a];
const SHIRTS = [0xb28dff, 0xff8a3d, 0xff6fae, 0xffe066, 0x4fc3f7];
const pick = (list) => list[Math.floor(Math.random() * list.length)];

function makeEye(size) {
  const eye = new THREE.Group();
  const white = new THREE.Mesh(
    new THREE.SphereGeometry(size, 14, 12),
    new THREE.MeshLambertMaterial({ color: 0xffffff }),
  );
  const pupil = new THREE.Mesh(
    new THREE.SphereGeometry(size * 0.45, 10, 8),
    new THREE.MeshBasicMaterial({ color: 0x111111 }),
  );
  pupil.position.z = size * 0.75;
  eye.add(white, pupil);
  eye.userData.pupil = pupil;
  return eye;
}

const bubbleGeo = new THREE.SphereGeometry(1.25, 20, 16);
const bubbleMat = new THREE.MeshBasicMaterial({ color: 0xe0c8ff, transparent: true, opacity: 0.35, depthWrite: false });
const iceGeo = new THREE.BoxGeometry(1.4, 2.3, 1.4);
const iceMat = new THREE.MeshLambertMaterial({
  color: 0xbfe8ff, transparent: true, opacity: 0.55, emissive: 0x335577, depthWrite: false,
});

// The colour a zombie glows: white when hit, blue when frozen, green when slimed.
const glowWhite = new THREE.Color(0xffffff);
const glowIce = new THREE.Color(0x3a78b0);
const glowSlime = new THREE.Color(0x2f7a10);
const glowNone = new THREE.Color(0x000000);

function makeShufflerMesh() {
  const skin = new THREE.MeshLambertMaterial({ color: pick(SKINS) });
  const shirt = new THREE.MeshLambertMaterial({ color: pick(SHIRTS) });
  const trousers = new THREE.MeshLambertMaterial({ color: 0x5a4a8a });

  const root = new THREE.Group(); // turns to face where it walks
  const body = new THREE.Group(); // wobbles and squashes
  root.add(body);

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.42, 0.5, 6, 14), shirt);
  torso.position.y = 1.0;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.42, 18, 14), skin);
  head.position.y = 1.75;
  body.add(torso, head);

  // googly eyes, one bigger than the other
  const eyeL = makeEye(0.17);
  eyeL.position.set(-0.17, 1.86, 0.33);
  const eyeR = makeEye(0.12);
  eyeR.position.set(0.17, 1.84, 0.36);
  body.add(eyeL, eyeR);

  // a surprised "O" mouth
  const mouth = new THREE.Mesh(
    new THREE.TorusGeometry(0.08, 0.035, 8, 16),
    new THREE.MeshBasicMaterial({ color: 0x3a1030 }),
  );
  mouth.position.set(0.02, 1.6, 0.4);
  body.add(mouth);

  // arms stuck out in front
  const arms = [];
  for (const x of [-0.5, 0.5]) {
    const arm = new THREE.Mesh(new THREE.CapsuleGeometry(0.11, 0.6, 4, 8), skin);
    arm.rotation.x = Math.PI / 2;
    arm.position.set(x, 1.25, 0.4);
    body.add(arm);
    arms.push(arm);
  }
  const legs = [];
  for (const x of [-0.18, 0.18]) {
    const leg = new THREE.Mesh(new THREE.CapsuleGeometry(0.13, 0.4, 4, 8), trousers);
    leg.position.set(x, 0.33, 0);
    body.add(leg);
    legs.push(leg);
  }

  root.traverse((o) => {
    if (o.isMesh) o.castShadow = true;
  });

  // floating health bar, shown once the zombie has been hit
  const bar = new THREE.Group();
  const back = new THREE.Mesh(
    new THREE.PlaneGeometry(1.0, 0.14),
    new THREE.MeshBasicMaterial({ color: 0x222222, depthTest: false }),
  );
  const fill = new THREE.Mesh(
    new THREE.PlaneGeometry(0.94, 0.09),
    new THREE.MeshBasicMaterial({ color: 0x9cff57, depthTest: false }),
  );
  fill.position.z = 0.001;
  bar.add(back, fill);
  bar.position.y = 2.5;
  bar.visible = false;
  bar.renderOrder = 5;
  root.add(bar);

  // stars that circle its head when it's dizzy
  const stars = new THREE.Group();
  const starMat = new THREE.MeshBasicMaterial({ color: 0xffe066 });
  for (let i = 0; i < 3; i++) {
    const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.12), starMat);
    const a = (i / 3) * Math.PI * 2;
    star.position.set(Math.cos(a) * 0.5, 0, Math.sin(a) * 0.5);
    stars.add(star);
  }
  stars.position.y = 2.3;
  stars.visible = false;
  root.add(stars);

  // a floating bubble (Bubble Blaster) and a block of ice (Snowball Cannon), shown when needed
  const bubble = new THREE.Mesh(bubbleGeo, bubbleMat);
  bubble.position.y = 1.1;
  bubble.visible = false;
  const ice = new THREE.Mesh(iceGeo, iceMat);
  ice.position.y = 1.05;
  ice.visible = false;
  root.add(bubble, ice);

  return {
    root, body, eyes: [eyeL, eyeR], arms, legs, bar, barFill: fill, stars, bubble, ice,
    flashMats: [skin, shirt, trousers],
  };
}

export class Zombie {
  constructor(type, healthMultiplier, x, z) {
    this.type = type;
    this.maxHealth = type.health * healthMultiplier;
    this.health = this.maxHealth;
    this.radius = type.radius;
    this.pos = new THREE.Vector3(x, 0, z);
    this.yaw = Math.random() * Math.PI * 2;
    this.wanderTarget = null;
    this.wanderTimer = 0;
    this.flash = 0;
    this.squash = 0;
    this.spawnPop = 0; // grows out of the ground when it arrives
    this.time = Math.random() * 10;
    this.alive = true;
    this.knockVel = new THREE.Vector3(); // set when a weapon bonks or squirts it backwards
    this.dizzy = 0; // counts down after it tags you; it stands still while dizzy
    // weapon effects, each counting down: slimed (slow), trapped in a bubble, frozen solid
    this.slowTime = 0;
    this.slowSpeed = 1;
    this.bubbleTime = 0;
    this.frozenTime = 0;
    this.lift = 0; // how high its bubble has floated
    Object.assign(this, makeShufflerMesh());
    this.root.position.copy(this.pos);
  }

  get centre() {
    return new THREE.Vector3(this.pos.x, 1.2, this.pos.z);
  }

  hit(damage) {
    this.health -= damage;
    this.flash = 0.15;
    this.squash = 1;
    this.bar.visible = true;
    this.barFill.scale.x = Math.max(0, this.health / this.maxHealth);
    this.barFill.position.x = -0.47 * (1 - this.barFill.scale.x);
    if (this.health <= 0.0001) this.alive = false;
    return !this.alive;
  }

  knock(dir, amount) {
    if (this.bubbleTime > 0 || this.frozenTime > 0) return; // bubbles and ice blocks don't get pushed
    this.knockVel.addScaledVector(dir, amount);
  }

  // What a weapon does besides damage.
  weaponEffects(w) {
    if (w.slowTime) {
      this.slowTime = w.slowTime;
      this.slowSpeed = w.slowSpeed;
    }
    if (w.bubbleTime) this.bubbleTime = w.bubbleTime;
    if (w.freezeTime) this.frozenTime = w.freezeTime;
  }

  // Standing still: dizzy, trapped in a bubble or frozen.
  get stuck() {
    return this.dizzy > 0 || this.bubbleTime > 0 || this.frozenTime > 0;
  }

  // Only a zombie that's fully arrived and not stuck can tag you.
  get canTag() {
    return this.spawnPop >= 1 && !this.stuck;
  }

  update(dt, player, world, others, camera) {
    this.time += dt;
    this.spawnPop = Math.min(1, this.spawnPop + dt * 2);
    this.dizzy = Math.max(0, this.dizzy - dt);
    this.slowTime = Math.max(0, this.slowTime - dt);
    this.bubbleTime = Math.max(0, this.bubbleTime - dt);
    this.frozenTime = Math.max(0, this.frozenTime - dt);

    const toPlayer = new THREE.Vector3(player.pos.x - this.pos.x, 0, player.pos.z - this.pos.z);
    const dist = toPlayer.length();
    let speed = 0;
    let dir = null;

    if (this.stuck) {
      // seeing stars, bubbled or frozen: stay put
    } else if (dist < this.type.noticeDistance && !player.tagged) {
      // chase, and stop once touching the hero (the touch costs them a heart)
      const touching = this.radius + player.radius + 0.15;
      if (dist > touching) {
        dir = toPlayer.normalize();
        speed = this.type.chaseSpeed;
      } else {
        this.yaw = Math.atan2(toPlayer.x, toPlayer.z);
      }
      this.wanderTarget = null;
    } else {
      this.wanderTimer -= dt;
      if (!this.wanderTarget || this.wanderTimer <= 0) {
        this.wanderTarget = new THREE.Vector3(
          this.pos.x + (Math.random() - 0.5) * 16, 0, this.pos.z + (Math.random() - 0.5) * 16,
        );
        this.wanderTimer = 3 + Math.random() * 4;
      }
      const toTarget = new THREE.Vector3().subVectors(this.wanderTarget, this.pos).setY(0);
      if (toTarget.length() > 0.5) {
        dir = toTarget.normalize();
        speed = this.type.wanderSpeed;
      }
    }

    // being knocked back slides it away and stops it walking for a moment
    const knocked = this.knockVel.length();
    if (knocked > 0.05) {
      this.pos.addScaledVector(this.knockVel, dt);
      this.knockVel.multiplyScalar(Math.exp(-6 * dt));
      speed *= Math.max(0, 1 - knocked / 3);
    }

    if (this.slowTime > 0) speed *= this.slowSpeed;
    if (dir) {
      this.pos.addScaledVector(dir, speed * dt);
      // turn smoothly towards where it's going
      const want = Math.atan2(dir.x, dir.z);
      let diff = want - this.yaw;
      diff = Math.atan2(Math.sin(diff), Math.cos(diff));
      this.yaw += diff * Math.min(1, dt * 5);
    }

    // don't stand inside each other
    for (const o of others) {
      if (o === this || !o.alive) continue;
      const dx = this.pos.x - o.pos.x;
      const dz = this.pos.z - o.pos.z;
      const d = Math.hypot(dx, dz);
      const min = this.radius + o.radius;
      if (d < min && d > 0.0001) {
        this.pos.x += (dx / d) * (min - d) * 0.5;
        this.pos.z += (dz / d) * (min - d) * 0.5;
      }
    }
    resolveCollisions(this.pos, this.radius, world);

    // ---- silly animation ----
    this.stars.visible = this.dizzy > 0;
    if (this.dizzy > 0) this.stars.rotation.y += dt * 6;
    this.bubble.visible = this.bubbleTime > 0;
    this.ice.visible = this.frozenTime > 0;
    // a bubble floats it up, then it drops back down when the bubble pops
    this.lift += ((this.bubbleTime > 0 ? 1.3 : 0) - this.lift) * Math.min(1, dt * (this.bubbleTime > 0 ? 2 : 8));
    if (this.bubbleTime > 0) this.bubble.scale.setScalar(1 + Math.sin(this.time * 4) * 0.04);
    this.root.position.copy(this.pos);
    this.root.position.y = this.lift;
    this.root.rotation.y = this.yaw;
    if (this.frozenTime > 0) {
      // frozen solid: no wobbling at all
      this.flash = Math.max(0, this.flash - dt);
      for (const m of this.flashMats) m.emissive.copy(this.flash > 0 ? glowWhite : glowIce);
      this.updateBar(camera);
      return;
    }
    const walk = speed > 0 ? this.time * (speed > 2 ? 7 : 4) : 0;
    // wobble, much more when dizzy
    this.body.rotation.z = this.dizzy > 0 ? Math.sin(this.time * 6) * 0.25 : Math.sin(this.time * 2.3) * 0.12;
    this.body.position.y = Math.abs(Math.sin(walk)) * 0.08;
    this.legs[0].rotation.x = Math.sin(walk) * 0.5;
    this.legs[1].rotation.x = -Math.sin(walk) * 0.5;
    this.arms[0].rotation.x = Math.PI / 2 + Math.sin(this.time * 3) * 0.15;
    this.arms[1].rotation.x = Math.PI / 2 - Math.sin(this.time * 3) * 0.15;
    for (const [i, eye] of this.eyes.entries()) {
      const p = eye.userData.pupil;
      p.position.x = Math.sin(this.time * (3 + i * 1.7)) * 0.05;
      p.position.y = Math.cos(this.time * (2.2 + i)) * 0.04;
    }

    // squash and flash white when bonked
    this.squash = Math.max(0, this.squash - dt * 4);
    const s = this.spawnPop * (1 + Math.sin(this.squash * Math.PI * 3) * 0.15 * this.squash);
    this.body.scale.set(s, this.spawnPop * (1 - this.squash * 0.2), s);
    this.flash = Math.max(0, this.flash - dt);
    const glow = this.flash > 0 ? glowWhite : this.slowTime > 0 ? glowSlime : glowNone;
    for (const m of this.flashMats) m.emissive.copy(glow);
    this.updateBar(camera);
  }

  // The health bar always faces the camera.
  updateBar(camera) {
    if (this.bar.visible) this.bar.quaternion.copy(camera.quaternion).premultiply(
      new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -this.yaw),
    );
  }
}
