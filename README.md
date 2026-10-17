# Zombie Tag

A silly, cartoony 3D first-person game invented by Chloe and Naomi.
Bonk goofy zombies, pop them into confetti and Tag Bux, spend your Tag Bux at the shop and get strong at the gym!

The full plan is in [DESIGN.md](DESIGN.md). The game is being built in small steps, play-testing after each one.

## Build steps

- [x] **1. Walk and bonk:** walk around Sunny Park and pop Shufflers into confetti.
- [x] **2. Tag Bux and the shop:** collect coins from popped zombies and buy the Foam Noodle Bat and Water Blaster.
- [x] **3. Hearts:** zombie touches cost hearts, Heart Medicine in the shop, and getting tagged sends you back to the start.
- [x] **4. The gym:** treadmill and weights mini-games that raise Speed and Strength.
- [x] **5. All the weapons and armour:** ten weapons up to the Sparkle Star Laser Gun, and three kinds of armour.
- [x] **6. Two players:** split screen, a second set of keys, separate wallets and giving Tag Bux.
- [x] **7. Character creator and outfits:** type your name, pick your look, and buy cool outfits.
- [x] **8. Levels 1 to 10:** ten places, new zombies, the Zombie King, level select and saving.
- [ ] 9. Polish

## How to play

On the start screen, choose **1 Player** or **2 Players** with W / S (or the arrows) and press Space,
then pick a level.

The first time, each hero is made in the **character creator**: type your name (up to 12 letters)
and press Enter, then pick your skin, hair style, hair colour and clothes colour with W / S and A / D
(Player 2: the arrows) while your hero turns round to show off. Press Space (Player 2: Enter) on
**Done!**. With 2 players, Player 1 goes first. To change your looks later, press **C** on the start screen.
With 2 players the screen splits down the middle: Player 1 on the left, Player 2 on the right.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Walk forward / back | W / S | ↑ / ↓ |
| Turn left / right | A / D | ← / → |
| Attack (hold it down for shooting weapons and the laser) | Space | Enter (or Numpad 0) |
| Shop and gym: choose / go | W / S, then Space | ↑ / ↓, then Enter |
| Treadmill | A, D, A, D… as fast as you can | ←, →, ←, →… |
| Weights | tap Space as fast as you can | tap Enter |
| Pause (then Q to go back to the start screen) | Esc | Esc |
| Level picker: choose / play | W A S D, then Space | arrows, then Enter |

You don't need to aim exactly: your weapon goes for the nearest zombie in front of you.

Popped zombies burst into spinning **Tag Bux** coins. Walk over them to collect them;
your Tag Bux are at the top right. A Shuffler is worth 5, so popping all 8 earns 40.

### Levels

Pop every zombie, then walk through the **glowing exit gate** at the far end of the path (look for the
beam of light) to finish the level. Each level unlocks the next one, and you can play any level you've
reached again from the level picker to earn more Tag Bux. The shop and gym are in a different spot each time.

| Level | Place | Zombies (1 player) | New zombie |
| --- | --- | --- | --- |
| 1 | 🌳 Sunny Park | 8 | Shuffler |
| 2 | 🏫 School and Playground | 10 | |
| 3 | 🛒 Supermarket Car Park | 12 | Speedy Sid: sprints, then stops to pant |
| 4 | 🏖️ Beach and Pier | 14 | |
| 5 | 🎡 Funfair | 16 | Bouncy Bob: hops right over fences and benches |
| 6 | ⛄ Snowy Village | 18 | Big Bertha: huge, and takes 2 hearts |
| 7 | 🧸 Toy Factory | 20 | |
| 8 | 🍄 Haunted Forest | 22 | Slime Zombie: splits into two little Shufflers |
| 9 | 🎃 Graveyard at Night | 25 | |
| 10 | 🏰 Zombie King's Castle | 30 + the King | 👑 The Zombie King: arrives after 20 pops and calls Shufflers to help |

Zombies get tougher on each level, so keep training and upgrading. Beat the Zombie King and all the
zombies become your friends for a big party!

**Saving:** progress saves by itself at the start of each level (and when you leave the shop or gym),
so you can stop and carry on another day. Press **N** on the start screen for a brand new game
(it asks first, because it wipes everything).

### Playing together

Each sister has her own hearts, Tag Bux, weapons, armour and training. Coins go to whoever touches them
first. In the shop you can **🎁 Give 10 Tag Bux** to your sister as many times as you like, and the coins
fly across the screen into her counter. There are 50% more zombies with two players,
and zombies chase whichever hero is nearest. If one of you gets tagged, she's back at the start after
10 seconds while the other keeps playing.

### Hearts

