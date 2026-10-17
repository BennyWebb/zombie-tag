# Zombie Tag

A silly, cartoony 3D first-person game invented by Chloe and Naomi.
Bonk goofy zombies with your Spiky Stick and pop them into confetti!

The full plan is in [DESIGN.md](DESIGN.md). The game is being built in small steps, play-testing after each one.

## Build steps

- [x] **1. Walk and bonk:** walk around Sunny Park and pop Shufflers into confetti.
- [ ] 2. Tag Bux and the shop
- [ ] 3. Hearts
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
| Bonk! | Space |
| Pause | Esc |

You don't need to aim exactly: the stick bonks the nearest zombie in front of you.
The Spiky Stick breaks after 4 hits. Walk back to the barrel with the yellow star
(next to where you start) for a free new one.

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

Speeds, damage, zombie health and level settings are all in [`src/config.js`](src/config.js).
Edit a number, save, and the game reloads by itself.
