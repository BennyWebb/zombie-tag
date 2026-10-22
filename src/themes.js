import * as THREE from 'three';

// What each level looks like: colours, light, walls and props.
// Every level shares the same layout (a cross of paths, a ring path, something big in the middle)
// so the start, the shop and gym spots and the exit gate are always in the same kind of places.
//
// decorate(ctx) places the props. ctx gives:
//   ctx.rand()                         a seeded random number, so a level looks the same every time
//   ctx.add(obj, x, z, { r, small })   add something; r makes it solid; small things can be hopped over
//   ctx.scatter(make, count, opts)     put `count` things in free spots (opts.gap keeps them apart)
//   ctx.ring(make, count, radius, opts) put things round the middle, facing in
//   ctx.animate(fn)                    fn(dt, time) runs every frame (spinning rides, falling snow...)

const mat = (color, extra = {}) => new THREE.MeshLambertMaterial({ color, ...extra });
const glowMat = (color) => new THREE.MeshBasicMaterial({ color });
const pick = (rand, list) => list[Math.floor(rand() * list.length)];

function mesh(geo, material, x = 0, y = 0, z = 0) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z);
  return m;
}

function group(...children) {
  const g = new THREE.Group();
  if (children.length) g.add(...children);
  return g;
}

// ---------- shared props ----------

function makeTree(rand, greens = [0x4caf50, 0x66bb6a, 0x7cb342, 0x43a047]) {
  const tree = group(mesh(new THREE.CylinderGeometry(0.3, 0.4, 2.4, 10), mat(0x8b5a2b), 0, 1.2));
  const leaves = mat(pick(rand, greens));
  for (let i = 0; i < 3; i++) {
    const r = 1.3 + rand() * 0.6;
    tree.add(mesh(new THREE.SphereGeometry(r, 14, 12), leaves, (rand() - 0.5) * 1.2, 3.0 + i * 0.7, (rand() - 0.5) * 1.2));
  }
  return tree;
}

function makeBush(rand, colour = 0x5cb85c) {
  const bush = new THREE.Group();
  const m = mat(colour);
  for (let i = 0; i < 3; i++) {
    bush.add(mesh(new THREE.SphereGeometry(0.6 + rand() * 0.3, 12, 10), m, (i - 1) * 0.6, 0.5, (rand() - 0.5) * 0.4));
  }
  return bush;
}

function makeBench(colour = 0xd2691e) {
  const wood = mat(colour);
  const metal = mat(0x555555);
  const back = mesh(new THREE.BoxGeometry(2.4, 0.6, 0.12), wood, 0, 1.0, -0.3);
  const bench = group(mesh(new THREE.BoxGeometry(2.4, 0.15, 0.7), wood, 0, 0.55), back);
  for (const x of [-1, 1]) bench.add(mesh(new THREE.BoxGeometry(0.12, 0.55, 0.6), metal, x, 0.27));
  return bench;
}

function makeFlowers(rand) {
  const bed = new THREE.Group();
  const colours = [0xff6fae, 0xffe066, 0xff8a3d, 0xb28dff, 0xffffff];
  const stem = mat(0x3f8f3f);
  for (let i = 0; i < 12; i++) {
    const x = (rand() - 0.5) * 2.5;
    const z = (rand() - 0.5) * 2.5;
    bed.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.4, 5), stem, x, 0.2, z));
    bed.add(mesh(new THREE.SphereGeometry(0.14, 8, 6), mat(pick(rand, colours)), x, 0.45, z));
  }
  return bed;
}

function makeFence(colour = 0xffffff) {
  const fence = new THREE.Group();
  const m = mat(colour);
  for (let i = -2; i <= 2; i++) fence.add(mesh(new THREE.BoxGeometry(0.12, 0.9, 0.08), m, i * 0.5, 0.45));
  for (const y of [0.3, 0.7]) fence.add(mesh(new THREE.BoxGeometry(2.3, 0.1, 0.06), m, 0, y));
  return fence;
}

function makeLamp(colour = 0xfff3b0, light = false) {
  const lamp = group(
    mesh(new THREE.CylinderGeometry(0.08, 0.1, 3.6, 8), mat(0x444444), 0, 1.8),
    mesh(new THREE.SphereGeometry(0.28, 12, 10), glowMat(colour), 0, 3.7),
  );
  if (light) {
    const l = new THREE.PointLight(colour, 6, 9);
    l.position.y = 3.6;
    lamp.add(l);
  }
  return lamp;
}

// A simple house: walls, a pointy roof, a door and windows (door faces +z).
function makeHouse(rand, walls, roof, snow = false) {
  const w = 5 + rand() * 1.5;
  const roofMesh = mesh(new THREE.ConeGeometry(w * 0.8, 2.2, 4), mat(roof), 0, 4.1);
  roofMesh.rotation.y = Math.PI / 4;
  const house = group(mesh(new THREE.BoxGeometry(w, 3, w), mat(walls), 0, 1.5), roofMesh);
  if (snow) {
    const cap = mesh(new THREE.ConeGeometry(w * 0.82, 0.8, 4), mat(0xffffff), 0, 4.95);
    cap.rotation.y = Math.PI / 4;
    house.add(cap);
  }
  house.add(mesh(new THREE.BoxGeometry(1, 1.8, 0.1), mat(0x7a4a2a), 0, 0.9, w / 2 + 0.01));
  const glass = glowMat(0xfff1a8);
  for (const x of [-w / 3, w / 3]) house.add(mesh(new THREE.PlaneGeometry(0.9, 0.8), glass, x, 1.9, w / 2 + 0.02));
  return house;
}

