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

// A barrel full of free Spiky Sticks, with a tall glowing star so you can always find it.
function makeStickBarrel() {
  const g = new THREE.Group();
  const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.6, 1.1, 16), mat(0xa0522d));
  barrel.position.y = 0.55;
  const band = mat(0x6b3a1a);
  for (const y of [0.25, 0.85]) {
    const b = new THREE.Mesh(new THREE.TorusGeometry(0.68, 0.05, 6, 20), band);
    b.rotation.x = Math.PI / 2;
    b.position.y = y;
    g.add(b);
  }
  g.add(barrel);
  // sticks poking out of the top
  const stickMat = mat(0x8b5a2b);
  for (let i = 0; i < 5; i++) {
    const s = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 1.2, 6), stickMat);
    const a = (i / 5) * Math.PI * 2;
    s.position.set(Math.cos(a) * 0.3, 1.3, Math.sin(a) * 0.3);
    s.rotation.set(Math.sin(a) * 0.3, 0, Math.cos(a) * 0.3);
    g.add(s);
  }
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 6, 8), mat(0xffffff));
  pole.position.set(0.9, 3, 0);
  g.add(pole);

  const starShape = new THREE.Shape();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? 0.9 : 0.4;
    const a = (i / 10) * Math.PI * 2 + Math.PI / 2;
    if (i === 0) starShape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    else starShape.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  const star = new THREE.Mesh(
    new THREE.ExtrudeGeometry(starShape, { depth: 0.2, bevelEnabled: false }),
    new THREE.MeshBasicMaterial({ color: 0xffe066 }),
  );
  star.position.set(0.9, 6.6, 0);
  g.add(star);
  const glow = new THREE.PointLight(0xffe066, 8, 10);
  glow.position.copy(star.position);
  g.add(glow);

  shadows(g);
  return { group: g, star };
}

export function buildWorld(scene, level) {
  const rand = makeRandom(1234);
  const half = level.size / 2;
  const colliders = []; // circles that block walking: { x, z, r }

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
      if (colliders.some((c) => Math.hypot(c.x - x, c.z - z) < c.r + minGap)) continue;
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
  const barrel = makeStickBarrel();
  barrel.group.position.set(3.5, 0, half - 5);
  scene.add(barrel.group);
  const stickBarrel = { x: 3.5, z: half - 5, r: 0.8, star: barrel.star };
  colliders.push({ x: stickBarrel.x, z: stickBarrel.z, r: stickBarrel.r });

  return {
    colliders,
    bounds: half - 1.5,
    playerStart,
    stickBarrel,
    // spot is clear of the pond, trees and the hedge
    isClear: (x, z, r) =>
      Math.abs(x) < half - 2 && Math.abs(z) < half - 2 &&
      !colliders.some((c) => Math.hypot(c.x - x, c.z - z) < c.r + r),
  };
}

// Pushes a circle out of anything solid and keeps it inside the hedge.
export function resolveCollisions(pos, radius, world) {
  for (const c of world.colliders) {
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
