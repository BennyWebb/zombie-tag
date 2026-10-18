import * as THREE from 'three';

// The weapon models you hold in your hand, and the Water Blaster's flying squirts.

const mat = (color, extra = {}) => new THREE.MeshLambertMaterial({ color, ...extra });

function makeSpikyStick() {
  const stick = new THREE.Group();
  const wood = mat(0x8b5a2b);
  const spikeMat = mat(0xd9c27a);
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

// A bendy pool noodle with a chunky handle.
function makeNoodleBat() {
  const bat = new THREE.Group();
  const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.3, 10), mat(0x4b1e8a));
  handle.position.y = 0.1;
  bat.add(handle);
  const curve = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(0, 0.22, 0),
    new THREE.Vector3(0.02, 0.6, 0),
    new THREE.Vector3(0.1, 0.95, 0),
  );
  const noodle = new THREE.Mesh(new THREE.TubeGeometry(curve, 16, 0.065, 12), mat(0xff6fae));
  bat.add(noodle);
  // the hole down the middle of the noodle, and yellow foam rings
  const hole = new THREE.Mesh(new THREE.CircleGeometry(0.035, 12), new THREE.MeshBasicMaterial({ color: 0x8a1f52 }));
  hole.position.set(0.1, 0.951, 0);
  hole.rotation.set(-Math.PI / 2, 0, -0.25);
  bat.add(hole);
  for (const t of [0.3, 0.6, 0.9]) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.068, 0.016, 6, 16), mat(0xffe066));
    const p = curve.getPoint(t);
    ring.position.copy(p);
    ring.rotation.x = Math.PI / 2;
    bat.add(ring);
  }
  return bat;
}

// A chunky toy water pistol, pointing away from you.
function makeWaterBlaster() {
  const gun = new THREE.Group();
  const orange = mat(0xff8a3d);
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.13, 0.42), orange);
  body.position.set(0, 0.06, -0.12);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.2, 0.1), mat(0x4fc3f7));
  grip.position.set(0, -0.05, 0.02);
  grip.rotation.x = 0.3;
  const tank = new THREE.Mesh(
    new THREE.SphereGeometry(0.11, 14, 10),
    mat(0x4fc3f7, { transparent: true, opacity: 0.8 }),
  );
  tank.position.set(0, 0.18, -0.08);
  const nozzle = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.035, 0.14, 10), mat(0xffe066));
  nozzle.rotation.x = Math.PI / 2;
  nozzle.position.set(0, 0.07, -0.38);
  gun.add(body, grip, tank, nozzle);
  gun.scale.setScalar(0.6);
  gun.position.set(-0.06, 0.02, -0.08);
  gun.rotation.y = 0.25; // point towards the middle of the screen
  return gun;
}

// Shooting weapons sit in the hand pointing at the middle of the screen, like the Water Blaster.
function gunPose(gun, scale = 0.6) {
  gun.scale.setScalar(scale);
  gun.position.set(-0.06, 0.02, -0.08);
  gun.rotation.y = 0.25;
  return gun;
}

// A squeaky yellow rubber chicken on a handle.
function makeChickenHammer() {
  const g = new THREE.Group();
  const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.04, 0.6, 8), mat(0x8e5bd6));
  handle.position.y = 0.3;
  const yellow = mat(0xffe066);
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.11, 0.3, 6, 12), yellow);
  body.rotation.z = Math.PI / 2;
  body.position.set(-0.05, 0.68, 0);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.1, 12, 10), yellow);
  head.position.set(-0.3, 0.76, 0);
  const comb = new THREE.Mesh(new THREE.ConeGeometry(0.04, 0.1, 6), mat(0xff3b3b));
  comb.position.set(-0.3, 0.88, 0);
  const beak = new THREE.Mesh(new THREE.ConeGeometry(0.035, 0.1, 6), mat(0xff8a3d));
  beak.rotation.z = Math.PI / 2;
  beak.position.set(-0.42, 0.75, 0);
  const eyeMat = new THREE.MeshBasicMaterial({ color: 0x111111 });
  for (const z of [-0.07, 0.07]) {
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.018, 6, 6), eyeMat);
    eye.position.set(-0.36, 0.8, z);
    g.add(eye);
  }
  g.add(handle, body, head, comb, beak);
  g.scale.setScalar(0.6);
  return g;
}