function makeCloud(rand) {
  const cloud = new THREE.Group();
  const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
  for (let i = 0; i < 5; i++) {
    cloud.add(mesh(new THREE.SphereGeometry(3 + rand() * 2, 12, 10), white, i * 3 - 6, rand() * 1.5, (rand() - 0.5) * 3));
  }
  return cloud;
}

function addClouds(ctx, count = 8) {
  for (let i = 0; i < count; i++) {
    const c = makeCloud(ctx.rand);
    c.position.set((ctx.rand() - 0.5) * 160, 35 + ctx.rand() * 15, (ctx.rand() - 0.5) * 160);
    ctx.group.add(c);
  }
}

// Little glowing dots drifting about: snow, fireflies or sparkles.
function addFloaters(ctx, { count, colour, size, area = 90, fall = 0, wander = 0.5, low = 0, high = 20 }) {
  const pos = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    pos[i * 3] = (ctx.rand() - 0.5) * area;
    pos[i * 3 + 1] = low + ctx.rand() * (high - low);
    pos[i * 3 + 2] = (ctx.rand() - 0.5) * area;
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const points = new THREE.Points(geo, new THREE.PointsMaterial({ color: colour, size, transparent: true, opacity: 0.9 }));
  // the settings, for the Godot export (tools/export.js)
  points.name = 'floaters';
  points.userData.floaters = { count, colour, size, area, fall, wander, low, high };
  ctx.group.add(points);
  ctx.animate((dt, t) => {
    for (let i = 0; i < count; i++) {
      pos[i * 3] += Math.sin(t * 0.7 + i) * wander * dt;
      pos[i * 3 + 1] -= fall * dt;
      pos[i * 3 + 2] += Math.cos(t * 0.6 + i * 1.3) * wander * dt;
      if (pos[i * 3 + 1] < low) pos[i * 3 + 1] = high;
    }
    geo.attributes.position.needsUpdate = true;
  });
}

// ---------- Sunny Park ----------

function parkCentre(ctx) {
  const pond = mesh(new THREE.CylinderGeometry(7, 7, 0.3, 40), mat(0x4fc3f7, { transparent: true, opacity: 0.9 }), 0, 0.1);
  const rim = mesh(new THREE.TorusGeometry(7, 0.4, 8, 40), mat(0xbdbdbd), 0, 0.3);
  rim.rotation.x = Math.PI / 2;
  const fountain = mesh(new THREE.CylinderGeometry(0.5, 1.2, 2, 16), mat(0xe0e0e0), 0, 1);
  ctx.add(group(pond, rim, fountain), 0, 0, { r: 7.4 });
}

// ---------- School and playground ----------

function makeSwings() {
  const red = mat(0xe53935);
  const swings = group(mesh(new THREE.CylinderGeometry(0.07, 0.07, 3.4, 8), red, 0, 2.4));
  swings.children[0].rotation.z = Math.PI / 2;
  for (const x of [-1.6, 1.6]) {
    for (const z of [-0.8, 0.8]) {
      const leg = mesh(new THREE.CylinderGeometry(0.07, 0.07, 2.6, 8), red, x, 1.2, z * 0.5);
      leg.rotation.x = z > 0 ? -0.3 : 0.3;
      swings.add(leg);
    }
  }
  for (const x of [-0.7, 0.7]) {
    swings.add(mesh(new THREE.BoxGeometry(0.6, 0.06, 0.25), mat(0xffd23f), x, 0.6));
    for (const dx of [-0.25, 0.25]) swings.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 1.8, 4), mat(0x888888), x + dx, 1.5));
  }
  return swings;
}

function makeSlide() {
  const slide = mesh(new THREE.BoxGeometry(0.8, 0.1, 3.4), mat(0x4fc3f7), 0, 1.1, 0.6);
  slide.rotation.x = 0.6;
  const tower = mesh(new THREE.BoxGeometry(1.2, 2.0, 1.2), mat(0xffd23f), 0, 1.0, -1.4);
  const roof = mesh(new THREE.ConeGeometry(1.0, 0.8, 4), mat(0xe53935), 0, 2.4, -1.4);
  roof.rotation.y = Math.PI / 4;
  return group(slide, tower, roof);
}

function schoolCentre(ctx) {
  // a big climbing frame on a round rubbery play mat
  const matFloor = mesh(new THREE.CylinderGeometry(7, 7, 0.08, 40), mat(0x4caf50), 0, 0.04);
  const frame = group(matFloor);
  const colours = [0xe53935, 0x4fc3f7, 0xffd23f, 0x8e5bd6];
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2;
    frame.add(mesh(new THREE.CylinderGeometry(0.12, 0.12, 3.5, 8), mat(colours[i]), Math.cos(a) * 2.5, 1.75, Math.sin(a) * 2.5));
  }
  const dome = mesh(
    new THREE.SphereGeometry(3, 8, 6, 0, Math.PI * 2, 0, Math.PI / 2),
    new THREE.MeshLambertMaterial({ color: 0xff8a3d, wireframe: true }),
    0, 0.1,
  );
  frame.add(dome);
  ctx.add(frame, 0, 0, { r: 3.4 });
}

// ---------- Supermarket car park ----------

