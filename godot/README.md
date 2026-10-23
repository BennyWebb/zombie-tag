# Zombie Tag for Godot

The Godot version of Zombie Tag, being built a step at a time. It uses everything exported from the
browser game, so it looks, sounds and plays the same.

Open this folder in Godot 4 (**Import**, then pick `project.godot`) and press **F5** (or the ▶ button)
to play.

## Building it up

| Phase | | |
| --- | --- | --- |
| 0 | ✅ | Export the browser game's levels, characters, sounds and numbers |
| 1 | ✅ | Walk and bonk in Sunny Park: the level, sky and sun, a hero, Shufflers that chase you and pop into confetti |
| 2 | ✅ | Tag Bux coins, hearts, getting tagged, and the HUD |
| 3 | | The shop and gym |
| 4 | | All the weapons |
| 5 | | Two players, split screen |
| 6 | | All ten levels and the Zombie King |
| 7 | | Menus, the character creator, saving, sound settings |
| 8 | | The Android TV app for the Shield, and speed-ups |

**Controls (phase 1):** W / S or ↑ / ↓ walk, A / D or ← / → turn, Space or Enter bonks. On a joypad: the
left stick or d-pad, and any face button or the right trigger. Esc or Start pauses. **F3** (or
Back / View / Select) shows the frame rate and how many things are drawn, for checking speed on the TV.

## Trying it on the Shield

Until phase 8 makes it a proper Android TV app (with a tile on the home screen), Godot's **one-click
deploy** puts a test version on the Shield and starts it:

1. In Godot: **Editor → Manage Export Templates → Download and Install** (once).
2. **Editor → Editor Settings → Export → Android** (once):
   - **Java SDK Path**: a Java 17 or newer, e.g. `C:\Program Files\Android\Android Studio\jbr` (the one
     that comes with Android Studio) or the Java 21 from `winget install Microsoft.OpenJDK.21`.
   - **Android SDK Path**: `C:\Users\<you>\AppData\Local\Android\Sdk`.
   Godot makes its own debug key for signing the app.
