import * as THREE from 'three';

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

function makeTree(rand) {
  const tree = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.4, 2.4, 10), mat(0x8b5a2b));
  trunk.position.y = 1.2;
  tree.add(trunk);
  const greens = [0x4caf50, 0x66bb6a, 0x7cb342, 0x43a047];
  const leaves = mat(greens[Math.floor(rand() * greens.length)]);
  for (let i = 0; i < 3; i++) {
    const r = 1.3 + rand() * 0.6;
    const blob = new THREE.Mesh(new THREE.SphereGeometry(r, 14, 12), leaves);
    blob.position.set((rand() - 0.5) * 1.2, 3.0 + i * 0.7, (rand() - 0.5) * 1.2);
    tree.add(blob);
  }
  return shadows(tree);
}

function makeBush(rand) {
  const bush = new THREE.Group();
  const m = mat(0x5cb85c);
  for (let i = 0; i < 3; i++) {
    const s = new THREE.Mesh(new THREE.SphereGeometry(0.6 + rand() * 0.3, 12, 10), m);
    s.position.set((i - 1) * 0.6, 0.5, (rand() - 0.5) * 0.4);
    bush.add(s);
  }
  return shadows(bush);
}

function makeBench() {
  const bench = new THREE.Group();
  const wood = mat(0xd2691e);
  const metal = mat(0x555555);
  const seat = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.15, 0.7), wood);
  seat.position.y = 0.55;
  const back = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.6, 0.12), wood);
  back.position.set(0, 1.0, -0.3);
  bench.add(seat, back);
  for (const x of [-1, 1]) {
    const leg = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.55, 0.6), metal);
    leg.position.set(x, 0.27, 0);
    bench.add(leg);
  }
  return shadows(bench);
}

function makeFlowers(rand) {
  const bed = new THREE.Group();
  const colours = [0xff6fae, 0xffe066, 0xff8a3d, 0xb28dff, 0xffffff];
  const stem = mat(0x3f8f3f);
  for (let i = 0; i < 12; i++) {
    const x = (rand() - 0.5) * 2.5;
    const z = (rand() - 0.5) * 2.5;
    const s = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.4, 5), stem);
    s.position.set(x, 0.2, z);
    const f = new THREE.Mesh(
      new THREE.SphereGeometry(0.14, 8, 6),
      mat(colours[Math.floor(rand() * colours.length)]),
    );
    f.position.set(x, 0.45, z);
    bed.add(s, f);
  }
  return bed;
}

