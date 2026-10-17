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

export const WEAPON_MODELS = {
  spikyStick: makeSpikyStick,
  noodleBat: makeNoodleBat,
  waterBlaster: makeWaterBlaster,
};

const squirtGeo = new THREE.SphereGeometry(0.09, 8, 6);
const squirtMat = new THREE.MeshBasicMaterial({ color: 0x4fc3f7 });

// Water squirts fly forward and hit the first zombie they touch.
export class Squirts {
  constructor(scene) {
    this.scene = scene;
    this.list = [];
  }

  fire(from, dir, weapon, by) {
    const mesh = new THREE.Mesh(squirtGeo, squirtMat);
    mesh.position.copy(from);
    mesh.scale.set(1, 1, 1.8);
    mesh.lookAt(from.clone().add(dir));
    this.scene.add(mesh);
    this.list.push({ mesh, vel: dir.clone().multiplyScalar(weapon.shotSpeed), weapon, by, travelled: 0 });
  }

  clear() {
    for (const s of this.list) this.scene.remove(s.mesh);
    this.list = [];
  }

  // Returns the hits this frame: [{ zombie, weapon, by, push }]
  update(dt, zombies) {
    const hits = [];
    for (let i = this.list.length - 1; i >= 0; i--) {
      const s = this.list[i];
      const p = s.mesh.position;
      p.addScaledVector(s.vel, dt);
      s.travelled += s.vel.length() * dt;
      let hit = null;
      for (const z of zombies) {
        if (z.alive && p.y < 2.3 && Math.hypot(p.x - z.pos.x, p.z - z.pos.z) < z.radius + 0.25) {
          hit = z;
          break;
        }
      }
      if (hit) {
        hits.push({ zombie: hit, weapon: s.weapon, by: s.by, push: s.vel.clone().setY(0).normalize(), at: p.clone() });
      }
      if (hit || s.travelled > s.weapon.range + 4 || p.y < 0) {
        this.scene.remove(s.mesh);
        this.list.splice(i, 1);
      }
    }
    return hits;
  }
}