function makeCar(rand) {
  const colour = pick(rand, [0xe53935, 0x4fc3f7, 0xffd23f, 0x4caf50, 0xffffff, 0x8e5bd6, 0xff8a3d]);
  const car = group(
    mesh(new THREE.BoxGeometry(1.8, 0.8, 3.6), mat(colour), 0, 0.7),
    mesh(new THREE.BoxGeometry(1.6, 0.7, 1.9), mat(colour), 0, 1.4, -0.2),
    mesh(new THREE.BoxGeometry(1.5, 0.5, 1.92), glowMat(0xbfeaff), 0, 1.4, -0.2),
  );
  const tyre = mat(0x222222);
  for (const x of [-0.9, 0.9]) {
    for (const z of [-1.1, 1.1]) {
      const t = mesh(new THREE.CylinderGeometry(0.35, 0.35, 0.25, 12), tyre, x, 0.35, z);
      t.rotation.z = Math.PI / 2;
      car.add(t);
    }
  }
  return car;
}

function makeTrolley() {
  const metal = mat(0xbbbbbb);
  const basket = mesh(new THREE.BoxGeometry(0.7, 0.5, 1.0), new THREE.MeshLambertMaterial({ color: 0xbbbbbb, wireframe: true }), 0, 0.85);
  const t = group(basket, mesh(new THREE.BoxGeometry(0.7, 0.05, 1.0), metal, 0, 0.35));
  t.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.8, 6), mat(0xe53935), 0, 1.15, 0.55));
  t.children[2].rotation.z = Math.PI / 2;
  return t;
}

function makeCone() {
  return group(
    mesh(new THREE.ConeGeometry(0.25, 0.7, 12), mat(0xff8a3d), 0, 0.35),
    mesh(new THREE.CylinderGeometry(0.17, 0.2, 0.12, 12), glowMat(0xffffff), 0, 0.35),
  );
}

function carParkCentre(ctx) {
  // a round flower bed with a big supermarket sign
  const bed = mesh(new THREE.CylinderGeometry(5, 5, 0.4, 32), mat(0x8bc34a), 0, 0.2);
  const pole = mesh(new THREE.CylinderGeometry(0.2, 0.2, 6, 8), mat(0x888888), 0, 3);
  const sign = mesh(new THREE.BoxGeometry(5, 1.6, 0.3), mat(0xe53935), 0, 6.5);
  const stripe = mesh(new THREE.BoxGeometry(5.1, 0.3, 0.32), glowMat(0xffffff), 0, 6.5);
  const g = group(bed, pole, sign, stripe);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    g.add(mesh(new THREE.SphereGeometry(0.5, 10, 8), mat(pick(ctx.rand, [0xffd23f, 0xff6fae, 0xffffff])), Math.cos(a) * 3.5, 0.6, Math.sin(a) * 3.5));
  }
  ctx.add(g, 0, 0, { r: 5.2 });
}

// ---------- Beach and pier ----------

function makePalm(rand) {
  const palm = new THREE.Group();
  const trunkMat = mat(0xa0784a);
  for (let i = 0; i < 6; i++) {
    const seg = mesh(new THREE.CylinderGeometry(0.22, 0.28, 0.9, 8), trunkMat, i * 0.12, 0.45 + i * 0.85);
    seg.rotation.z = -0.12;
    palm.add(seg);
  }
  const leafMat = mat(0x3fae4a, { side: THREE.DoubleSide });
  for (let i = 0; i < 6; i++) {
    const leaf = mesh(new THREE.BoxGeometry(0.6, 0.06, 2.6), leafMat, 0.7, 5.3, 0);
    leaf.geometry.translate(0, 0, 1.3);
    leaf.rotation.set(0.4, (i / 6) * Math.PI * 2, 0);
    palm.add(leaf);
  }
  for (let i = 0; i < 3; i++) palm.add(mesh(new THREE.SphereGeometry(0.18, 8, 6), mat(0x6b4a2a), 0.6 + (i - 1) * 0.2, 5.0, 0.15));
  palm.rotation.y = rand() * Math.PI * 2;
  return palm;
}

function makeUmbrella(rand) {
  const colours = [0xe53935, 0x4fc3f7, 0xffd23f, 0xff6fae];
  const top = mesh(new THREE.ConeGeometry(1.6, 0.7, 8), mat(pick(rand, colours)), 0, 2.4);
  const towel = mesh(new THREE.BoxGeometry(1.0, 0.03, 2.0), mat(pick(rand, colours)), 1.2, 0.03, 0.4);
  return group(mesh(new THREE.CylinderGeometry(0.05, 0.05, 2.5, 6), mat(0xffffff), 0, 1.25), top, towel);
}

function makeSandcastle(size = 1) {
  const sand = mat(0xe8c97a);
  const castle = group(mesh(new THREE.BoxGeometry(1.4 * size, 0.7 * size, 1.4 * size), sand, 0, 0.35 * size));
  for (const x of [-0.6, 0.6]) {
    for (const z of [-0.6, 0.6]) {
      castle.add(mesh(new THREE.CylinderGeometry(0.25 * size, 0.3 * size, 1.1 * size, 8), sand, x * size, 0.55 * size, z * size));
    }
  }
  castle.add(mesh(new THREE.ConeGeometry(0.03 * size + 0.02, 0.4 * size, 4), mat(0xe53935), 0, 1.0 * size));
  return castle;
}

function beachCentre(ctx) {
  ctx.add(makeSandcastle(4), 0, 0, { r: 4.5 });
}

// ---------- Funfair ----------

function makeTent(rand) {
  const colours = [0xe53935, 0x4fc3f7, 0x8e5bd6, 0x4caf50];
  const c = pick(rand, colours);
  const tent = new THREE.Group();
  for (let i = 0; i < 8; i++) {
    const wall = mesh(
      new THREE.CylinderGeometry(2, 2, 2.2, 8, 1, true, (i / 8) * Math.PI * 2, Math.PI / 4),
      mat(i % 2 ? 0xffffff : c, { side: THREE.DoubleSide }), 0, 1.1,
    );
    tent.add(wall);
  }
  tent.add(mesh(new THREE.ConeGeometry(2.3, 1.8, 8), mat(c), 0, 3.1));
  tent.add(mesh(new THREE.ConeGeometry(0.15, 0.6, 6), mat(0xffd23f), 0, 4.3));
  return tent;
}

