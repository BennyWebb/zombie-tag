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
    taggedTimeTwoPlayers: 10, // with 2 players you wait longer, while your sister carries on
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
      word: 'BONK!', // what pops up when it hits
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
      word: 'SPLOSH!', // what pops up when it hits
      kind: 'shoot',
      damage: 1 / 3, // play-test: it takes 3 squirts to pop a Shuffler
      range: 14,
      aimAngle: 25,
      fireInterval: 0.13, // seconds between squirts while Space is held
      shotSpeed: 26,
      shot: 'water', // what flies out (see weapons.js)
      knockback: 4, // every squirt pushes a bit
    },
    chickenHammer: {
      name: 'Rubber Chicken Hammer',
      icon: '🐔',
      about: 'SQUAWK! Bonks every zombie in front of you',
      price: 120,
      word: 'SQUAWK!', // what pops up when it hits
      kind: 'swing',
      damage: 4,
      range: 3.8,
      aimAngle: 70,
      swingTime: 0.45,
      hitsAll: true, // hits every zombie in reach, not just one
      knockback: 7,
    },
    slimeSlinger: {
      name: 'Slime Slinger',
      icon: '🧪',
      about: 'Green goo makes zombies slow for 3 seconds',
      price: 200,
      word: 'SPLAT!', // what pops up when it hits
      kind: 'shoot',
      damage: 3,
      range: 14,
      aimAngle: 25,
      fireInterval: 0.5,
      shotSpeed: 18,
      shot: 'slime',
      slowTime: 3,
      slowSpeed: 0.35, // slimed zombies move at this much of their speed
    },
    bubbleBlaster: {
      name: 'Bubble Blaster',
      icon: '🧼',
      about: 'Traps a zombie in a floating bubble for 3 seconds',
      price: 350,
      word: 'BLOOP!', // what pops up when it hits
      kind: 'shoot',
      damage: 3,
      range: 13,
      aimAngle: 25,
      fireInterval: 0.6,
      shotSpeed: 12,
      shot: 'bubble',
      bubbleTime: 3,
    },
    snowballCannon: {
      name: 'Snowball Cannon',
      icon: '❄️',
      about: 'Freezes zombies solid for 2 seconds',
      price: 500,
      word: 'BRRR!', // what pops up when it hits
      kind: 'shoot',
      damage: 5,
      range: 15,
      aimAngle: 25,
      fireInterval: 0.7,
      shotSpeed: 20,
      shot: 'snowball',
      freezeTime: 2,
    },
    boomerangBanana: {
      name: 'Boomerang Banana',
      icon: '🍌',
      about: 'Flies out and comes back, hitting zombies both ways',
      price: 700,
      word: 'BONK!', // what pops up when it hits
      kind: 'throw',
      damage: 6,
      range: 12,
      aimAngle: 30,
      shotSpeed: 16,
      shot: 'banana',
    },
    pumpkinLauncher: {
      name: 'Pumpkin Launcher',
      icon: '🎃',
      about: 'Slow, but each pumpkin splats every zombie nearby',
      price: 1000,
      word: 'SPLAT!', // what pops up when it hits
      kind: 'shoot',
      damage: 10,
      range: 16,
      aimAngle: 30,
      fireInterval: 1.4,
      shotSpeed: 14,
      shot: 'pumpkin',
      gravity: 9, // pumpkins fly in an arc
      splashRadius: 4, // every zombie this close to the splat gets hit
    },
    starLaser: {
      name: 'Sparkle Star Laser Gun',
      icon: '🌟',
      about: 'The best weapon! A sparkly laser with swirling stars',
      price: 1600,
      word: 'ZAP!', // what pops up when it hits
      kind: 'beam',
      damage: 8,
      range: 16,
      aimAngle: 20,
      fireInterval: 0.25, // the beam hits this often while Space is held
      starsPerSecond: 40,
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

  // Armour takes hits for you before your hearts do. It refills at the start of each level
  // (and when you get tagged). Only your best armour counts.
  armour: {
    cardboardBox: { name: 'Cardboard Box Armour', icon: '📦', price: 40, blocks: 1 },
    sportsPads: { name: 'Sports Pads and Helmet', icon: '🏈', price: 150, blocks: 2 },
    knightArmour: { name: 'Shiny Knight Armour', icon: '🛡️', price: 600, blocks: 3 },
  },

  // Training is free. Filling the bar raises a stat by 1, up to maxLevel.
  gym: {
    maxLevel: 10,
    upgradesPerLevel: 1, // each place lets you raise Speed and Strength this many times each
    treadmill: {
      time: 15, // seconds to fill the bar
      presses: 20, // good presses (left, right, left...) needed to go from Speed 1 to 2
      morePressesPerLevel: 4, // each level after that needs this many more
      drainAfter: 0.4, // stop pressing for this long and the bar starts to drain
      drainPerSecond: 0.15, // how much of the bar drains each second
    },
    weights: {
      time: 10,
      // rise: how much each tap lifts the bar (1 is the top); sink: how fast it falls each second
      dumbbells: {
        small: { name: 'Small', icon: '🔵', rise: 0.085, sink: 0.08, maxLevel: 4 },
        medium: { name: 'Medium', icon: '🟠', rise: 0.075, sink: 0.16, maxLevel: 7 },
        heavy: { name: 'Heavy', icon: '🔴', rise: 0.065, sink: 0.25, maxLevel: 10 },
      },
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

  // Every zombie has the same touch rules: after tagging you it bounces back and goes dizzy.
  zombies: {
    shuffler: {
      name: 'Shuffler',
      health: 1,
      wanderSpeed: 0.9,
      chaseSpeed: 3.0, // you walk at 4.0 forwards and 2.8 backwards
      noticeDistance: 15,
      radius: 0.55,
      size: 1, // how big it is drawn
      tagBux: 5,
      touchHearts: 1, // hearts lost when it touches you
      bounceBack: 8, // it gets bumped back after tagging you
      dizzyTime: 2.5, // then it stands still, seeing stars, so you can get away
    },
    speedySid: {
      name: 'Speedy Sid',
      health: 2,
      wanderSpeed: 1.4,
      chaseSpeed: 6.0, // faster than you, but only in short bursts
      sprintTime: 1.4, // seconds of sprinting...
      pantTime: 1.6, // ...then he stops to pant
      noticeDistance: 16,
      radius: 0.5,
      size: 0.95,
      tagBux: 10,
      touchHearts: 1,
      bounceBack: 8,
      dizzyTime: 2.5,
    },
    bouncyBob: {
      name: 'Bouncy Bob',
      health: 3,
      wanderSpeed: 1.2,
      chaseSpeed: 3.3,
      hopHeight: 0.9, // he hops like a kangaroo...
      hopsPerSecond: 1.6,
      jumpsSmallThings: true, // ...right over fences, bushes and benches
      noticeDistance: 16,
      radius: 0.55,
      size: 1,
      tagBux: 15,
      touchHearts: 1,
      bounceBack: 8,
      dizzyTime: 2.5,
    },
    bigBertha: {
      name: 'Big Bertha',
      health: 8,
      wanderSpeed: 0.6,
      chaseSpeed: 2.0,
      noticeDistance: 14,
      radius: 1.0,
      size: 1.8,
      tagBux: 25,
      touchHearts: 2, // she's so big she takes 2 hearts
      bounceBack: 5,
      dizzyTime: 2.5,
    },
    slimeZombie: {
      name: 'Slime Zombie',
      health: 4,
      wanderSpeed: 1.0,
      chaseSpeed: 3.2,
      splitsInto: 'smallShuffler', // two of these pop out when it's popped
      noticeDistance: 15,
      radius: 0.6,
      size: 1.05,
      tagBux: 20,
      touchHearts: 1,
      bounceBack: 8,
      dizzyTime: 2.5,
    },
    smallShuffler: {
      name: 'Little Shuffler',
      health: 1,
      wanderSpeed: 1.0,
      chaseSpeed: 3.0,
      noticeDistance: 15,
      radius: 0.4,
      size: 0.65,
      tagBux: 3,
      touchHearts: 1,
      bounceBack: 8,
      dizzyTime: 2.5,
    },
    zombieKing: {
      name: 'Zombie King',
      health: 60,
      wanderSpeed: 0.8,
      chaseSpeed: 2.2,
      noticeDistance: 30,
      radius: 1.2,
      size: 2.2,
      tagBux: 300,
      touchHearts: 2,
      bounceBack: 4,
      dizzyTime: 2.5,
      boss: true,
      callHelpEvery: 10, // seconds between calling in Shufflers to help
      helpers: 2, // how many come each time
      maxHelpers: 6, // never more than this many helpers at once
    },
  },

  // A level: its place and theme (see themes.js), how many zombies and how tough.
  // mix: how often each kind of zombie turns up (bigger number = more of them).
  levels: [
    { name: 'Sunny Park', icon: '🌳', theme: 'park', zombies: 8, healthMultiplier: 1.0, mix: { shuffler: 1 } },
    { name: 'School and Playground', icon: '🏫', theme: 'school', zombies: 10, healthMultiplier: 1.2, mix: { shuffler: 1 } },
    {
      name: 'Supermarket Car Park', icon: '🛒', theme: 'carPark', zombies: 12, healthMultiplier: 1.4,
      mix: { shuffler: 3, speedySid: 2 },
    },
    { name: 'Beach and Pier', icon: '🏖️', theme: 'beach', zombies: 14, healthMultiplier: 1.7, mix: { shuffler: 3, speedySid: 2 } },
    {
      name: 'Funfair', icon: '🎡', theme: 'funfair', zombies: 16, healthMultiplier: 2.0,
      mix: { shuffler: 3, speedySid: 2, bouncyBob: 2 },
    },
    {
      name: 'Snowy Village', icon: '⛄', theme: 'snow', zombies: 18, healthMultiplier: 2.4,
      mix: { shuffler: 3, speedySid: 2, bouncyBob: 2, bigBertha: 1 },
    },
    {
      name: 'Toy Factory', icon: '🧸', theme: 'toys', zombies: 20, healthMultiplier: 2.8,
      mix: { shuffler: 3, speedySid: 2, bouncyBob: 2, bigBertha: 1 },
    },
    {
      name: 'Haunted Forest', icon: '🍄', theme: 'forest', zombies: 22, healthMultiplier: 3.3,
      mix: { shuffler: 2, speedySid: 2, bouncyBob: 2, bigBertha: 1, slimeZombie: 2 },
    },
    {
      name: 'Graveyard at Night', icon: '🎃', theme: 'graveyard', zombies: 25, healthMultiplier: 3.8,
      mix: { shuffler: 2, speedySid: 2, bouncyBob: 2, bigBertha: 1, slimeZombie: 2 },
    },
    {
      name: 'Zombie King\'s Castle', icon: '🏰', theme: 'castle', zombies: 30, healthMultiplier: 4.5,
      mix: { shuffler: 2, speedySid: 2, bouncyBob: 2, bigBertha: 1, slimeZombie: 2 },
      boss: 'zombieKing', // the King arrives for the final battle once every other zombie is popped
    },
  ],

  // Chosen before picking a level. Easy is how the game started out.
  // loseItems: getting tagged takes your weapons and armour (you get a new Spiky Stick).
  // oneLife: getting tagged is game over: weapons, armour and Tag Bux are all gone.
  // king: changes to the Zombie King (health is before the level's healthMultiplier).
  difficulties: {
    easy: { name: 'Easy', icon: '🙂', about: 'Get tagged and you keep everything' },
    hard: {
      name: 'Hard', icon: '😬', about: 'Get tagged and you lose your weapons and armour',
      loseItems: true,
      king: { health: 100, chaseSpeed: 3.3, wanderSpeed: 1.4, instantTag: true },
    },
    hardcore: {
      name: 'Hardcore', icon: '💀', about: 'Only 1 life! Get tagged and you lose your weapons, armour and Tag Bux',
      loseItems: true,
      oneLife: true,
      king: { health: 100, chaseSpeed: 3.3, wanderSpeed: 1.4, instantTag: true },
    },
  },

  maxProfiles: 8, // heroes that can be saved on the "Who's playing?" screen

  // Starting volumes (0 to 10); they can be changed in the pause menu.
  sound: { music: 6, sounds: 8 },

  // The same for every level.
  arena: {
    size: 80, // each level is size x size
    waveSize: 4, // zombies arrive a few at a time
    nextWaveWhenLeft: 1, // send the next wave when this many are still standing
    spawnAway: 22, // zombies never appear closer than this to a hero
  },

  // How each hero starts out, before the character creator.
  heroes: [
    {
      name: 'Player 1', skin: 0xf1c27d, hairStyle: 'ponytail', hair: 0x6b3a1a, outfit: 0xff6fae,
      trousers: 0x5a4a8a, tagColour: '#ff4f8b',
    },
    {
      name: 'Player 2', skin: 0xe0ac69, hairStyle: 'pigtails', hair: 0x2a1a10, outfit: 0x4fc3f7,
      trousers: 0x3a5a8a, tagColour: '#1e6fd6',
    },
  ],

  // The big picture buttons in the character creator.
  creator: {
    maxNameLength: 12,
    skins: [0xffdbc4, 0xf1c27d, 0xe0ac69, 0xc68642, 0x8d5524, 0x5c3a21],
    hairStyles: [
      { id: 'short', name: 'Short' },
      { id: 'long', name: 'Long' },
      { id: 'ponytail', name: 'Ponytail' },
      { id: 'pigtails', name: 'Pigtails' },
      { id: 'bun', name: 'Bun' },
      { id: 'curly', name: 'Curly' },
    ],
    hairColours: [0x2a1a10, 0x6b3a1a, 0xc68a3a, 0xf3d36b, 0xd2552b, 0xff6fae, 0x8e5bd6, 0x4fc3f7],
    outfitColours: [0xff6fae, 0x4fc3f7, 0x8e5bd6, 0x4caf50, 0xffd23f, 0xff8a3d, 0xe53935, 0xffffff],
  },

  // Cool outfits: just for looks, no powers. Wearing one takes off anything in the same place.
  outfits: {
    pirateHat: { name: 'Pirate Hat', icon: '🏴‍☠️', price: 40, covers: ['head'] },
    superheroCape: { name: 'Superhero Cape', icon: '🦸', price: 50, covers: ['back'] },
    unicornOnesie: { name: 'Unicorn Onesie', icon: '🦄', price: 80, covers: ['body', 'head'] },
    dancerOutfit: { name: 'Sparkly Dancer Outfit', icon: '🩰', price: 100, covers: ['body'] },
    astronautSuit: { name: 'Astronaut Suit', icon: '🧑‍🚀', price: 150, covers: ['body', 'head', 'back'] },
    goldenCrown: { name: 'Golden Crown', icon: '👑', price: 300, covers: ['head'] },
  },
  twoPlayerZombies: 1.5, // 50% more zombies with 2 players, so you both earn enough Tag Bux
  giveTagBux: 10, // how many Tag Bux "Give" in the shop hands to your sister

  keys: {
    p1: { forward: ['KeyW'], back: ['KeyS'], left: ['KeyA'], right: ['KeyD'], attack: ['Space'] },
    p2: {
      forward: ['ArrowUp'], back: ['ArrowDown'], left: ['ArrowLeft'], right: ['ArrowRight'],
      attack: ['Enter', 'Numpad0', 'NumpadEnter'], // Enter for laptops without a number pad
    },
  },
};
