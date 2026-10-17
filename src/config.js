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
  },

  weapons: {
    spikyStick: {
      name: 'Spiky Stick',
      damage: 1,
      maxHits: 4, // breaks after this many hits
      range: 3.2, // how far it reaches
      aimAngle: 60, // degrees either side of straight ahead that lock on
      swingTime: 0.35, // seconds
    },
  },

  zombies: {
    shuffler: {
      name: 'Shuffler',
      health: 1,
      wanderSpeed: 0.9,
      chaseSpeed: 3.4,
      noticeDistance: 15,
      radius: 0.55,
      tagBux: 5, // used from build step 2
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