function makeBalloons(rand) {
  const b = new THREE.Group();
  for (let i = 0; i < 5; i++) {
    const x = (rand() - 0.5) * 0.8;
    const z = (rand() - 0.5) * 0.8;
    const y = 2.6 + rand() * 0.8;
    b.add(mesh(new THREE.SphereGeometry(0.3, 10, 8), mat(pick(rand, [0xe53935, 0xffd23f, 0x4fc3f7, 0xff6fae, 0x7dff4f])), x, y, z));
    const string = mesh(new THREE.CylinderGeometry(0.01, 0.01, y, 4), mat(0xffffff), x / 2, y / 2, z / 2);
    b.add(string);
  }
  return b;
}

function funfairCentre(ctx) {
  // a carousel that goes round
  const base = mesh(new THREE.CylinderGeometry(5, 5, 0.5, 24), mat(0xffd23f), 0, 0.25);
  const roof = mesh(new THREE.ConeGeometry(5.5, 2.4, 24), mat(0xe53935), 0, 5.2);
  const pole = mesh(new THREE.CylinderGeometry(0.4, 0.4, 4.5, 12), mat(0xffffff), 0, 2.5);
  const spin = new THREE.Group();
  const horseColours = [0xffffff, 0xff9ed2, 0x4fc3f7, 0xb28dff];
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const horse = group(
      mesh(new THREE.CylinderGeometry(0.05, 0.05, 4, 6), mat(0xffd23f), 0, 2.3),
      mesh(new THREE.CapsuleGeometry(0.3, 0.7, 4, 8), mat(horseColours[i % 4]), 0, 1.5),
    );
    horse.children[1].rotation.z = Math.PI / 2;
    horse.position.set(Math.cos(a) * 3.8, 0, Math.sin(a) * 3.8);
    horse.rotation.y = -a;
    spin.add(horse);
  }
  spin.add(roof);
  spin.name = 'carousel'; // for the Godot export
  ctx.add(group(base, pole, spin), 0, 0, { r: 5.2 });
  ctx.animate((dt, t) => {
    spin.rotation.y += dt * 0.6;
    spin.children.forEach((h, i) => { if (i < 8) h.children[1].position.y = 1.5 + Math.sin(t * 2 + i) * 0.3; });
  });
}

function addFerrisWheel(ctx) {
  // a giant wheel just outside the north wall, high above everything
  const wheel = new THREE.Group();
  const rim = mesh(new THREE.TorusGeometry(10, 0.3, 8, 40), mat(0xffffff));
  wheel.add(rim);
  const colours = [0xe53935, 0x4fc3f7, 0xffd23f, 0x7dff4f, 0xff6fae, 0x8e5bd6];
  const cars = [];
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    const spoke = mesh(new THREE.BoxGeometry(0.15, 10, 0.15), mat(0xdddddd), Math.cos(a) * 5, Math.sin(a) * 5);
    spoke.rotation.z = a - Math.PI / 2;
    wheel.add(spoke);
    const car = mesh(new THREE.BoxGeometry(1.4, 1.2, 1.2), mat(colours[i % colours.length]), Math.cos(a) * 10, Math.sin(a) * 10);
    wheel.add(car);
    cars.push(car);
  }
  wheel.position.set(0, 13, -ctx.half - 10);
  wheel.name = 'ferrisWheel'; // for the Godot export
  const legs = new THREE.Group();
  for (const x of [-4, 4]) {
    const leg = mesh(new THREE.BoxGeometry(0.5, 14, 0.5), mat(0xaaaaaa), x, 6.5, -ctx.half - 10);
    leg.rotation.z = x > 0 ? 0.25 : -0.25;
    legs.add(leg);
  }
  ctx.group.add(wheel, legs);
  ctx.animate((dt) => {
    wheel.rotation.z += dt * 0.15;
    for (const car of cars) car.rotation.z = -wheel.rotation.z; // the little cars hang the right way up
  });
}

// ---------- Snowy village ----------

function makePine(rand) {
  const green = mat(0x2e7d4f);
  const snow = mat(0xffffff);
  const pine = group(mesh(new THREE.CylinderGeometry(0.25, 0.3, 1.2, 8), mat(0x6b4a2a), 0, 0.6));
  const s = 0.9 + rand() * 0.4;
  for (let i = 0; i < 3; i++) {
    pine.add(mesh(new THREE.ConeGeometry((2 - i * 0.5) * s, 1.8 * s, 10), green, 0, (1.6 + i * 1.1) * s));
    pine.add(mesh(new THREE.ConeGeometry((1.2 - i * 0.3) * s, 0.7 * s, 10), snow, 0, (2.2 + i * 1.1) * s));
  }
  return pine;
}

function makeSnowman(rand) {
  const snow = mat(0xffffff);
  const man = group(
    mesh(new THREE.SphereGeometry(0.7, 14, 12), snow, 0, 0.6),
    mesh(new THREE.SphereGeometry(0.5, 14, 12), snow, 0, 1.5),
    mesh(new THREE.SphereGeometry(0.35, 14, 12), snow, 0, 2.2),
    mesh(new THREE.ConeGeometry(0.07, 0.4, 8), mat(0xff8a3d), 0, 2.2, -0.45),
  );
  man.children[3].rotation.x = -Math.PI / 2;
  const scarf = mesh(new THREE.TorusGeometry(0.38, 0.09, 6, 16), mat(pick(rand, [0xe53935, 0x4fc3f7, 0x8e5bd6])), 0, 1.9);
  scarf.rotation.x = Math.PI / 2;
  man.add(scarf);
  for (const x of [-0.12, 0.12]) man.add(mesh(new THREE.SphereGeometry(0.05, 6, 6), glowMat(0x222222), x, 2.3, -0.3));
  return man;
}

