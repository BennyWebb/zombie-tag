import * as THREE from 'three';

// A hero's whole body, for the other player to see on their half of the screen
// and for the character creator's preview. (In the game you only see your own hand.)

const mat = (color, extra = {}) => new THREE.MeshLambertMaterial({ color, ...extra });

function nameTag(text, colour) {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 96;
  const ctx = canvas.getContext('2d');
  ctx.font = 'bold 56px "Fredoka", "Comic Sans MS", sans-serif';
  const w = Math.min(496, ctx.measureText(text).width + 60);
  ctx.fillStyle = colour;
  ctx.beginPath();
  ctx.roundRect(256 - w / 2, 8, w, 80, 40);
  ctx.fill();
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText(text, 256, 52, 470);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false }));
  sprite.scale.set(2.4, 0.45, 1);
  sprite.renderOrder = 6;
  return sprite;
}

// The colour of your clothes: your favourite colour, unless an outfit covers your body.
export function clothesColour(look, wearing) {
  if (wearing.includes('unicornOnesie')) return 0xffffff;
  if (wearing.includes('dancerOutfit')) return 0xd36bff;
  if (wearing.includes('astronautSuit')) return 0xf2f2f2;
  return look.outfit;
}

function addHair(head, style, colour) {
  const hair = mat(colour);
  const cap = new THREE.Mesh(new THREE.SphereGeometry(0.32, 18, 14, 0, Math.PI * 2, 0, Math.PI * 0.55), hair);
  cap.position.y = 0.02;
  cap.rotation.x = 0.25; // more hair at the back than over the face
  head.add(cap);
  const add = (geo, x, y, z) => {
    const m = new THREE.Mesh(geo, hair);
    m.position.set(x, y, z);
    head.add(m);
    return m;
  };
  if (style === 'long') {
    add(new THREE.BoxGeometry(0.58, 0.55, 0.16), 0, -0.2, 0.2);
  } else if (style === 'ponytail') {
    add(new THREE.SphereGeometry(0.1, 10, 8), 0, 0.1, 0.32);
    add(new THREE.CapsuleGeometry(0.08, 0.3, 4, 8), 0, -0.12, 0.38).rotation.x = 0.3;
  } else if (style === 'pigtails') {
    for (const x of [-0.32, 0.32]) {
      add(new THREE.CapsuleGeometry(0.08, 0.25, 4, 8), x, -0.12, 0.08).rotation.z = x > 0 ? -0.3 : 0.3;
    }
  } else if (style === 'bun') {
    add(new THREE.SphereGeometry(0.14, 12, 10), 0, 0.3, 0.12);
  } else if (style === 'curly') {
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      add(new THREE.SphereGeometry(0.1, 8, 6), Math.cos(a) * 0.3, 0.05 + Math.sin(i * 1.7) * 0.06, Math.sin(a) * 0.3 + 0.04);
    }
  }
}

