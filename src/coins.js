import * as THREE from 'three';
import { CONFIG } from './config.js';
import { resolveCollisions } from './world.js';

// Spinning Tag Bux coins that burst out of popped zombies. Walk over them to collect.

function coinFaceTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#ffd23f';
  ctx.fillRect(0, 0, 128, 128);
  ctx.lineWidth = 10;
  ctx.strokeStyle = '#e09b00';
  ctx.beginPath();
  ctx.arc(64, 64, 52, 0, Math.PI * 2);
  ctx.stroke();
  ctx.font = 'bold 80px "Fredoka", "Comic Sans MS", sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#e09b00';
  ctx.fillText('T', 64, 70);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

const coinGeo = new THREE.CylinderGeometry(0.3, 0.3, 0.07, 24);
const edgeMat = new THREE.MeshLambertMaterial({ color: 0xe0a800, emissive: 0x553300 });
const faceMat = new THREE.MeshLambertMaterial({ map: coinFaceTexture(), emissive: 0x443300 });
const coinMats = [edgeMat, faceMat, faceMat];

export class Coins {
  constructor(scene) {
    this.scene = scene;
    this.list = [];
  }

  // Scatter enough coins to add up to `value` Tag Bux.
  burst(pos, value) {
    const count = Math.max(1, Math.round(value / CONFIG.tagBux.coinValue));
    for (let i = 0; i < count; i++) {
      const mesh = new THREE.Mesh(coinGeo, coinMats);
      mesh.rotation.x = Math.PI / 2; // stand it up on its edge
      const spinner = new THREE.Group();
      spinner.add(mesh);
      spinner.position.copy(pos);
      spinner.rotation.y = Math.random() * Math.PI * 2;
      this.scene.add(spinner);
      const a = (i / count) * Math.PI * 2 + Math.random() * 0.5;
      const s = 1.5 + Math.random() * 1.5;
      this.list.push({
        spinner,
        pos: spinner.position,
        vel: new THREE.Vector3(Math.cos(a) * s, 4 + Math.random() * 2, Math.sin(a) * s),
        value: count === 1 ? value : CONFIG.tagBux.coinValue,
        age: 0,
        landed: false,
      });
    }
  }

  clear() {
    for (const c of this.list) this.scene.remove(c.spinner);
    this.list = [];
  }

  // Moves the coins and hands them to whoever touches them first.
  // `pullAll` makes every coin fly to the nearest player (used when the level is cleared).
  // Returns what was collected this frame: [{ player, value, at }]
  update(dt, players, world, pullAll = false) {
    const t = CONFIG.tagBux;
    const collected = [];
    for (let i = this.list.length - 1; i >= 0; i--) {
      const c = this.list[i];
      c.age += dt;
      c.spinner.rotation.y += dt * 4;

      let nearest = null;
      let nearestDist = Infinity;
      for (const p of players) {
        if (p.inShop) continue;
        const d = Math.hypot(p.pos.x - c.pos.x, p.pos.z - c.pos.z);
        if (d < nearestDist) {
          nearest = p;
          nearestDist = d;
        }
      }

      // let it fly out of the zombie for a moment before it can be grabbed
      const ready = c.age > 0.4;
      if (nearest && ready && (pullAll || nearestDist < t.magnetDistance)) {
        const to = new THREE.Vector3(nearest.pos.x - c.pos.x, 1.0 - c.pos.y, nearest.pos.z - c.pos.z);
        const step = Math.min(to.length(), t.magnetSpeed * (pullAll ? 1.6 : 1) * dt);
        c.pos.addScaledVector(to.normalize(), step);
        c.vel.set(0, 0, 0);
        c.landed = true;
      } else if (!c.landed) {
        c.vel.y -= 14 * dt;
        c.pos.addScaledVector(c.vel, dt);
        resolveCollisions(c.pos, 0.3, world); // never land in the pond or a tree
        if (c.pos.y < 0.5) {
          c.pos.y = 0.5;
          c.vel.multiplyScalar(0.4);
          c.vel.y = Math.abs(c.vel.y) > 1 ? -c.vel.y : 0;
          if (c.vel.length() < 0.3) c.landed = true;
        }
      } else {
        c.pos.y = 0.5 + Math.sin(c.age * 3 + i) * 0.08; // gentle bob
      }

      if (nearest && ready && Math.hypot(nearest.pos.x - c.pos.x, nearest.pos.z - c.pos.z) < nearest.radius + t.pickupDistance) {
        nearest.tagBux += c.value;
        collected.push({ player: nearest, value: c.value, at: c.pos.clone() });
        this.scene.remove(c.spinner);
        this.list.splice(i, 1);
      }
    }
    return collected;
  }
}