You have **3 hearts** (top left). A zombie touch costs 1 heart, then you blink for 2 seconds and
can't be hurt, so run away! Lose all 3 and you're **TAGGED**: after a 3-second countdown you're back
at the start with 3 hearts, and you keep your Tag Bux and weapons. A zombie that tags you gets
bumped back and goes dizzy (stars round its head) for a moment, so you can get away. Turn round and
run: you're faster than a chasing zombie going forwards, but a bit slower walking backwards.

Look for the **glowing pink shopping bag** above the trees and walk in through the shop door.
Zombies can't get in. In the shop:

| Weapon | Price | Power | What's special |
| --- | --- | --- | --- |
| 🪵 Spiky Stick | Free | 1 | Breaks after 4 hits. Get a free one any time you have no weapon. |
| 🏏 Foam Noodle Bat | 25 | 2 | Never breaks. Bonks zombies back. |
| 💦 Squirty Water Blaster | 60 | ⅓ | Shoots super fast. Pushes zombies away. 3 squirts pop a Shuffler. |
| 🐔 Rubber Chicken Hammer | 120 | 4 | SQUAWK! Bonks every zombie in front of you at once. |
| 🧪 Slime Slinger | 200 | 3 | Green goo makes zombies slow for 3 seconds. |
| 🧼 Bubble Blaster | 350 | 3 | Traps a zombie in a floating bubble for 3 seconds. |
| ❄️ Snowball Cannon | 500 | 5 | Freezes zombies solid for 2 seconds. |
| 🍌 Boomerang Banana | 700 | 6 | Flies out and comes back, hitting zombies both ways. |
| 🎃 Pumpkin Launcher | 1,000 | 10 | Slow, but each pumpkin splats every zombie nearby. |
| 🌟 Sparkle Star Laser Gun | 1,600 | 8 | The best weapon! Hold Space for a sparkly laser with swirling stars. |

Zombies that are bubbled, frozen or dizzy can't tag you.

**Armour** takes hits for you before your hearts do. It shows as blue shields next to your hearts
and fills back up at the start of each level (and when you get tagged). Only your best armour counts.

| Armour | Price | Blocks |
| --- | --- | --- |
| 📦 Cardboard Box Armour | 40 | 1 hit |
| 🏈 Sports Pads and Helmet | 150 | 2 hits |
| 🛡️ Shiny Knight Armour | 600 | 3 hits |

**Cool outfits** are just for looks, and your sister sees them on your hero:
🏴‍☠️ Pirate Hat (40), 🦸 Superhero Cape (50), 🦄 Unicorn Onesie (80), 🩰 Sparkly Dancer Outfit (100),
🧑‍🚀 Astronaut Suit (150) and 👑 Golden Crown (300). You can wear a hat and a cape together; putting on
something that covers the same place takes the other one off. Choose an outfit you're wearing to take it off.

The shop list scrolls: keep pressing S to see everything. It also sells **💊 Heart Medicine** (15 Tag Bux), which gives back 1 heart. Zombies wait outside
the door, so you get 2 safe seconds when you walk back out.

A new weapon goes straight into your hand. You keep every weapon you buy and can swap
which one you hold in the shop. Choose **Leave** to go back outside.
When you play again, you keep your Tag Bux and weapons, so after two clears you can afford the Water Blaster.

## The gym

Look for the **glowing blue dumbbell** above the trees and walk in through the door. Training is free.

- **🏃 Treadmill (Speed):** press A, D, A, D… as fast as you can. Pressing the same key twice doesn't
  count. Fill the bar in 15 seconds for +1 Speed. Each level needs a few more presses.
  Every Speed level makes you 10% faster.
- **🏋️ Weights (Strength):** pick a dumbbell, then tap Space as fast as you can to lift it to the top
  in 10 seconds. It sinks if you stop! Every Strength level makes all your weapons hit 20% harder.

| Dumbbell | Sinks | Gets your Strength up to |
| --- | --- | --- |
| 🔵 Small | slowly | 4 |
| 🟠 Medium | quicker | 7 |
| 🔴 Heavy | very quickly | 10 |

If you don't make it, nothing is lost: just try again. Beat your fastest time for a **PERSONAL BEST!**
Speed and Strength go up to 10, and you keep them when you play again or get tagged.

## Running it on a Windows PC

You only need to do this once: install **Node.js** (the "LTS" version) from <https://nodejs.org>.

Then either:

- **Double-click `start-game.bat`.** The first time, it spends a minute installing; then the game opens in your browser.

or, in a terminal in this folder:

```
npm install
npm run dev
```

The game opens at <http://localhost:5173>. Use Chrome or Edge. Keep the black terminal window open while playing;
close it when you've finished.

## Changing the numbers

Speeds, damage, prices, hearts, gym difficulty, zombies, and each level's zombie count, toughness and mix are all in [`src/config.js`](src/config.js).
Edit a number, save, and the game reloads by itself.