function makeCloud(rand) {
  const cloud = new THREE.Group();
  const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
  for (let i = 0; i < 5; i++) {
    const s = new THREE.Mesh(new THREE.SphereGeometry(3 + rand() * 2, 12, 10), white);
    s.position.set(i * 3 - 6, rand() * 1.5, (rand() - 0.5) * 3);
    cloud.add(s);
  }
  return cloud;
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

export function buildWorld(scene, level) {
  const rand = makeRandom(1234);
  const half = level.size / 2;
  const colliders = []; // circles { x, z, r } and boxes { x, z, hw, hd } that block walking

  scene.background = new THREE.Color(0x87ceeb);
  scene.fog = new THREE.Fog(0x87ceeb, 40, 110);

  scene.add(new THREE.HemisphereLight(0xffffff, 0x6aa84f, 1.6));
  const sun = new THREE.DirectionalLight(0xfff4d6, 2.2);
  sun.position.set(30, 50, 20);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const sc = sun.shadow.camera;
  sc.left = -half - 5; sc.right = half + 5; sc.top = half + 5; sc.bottom = -half - 5;
  sc.near = 1; sc.far = 150;
  scene.add(sun);

  const sunBall = new THREE.Mesh(
    new THREE.SphereGeometry(6, 20, 16),
    new THREE.MeshBasicMaterial({ color: 0xfff176, fog: false }),
  );
  sunBall.position.set(60, 70, -90);
  scene.add(sunBall);

  // grass, with grass outside the hedge too so the world doesn't end in a cliff
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), mat(0x7ccf5a));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);

  // paths: a cross through the middle and a ring
  const pathMat = mat(0xe8d5a3);
  for (const [w, d] of [[4, level.size], [level.size, 4]]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(w, d), pathMat);
    p.rotation.x = -Math.PI / 2;
    p.position.y = 0.02;
    p.receiveShadow = true;
    scene.add(p);
  }
  const ring = new THREE.Mesh(new THREE.RingGeometry(18, 21.5, 64), pathMat);
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = 0.03;
  ring.receiveShadow = true;
  scene.add(ring);

  // a round pond in the middle with a fountain
  const pond = new THREE.Mesh(
    new THREE.CylinderGeometry(7, 7, 0.3, 40),
    mat(0x4fc3f7, { transparent: true, opacity: 0.9 }),
  );
  pond.position.y = 0.1;
  const rim = new THREE.Mesh(new THREE.TorusGeometry(7, 0.4, 8, 40), mat(0xbdbdbd));
  rim.rotation.x = Math.PI / 2;
  rim.position.y = 0.3;
  const fountain = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 1.2, 2, 16), mat(0xe0e0e0));
  fountain.position.y = 1;
  scene.add(shadows(pond), shadows(rim), shadows(fountain));
  colliders.push({ x: 0, z: 0, r: 7.4 });

  // hedge wall all the way round
  const hedgeMat = mat(0x2e7d32);
  for (const [x, z, w, d] of [
    [0, -half, level.size + 2, 2], [0, half, level.size + 2, 2],
    [-half, 0, 2, level.size + 2], [half, 0, 2, level.size + 2],
  ]) {
    const h = new THREE.Mesh(new THREE.BoxGeometry(w, 2.2, d), hedgeMat);
    h.position.set(x, 1.1, z);
    scene.add(shadows(h));
  }

  // the shop and the gym, both in sight of the start, far from each other
  const placeBuilding = (look, x, z) => {
    const b = makeBuilding(look);
    b.group.position.set(x, 0, z);
    scene.add(b.group);
    colliders.push({ x, z, hw: b.halfW, hd: b.halfD });
    const door = { x, z: z + b.halfD };
    return {
      door,
      // where you stand when you walk back out, facing away from the building
      outside: { x: door.x, z: door.z + 2.4, yaw: Math.PI },
      sign: b.sign,
    };
  };
  const shop = placeBuilding({
    walls: 0xffa8cc, trim: 0x8e5bd6, stripe: 0xff4f8b, stripeGlow: 0x661a38,
    text: 'SHOP', textColour: '#ff4f8b', glow: 0xff4f8b, makeSign: makeBagSign,
  }, -25, 11);
  const gym = placeBuilding({
    walls: 0xa8e6ff, trim: 0x1e6fd6, stripe: 0x4fc3f7, stripeGlow: 0x14506e,
    text: 'GYM', textColour: '#1e6fd6', glow: 0x4fc3f7, makeSign: makeDumbbellSign,
  }, 25, -12);
  const doors = [shop.door, gym.door];

  // keep things off the paths, the pond and the start
  const onPath = (x, z) => {
    const r = Math.hypot(x, z);
    return Math.abs(x) < 3.5 || Math.abs(z) < 3.5 || (r > 16.5 && r < 23) || r < 10;
  };
  const freeSpot = (minGap) => {
    for (let tries = 0; tries < 200; tries++) {
      const x = (rand() - 0.5) * (level.size - 8);
      const z = (rand() - 0.5) * (level.size - 8);
      if (onPath(x, z)) continue;
      if (Math.hypot(x - 0, z - (half - 6)) < 8) continue; // the start
      if (doors.some((d) => Math.hypot(x - d.x, z - (d.z + 3)) < 5)) continue; // in front of a door
      if (colliders.some((c) => distanceTo(c, x, z) < minGap)) continue;
      return { x, z };
    }
    return null;
  };

  for (let i = 0; i < 28; i++) {
    const spot = freeSpot(3);
    if (!spot) break;
    const t = makeTree(rand);
    t.position.set(spot.x, 0, spot.z);
    t.rotation.y = rand() * Math.PI * 2;
    scene.add(t);
    colliders.push({ x: spot.x, z: spot.z, r: 0.6 });
  }
  for (let i = 0; i < 18; i++) {
    const spot = freeSpot(1.5);
    if (!spot) break;
    const b = makeBush(rand);
    b.position.set(spot.x, 0, spot.z);
    b.rotation.y = rand() * Math.PI * 2;
    scene.add(b);
    colliders.push({ x: spot.x, z: spot.z, r: 1.1 });
  }
  for (let i = 0; i < 10; i++) {
    const spot = freeSpot(1);
    if (!spot) break;
    const f = makeFlowers(rand);
    f.position.set(spot.x, 0, spot.z);
    scene.add(f);
  }
  // benches facing the pond, just inside the ring path
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 + Math.PI / 6;
    const b = makeBench();
    b.position.set(Math.cos(a) * 15.5, 0, Math.sin(a) * 15.5);
    b.lookAt(0, 0, 0);
    scene.add(b);
    colliders.push({ x: b.position.x, z: b.position.z, r: 1.2 });
  }
  for (let i = 0; i < 8; i++) {
    const c = makeCloud(rand);
    c.position.set((rand() - 0.5) * 160, 35 + rand() * 15, (rand() - 0.5) * 160);
    scene.add(c);
  }

  const playerStart = { x: 0, z: half - 6, yaw: 0 }; // yaw 0 faces the middle of the park

  return {
    colliders,
    bounds: half - 1.5,
    playerStart,
    shop,
    gym,
    // spot is clear of the pond, trees, the shop and the hedge
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
export function resolveCollisions(pos, radius, world) {
  for (const c of world.colliders) {
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
