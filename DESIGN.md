# Zombie Tag – Game Design Document

Idea by Chloe Rose · Oct 17, 2026 · @Benjamin Webb

## Overview

Zombie Tag is a cartoony 3D first-person game for 1 or 2 players on one keyboard. You start slow and weak with nothing but a free spiky stick. You beat zombies, collect the Tag Bux they explode into, train at the gym and buy better weapons, until you are strong enough to take on all 10 levels.

**The game loop:** explore the level, find the shop and the gym, defeat zombies, collect Tag Bux, spend them and train, clear the level, then move on to a harder one.

&#91;embedded content: the Zombie Tag game loop\]

**Design pillars**

- **Silly, not scary.** Zombies are goofy cartoons that pop into Tag Bux and confetti. No blood, nothing a 7-year-old would find frightening.
- **You can feel yourself getting stronger.** Every gym session and every new weapon makes a noticeable difference straight away.
- **Better together.** Chloe and Naomi play side by side on a split screen, each with their own hero, weapons and Tag Bux.
- **Easy to pick up.** Few keys, big readable screens, generous aiming, and losing never feels harsh.

**Platform:** a web browser game on a Windows PC or laptop, keyboard controls. Built with Claude Code.

Items marked *(suggestion)* are Claude's ideas to fill gaps. Chloe gets the final say on all of them.

## Players and controls

Each player makes their own hero, and two players share one keyboard on a split screen.

**Character creator** (at the start of a new game)

- Type a name (up to 12 letters).
- Pick skin colour, hair style, hair colour and starting outfit colour from big picture buttons.
- In 2-player mode, Player 1 creates first, then Player 2.
- Outfits bought later in the shop are worn on top. You see your own hands and weapon in first person; you see your sister's whole hero on her side of the screen.

**Screen layout**

- 1 player: full screen.
- 2 players: the screen splits down the middle. Player 1 on the left, Player 2 on the right. Each half has its own hearts, Tag Bux and weapon display.

**Keys**

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Walk forward / back | W / S | Up / Down arrow |
| Turn left / right | A / D | Left / Right arrow |
| Attack (swing or fire) | Space | Numpad 0 |
| Treadmill (alternate fast) | A then D, A then D… | Left then Right… |
| Lift weights (tap fast) | Space | Numpad 0 |
| Shop menu: choose / buy | W / S, then Space | Up / Down, then Numpad 0 |
| Pause | Esc | Esc |

- There is no mouse, so A/D and the left/right arrows **turn** the hero rather than step sideways. This is easier for young players.
- You enter the shop or gym by walking through its door; walking out of the menu's "Leave" option puts you back outside. No extra keys needed.
- **Aim help:** attacks lock on to the nearest zombie roughly in front of you, so no precise aiming is needed.
- Many laptops have no number pad. Player 2 can also use **Enter** to attack.
- Some laptop keyboards can't register lots of keys at once. Test early with both girls mashing keys together; a cheap USB keyboard often fixes it.

## Stats, hearts and Tag Bux

Every hero has two trainable stats, three hearts and their own Tag Bux wallet.

| Stat | Starts at | Max | What it does |
| --- | --- | --- | --- |
| Speed | 1 | 10 | Walking speed. Level 1 is only just faster than the slowest zombie; level 10 outruns everything. Each level adds about 10%. |
| Strength | 1 | 10 | Damage of every weapon. Each level adds 20% (level 10 hits almost 3 times as hard). |
| Hearts | 3 | 3 | Lose one each time a zombie touches you. |
| Tag Bux | 0 | no limit | Money for the shop. Kept between levels. |

**Hearts**

- A zombie touch costs 1 heart, then you flash and can't be hurt for 2 seconds, so you can escape.
- Medicine from the shop gives back 1 heart (never more than 3).
- Armour takes hits for you before your hearts do (see the shop).
- **Losing all 3 hearts**: you are "tagged" and go back to the level start with 3 hearts, keeping your Tag Bux, weapons and training. In 2-player mode you come back after a 10-second countdown. Nothing is ever lost for good.

**Tag Bux**

- Beaten zombies explode into spinning Tag Bux coins. Walk over them to collect.
- In 2-player mode, whoever touches the coins first gets them, and each player has their own wallet.
  - Sisters can give each other Tag Bux. In the shop menu, choose "Give 10 Tag Bux to \[sister's name\]" as many times as you like, and the coins fly across to her wallet.
