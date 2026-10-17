import * as THREE from 'three';
import { CONFIG } from './config.js';

// A tiny seeded random number generator, so the park looks the same every time.
function makeRandom(seed) {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
}

const mat = (color, extra = {}) => new THREE.MeshLambertMaterial({ color, ...extra });

function shadows(obj) {
  obj.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true;
      o.receiveShadow = true;
    }
  });
  return obj;
}

// Draws text onto a canvas so it can be painted on the shop front.
function textMaterial(text, width, height, bg, fg) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, width, height);
  ctx.font = `bold ${height * 0.7}px "Fredoka", "Comic Sans MS", sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = height * 0.1;
  ctx.strokeStyle = '#4b1e8a';
  ctx.strokeText(text, width / 2, height / 2);
  ctx.fillStyle = fg;
  ctx.fillText(text, width / 2, height / 2);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return new THREE.MeshBasicMaterial({ map: tex });
}

// A big glowing shopping bag, drawn without fog so it shines across the whole park.
function makeBagSign() {
  const bag = new THREE.Group();
  const pink = new THREE.MeshBasicMaterial({ color: 0xff4f8b, fog: false });
  const body = new THREE.Mesh(new THREE.BoxGeometry(2.4, 2.6, 1.0), pink);
  bag.add(body);
  const fold = new THREE.Mesh(
    new THREE.BoxGeometry(2.5, 0.3, 1.1),
    new THREE.MeshBasicMaterial({ color: 0xffb3d1, fog: false }),
  );
  fold.position.y = 1.2;
  bag.add(fold);
  const handleMat = new THREE.MeshBasicMaterial({ color: 0xffe066, fog: false });
  const handle = new THREE.Mesh(new THREE.TorusGeometry(0.65, 0.12, 8, 20, Math.PI), handleMat);
  handle.position.y = 1.35;
  bag.add(handle);
  // a coin on each side of the bag
  const coinMat = new THREE.MeshBasicMaterial({ color: 0xffd23f, fog: false });
  const coin = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 1.2, 24), coinMat);
  coin.rotation.x = Math.PI / 2;
  bag.add(coin);
  return bag;
}

// A big glowing dumbbell for the gym's sign.
function makeDumbbellSign() {
  const bell = new THREE.Group();
  const bar = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.22, 3.2, 12),
    new THREE.MeshBasicMaterial({ color: 0xdddddd, fog: false }),
  );
  bar.rotation.z = Math.PI / 2;
  bell.add(bar);
  const plateMat = new THREE.MeshBasicMaterial({ color: 0x4fc3f7, fog: false });
  const capMat = new THREE.MeshBasicMaterial({ color: 0xffe066, fog: false });
  for (const side of [-1, 1]) {
    for (const [x, r] of [[1.1, 1.0], [1.5, 0.8]]) {
      const plate = new THREE.Mesh(new THREE.CylinderGeometry(r, r, 0.35, 24), plateMat);
      plate.rotation.z = Math.PI / 2;
      plate.position.x = side * x;
      bell.add(plate);
    }
    const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.2, 12), capMat);
    cap.rotation.z = Math.PI / 2;
    cap.position.x = side * 1.75;
    bell.add(cap);
  }
  return bell;
}

// A safe building that zombies can't get into (the shop or the gym). The door is on the +z side.
function makeBuilding(look) {
  const g = new THREE.Group();
  const w = 8;
  const d = 6;
  const h = 4.8;
  const walls = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat(look.walls));
  walls.position.y = h / 2;
  g.add(walls);
  const roof = new THREE.Mesh(new THREE.BoxGeometry(w + 0.6, 0.4, d + 0.6), mat(look.trim));
  roof.position.y = h + 0.2;
  g.add(roof);

  const front = d / 2;
  // doorway with a glowing inside, so it's obvious where to walk in
  const frame = new THREE.Mesh(new THREE.BoxGeometry(2.0, 3.0, 0.2), mat(look.trim));
  frame.position.set(0, 1.5, front + 0.05);
  const doorway = new THREE.Mesh(
    new THREE.PlaneGeometry(1.6, 2.7),
    new THREE.MeshBasicMaterial({ color: 0xfff1a8 }),
  );
  doorway.position.set(0, 1.35, front + 0.16);
  g.add(frame, doorway);
  const mat2 = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.04, 1.4), mat(0x4fc3f7));
  mat2.position.set(0, 0.04, front + 0.8);
  g.add(mat2);

  // windows either side of the door
  const glass = new THREE.MeshBasicMaterial({ color: 0xbfeaff });
  for (const x of [-2.7, 2.7]) {
    const win = new THREE.Mesh(new THREE.PlaneGeometry(1.8, 1.4), glass);
    win.position.set(x, 1.9, front + 0.02);
    g.add(win);
  }

  // stripy awning
  for (let i = 0; i < 8; i++) {
    const stripe = new THREE.Mesh(
      new THREE.BoxGeometry(w / 8, 0.12, 1.3),
      mat(i % 2 ? 0xffffff : look.stripe, { emissive: i % 2 ? 0x555555 : look.stripeGlow }),
    );
    stripe.position.set(-w / 2 + w / 16 + (i * w) / 8, 3.25, front + 0.6);
    stripe.rotation.x = 0.25;
    g.add(stripe);
  }

  const sign = new THREE.Mesh(new THREE.PlaneGeometry(4.4, 0.85), textMaterial(look.text, 512, 100, '#ffe066', look.textColour));
  sign.position.set(0, 4.2, front + 0.02);
  g.add(sign);

  // tall pole with the glowing sign on top, high above the trees
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 7, 8), mat(0xffffff));
  pole.position.y = h + 3.5;
  g.add(pole);
  const topper = look.makeSign();
  topper.scale.setScalar(1.6);
  topper.position.y = h + 9.2;
  g.add(topper);
  const glow = new THREE.PointLight(look.glow, 25, 16);
  glow.position.y = h + 9.2;
  g.add(glow);

  shadows(g);
  topper.traverse((o) => { o.castShadow = false; });
  return { group: g, sign: topper, halfW: w / 2, halfD: d / 2 };
}

// The exit gate: closed with bars until every zombie is popped, then it opens and sparkles.
function makeGate() {
  const g = new THREE.Group();
  const stone = mat(0xb28dff);
  for (const x of [-2.6, 2.6]) g.add(meshAt(new THREE.BoxGeometry(1, 5, 1), stone, x, 2.5, 0));
  const arch = new THREE.Mesh(new THREE.TorusGeometry(2.6, 0.45, 8, 20, Math.PI), stone);
  arch.position.y = 5;
  g.add(arch);
  const bars = new THREE.Group();
  for (let i = -3; i <= 3; i++) bars.add(meshAt(new THREE.CylinderGeometry(0.08, 0.08, 5, 6), mat(0x555566), i * 0.65, 2.5, 0));
  g.add(bars);
  // the glowing "way out" that shows once it's open, with a beam of light up into the sky
  const glow = new THREE.Mesh(
    new THREE.PlaneGeometry(4.2, 4.6),
    new THREE.MeshBasicMaterial({ color: 0xfff1a8, transparent: true, opacity: 0.85, side: THREE.DoubleSide }),
  );
  glow.position.y = 2.4;
  const beam = new THREE.Mesh(
    new THREE.CylinderGeometry(2.2, 2.2, 80, 20, 1, true),
    new THREE.MeshBasicMaterial({
      color: 0xffe066, transparent: true, opacity: 0.25, side: THREE.DoubleSide, depthWrite: false, fog: false,
    }),
  );
  beam.position.y = 40;
  const open = new THREE.Group();
  open.add(glow, beam);
  open.visible = false;
  g.add(open);
  return { group: g, bars, open, beam };
}

function meshAt(geo, material, x, y, z) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z);
  return m;
}

// Where the shop and gym can go (their doors face +z). Two are picked at random each level,
// never right next to the start or next to each other.
const BUILDING_SPOTS = [[-25, 11], [25, 12], [-25, -14], [25, -14], [-12, -27], [12, -27]];

export function buildWorld(scene, level, theme) {
  const rand = makeRandom(1234 + level.number * 77);
  const size = CONFIG.arena.size;
  const half = size / 2;
  const colliders = []; // circles { x, z, r } and boxes { x, z, hw, hd } that block walking
  const group = new THREE.Group(); // everything in this level, so it can be cleared away
  scene.add(group);
  const animations = [];

  scene.background = new THREE.Color(theme.sky);
  scene.fog = new THREE.Fog(theme.sky, theme.fog[0], theme.fog[1]);

  const L = theme.light;
  group.add(new THREE.HemisphereLight(L.sky, L.ground, L.amount));
  const sun = new THREE.DirectionalLight(L.sun, L.sunAmount);
  sun.position.set(30, 50, 20);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const sc = sun.shadow.camera;
  sc.left = -half - 5; sc.right = half + 5; sc.top = half + 5; sc.bottom = -half - 5;
  sc.near = 1; sc.far = 150;
  group.add(sun);

  // the sun, or a big friendly moon at night
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(6, 20, 16),
    new THREE.MeshBasicMaterial({ color: theme.night ? 0xf4f0d0 : 0xfff176, fog: false }),
  );
  sky.position.set(60, 70, -90);
  group.add(sky);

  // ground inside and outside the wall, so the world doesn't end in a cliff
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), mat(theme.ground));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  group.add(ground);

  // paths: a cross through the middle and a ring
  const pathMat = mat(theme.path);
  for (const [w, d] of [[4, size], [size, 4]]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(w, d), pathMat);
    p.rotation.x = -Math.PI / 2;
    p.position.y = 0.02;
    p.receiveShadow = true;
    group.add(p);
  }
  const ring = new THREE.Mesh(new THREE.RingGeometry(18, 21.5, 64), pathMat);
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = 0.03;
  ring.receiveShadow = true;
  group.add(ring);

  // the wall all the way round
  const wallMat = mat(theme.wall.colour);
  const wh = theme.wall.height;
  for (const [x, z, w, d] of [
    [0, -half, size + 2, 2], [0, half, size + 2, 2],
    [-half, 0, 2, size + 2], [half, 0, 2, size + 2],
  ]) {
    const h = new THREE.Mesh(new THREE.BoxGeometry(w, wh, d), wallMat);
    h.position.set(x, wh / 2, z);
    group.add(shadows(h));
    if (theme.wall.battlements) {
      const along = w > d ? 'x' : 'z';
      for (let i = -half; i <= half; i += 3) {
        const b = new THREE.Mesh(new THREE.BoxGeometry(1.5, 1.2, 1.5), wallMat);
        b.position.set(along === 'x' ? i : x, wh + 0.6, along === 'z' ? i : z);
        group.add(b);
      }
    }
  }

  // the shop and the gym at two random spots
  const placeBuilding = (look, [x, z]) => {
    const b = makeBuilding(look);
    b.group.position.set(x, 0, z);
    group.add(b.group);
    colliders.push({ x, z, hw: b.halfW, hd: b.halfD });
    const door = { x, z: z + b.halfD };
    return {
      door,
      // where you stand when you walk back out, facing away from the building
      outside: { x: door.x, z: door.z + 2.4, yaw: Math.PI },
      sign: b.sign,
    };
  };
  const spots = [...BUILDING_SPOTS].sort(() => Math.random() - 0.5);
  const shopSpot = spots[0];
  const gymSpot = spots.find((s) => Math.hypot(s[0] - shopSpot[0], s[1] - shopSpot[1]) > 30);
  const shop = placeBuilding({
    walls: 0xffa8cc, trim: 0x8e5bd6, stripe: 0xff4f8b, stripeGlow: 0x661a38,
    text: 'SHOP', textColour: '#ff4f8b', glow: 0xff4f8b, makeSign: makeBagSign,
  }, shopSpot);
  const gym = placeBuilding({
    walls: 0xa8e6ff, trim: 0x1e6fd6, stripe: 0x4fc3f7, stripeGlow: 0x14506e,
    text: 'GYM', textColour: '#1e6fd6', glow: 0x4fc3f7, makeSign: makeDumbbellSign,
  }, gymSpot);

  // the exit gate, at the far end of the path from the start
  const gate = makeGate();
  const gatePos = { x: 0, z: -half + 2.5 };
  gate.group.position.set(gatePos.x, 0, gatePos.z);
  group.add(shadows(gate.group));
  gate.beam.castShadow = false;
  for (const x of [-2.6, 2.6]) colliders.push({ x: gatePos.x + x, z: gatePos.z, r: 0.8 });

  const playerStart = { x: 0, z: half - 6, yaw: 0 }; // yaw 0 faces the middle
  const doors = [shop.door, gym.door];

  // keep things off the paths, the middle, the start, the doors and the gate
  const onPath = (x, z) => {
    const r = Math.hypot(x, z);
    return Math.abs(x) < 3.5 || Math.abs(z) < 3.5 || (r > 16.5 && r < 23) || r < 10;
  };
  const freeSpot = (minGap) => {
    for (let tries = 0; tries < 200; tries++) {
      const x = (rand() - 0.5) * (size - 8);
      const z = (rand() - 0.5) * (size - 8);
      if (onPath(x, z)) continue;
      if (Math.hypot(x - playerStart.x, z - playerStart.z) < 8) continue;
      if (Math.hypot(x - gatePos.x, z - gatePos.z) < 7) continue;
      if (doors.some((d) => Math.hypot(x - d.x, z - (d.z + 3)) < 5)) continue;
      if (colliders.some((c) => distanceTo(c, x, z) < minGap)) continue;
      return { x, z };
    }
    return null;
  };

  const ctx = {
    rand,
    half,
    group,
    add(obj, x, z, { r, small, box } = {}) {
      obj.position.x = x;
      obj.position.z = z;
      group.add(shadows(obj));
      if (r) colliders.push({ x, z, r, small });
      if (box) colliders.push({ x, z, hw: box[0], hd: box[1] });
    },
    scatter(make, count, { gap = 1, r, small } = {}) {
      for (let i = 0; i < count; i++) {
        const spot = freeSpot(gap + (r || 0));
        if (!spot) break;
        const obj = make(rand, i);
        obj.rotation.y += rand() * Math.PI * 2;
        ctx.add(obj, spot.x, spot.z, { r, small });
      }
    },
    ring(make, count, radius, { r, small } = {}) {
      for (let i = 0; i < count; i++) {
        const a = (i / count) * Math.PI * 2 + Math.PI / 6;
        const obj = make(rand, i);
        obj.position.set(Math.cos(a) * radius, 0, Math.sin(a) * radius);
        obj.lookAt(0, 0, 0);
        ctx.add(obj, obj.position.x, obj.position.z, { r, small });
      }
    },
    animate(fn) {
      animations.push(fn);
    },
  };
  theme.decorate(ctx);

  let time = 0;
  return {
    group,
    colliders,
    bounds: half - 1.5,
    playerStart,
    shop,
    gym,
    gate: { ...gatePos, isOpen: false },
    openGate() {
      this.gate.isOpen = true;
      gate.bars.visible = false;
      gate.open.visible = true;
    },
    // spinning signs, rides, snow and so on
    update(dt) {
      time += dt;
      shop.sign.rotation.y += dt * 1.2;
      gym.sign.rotation.y += dt * 1.2;
      if (gate.open.visible) {
        gate.beam.rotation.y += dt;
        gate.open.children[0].material.opacity = 0.65 + Math.sin(time * 4) * 0.2;
      }
      for (const fn of animations) fn(dt, time);
    },
    // spot is clear of the middle, props, buildings and the wall
    isClear: (x, z, r) =>
      Math.abs(x) < half - 2 && Math.abs(z) < half - 2 &&
      !colliders.some((c) => distanceTo(c, x, z) < r),
  };
}

// How far a point is from the edge of a collider (negative when inside it).
function distanceTo(c, x, z) {
  if (c.r !== undefined) return Math.hypot(c.x - x, c.z - z) - c.r;
  const dx = Math.max(Math.abs(x - c.x) - c.hw, 0);
  const dz = Math.max(Math.abs(z - c.z) - c.hd, 0);
  return Math.hypot(dx, dz);
}

// Pushes a circle out of anything solid and keeps it inside the hedge.
// `hopper` (Bouncy Bob) jumps over small things like fences, bushes and benches.
export function resolveCollisions(pos, radius, world, hopper = false) {
  for (const c of world.colliders) {
    if (hopper && c.small) continue;
    if (c.r === undefined) {
      pushOutOfBox(pos, radius, c);
      continue;
    }
    const dx = pos.x - c.x;
    const dz = pos.z - c.z;
    const dist = Math.hypot(dx, dz);
    const min = c.r + radius;
    if (dist < min && dist > 0.0001) {
      pos.x = c.x + (dx / dist) * min;
      pos.z = c.z + (dz / dist) * min;
    }
  }
  const b = world.bounds - radius;
  pos.x = Math.max(-b, Math.min(b, pos.x));
  pos.z = Math.max(-b, Math.min(b, pos.z));
}

function pushOutOfBox(pos, radius, c) {
  const nx = Math.max(c.x - c.hw, Math.min(c.x + c.hw, pos.x));
  const nz = Math.max(c.z - c.hd, Math.min(c.z + c.hd, pos.z));
  const dx = pos.x - nx;
  const dz = pos.z - nz;
  const dist = Math.hypot(dx, dz);
  if (dist > 0.0001) {
    if (dist < radius) {
      pos.x = nx + (dx / dist) * radius;
      pos.z = nz + (dz / dist) * radius;
    }
    return;
  }
  // the middle is inside the box: push out through the nearest side
  const px = c.hw - Math.abs(pos.x - c.x);
  const pz = c.hd - Math.abs(pos.z - c.z);
  if (px < pz) pos.x = c.x + Math.sign(pos.x - c.x || 1) * (c.hw + radius);
  else pos.z = c.z + Math.sign(pos.z - c.z || 1) * (c.hd + radius);
}