function snowCentre(ctx) {
  // a frozen pond with a giant decorated tree
  const ice = mesh(new THREE.CylinderGeometry(7, 7, 0.15, 40), mat(0xd6f0ff, { emissive: 0x223344 }), 0, 0.08);
  const tree = makePine(ctx.rand);
  tree.scale.setScalar(1.8);
  const g = group(ice, tree);
  const baubles = [0xe53935, 0xffd23f, 0x4fc3f7, 0xff6fae];
  for (let i = 0; i < 16; i++) {
    const a = i * 2.4;
    const y = 2.5 + (i % 5) * 1.1;
    const r = 3.2 - (i % 5) * 0.55;
    g.add(mesh(new THREE.SphereGeometry(0.22, 8, 6), glowMat(baubles[i % 4]), Math.cos(a) * r, y, Math.sin(a) * r));
  }
  g.add(mesh(new THREE.OctahedronGeometry(0.6), glowMat(0xffe066), 0, 9.4));
  ctx.add(g, 0, 0, { r: 7.2 });
}

// ---------- Toy factory ----------

function makeBlock(rand) {
  const colours = [0xe53935, 0x4fc3f7, 0xffd23f, 0x4caf50, 0xff8a3d, 0x8e5bd6];
  const size = 1.4 + rand() * 0.8;
  const block = group(mesh(new THREE.BoxGeometry(size, size, size), mat(pick(rand, colours)), 0, size / 2));
  if (rand() < 0.5) {
    const top = mesh(new THREE.BoxGeometry(size * 0.8, size * 0.8, size * 0.8), mat(pick(rand, colours)), 0.1, size * 1.4);
    top.rotation.y = 0.5;
    block.add(top);
  }
  block.rotation.y = rand() * Math.PI;
  return block;
}

function makeTeddy(scale = 1, colour = 0xc68642) {
  const fur = mat(colour);
  const light = mat(0xf3d9b0);
  const t = group(
    mesh(new THREE.SphereGeometry(0.9, 16, 12), fur, 0, 1.0),
    mesh(new THREE.SphereGeometry(0.6, 16, 12), fur, 0, 2.2),
    mesh(new THREE.SphereGeometry(0.25, 10, 8), light, 0, 2.05, -0.5),
    mesh(new THREE.SphereGeometry(0.5, 12, 10), light, 0, 1.0, -0.55),
  );
  for (const x of [-0.45, 0.45]) {
    t.add(mesh(new THREE.SphereGeometry(0.22, 10, 8), fur, x, 2.75));
    t.add(mesh(new THREE.SphereGeometry(0.3, 10, 8), fur, x * 2.1, 1.3, -0.1));
    t.add(mesh(new THREE.SphereGeometry(0.32, 10, 8), fur, x, 0.25, -0.3));
    t.add(mesh(new THREE.SphereGeometry(0.07, 6, 6), glowMat(0x111111), x * 0.45, 2.35, -0.52));
  }
  t.scale.setScalar(scale);
  return t;
}

function makeDuck() {
  const yellow = mat(0xffe066);
  const duck = group(
    mesh(new THREE.SphereGeometry(0.6, 12, 10), yellow, 0, 0.55),
    mesh(new THREE.SphereGeometry(0.38, 12, 10), yellow, 0, 1.2, -0.35),
    mesh(new THREE.ConeGeometry(0.15, 0.35, 8), mat(0xff8a3d), 0, 1.15, -0.78),
  );
  duck.children[0].scale.set(1, 0.8, 1.3);
  duck.children[2].rotation.x = -Math.PI / 2;
  for (const x of [-0.18, 0.18]) duck.add(mesh(new THREE.SphereGeometry(0.06, 6, 6), glowMat(0x111111), x, 1.3, -0.65));
  return duck;
}

function makeBall(rand) {
  const ball = mesh(new THREE.SphereGeometry(1.0, 16, 12), mat(pick(rand, [0xe53935, 0x4fc3f7, 0xffd23f])), 0, 1.0);
  const stripe = mesh(new THREE.TorusGeometry(1.0, 0.12, 6, 24), mat(0xffffff), 0, 1.0);
  return group(ball, stripe);
}

function toysCentre(ctx) {
  ctx.add(makeTeddy(2.6, 0xd2a066), 0, 0, { r: 3.6 });
}

// ---------- Haunted forest ----------

function makeSpookyTree(rand) {
  const bark = mat(0x4a3a4a);
  const tree = group(mesh(new THREE.CylinderGeometry(0.3, 0.5, 4, 8), bark, 0, 2));
  for (let i = 0; i < 4; i++) {
    const branch = mesh(new THREE.CylinderGeometry(0.07, 0.14, 1.8, 6), bark, 0, 2.8 + i * 0.35);
    branch.geometry.translate(0, 0.9, 0);
    branch.rotation.set(0.9 + rand() * 0.4, (i / 4) * Math.PI * 2 + rand(), 0);
    tree.add(branch);
  }
  // a few purple leaves so it's spooky-pretty, not scary
  tree.add(mesh(new THREE.SphereGeometry(1.2, 10, 8), mat(0x5a3a7a), 0, 4.4));
  return tree;
}

