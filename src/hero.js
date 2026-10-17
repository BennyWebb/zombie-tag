import * as THREE from 'three';

// A hero's whole body, for the other player to see on their half of the screen.
// (You only see your own hand.) The character creator will dress these up later.

const mat = (color) => new THREE.MeshLambertMaterial({ color });

function nameTag(text, colour) {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 96;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = colour;
  ctx.beginPath();
  ctx.roundRect(8, 8, 240, 80, 40);
  ctx.fill();
  ctx.font = 'bold 56px "Fredoka", "Comic Sans MS", sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText(text, 128, 52);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false }));
  sprite.scale.set(1.2, 0.45, 1);
  sprite.renderOrder = 6;
  return sprite;
}

export function makeHeroBody(look) {
  const root = new THREE.Group();
  const skin = mat(look.skin);
  const outfit = mat(look.outfit);
  const trousers = mat(look.trousers);

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.32, 0.45, 6, 14), outfit);
  torso.position.y = 1.05;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.3, 18, 14), skin);
  head.position.y = 1.68;
  const hair = new THREE.Mesh(new THREE.SphereGeometry(0.32, 18, 14, 0, Math.PI * 2, 0, Math.PI * 0.55), mat(look.hair));
  hair.position.y = 1.7;
  hair.rotation.x = 0.25; // more hair at the back than over the face
  root.add(torso, head, hair);

  const eyeMat = new THREE.MeshBasicMaterial({ color: 0x222222 });
  for (const x of [-0.1, 0.1]) {
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), eyeMat);
    eye.position.set(x, 1.72, -0.27); // the hero faces -z, like the camera
    root.add(eye);
  }
  const smile = new THREE.Mesh(
    new THREE.TorusGeometry(0.08, 0.02, 6, 12, Math.PI),
    new THREE.MeshBasicMaterial({ color: 0x8a2a3a }),
  );
  smile.position.set(0, 1.6, -0.28);
  smile.rotation.z = Math.PI;
  root.add(smile);

  const arms = [];
  for (const x of [-0.42, 0.42]) {
    const arm = new THREE.Group();
    const sleeve = new THREE.Mesh(new THREE.CapsuleGeometry(0.1, 0.4, 4, 8), outfit);
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
  const tag = nameTag(look.label, look.tagColour);
  tag.position.y = 2.3;
  root.add(tag);

  root.traverse((o) => {
    if (o.isMesh) o.castShadow = true;
  });
  return { root, arms, legs };
}
