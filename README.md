# Zombie Tag

A silly, cartoony 3D first-person game invented by Chloe and Naomi.
Bonk goofy zombies, pop them into confetti and Tag Bux, and spend your Tag Bux at the shop!

The full plan is in [DESIGN.md](DESIGN.md). The game is being built in small steps, play-testing after each one.

## Build steps

- [x] **1. Walk and bonk:** walk around Sunny Park and pop Shufflers into confetti.
- [x] **2. Tag Bux and the shop:** collect coins from popped zombies and buy the Foam Noodle Bat and Water Blaster.
- [x] **3. Hearts:** zombie touches cost hearts, Heart Medicine in the shop, and getting tagged sends you back to the start.
- [ ] 4. The gym
- [ ] 5. All the weapons and armour
- [ ] 6. Two players
- [ ] 7. Character creator and outfits
- [ ] 8. Levels 1 to 10
- [ ] 9. Polish

## How to play

| Action | Keys |
| --- | --- |
| Walk forward / back | W / S |
| Turn left / right | A / D |
| Bonk! (hold it down to keep squirting the Water Blaster) | Space |
| Shop: choose / buy | W / S, then Space |
| Pause | Esc |

You don't need to aim exactly: your weapon goes for the nearest zombie in front of you.

Popped zombies burst into spinning **Tag Bux** coins. Walk over them to collect them;
your Tag Bux are at the top right. A Shuffler is worth 5, so popping all 8 earns 40.

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

The shop also sells **💊 Heart Medicine** (15 Tag Bux), which gives back 1 heart. Zombies wait outside
the door, so you get 2 safe seconds when you walk back out.

A new weapon goes straight into your hand. You keep every weapon you buy and can swap
which one you hold in the shop. Choose **Leave** to go back outside.
When you play again, you keep your Tag Bux and weapons, so after two clears you can afford the Water Blaster.

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

Speeds, damage, prices, hearts, zombie health and level settings are all in [`src/config.js`](src/config.js).
Edit a number, save, and the game reloads by itself.
