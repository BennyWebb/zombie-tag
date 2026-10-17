import * as THREE from 'three';

const CONFETTI_COLOURS = [0xff4f8b, 0xffe066, 0x4fc3f7, 0x9cff57, 0xb28dff, 0xff8a3d];
const confettiGeo = new THREE.PlaneGeometry(0.14, 0.09);
const confettiMats = CONFETTI_COLOURS.map(
  (c) => new THREE.MeshBasicMaterial({ color: c, side: THREE.DoubleSide }),
);

// one material per colour, shared by every splash
const splashMats = new Map();
function splashMat(colour) {
  if (!splashMats.has(colour)) {
    splashMats.set(colour, new THREE.MeshBasicMaterial({ color: colour, side: THREE.DoubleSide }));
  }
  return splashMats.get(colour);
}

const textTextures = new Map();
function textTexture(text, colour) {
  const key = text + colour;
  if (!textTextures.has(key)) {
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 128;
    const ctx = canvas.getContext('2d');
    // shrink long words so they fit
    let px = 84;
    do {
      ctx.font = `bold ${px}px "Fredoka", "Comic Sans MS", sans-serif`;
      px -= 4;
    } while (ctx.measureText(text).width > 230 && px > 30);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = 14;
    ctx.strokeStyle = '#4b1e8a';
    ctx.strokeText(text, 128, 64);
    ctx.fillStyle = colour;
    ctx.fillText(text, 128, 64);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    textTextures.set(key, tex);
  }
  return textTextures.get(key);
}

export class Effects {
  constructor(scene) {
    this.scene = scene;
    this.bits = [];
    this.texts = [];
  }

  confetti(pos, count = 70) {
    for (let i = 0; i < count; i++) {
      const m = new THREE.Mesh(confettiGeo, confettiMats[i % confettiMats.length]);
      m.position.copy(pos);
      m.rotation.set(Math.random() * 6, Math.random() * 6, Math.random() * 6);
      const a = Math.random() * Math.PI * 2;
      const s = 2 + Math.random() * 4;
      this.scene.add(m);
      this.bits.push({
        mesh: m,
        vel: new THREE.Vector3(Math.cos(a) * s, 3 + Math.random() * 5, Math.sin(a) * s),
        spin: new THREE.Vector3(Math.random() * 10, Math.random() * 10, Math.random() * 10),
        life: 1.6 + Math.random() * 0.8,
      });
    }
  }

  // a little burst of drops (water, goo, snow, pumpkin...) where a shot lands
  splash(pos, count = 12, colours = [0x4fc3f7, 0xbfeaff, 0xffffff], power = 1) {
    for (let i = 0; i < count; i++) {
      const m = new THREE.Mesh(confettiGeo, splashMat(colours[i % colours.length]));
      m.position.copy(pos);
      m.scale.setScalar(power);
      const a = Math.random() * Math.PI * 2;
      const s = (1 + Math.random() * 2) * power;
      this.scene.add(m);
      this.bits.push({
        mesh: m,
        vel: new THREE.Vector3(Math.cos(a) * s, (1 + Math.random() * 3) * power, Math.sin(a) * s),
        spin: new THREE.Vector3(Math.random() * 10, Math.random() * 10, 0),
        life: (0.4 + Math.random() * 0.3) * power,
      });
    }
  }

  floatText(pos, text, colour = '#ffe066', size = 1.6) {
    const sprite = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: textTexture(text, colour), transparent: true, depthTest: false }),
    );
    sprite.scale.set(size, size / 2, 1);
    sprite.position.copy(pos);
    sprite.renderOrder = 10;
    this.scene.add(sprite);
    this.texts.push({ sprite, life: 1, size });
  }

  update(dt) {
    for (let i = this.bits.length - 1; i >= 0; i--) {
      const b = this.bits[i];
      b.life -= dt;
      b.vel.y -= 9 * dt;
      b.vel.multiplyScalar(1 - 1.5 * dt); // air drag so it flutters
      b.mesh.position.addScaledVector(b.vel, dt);
      if (b.mesh.position.y < 0.03) {
        b.mesh.position.y = 0.03;
        b.vel.set(0, 0, 0);
        b.spin.set(0, 0, 0);
      }
      b.mesh.rotation.x += b.spin.x * dt;
      b.mesh.rotation.y += b.spin.y * dt;
      b.mesh.rotation.z += b.spin.z * dt;
      if (b.life <= 0) {
        this.scene.remove(b.mesh);
        this.bits.splice(i, 1);
      }
    }
    for (let i = this.texts.length - 1; i >= 0; i--) {
      const t = this.texts[i];
      t.life -= dt;
      t.sprite.position.y += 1.5 * dt;
      const grow = 1 + (1 - t.life) * 0.5;
      t.sprite.scale.set(t.size * grow, (t.size / 2) * grow, 1);
      t.sprite.material.opacity = Math.min(1, t.life * 2);
      if (t.life <= 0) {
        this.scene.remove(t.sprite);
        t.sprite.material.dispose();
        this.texts.splice(i, 1);
      }
    }
  }
}