// The outfits from the shop, added on top.
function addOutfits(parts, wearing) {
  const { root, head, torso } = parts;
  if (wearing.includes('superheroCape')) {
    const cape = new THREE.Mesh(new THREE.BoxGeometry(0.75, 1.1, 0.04), mat(0xe53935, { side: THREE.DoubleSide }));
    cape.position.set(0, 0.95, 0.36);
    cape.rotation.x = -0.12;
    root.add(cape);
    parts.cape = cape;
  }
  if (wearing.includes('pirateHat')) {
    const black = mat(0x222222);
    const brim = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.05, 20), black);
    brim.position.y = 0.22;
    brim.scale.z = 0.7;
    const top = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.3, 0.25, 16), black);
    top.position.y = 0.35;
    const skull = new THREE.Mesh(new THREE.CircleGeometry(0.07, 12), new THREE.MeshBasicMaterial({ color: 0xffffff }));
    skull.position.set(0, 0.36, -0.27);
    skull.rotation.y = Math.PI;
    head.add(brim, top, skull);
  }
  if (wearing.includes('goldenCrown')) {
    const gold = mat(0xffd23f, { emissive: 0x664400 });
    const band = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.12, 16, 1, true), gold);
    band.position.y = 0.3;
    head.add(band);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      const spike = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.14, 6), gold);
      spike.position.set(Math.cos(a) * 0.23, 0.42, Math.sin(a) * 0.23);
      head.add(spike);
    }
    const gem = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), mat(0xe53935, { emissive: 0x550000 }));
    gem.position.set(0, 0.3, -0.24);
    head.add(gem);
  }
  if (wearing.includes('unicornOnesie')) {
    const hood = new THREE.Mesh(
      new THREE.SphereGeometry(0.35, 18, 14, 0, Math.PI * 2, 0, Math.PI * 0.6),
      mat(0xffffff),
    );
    hood.rotation.x = 0.5;
    head.add(hood);
    const horn = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.3, 10), mat(0xffd23f, { emissive: 0x553300 }));
    horn.position.set(0, 0.38, -0.12);
    horn.rotation.x = -0.4;
    head.add(horn);
    for (const x of [-0.18, 0.18]) {
      const ear = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.14, 6), mat(0xff9ed2));
      ear.position.set(x, 0.32, 0.05);
      head.add(ear);
    }
    // a rainbow mane down the back
    const rainbow = [0xff6fae, 0xffd23f, 0x7dff4f, 0x4fc3f7, 0xb28dff];
    rainbow.forEach((c, i) => {
      const tuft = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 6), mat(c));
      tuft.position.set(0, 0.25 - i * 0.12, 0.3 + i * 0.02);
      head.add(tuft);
    });
  }
  if (wearing.includes('dancerOutfit')) {
    const tutu = new THREE.Mesh(
      new THREE.CylinderGeometry(0.3, 0.55, 0.2, 20, 1, true),
      mat(0xff9ed2, { side: THREE.DoubleSide, emissive: 0x401030 }),
    );
    tutu.position.y = 0.72;
    root.add(tutu);
    // sparkles all over
    const sparkle = new THREE.MeshBasicMaterial({ color: 0xffffff });
    for (let i = 0; i < 14; i++) {
      const s = new THREE.Mesh(new THREE.OctahedronGeometry(0.035), sparkle);
      const a = i * 2.3;
      s.position.set(Math.cos(a) * 0.33, -0.2 + (i % 5) * 0.12, Math.sin(a) * 0.33);
      torso.add(s);
    }
  }
  if (wearing.includes('astronautSuit')) {
    const helmet = new THREE.Mesh(
      new THREE.SphereGeometry(0.42, 20, 16),
      new THREE.MeshLambertMaterial({ color: 0xbfeaff, transparent: true, opacity: 0.35, depthWrite: false }),
    );
    head.add(helmet);
    const pack = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.6, 0.25), mat(0xdddddd));
    pack.position.set(0, 1.1, 0.42);
    root.add(pack);
    const badge = new THREE.Mesh(new THREE.CircleGeometry(0.07, 12), new THREE.MeshBasicMaterial({ color: 0x1e6fd6 }));
    badge.position.set(-0.13, 0.15, -0.33);
    badge.rotation.y = Math.PI;
    torso.add(badge);
  }
}

// look: { name, skin, hairStyle, hair, outfit, trousers, tagColour }; wearing: outfit ids.
export function makeHeroBody(look, wearing = []) {
  const root = new THREE.Group();
  const skin = mat(look.skin);
  const clothes = mat(clothesColour(look, wearing));
  const covered = wearing.includes('unicornOnesie') || wearing.includes('astronautSuit');
  const trousers = covered ? clothes : mat(look.trousers);

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.32, 0.45, 6, 14), clothes);
  torso.position.y = 1.05;
  root.add(torso);

  const head = new THREE.Group(); // the face looks along -z, like the camera
  head.position.y = 1.68;
  root.add(head);
  head.add(new THREE.Mesh(new THREE.SphereGeometry(0.3, 18, 14), skin));
  if (!wearing.includes('unicornOnesie')) addHair(head, look.hairStyle, look.hair);
  const eyeMat = new THREE.MeshBasicMaterial({ color: 0x222222 });
  for (const x of [-0.1, 0.1]) {
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), eyeMat);
    eye.position.set(x, 0.04, -0.27);
    head.add(eye);
  }
  const smile = new THREE.Mesh(
    new THREE.TorusGeometry(0.08, 0.02, 6, 12, Math.PI),
    new THREE.MeshBasicMaterial({ color: 0x8a2a3a }),
  );
  smile.position.set(0, -0.06, -0.28);
  smile.rotation.z = Math.PI;
  head.add(smile);

  const arms = [];
  for (const x of [-0.42, 0.42]) {
    const arm = new THREE.Group();
    const sleeve = new THREE.Mesh(new THREE.CapsuleGeometry(0.1, 0.4, 4, 8), clothes);
    sleeve.position.y = -0.25;
    const hand = new THREE.Mesh(new THREE.SphereGeometry(0.09, 10, 8), skin);
    hand.position.y = -0.55;
    arm.add(sleeve, hand);
    arm.position.set(x, 1.35, 0);
    root.add(arm);
    arms.push(arm);
  }
  const legs = [];
  for (const x of [-0.15, 0.15]) {
    const leg = new THREE.Group();
    const m = new THREE.Mesh(new THREE.CapsuleGeometry(0.12, 0.4, 4, 8), trousers);
    m.position.y = -0.3;
    leg.add(m);
    leg.position.set(x, 0.62, 0);
    root.add(leg);
    legs.push(leg);
  }
  const parts = { root, head, torso, arms, legs };
  addOutfits(parts, wearing);

  const tag = nameTag(look.name, look.tagColour);
  tag.position.y = 2.45;
  root.add(tag);

  root.traverse((o) => {
    if (o.isMesh) o.castShadow = true;
  });
  return parts;
}
