# Zombie Tag for Godot

This is where the Godot version of Zombie Tag will live. So far it holds everything exported from the
browser game, so the Godot version looks, sounds and plays the same:

| Folder | What's in it |
| --- | --- |
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

## Using them in Godot

Make a new Godot 4 project in this folder (choose the **Compatibility** renderer, which suits the
Shield). Godot imports the `.glb` and `.wav` files by itself.

**Models.** Drag a `.glb` into a scene. Each one is a little tree of named parts, for example a zombie
has `body`, `head`, `armL`, `armR`, `legL`, `legR`, `pupil`, `stars`, `bubble`, `ice` and `healthBar`.
The game moves those parts to make it wobble and walk.

- **Hidden parts.** A `.glb` can't say that a part starts hidden, so `data/models.json` lists them
  (`hidden`), like a zombie's bubble, ice block and stars. Hide them when the model is loaded.
- **Recolouring.** Zombies and heroes get their colours when they're made. The materials to change are
  named `skin`, `shirt`, `trousers`, `clothes` and `hair` (`recolour` in `data/models.json`).
- **Level scenery** is merged into one mesh per 20 x 20 m square, so Godot can skip squares that are out
  of view. Its colours come from a small palette texture (a grid of coloured squares) in the same file.
  Things that move are kept separate: the `gate` (hide `gate/open` until it opens) and, on the Funfair,
  the `carousel` and `ferrisWheel`.
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