// A green goo gun with a bubbling tank.
function makeSlimeSlinger() {
  const gun = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.14, 0.42), mat(0x6a3fb5));
  body.position.set(0, 0.06, -0.12);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.2, 0.1), mat(0x333333));
  grip.position.set(0, -0.05, 0.02);
  grip.rotation.x = 0.3;
  const tank = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.22, 12), mat(0x7dff4f, { emissive: 0x1d5a00 }));
  tank.rotation.x = Math.PI / 2;
  tank.position.set(0, 0.19, -0.1);
  const nozzle = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.035, 0.12, 10), mat(0x7dff4f));
  nozzle.rotation.x = Math.PI / 2;
  nozzle.position.set(0, 0.06, -0.38);
  gun.add(body, grip, tank, nozzle);
  return gunPose(gun);
}

// A bubble wand gun: a pink body with a ring on the front.
function makeBubbleBlaster() {
  const gun = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.08, 0.3, 6, 12), mat(0xff8ad8));
  body.rotation.x = Math.PI / 2;
  body.position.set(0, 0.06, -0.12);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.2, 0.1), mat(0xb28dff));
  grip.position.set(0, -0.05, 0.02);
  grip.rotation.x = 0.3;
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.02, 8, 20), mat(0x4fc3f7));
  ring.position.set(0, 0.06, -0.4);
  const film = new THREE.Mesh(
    new THREE.CircleGeometry(0.1, 20),
    new THREE.MeshBasicMaterial({ color: 0xe0f7ff, transparent: true, opacity: 0.4, side: THREE.DoubleSide }),
  );
  film.position.copy(ring.position);
  gun.add(body, grip, ring, film);
  return gunPose(gun);
}

// A chunky snow cannon with a snowball ready to go.
function makeSnowballCannon() {
  const gun = new THREE.Group();
  const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.5, 14), mat(0x4fa8ff));
  tube.rotation.x = Math.PI / 2;
  tube.position.set(0, 0.07, -0.15);
  const stripe = new THREE.Mesh(new THREE.CylinderGeometry(0.125, 0.125, 0.06, 14), mat(0xffffff));
  stripe.rotation.x = Math.PI / 2;
  stripe.position.set(0, 0.07, -0.05);
  const ball = new THREE.Mesh(new THREE.SphereGeometry(0.08, 12, 10), mat(0xffffff, { emissive: 0x333333 }));
  ball.position.set(0, 0.07, -0.42);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.2, 0.1), mat(0x333333));
  grip.position.set(0, -0.06, 0.02);
  grip.rotation.x = 0.3;
  gun.add(tube, stripe, ball, grip);
  return gunPose(gun);
}

// A big curved banana, held ready to throw.
function makeBoomerangBanana() {
  const g = new THREE.Group();
  const curve = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(-0.18, 0, 0), new THREE.Vector3(0, 0.12, 0), new THREE.Vector3(0.18, 0, 0),
  );
  const banana = new THREE.Mesh(new THREE.TubeGeometry(curve, 12, 0.045, 10), mat(0xffe135));
  const tipMat = mat(0x5a3a1a);
  for (const x of [-0.18, 0.18]) {
    const tip = new THREE.Mesh(new THREE.SphereGeometry(0.03, 6, 6), tipMat);
    tip.position.set(x, 0, 0);
    g.add(tip);
  }
  g.add(banana);
  g.position.set(0, 0.12, -0.05);
  g.rotation.set(0.3, 0.3, 0.5);
  return g;
}

// A wide orange launcher with a pumpkin poking out.
function makePumpkinLauncher() {
  const gun = new THREE.Group();
  const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.16, 0.55, 16), mat(0x5a3a8a));
  tube.rotation.x = Math.PI / 2;
  tube.position.set(0, 0.08, -0.15);
  const pumpkin = makePumpkin(0.12);
  pumpkin.position.set(0, 0.08, -0.45);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.2, 0.1), mat(0x333333));
  grip.position.set(0, -0.06, 0.02);
  grip.rotation.x = 0.3;
  gun.add(tube, pumpkin, grip);
  return gunPose(gun);
}