function makeMushroom(rand, glow = true) {
  const colours = [0xff6fd8, 0x7dfff0, 0xb28dff, 0xffe066];
  const cap = mesh(
    new THREE.SphereGeometry(0.45, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2),
    glow ? glowMat(pick(rand, colours)) : mat(0xe53935), 0, 0.55,
  );
  return group(mesh(new THREE.CylinderGeometry(0.12, 0.16, 0.6, 8), mat(0xf3e9d2), 0, 0.3), cap);
}

function forestCentre(ctx) {
  // a giant glowing mushroom ring round an old tree
  const g = group();
  const old = makeSpookyTree(ctx.rand);
  old.scale.setScalar(1.8);
  g.add(old);
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    const m = makeMushroom(ctx.rand);
    m.scale.setScalar(2);
    m.position.set(Math.cos(a) * 5.5, 0, Math.sin(a) * 5.5);
    g.add(m);
  }
  ctx.add(g, 0, 0, { r: 6 });
}

// ---------- Graveyard at night ----------

function makeGravestone(rand) {
  const stone = mat(pick(rand, [0x9a9aa8, 0x8a8a96, 0xa8a8b4]));
  const g = group(
    mesh(new THREE.BoxGeometry(0.9, 1.1, 0.25), stone, 0, 0.55),
    mesh(new THREE.CylinderGeometry(0.45, 0.45, 0.25, 12, 1, false, 0, Math.PI), stone, 0, 1.1),
  );
  g.children[1].rotation.set(Math.PI / 2, Math.PI / 2, 0);
  g.rotation.y = (rand() - 0.5) * 0.4;
  g.rotation.z = (rand() - 0.5) * 0.15;
  return g;
}

function makeJackOLantern(rand) {
  const pumpkin = mesh(new THREE.SphereGeometry(0.45, 12, 10), mat(0xff8a1f, { emissive: 0x552200 }), 0, 0.4);
  pumpkin.scale.y = 0.8;
  const g = group(pumpkin, mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.2, 6), mat(0x3f8f3f), 0, 0.82));
  // a happy face
  const face = glowMat(0xffe066);
  for (const x of [-0.15, 0.15]) g.add(mesh(new THREE.ConeGeometry(0.07, 0.1, 3), face, x, 0.5, -0.42));
  const smile = mesh(new THREE.TorusGeometry(0.15, 0.035, 4, 10, Math.PI), face, 0, 0.36, -0.42);
  smile.rotation.z = Math.PI;
  g.add(smile);
  g.rotation.y = rand() * 0.6 - 0.3;
  return g;
}

function graveyardCentre(ctx) {
  // a little crypt with a glowing door
  const stone = mat(0x8a8a96);
  const crypt = group(
    mesh(new THREE.BoxGeometry(5, 3.4, 5), stone, 0, 1.7),
    mesh(new THREE.ConeGeometry(3.9, 1.8, 4), mat(0x5a5a6a), 0, 4.3),
    mesh(new THREE.PlaneGeometry(1.4, 2.2), glowMat(0x9cff57), 0, 1.1, 2.51),
  );
  crypt.children[1].rotation.y = Math.PI / 4;
  ctx.add(crypt, 0, 0, { r: 3.6 });
}

// ---------- Zombie King's castle ----------

function makeTorch(light) {
  const torch = group(
    mesh(new THREE.CylinderGeometry(0.08, 0.12, 2.2, 8), mat(0x5a3a1a), 0, 1.1),
    mesh(new THREE.ConeGeometry(0.22, 0.55, 8), glowMat(0xff9a1f), 0, 2.45),
  );
  if (light) {
    const l = new THREE.PointLight(0xff9a3f, 6, 9);
    l.position.y = 2.5;
    torch.add(l);
  }
  return torch;
}

function makeBanner(rand) {
  const colour = pick(rand, [0x8e5bd6, 0xe53935, 0x1e6fd6]);
  const pole = mesh(new THREE.CylinderGeometry(0.07, 0.07, 4.5, 8), mat(0x888888), 0, 2.25);
  const flag = mesh(new THREE.PlaneGeometry(1.2, 1.8), mat(colour, { side: THREE.DoubleSide }), 0.65, 3.4);
  const crown = mesh(new THREE.CircleGeometry(0.3, 5), glowMat(0xffd23f), 0.65, 3.6, 0.01);
  return group(pole, flag, crown);
}

function makeBarrel() {
  const wood = mat(0x8b5a2b);
  const b = group(mesh(new THREE.CylinderGeometry(0.5, 0.45, 1.1, 12), wood, 0, 0.55));
  for (const y of [0.25, 0.85]) {
    const band = mesh(new THREE.TorusGeometry(0.49, 0.04, 6, 16), mat(0x444444), 0, y);
    band.rotation.x = Math.PI / 2;
    b.add(band);
  }
  return b;
}

function castleCentre(ctx) {
  // the King's throne on a round stone stage
  const stage = mesh(new THREE.CylinderGeometry(5, 5.4, 0.8, 24), mat(0x8a8a96), 0, 0.4);
  const throne = group(
    mesh(new THREE.BoxGeometry(2.2, 1.0, 2), mat(0x8e5bd6), 0, 1.3),
    mesh(new THREE.BoxGeometry(2.2, 3.2, 0.4), mat(0x8e5bd6), 0, 2.4, 0.9),
  );
  for (let i = 0; i < 5; i++) throne.add(mesh(new THREE.ConeGeometry(0.15, 0.5, 6), mat(0xffd23f), -0.8 + i * 0.4, 4.2, 0.9));
  const carpet = mesh(new THREE.BoxGeometry(2.4, 0.05, 6), mat(0xe53935), 0, 0.83, -2);
  ctx.add(group(stage, throne, carpet), 0, 0, { r: 5.4 });
}

