// All the game's numbers live here, so balancing is just editing this file.

export const CONFIG = {
  player: {
    eyeHeight: 1.6,
    radius: 0.5,
    // Speed stat 1 is only just faster than a chasing Shuffler; each level adds 10%.
    baseSpeed: 4.0,
    speedPerLevel: 0.1,
    turnSpeed: 2.4, // radians per second
    // Each Strength level adds 20% damage to every weapon.
    strengthPerLevel: 0.2,
    startSpeed: 1,
    startStrength: 1,
    hearts: 3,
    safeTime: 2, // seconds you flash and can't be hurt after a zombie touch
    leaveShopSafeTime: 2, // and after walking out of the shop, in case zombies are waiting
    taggedTime: 3, // seconds of "TAGGED!" before you're back at the start
    touchDistance: 0.3, // how close a zombie gets (past touching skin) to tag you
  },

  // The shop sells these in this order. Damage is before the Strength bonus.
  weapons: {
    spikyStick: {
      name: 'Spiky Stick',
      icon: '🪵',
      about: 'Breaks after 4 hits',
      price: 0, // free whenever you have no weapon
      kind: 'swing',
      damage: 1,
      maxHits: 4, // breaks after this many hits
      range: 3.2, // how far it reaches
      aimAngle: 60, // degrees either side of straight ahead that lock on
      swingTime: 0.35, // seconds
    },
    noodleBat: {
      name: 'Foam Noodle Bat',
      icon: '🏏',
      about: 'Never breaks. Bonks zombies back!',
      price: 25,
      kind: 'swing',
      damage: 2,
      range: 3.4,
      aimAngle: 60,
      swingTime: 0.4,
      knockback: 9, // how hard it bonks zombies back (about 1.5 steps)
    },
    waterBlaster: {
      name: 'Squirty Water Blaster',
      icon: '💦',
      about: 'Shoots super fast. Pushes zombies away!',
      price: 60,
      kind: 'shoot',
      damage: 1 / 3, // play-test: it takes 3 squirts to pop a Shuffler
      range: 14,
      aimAngle: 25,
      fireInterval: 0.13, // seconds between squirts while Space is held
      shotSpeed: 26,
      knockback: 4, // every squirt pushes a bit
    },
  },

  // Other things the shop sells, listed after the weapons.
  items: {
    medicine: {
      name: 'Heart Medicine',
      icon: '💊',
      about: 'Gives back 1 heart',
      price: 15,
      hearts: 1,
    },
  },

  tagBux: {
    coinValue: 1, // each coin is worth this; a zombie drops its tagBux as separate coins
    pickupDistance: 0.7, // walk this close to grab a coin
    magnetDistance: 2.5, // coins fly to you from this close
    magnetSpeed: 12,
  },

  shop: {
    enterDistance: 1.4, // how close to the door you walk to go in
  },

  zombies: {
    shuffler: {
      name: 'Shuffler',
      health: 1,
      wanderSpeed: 0.9,
      chaseSpeed: 3.0, // you walk at 4.0 forwards and 2.8 backwards
      noticeDistance: 15,
      radius: 0.55,
      tagBux: 5,
      touchHearts: 1, // hearts lost when it touches you
      bounceBack: 8, // it gets bumped back after tagging you
      dizzyTime: 2.5, // then it stands still, seeing stars, so you can get away
    },
  },

  levels: [
    {
      name: 'Sunny Park',
      size: 80, // the park is size x size
      zombies: 8,
      healthMultiplier: 1.0,
      waveSize: 3, // zombies arrive a few at a time
      nextWaveWhenLeft: 1, // send the next wave when this many are still standing
      zombieTypes: ['shuffler'],
    },
  ],

  keys: {
    p1: { forward: ['KeyW'], back: ['KeyS'], left: ['KeyA'], right: ['KeyD'], attack: ['Space'] },
    p2: {
      forward: ['ArrowUp'], back: ['ArrowDown'], left: ['ArrowLeft'], right: ['ArrowRight'],
      attack: ['Numpad0', 'Enter', 'NumpadEnter'],
    },
  },
};