// The best weapon: a sleek glowing laser gun with a star on top.
function makeStarLaser() {
  const gun = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, 0.46), mat(0xb28dff, { emissive: 0x2a1060 }));
  body.position.set(0, 0.06, -0.14);
  const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.2, 10), mat(0xffffff, { emissive: 0x666666 }));
  barrel.rotation.x = Math.PI / 2;
  barrel.position.set(0, 0.06, -0.45);
  const tip = new THREE.Mesh(new THREE.SphereGeometry(0.045, 10, 8), new THREE.MeshBasicMaterial({ color: 0xff6fd8 }));
  tip.position.set(0, 0.06, -0.56);
  const star = new THREE.Mesh(
    new THREE.ExtrudeGeometry(starShape(0.09, 0.04), { depth: 0.03, bevelEnabled: false }),
    new THREE.MeshBasicMaterial({ color: 0xffe066 }),
  );
  star.position.set(0, 0.17, -0.1);
  const grip = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.2, 0.1), mat(0xff6fd8));
  grip.position.set(0, -0.05, 0.02);
  grip.rotation.x = 0.3;
  gun.add(body, barrel, tip, star, grip);
  return gunPose(gun);
}

function starShape(outer, inner) {
  const shape = new THREE.Shape();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = (i / 10) * Math.PI * 2 + Math.PI / 2;
    if (i === 0) shape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    else shape.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  return shape;
}

function makePumpkin(r) {
  const g = new THREE.Group();
  const ball = new THREE.Mesh(new THREE.SphereGeometry(r, 14, 10), mat(0xff8a1f));
  ball.scale.y = 0.8;
  const stem = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.12, r * 0.15, r * 0.5, 6), mat(0x3f8f3f));
  stem.position.y = r * 0.85;
  g.add(ball, stem);
  return g;
}

export const WEAPON_MODELS = {
  spikyStick: makeSpikyStick,
  noodleBat: makeNoodleBat,
  waterBlaster: makeWaterBlaster,
  chickenHammer: makeChickenHammer,
  slimeSlinger: makeSlimeSlinger,
  bubbleBlaster: makeBubbleBlaster,
  snowballCannon: makeSnowballCannon,
  boomerangBanana: makeBoomerangBanana,
  pumpkinLauncher: makePumpkinLauncher,
  starLaser: makeStarLaser,
};

// What each kind of shot looks like as it flies.
const SHOT_LOOKS = {
  water: () => new THREE.Mesh(new THREE.SphereGeometry(0.09, 8, 6), new THREE.MeshBasicMaterial({ color: 0x4fc3f7 })),
  slime: () => new THREE.Mesh(new THREE.SphereGeometry(0.16, 10, 8), new THREE.MeshBasicMaterial({ color: 0x7dff4f })),
  bubble: () => new THREE.Mesh(
    new THREE.SphereGeometry(0.3, 16, 12),
    new THREE.MeshBasicMaterial({ color: 0xe0c8ff, transparent: true, opacity: 0.55 }),
  ),
  snowball: () => new THREE.Mesh(new THREE.SphereGeometry(0.2, 12, 10), new THREE.MeshBasicMaterial({ color: 0xffffff })),
  banana: () => {
    const b = makeBoomerangBanana();
    b.position.set(0, 0, 0);
    b.rotation.set(0, 0, 0);
    b.scale.setScalar(2.2);
    return b;
  },
  pumpkin: () => makePumpkin(0.35),
};

// The colours that splash out where each kind of shot lands.
export const SPLASH_COLOURS = {
  water: [0x4fc3f7, 0xbfeaff, 0xffffff],
  slime: [0x7dff4f, 0x3fbf1f, 0xc8ff9a],
  bubble: [0xe0c8ff, 0xffffff, 0xff8ad8],
  snowball: [0xffffff, 0xd8f0ff, 0xbfe4ff],
  banana: [0xffe135, 0xfff3a0],
  pumpkin: [0xff8a1f, 0xffb35a, 0x3f8f3f, 0xffe066],
};