// Tall stone towers with pointy roofs in each corner.
function addTowers(ctx) {
  for (const [x, z] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    const tower = group(
      mesh(new THREE.CylinderGeometry(3, 3.2, 12, 16), mat(0x9a9aa6), 0, 6),
      mesh(new THREE.ConeGeometry(3.6, 4, 16), mat(0x8e5bd6), 0, 14),
    );
    tower.position.set(x * ctx.half, 0, z * ctx.half);
    ctx.group.add(tower);
  }
}

// ---------- the themes ----------

export const THEMES = {
  park: {
    sky: 0x87ceeb, fog: [40, 110], ground: 0x7ccf5a, path: 0xe8d5a3,
    light: { sky: 0xffffff, ground: 0x6aa84f, amount: 1.6, sun: 0xfff4d6, sunAmount: 2.2 },
    wall: { colour: 0x2e7d32, height: 2.2 },
    decorate(ctx) {
      parkCentre(ctx);
      ctx.scatter((r) => makeTree(r), 28, { gap: 3, r: 0.6 });
      ctx.scatter((r) => makeBush(r), 18, { gap: 1.5, r: 1.1, small: true });
      ctx.scatter(makeFlowers, 10, { gap: 1 });
      ctx.ring(() => makeBench(), 6, 15.5, { r: 1.2, small: true });
      addClouds(ctx);
    },
  },
  school: {
    sky: 0x8fd3ff, fog: [40, 110], ground: 0x8fd16a, path: 0xb0b0b8,
    light: { sky: 0xffffff, ground: 0x7ab85f, amount: 1.6, sun: 0xfff4d6, sunAmount: 2.2 },
    wall: { colour: 0xb5523b, height: 2.4 }, // a red brick wall
    decorate(ctx) {
      schoolCentre(ctx);
      for (const [x, z] of [[-30, -31], [30, -31]]) ctx.add(makeHouse(ctx.rand, 0xe8c9a0, 0xb5523b), x, z, { box: [4, 4] });
      ctx.scatter(makeSwings, 4, { gap: 3, r: 1.8 });
      ctx.scatter(makeSlide, 4, { gap: 3, r: 1.6 });
      ctx.scatter((r) => makeTree(r), 14, { gap: 3, r: 0.6 });
      ctx.scatter(() => makeFence(0xffffff), 14, { gap: 1.5, r: 1.2, small: true });
      ctx.ring(() => makeBench(0x4fc3f7), 6, 15.5, { r: 1.2, small: true });
      addClouds(ctx);
    },
  },
  carPark: {
    sky: 0x9fd0ff, fog: [40, 110], ground: 0x6f6f78, path: 0x9a9aa4,
    light: { sky: 0xffffff, ground: 0x777777, amount: 1.6, sun: 0xfff4d6, sunAmount: 2.0 },
    wall: { colour: 0xc8c8c8, height: 1.4 },
    decorate(ctx) {
      carParkCentre(ctx);
      ctx.scatter(makeCar, 22, { gap: 2, r: 1.7 });
      ctx.scatter(makeTrolley, 14, { gap: 1, r: 0.6, small: true });
      ctx.scatter(() => makeLamp(), 10, { gap: 2, r: 0.3 });
      ctx.scatter(makeCone, 16, { gap: 0.5 });
      ctx.scatter((r) => makeTree(r), 8, { gap: 3, r: 0.6 });
      addClouds(ctx);
    },
  },
  beach: {
    sky: 0x7fd4ff, fog: [45, 120], ground: 0xf3dfa2, path: 0xc8a26b,
    light: { sky: 0xffffff, ground: 0xe8d090, amount: 1.7, sun: 0xfff1c8, sunAmount: 2.3 },
    wall: { colour: 0xb88a5a, height: 1.2 }, // a low wooden fence
    decorate(ctx) {
      beachCentre(ctx);
      // the sea, past the north fence, with a pier going out into it
      const sea = mesh(new THREE.PlaneGeometry(400, 160), mat(0x2fa8e0, { transparent: true, opacity: 0.95 }), 0, 0.15, -ctx.half - 80);
      sea.rotation.x = -Math.PI / 2;
      const pier = mesh(new THREE.BoxGeometry(5, 0.4, 40), mat(0xa0784a), 14, 0.6, -ctx.half - 21);
      ctx.group.add(sea, pier);
      for (let i = 0; i < 8; i++) ctx.group.add(mesh(new THREE.CylinderGeometry(0.25, 0.25, 2, 8), mat(0x6b4a2a), 14 + (i % 2 ? 2.2 : -2.2), 0, -ctx.half - 4 - Math.floor(i / 2) * 10));
      ctx.scatter(makePalm, 18, { gap: 3, r: 0.5 });
      ctx.scatter(makeUmbrella, 12, { gap: 2, r: 0.4 });
      ctx.scatter(() => makeSandcastle(0.8), 10, { gap: 1, r: 0.8, small: true });
      addClouds(ctx, 6);
    },
  },
  funfair: {
    sky: 0x9ad8ff, fog: [50, 130], ground: 0x7ccf5a, path: 0xf0c27b,
    light: { sky: 0xffffff, ground: 0x6aa84f, amount: 1.6, sun: 0xfff4d6, sunAmount: 2.2 },
    wall: { colour: 0xff6fae, height: 1.6 },
    decorate(ctx) {
      funfairCentre(ctx);
      addFerrisWheel(ctx);
      ctx.scatter(makeTent, 10, { gap: 3, r: 2.2 });
      ctx.scatter(makeBalloons, 12, { gap: 1.5, r: 0.4 });
      ctx.scatter(() => makeLamp(0xff6fd8), 10, { gap: 2, r: 0.3 });
      ctx.scatter((r) => makeTree(r), 10, { gap: 3, r: 0.6 });
      ctx.ring(() => makeBench(0xe53935), 6, 15.5, { r: 1.2, small: true });
      addClouds(ctx, 6);
    },
  },
  snow: {
    sky: 0xc8e4f8, fog: [30, 100], ground: 0xf4f8ff, path: 0xc9d9ea,
    light: { sky: 0xffffff, ground: 0xdde8f5, amount: 1.5, sun: 0xffffff, sunAmount: 1.8 },
    wall: { colour: 0xffffff, height: 1.8 }, // a bank of snow
    decorate(ctx) {
      snowCentre(ctx);
      for (const [x, z] of [[-30, -31], [30, -31], [-31, 30], [31, 30]]) {
        ctx.add(makeHouse(ctx.rand, pick(ctx.rand, [0xe57373, 0x81c784, 0x64b5f6, 0xffd54f]), 0x6b4a2a, true), x, z, { box: [3.5, 3.5] });
      }
      ctx.scatter(makePine, 28, { gap: 3, r: 0.7 });
      ctx.scatter(makeSnowman, 10, { gap: 1.5, r: 0.7 });
      ctx.scatter(() => makeFence(0x8b5a2b), 12, { gap: 1.5, r: 1.2, small: true });
      addFloaters(ctx, { count: 900, colour: 0xffffff, size: 0.18, fall: 1.2, wander: 0.4, high: 25 });
    },
  },
  toys: {
    sky: 0xd9c8ff, fog: [40, 100], ground: 0xe8d4b0, path: 0xff9ed2,
    light: { sky: 0xffffff, ground: 0xd8c0a0, amount: 1.7, sun: 0xfff4ff, sunAmount: 2.0 },
    wall: { colour: 0x4fc3f7, height: 3.5 },
    decorate(ctx) {
      toysCentre(ctx);
      ctx.scatter(makeBlock, 22, { gap: 2, r: 1.3 });
      ctx.scatter(() => makeTeddy(1, pick(ctx.rand, [0xc68642, 0xff9ed2, 0x9fd0ff])), 8, { gap: 2, r: 1.0 });
      ctx.scatter(makeDuck, 8, { gap: 1.5, r: 0.7, small: true });
      ctx.scatter(makeBall, 10, { gap: 1.5, r: 1.0 });
      addFloaters(ctx, { count: 300, colour: 0xffe066, size: 0.25, wander: 0.6, low: 2, high: 14 });
    },
  },
  forest: {
    sky: 0x6a5a8a, fog: [18, 75], ground: 0x4f7048, path: 0x8a7458,
    light: { sky: 0xd8ccff, ground: 0x4f7048, amount: 2.0, sun: 0xe8dcff, sunAmount: 1.5 },
    wall: { colour: 0x1f3a24, height: 3 },
    decorate(ctx) {
      forestCentre(ctx);
      ctx.scatter(makeSpookyTree, 34, { gap: 2.5, r: 0.6 });
      ctx.scatter((r) => makeMushroom(r), 24, { gap: 0.8 });
      ctx.scatter((r) => makeBush(r, 0x2f5a3a), 12, { gap: 1.5, r: 1.1, small: true });
      addFloaters(ctx, { count: 160, colour: 0xc8ff6a, size: 0.25, wander: 1.0, low: 0.5, high: 5 }); // fireflies
    },
  },
  graveyard: {
    sky: 0x2a2860, fog: [25, 85], ground: 0x4c6a52, path: 0x9a9ab0, night: true,
    light: { sky: 0xb0bcff, ground: 0x4c6a52, amount: 2.1, sun: 0xd8e0ff, sunAmount: 1.4 },
    wall: { colour: 0x222233, height: 1.8 },
    decorate(ctx) {
      graveyardCentre(ctx);
      ctx.scatter(makeGravestone, 36, { gap: 1, r: 0.5, small: true });
      ctx.scatter(makeSpookyTree, 10, { gap: 3, r: 0.6 });
      ctx.scatter(makeJackOLantern, 14, { gap: 1, r: 0.4, small: true });
      ctx.scatter((r, i) => makeLamp(0xffe8a0, i < 6), 10, { gap: 3, r: 0.3 });
      ctx.scatter(() => makeFence(0x333344), 10, { gap: 1.5, r: 1.2, small: true });
      addFloaters(ctx, { count: 120, colour: 0x9cff57, size: 0.25, wander: 0.8, low: 0.5, high: 6 });
    },
  },
  castle: {
    sky: 0x7a6aa8, fog: [35, 110], ground: 0x8f8f86, path: 0xbdb6a0,
    light: { sky: 0xffffff, ground: 0x8f8f86, amount: 1.5, sun: 0xffe8c8, sunAmount: 1.8 },
    wall: { colour: 0x9a9aa6, height: 6, battlements: true },
    decorate(ctx) {
      castleCentre(ctx);
      addTowers(ctx);
      ctx.scatter((r, i) => makeTorch(i < 6), 14, { gap: 2, r: 0.3 });
      ctx.scatter(makeBanner, 10, { gap: 2, r: 0.3 });
      ctx.scatter(makeBarrel, 14, { gap: 1, r: 0.55, small: true });
      ctx.scatter((r) => makeBush(r, 0x4a7a4a), 8, { gap: 1.5, r: 1.1, small: true });
      addClouds(ctx, 5);
    },
  },
};