3. Connect to the Shield (with Network debugging on, as for the browser version's app):
   ```
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" connect <the Shield's IP address>:5555
   ```
4. A **Remote Deploy** button (▶ with radio waves) appears next to the play buttons at the top right
   of Godot (restart Godot if you pulled while it was open). Click it and pick the Shield: Godot builds
   the game, puts it on the Shield and starts it. Next time, steps 3 and 4 are all you need.

   If it doesn't appear, check **Project → Export…** lists **Android (Runnable)** with no red errors,
   and that `adb devices` shows the Shield as `device` (not `unauthorized` or `offline`). Or export
   an APK from that window and install it with `adb install -r zombie-tag.apk`.

On the Shield, Back or Start pauses. To start it again later without the PC, it's in **Settings →
Apps → See all apps → Zombie Tag (Godot)**. Press **Back / View / Select** on a joypad (F3 on a
keyboard) to see the frame rate and how big it's drawn.

## The scripts

Everything is made in code, so you can read how it fits together, starting from `scripts/main.gd`:

| Script | What it does | From the browser game's |
| --- | --- | --- |
| `main.gd` | Runs a level: zombies arrive in waves, bonks and pops, the exit gate | `src/main.js` |
| `level.gd` | The scenery, sky, fog and sun, the shop and gym, the gate, and what you can't walk through | `src/world.js` |
| `hero.gd` | You: walking, turning, and swinging your weapon at the nearest zombie in front of you | `src/player.js` |
| `zombie.gd` | A zombie: wandering, chasing, its silly walk, squashing and flashing when bonked | `src/zombie.js` |
| `effects.gd` | Confetti and words that float up, like "POP!" | `src/effects.js` |
| `coins.gd` | Tag Bux coins: bursting out, bouncing, flying to you | `src/coins.js` |
| `hud.gd` | What's drawn over the game: hearts, Tag Bux, messages, the TAGGED! screen | `src/hud.js` |
| `hud_icon.gd` | The HUD's hearts, armour shields and coin, drawn as shapes | |
| `data.gd` | Reads the exported numbers and helps with the models (an autoload: use it anywhere as `Data`) | |
| `controls.gd` | The keys and joypad buttons for each action (an autoload: `Controls`) | `src/input.js` |
| `sound.gd` | Plays sound effects and music (an autoload: `Sound`) | `src/audio.js` |

## What's in the other folders

| Folder | What's in it |
| --- | --- |
| `fonts/` | [Fredoka](https://github.com/hafontia/Fredoka-One), the round font the browser game asks for (free to use under the SIL Open Font License in `fonts/OFL.txt`) |
| `data/config.json` | All the game's numbers, from `src/config.js`: speeds, prices, weapons, zombies, levels... |
| `data/levels/` | Each level's layout: colliders, where you start, the gate, the building spots, sky, fog and light colours |
| `data/models.json` | What's in each model: its parts' names, which materials to recolour, and which parts start hidden |
| `models/levels/` | Each level's scenery, already merged into a few big meshes so it draws quickly |
| `models/` | The shop, gym and gate, every zombie, heroes (each hair style and outfit), the hand with every weapon, shots and the coin |
| `sounds/sfx/` | Every sound effect |
| `sounds/music/` | Every tune, each one a loop that joins up with itself |

## Making them again

The files come from the browser game's own code, so after changing the game, export again:

```
npm run export:godot
```

That writes `data/config.json`, then opens an export page in the browser that makes everything else.
Leave it open until it says it's finished. If you only changed numbers in `src/config.js`, `npm run
export:config` is enough.

## Using the exported files

Godot imports the `.glb` and `.wav` files by itself. The project uses the **Compatibility** renderer,
which suits the Shield.

**Models.** Drag a `.glb` into a scene. Each one is a little tree of named parts, for example a zombie
has `body`, `head`, `armL`, `armR`, `legL`, `legR`, `pupilL`, `pupilR`, `stars`, `bubble`, `ice` and `healthBar`.
The game moves those parts to make it wobble and walk.

- **Hidden parts.** A `.glb` can't say that a part starts hidden, so `data/models.json` lists them
  (`hidden`), like a zombie's bubble, ice block and stars. `Data.hide_parts()` hides them.
- **Recolouring.** Zombies and heroes get their colours when they're made. The materials to change are
  named `skin`, `shirt`, `trousers`, `clothes` and `hair` (`recolour` in `data/models.json`);
  `Data.own_material()` gives a model its own copy of one to change.
- **Level scenery** is merged into one mesh per 20 x 20 m square, so Godot can skip squares that are out
  of view. Its colours come from a small palette texture (a grid of coloured squares) in the same file.
  Things that move are kept separate: the `gate` (hide `gate/open` until it opens) and, on the Funfair,
  the `carousel` and `ferrisWheel`.
- **Shadows.** Godot gives everything a shadow, but in the game some things have none: clouds, the
  gate's light beam, the Ferris wheel, coins and a few more. Those meshes have `noShadow: true` in their
  extras metadata (merged scenery also has "no shadow" in its name). `Data.remove_extra_shadows()`
  turns their shadows off.
- The shop and gym aren't in the levels. Put them at two of the level's `buildingSpots`, at least 30 m
  apart, like the browser game does.

**Colours** in the JSON files are numbers like `16731019` (that's `0xff4f8b`). In GDScript:

```gdscript
var colour := Color.hex((int(c) << 8) | 0xff)
```

**Colliders** (`colliders` in each level's file) are circles `{ x, z, r }` and boxes `{ x, z, hw, hd }`
(half the width and depth). `small` ones are low enough for Bouncy Bob to hop over. The browser game
pushes heroes and zombies out of them in `src/world.js` (`resolveCollisions`).

**Lights.** Each level's `light` has the sky, ground and sun colours and strengths (a hemisphere light
and a sun at `sunPosition`). `pointLights` lists the lamps and torches; on the Shield, glowing
materials are cheaper than real lights.

**Floaters** (`floaters`: the snow, fireflies and sparkles) are little dots drifting about. Make them
with a `CPUParticles3D` using the count, colour, size and heights listed.

**Sounds.** Sound effects are recorded at normal pitch. The game plays some higher or lower (the coin's
ka-ching goes up as you collect more), which in Godot is `pitch_scale` on the `AudioStreamPlayer`.
The tunes loop by themselves: each `.wav` says where its loop is, and Godot reads that when it imports
them.