- Bigger, tougher zombies drop more (see Zombies).

**Saving:** progress saves automatically at the start of each level, so the girls can stop and carry on another day.

## The gym

The gym is a safe building (zombies can't get in) with a treadmill for Speed and a weights bench for Strength. Training is free but takes effort. Each finished session that fills the bar raises the stat by 1.

**Treadmill (Speed)**

1. Step onto the treadmill. Your hero starts jogging on screen.
2. Press the two keys one after the other, as fast as you can: A, D, A, D (Player 2: Left, Right, Left, Right). Pressing the same key twice doesn't count.
3. A power bar fills with each good press and slowly drains if you stop. The faster you go, the faster your hero runs on screen.
4. Fill the bar within 15 seconds to gain +1 Speed. Each new level needs a few more presses than the last.

**Weights (Strength)**

1. Choose a weight: Small, Medium or Heavy dumbbell.
2. Tap Space (Player 2: Numpad 0) as fast as you can to lift it. The bar rises with each tap and sinks when you stop.
3. Heavier weights sink faster, so you must tap faster, but give a bigger reward.
4. Get the bar to the top before the 10-second timer ends.

| Weight | How fast it sinks | Reward |
| --- | --- | --- |
| Small | Slowly | +1 Strength, but only up to level 4 |
| Medium | Quicker | +1 Strength, up to level 7 |
| Heavy | Very quickly | +1 Strength, up to level 10 |

- A failed attempt costs nothing. You just try again.
- Fun touches *(suggestion)*: sweat drops, a "PERSONAL BEST!" banner, and your hero flexing when a stat goes up.
- In 2-player mode each sister trains on her own half of the screen, so one can train while the other fights.

## The shop

The shop is a safe building where you claim your free Spiky Stick and spend Tag Bux on weapons, medicine, armour and outfits. You keep every weapon you buy; your newest one is held automatically, and you can swap which one you hold at the shop or start of the level. No weapon ever runs out of ammo.

**Weapons** (cheapest first; damage is before the Strength bonus)

| Weapon | Price (Tag Bux) | Damage | Type | Special |
| --- | --- | --- | --- | --- |
| Spiky Stick | Free | 1 | Swing | Breaks after 4 hits. You can claim another free one whenever you have no weapon *(suggestion)*. |
| Foam Noodle Bat *(suggestion)* | 25 | 2 | Swing | Never breaks. Bonks zombies back a little. |
| Squirty Water Blaster *(suggestion)* | 60 | ⅓ | Shoots | Fires very fast. Pushes zombies away. 3 squirts pop a Shuffler (changed after play-testing). |
| Rubber Chicken Hammer *(suggestion)* | 120 | 4 | Swing | Squawks on every hit and bonks every zombie in front of you. |
| Slime Slinger *(suggestion)* | 200 | 3 | Shoots | Green goo makes zombies slow for 3 seconds. |
| Bubble Blaster *(suggestion)* | 350 | 3 | Shoots | Traps a zombie in a floating bubble for 3 seconds. |
| Snowball Cannon *(suggestion)* | 500 | 5 | Shoots | Freezes zombies solid for 2 seconds. |
| Boomerang Banana *(suggestion)* | 700 | 6 | Throws | Flies out and comes back, hitting zombies both ways. |
| Pumpkin Launcher *(suggestion)* | 1,000 | 10 | Shoots | Slow, but each pumpkin splats every zombie nearby. |
| Sparkle Star Laser Gun | 1,600 | 8 | Beam | The best weapon. Rapid pretty laser with star particles swirling around it. |

**Medicine and armour**

| Item | Price (Tag Bux) | What it does |
| --- | --- | --- |
| Heart Medicine | 15 | Gives back 1 heart. |
| Cardboard Box Armour *(suggestion)* | 40 | Blocks 1 hit per level. |
| Sports Pads and Helmet *(suggestion)* | 150 | Blocks 2 hits per level. |
| Shiny Knight Armour *(suggestion)* | 600 | Blocks 3 hits per level. |

Armour shows as blue shields next to your hearts and refills at the start of each level *(suggestion)*. Only your best armour counts.

**Cool outfits** (just for looks, no powers) *(suggestion)*: Superhero Cape (50), Pirate Hat (40), Unicorn Onesie (80), Sparkly Dancer Outfit (100), Astronaut Suit (150), Golden Crown (300).

## Zombies

Zombies are goofy, colourful cartoons that wander towards the nearest hero and explode into Tag Bux and confetti with a funny "POP!" when beaten. New kinds appear as the levels go on *(all names are suggestions)*.

| Zombie | First level | Health (level 1 strength) | Speed | Tag Bux | What's special |
| --- | --- | --- | --- | --- | --- |
| Shuffler | 1 | 1 | Slow | 5 | Arms out, groans, wobbles about. |
| Speedy Sid | 3 | 2 | Fast | 10 | Sprints in short bursts, then stops to pant. |
| Bouncy Bob | 5 | 3 | Medium | 15 | Hops like a kangaroo. Can jump over small fences. |
| Big Bertha | 6 | 8 | Very slow | 25 | Huge and tough. Takes 2 hearts per touch. |
| Slime Zombie | 8 | 4 | Medium | 20 | Splits into two small Shufflers when popped. |
| Zombie King (boss) | 10 | 60 | Slow | 300 | Wears a wonky crown and calls in Shufflers to help. |

**How zombies behave**

- They wander slowly until a hero comes close, then chase.
- They can't go into the shop or the gym. They wait outside the door, so heroes can't just hide there forever.
- Getting hit makes a zombie flash white and wobble so it's easy to see you landed a hit.
- A health bar floats over any zombie that has been hit.
- Each level makes zombies tougher using a health multiplier (see Levels), so you need to keep training and upgrading.

## Levels

There are 10 levels, each a new place with more and tougher zombies. Pop every zombie to open the exit gate to the next level.

| Level | Place | Zombies (1 player) | Zombie health × | New zombie |
| --- | --- | --- | --- | --- |
| 1 | Sunny Park | 8 | 1.0 | Shuffler |
| 2 | School and playground | 10 | 1.2 |  |
| 3 | Supermarket car park *(suggestion)* | 12 | 1.4 | Speedy Sid |
| 4 | Beach and pier *(suggestion)* | 14 | 1.7 |  |
| 5 | Funfair *(suggestion)* | 16 | 2.0 | Bouncy Bob |
| 6 | Snowy village *(suggestion)* | 18 | 2.4 | Big Bertha |
| 7 | Toy factory *(suggestion)* | 20 | 2.8 |  |
| 8 | Haunted forest *(suggestion)* | 22 | 3.3 | Slime Zombie |
| 9 | Graveyard at night | 25 | 3.8 |  |
| 10 | Zombie King's castle *(suggestion)* | 30 + boss | 4.5 | Zombie King |

**How a level works**

- Each level is a walled-in area, about the size of a big park, with paths, trees, buildings and props that fit the theme.
- The shop and the gym are placed at a random spot each time you play, picked from 4 to 6 set spots per level. They are never right next to the start or next to each other.
- Both buildings have a tall, glowing sign (a shopping bag and a dumbbell) that you can see over the rooftops, so they are fun to find without getting lost.
- Zombies arrive a few at a time in waves, not all at once.
- A counter shows how many zombies are left. When it reaches zero, a sparkly exit gate opens.
- In 2-player mode there are 50% more zombies, so both sisters earn enough Tag Bux *(suggestion)*.
- Finished levels can be replayed from the level menu to earn extra Tag Bux *(suggestion)*.

**Balance check:** a player who clears every level once earns roughly 2,000 Tag Bux, enough to afford the Sparkle Star Laser Gun around level 8 or 9. These numbers are a starting point to tune after the girls play-test.

## Art, sound and screen display

The game looks like a bright, chunky cartoon toy world, seen through the hero's eyes.

**Look**

- Simple rounded 3D shapes, bold colours, soft shadows. Each level has its own colour mood (green park, golden beach, purple graveyard).
- Zombies are green or blue with big googly eyes and silly expressions.
- Effects: confetti and coin bursts when a zombie pops, a sparkly trail on the laser gun, stars when a stat goes up.
- For the prototype, everything can be built from basic 3D shapes in code, so no art files are needed to start. Better models can be added later.

**Sound** *(suggestion)*

- Cheerful "boing", "pop" and "ka-ching" sounds for hits, zombies popping and collecting Tag Bux.
- Silly zombie groans, a squawk for the Rubber Chicken Hammer, a "pew pew" for the laser.
- Upbeat background music, a little spookier in the graveyard and castle. Volume control in the pause menu.

**On-screen display** (one set per player)

- Top left: hearts (red) and armour shields (blue).
- Top right: Tag Bux counter with a coin icon.
- Bottom: the weapon you're holding, with "hits left" for the Spiky Stick.
- Small badges: Speed and Strength levels.
- Top middle: zombies left in this level.

**Menus:** title screen (1 Player / 2 Players / Continue), character creator, level select, pause (resume, volume, quit). Big buttons and large text throughout, since Naomi is 7.

## Technical plan and build steps

Build it as a browser game with JavaScript and Three.js, in small steps that the girls can play-test after each one.

**Technology**

- **Three.js** for the 3D world, run locally with **Vite** (`npm run dev`, then open the page in Chrome or Edge).
- **Split screen:** one shared world drawn twice per frame by two cameras, each into its own half of the window.
- **Keyboard:** track which keys are down using `event.code` (`KeyW`, `ArrowUp`, `Space`, `Numpad0`, `Enter`) so both players' keys work at the same time.
- **All numbers in one file** (`config.js`): speeds, damage, prices, zombie health and level settings, so balancing is just editing numbers.
- **Saving:** browser local storage, with a saved profile for each hero.
- **Sound:** short sound effects generated in code or free sound files added later.

**Build steps** (play-test with Chloe and Naomi after each)

1. **Walk and bonk:** one player walks around Sunny Park in first person, holding the Spiky Stick, and pops Shufflers into confetti.
2. **Tag Bux and the shop:** coins to collect, a shop building with a glowing sign, buying the Foam Noodle Bat and Water Blaster.
3. **Hearts:** zombie touches, medicine, being tagged and coming back.
4. **The gym:** treadmill and weights mini-games that raise Speed and Strength.
5. **All the weapons and armour**, including the Sparkle Star Laser Gun's star particles.
6. **Two players:** split screen, second set of keys, separate wallets.
7. **Character creator and outfits.**
8. **Levels 1 to 10:** themes, random shop and gym spots, new zombie types, the Zombie King, level select and saving.
   8b. **Sound and music:** sound effects and a tune for each place, made in code, with volume in the pause menu.
9. **Refinement:** menus, and tuning the numbers from play-testing. From the first play-tests:
   Easy, Hard and Hardcore difficulty; a saved profile for every hero (not just Player 1 and 2);
   the gym limited to one Speed and one Strength upgrade per level; and the Zombie King arriving as
   the final battle after every other zombie, tougher and faster on Hard and Hardcore. Joypad support
   for both players (simple: left stick walks and turns; or two sticks; each joypad belongs to whoever
   presses fire on it on "Who's playing?"; every face button fires), and optional mouse controls
   (mouse to turn, A/D to step sideways) for Player 1. Hardcore is its own game for each hero, starting
   from nothing but outfits, with twice the zombies; game over starts it again.

**Getting started in Claude Code**

Export this document as Markdown, save it as `DESIGN.md` in an empty project folder, open Claude Code there and say:

> Read DESIGN.md. It's the design for a game my daughters invented. Set up the project and build step 1 only, then tell me how to run it so they can try it.

## Questions for Chloe and Naomi

These don't stop the build from starting, but the answers will make the game more theirs.

- [ ] When the Spiky Stick breaks, can you go back and get another free one, or only once? Answer: yes get another free one
- [ ] Should training at the gym cost Tag Bux, or stay free? Answer: stay free
- [ ] Decided: separate wallets, and sisters can give each other Tag Bux.
- [ ] Do you like the suggested weapons? Which would you swap or add? Answer: They are good
- [ ] Do you like the zombie names, or do you want to name them yourselves? Answer: They are good
- [ ] Which places would you change in the level list? Answer: They are good
- [ ] What should happen when you beat the Zombie King? Answer: You get a big party with all the zombies, that have now become your friends
- [ ] Does your laptop have a number pad, or should Player 2 use Enter to attack? Answer: Yes