// Everything that flies: squirts, goo, bubbles, snowballs, pumpkins and the boomerang banana.
export class Shots {
  constructor(scene) {
    this.scene = scene;
    this.list = [];
  }

  // `target` is a point to aim at (it can be null to shoot straight ahead along `dir`).
  fire(from, dir, weapon, by, target) {
    const mesh = SHOT_LOOKS[weapon.shot]();
    mesh.position.copy(from);
    this.scene.add(mesh);
    const vel = dir.clone().multiplyScalar(weapon.shotSpeed);
    if (weapon.gravity) {
      // throw it up enough to land on the target (or at the end of its range)
      const flat = Math.hypot(dir.x, dir.z) || 1;
      const dist = target ? Math.hypot(target.x - from.x, target.z - from.z) : weapon.range;
      const t = dist / weapon.shotSpeed;
      vel.set((dir.x / flat) * weapon.shotSpeed, 0, (dir.z / flat) * weapon.shotSpeed);
      const dy = (target ? target.y : 0.3) - from.y;
      vel.y = (dy + 0.5 * weapon.gravity * t * t) / t;
    }
    if (weapon.shot === 'water') {
      mesh.scale.set(1, 1, 1.8);
      mesh.lookAt(from.clone().add(dir));
    }
    const shot = { mesh, vel, weapon, by, travelled: 0, hitSet: new Set(), returning: false };
    if (weapon.kind === 'throw') by.thrown = shot;
    this.list.push(shot);
  }

  clear() {
    for (const s of this.list) {
      this.scene.remove(s.mesh);
      if (s.by.thrown === s) s.by.thrown = null;
    }
    this.list = [];
  }

  // Returns the hits this frame: [{ zombie, weapon, by, push, at }]
  update(dt, zombies) {
    const hits = [];
    for (let i = this.list.length - 1; i >= 0; i--) {
      const s = this.list[i];
      const w = s.weapon;
      const p = s.mesh.position;
      let done = false;

      if (w.kind === 'throw') {
        // the banana spins out, then turns round and flies back to whoever threw it
        s.mesh.rotation.y += dt * 18;
        if (s.returning) {
          const back = new THREE.Vector3(s.by.pos.x - p.x, 1.2 - p.y, s.by.pos.z - p.z);
          if (back.length() < 0.8) done = true;
          s.vel.copy(back.normalize().multiplyScalar(w.shotSpeed * 1.1));
        } else if (s.travelled > w.range) {
          s.returning = true;
          s.hitSet.clear(); // it can hit the same zombies again on the way back
        }
      }
      if (w.gravity) s.vel.y -= w.gravity * dt;
      p.addScaledVector(s.vel, dt);
      s.travelled += s.vel.length() * dt;
      if (w.shot === 'bubble') s.mesh.scale.setScalar(1 + Math.sin(s.travelled * 3) * 0.08);
      if (w.shot === 'pumpkin') s.mesh.rotation.x += dt * 5;

      let hit = null;
      for (const z of zombies) {
        if (!z.alive || s.hitSet.has(z)) continue;
        if (p.y < Math.max(2.5, 2.2 * z.type.size + z.lift) && Math.hypot(p.x - z.pos.x, p.z - z.pos.z) < z.radius + 0.3) {
          hit = z;
          break;
        }
      }
      const push = s.vel.clone().setY(0).normalize();
      if (w.splashRadius && (hit || p.y < 0.2)) {
        // the pumpkin splats every zombie close by
        for (const z of zombies) {
          if (z.alive && Math.hypot(p.x - z.pos.x, p.z - z.pos.z) < w.splashRadius + z.radius) {
            const away = new THREE.Vector3(z.pos.x - p.x, 0, z.pos.z - p.z).normalize();
            hits.push({ zombie: z, weapon: w, by: s.by, push: away, at: null });
          }
        }
        hits.push({ zombie: null, weapon: w, by: s.by, at: p.clone().setY(Math.max(0.3, p.y)), splat: true });
        done = true;
      } else if (hit) {
        hits.push({ zombie: hit, weapon: w, by: s.by, push, at: p.clone() });
        if (w.kind === 'throw') s.hitSet.add(hit); // the banana keeps going
        else done = true;
      }
      if (w.kind !== 'throw' && (s.travelled > w.range + 4 || p.y < 0)) done = true;
      if (done) {
        this.scene.remove(s.mesh);
        this.list.splice(i, 1);
        if (s.by.thrown === s) s.by.thrown = null;
      }
    }
    return hits;
  }
}

// The Sparkle Star Laser Gun's beam, with stars swirling round it.
function starTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 64;
  const ctx = canvas.getContext('2d');
  ctx.translate(32, 32);
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? 28 : 12;
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
    ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  ctx.closePath();
  ctx.fillStyle = '#fff';
  ctx.fill();
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
const STAR_COLOURS = [0xffe066, 0xff6fd8, 0xb28dff, 0x9cfff0, 0xffffff];
const starMats = STAR_COLOURS.map((c) => new THREE.SpriteMaterial({
  map: starTexture(), color: c, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
}));

export class Beam {
  constructor(scene) {
    this.scene = scene;
    this.group = new THREE.Group();
    const glow = new THREE.Mesh(
      new THREE.CylinderGeometry(0.06, 0.06, 1, 12, 1, true),
      new THREE.MeshBasicMaterial({
        color: 0xff6fd8, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false,
      }),
    );
    const core = new THREE.Mesh(
      new THREE.CylinderGeometry(0.018, 0.018, 1, 8),
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
    );
    glow.rotation.x = core.rotation.x = Math.PI / 2; // the cylinders point along the beam
    this.group.add(glow, core);
    this.group.visible = false;
    scene.add(this.group);
    this.stars = [];
    this.from = new THREE.Vector3();
    this.to = new THREE.Vector3();
    this.toSpawn = 0;
  }

  // Shows the beam from `from` to `to`; call hide() when it stops.
  show(from, to) {
    this.from.copy(from);
    this.to.copy(to);
    const len = from.distanceTo(to);
    this.group.position.copy(from).lerp(to, 0.5);
    this.group.lookAt(to);
    this.group.scale.set(1, 1, len);
    this.group.visible = true;
  }

  hide() {
    this.group.visible = false;
  }

  update(dt, starsPerSecond) {
    const t = performance.now() / 1000;
    this.group.children[0].scale.set(1 + Math.sin(t * 30) * 0.25, 1 + Math.sin(t * 30) * 0.25, 1);
    if (this.group.visible) {
      // new stars appear along the beam and swirl round it
      this.toSpawn += starsPerSecond * dt;
      const axis = new THREE.Vector3().subVectors(this.to, this.from);
      const side = new THREE.Vector3(0, 1, 0).cross(axis).normalize();
      const up = new THREE.Vector3().crossVectors(axis, side).normalize();
      while (this.toSpawn >= 1) {
        this.toSpawn -= 1;
        const sprite = new THREE.Sprite(starMats[Math.floor(Math.random() * starMats.length)]);
        this.scene.add(sprite);
        this.stars.push({
          sprite, along: 0.15 + Math.random() * 0.85, angle: Math.random() * Math.PI * 2, radius: 0.08,
          life: 0.7, axis: axis.clone(), from: this.from.clone(), side: side.clone(), up: up.clone(),
          size: 0.12 + Math.random() * 0.16,
        });
      }
    }
    for (let i = this.stars.length - 1; i >= 0; i--) {
      const s = this.stars[i];
      s.life -= dt;
      s.angle += dt * 9;
      s.radius += dt * 0.6;
      const p = s.from.clone().addScaledVector(s.axis, s.along)
        .addScaledVector(s.side, Math.cos(s.angle) * s.radius)
        .addScaledVector(s.up, Math.sin(s.angle) * s.radius);
      s.sprite.position.copy(p);
      const k = Math.max(0, s.life / 0.7);
      s.sprite.scale.setScalar(s.size * (0.5 + k));
      if (s.life <= 0) {
        this.scene.remove(s.sprite);
        this.stars.splice(i, 1);
      }
    }
  }
}
