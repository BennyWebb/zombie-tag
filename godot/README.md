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
| 3 | ✅ | The shop and gym |
| 4 | ✅ | All the weapons: squirts, goo, bubbles, snowballs, the boomerang banana, pumpkins and the star laser |
| 5 | ✅ | Two players, split screen |
| 6 | ✅ | All ten levels and the Zombie King |
| 7 | ✅ | Menus, the character creator, saving, sound settings |
| 8 | ✅ | The Android TV app for the Shield, graphics settings, and joypads with two sticks |

**Controls:** on a joypad, the left stick or d-pad walks and turns, and any face button or the right
trigger bonks (hold it to keep shooting). Start pauses. On a keyboard: W / S or ↑ / ↓ walk, A / D or
← / → turn, Space or Enter bonks, Esc pauses. Walk in through the shop's or gym's door to go in;
inside, up and down choose and bonk picks. **F3** (or Back / View / Select) shows the frame rate and
how many things are drawn, for checking speed on the TV.

**The menus:** the title screen picks 1 or 2 players, then "Who's playing?" picks each player's saved
hero (or makes a new one in the character creator: a name, then skin, hair and clothes), then how
hard (Easy, Hard or Hardcore) and which level. Back / Select on the title screen lets heroes change
how they look; on "Who's playing?" it deletes one. The pause menu has the music and sound volumes,
and the way back to the start screen.

**Two players:** each sister plays with what she picked her hero with: her own joypad, or the
keyboard (or half each: Player 1 on W A S D and Space, Player 2 on the arrows and Enter). The screen
splits in two, each sister with her own half, and there are half as many zombies again. In the shop
each can give the other Tag Bux, and outfits show on your body, which your sister sees. Messages on
the Android version only talk about joypad buttons (the TV has no keyboard).

**Saving:** each hero's progress is saved in `user://save.json`: on a computer that's in Godot's app
data folder (Project → Open User Data Folder), and on the Shield in the app's own storage.

## The app on the Shield

The game is an Android TV app, with its own tile on the Shield's home screen (the banner in
`icons/banner.png`). Getting it there the first time:

1. In Godot: **Editor → Manage Export Templates → Download and Install** (once).
2. **Editor → Editor Settings → Export → Android** (once):
   - **Java SDK Path**: a Java 17 or newer, e.g. `C:\Program Files\Android\Android Studio\jbr` (the one
     that comes with Android Studio) or the Java 21 from `winget install Microsoft.OpenJDK.21`.
   - **Android SDK Path**: `C:\Users\<you>\AppData\Local\Android\Sdk`.
   Godot makes its own debug key for signing the app.
3. **Project → Install Android Build Template…** (once). Showing on the TV's home screen needs the
   app built the full way ("Gradle"), which uses this template. It goes in the `android/` folder,
   which git leaves out, since it belongs to your copy of Godot. The first build downloads what it
   needs, so it takes a few minutes; after that it's quicker.
4. Connect to the Shield (with Network debugging on, as for the browser version's app):
   ```
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" connect <the Shield's IP address>:5555
   ```
5. Click **Remote Deploy** (▶ with radio waves, at the top right) and pick the Shield: Godot builds the
   app, puts it on the Shield and starts it. Next time, steps 4 and 5 are all you need.

   If it doesn't work, check **Project → Export…** lists **Android (Runnable)** with no red errors,
   and that `adb devices` shows the Shield as `device` (not `unauthorized` or `offline`). Or export
   an APK from that window and install it with `adb install -r zombie-tag.apk`.

After that, **Zombie Tag** is on the Shield's home screen (in the Apps row; hold Select on it to move
it). The older test version, "Zombie Tag (Godot)", and the browser version's app can be uninstalled
in **Settings → Apps**.

The banner: Godot has no setting for a TV banner, so the little add-on in `addons/tv_banner/` puts
`icons/banner.png` into the build template each time you export. `tools/make-icons.gd` drew the icon
and banner from the game's own models (`godot --path godot -s ../tools/make-icons.gd`).

## Making it run smoothly

**Pause → ✨ Graphics** changes how the game is drawn while you watch, with the frame rate at the top
(60 fps needs each frame to take 16.7 ms or less). There's a set of settings for 1 player and another
for 2, since two players draw the world twice. Further down each list is quicker but not as nice:

| Setting | What it does |
| --- | --- |
| 🖼️ Sharpness | Draws the world with fewer dots and stretches it to fit (the HUD and menus stay sharp) |
| 🌳 Shadows | The sun's shadows in four layers near to far, two, one, or none (each layer draws everything that casts a shadow again) |
| ✨ Smooth edges | Smoothing jagged edges ("anti-aliasing"): 4x, 2x or off |
| 🔭 View distance | Brings the fog in, and doesn't draw anything past it (far things like the sun go too) |
| ❄️ Snow and lamps | The snow, sparkles and fireflies, and the lamps and torches at night |

They're saved with the game. If the game stops while starting or just after a setting changes
(a crash), it starts next time with the graphics back to normal, and says so on the title screen.
**F3** (Back / View / Select on a joypad) shows the frame rate and draw
calls while playing.

**Pause → 🎮 Joypads** chooses how joypads play: **Simple** (the left stick or d-pad walks and turns,
for joypads with one stick or none) or **Two sticks** (the left stick walks and steps sideways and the
right stick turns, like an Xbox controller in most games). The d-pad always walks and turns.

## The scripts

Everything is made in code, so you can read how it fits together, starting from `scripts/main.gd`:

| Script | What it does | From the browser game's |
| --- | --- | --- |
| `main.gd` | Runs the game: zombies arrive in waves, bonks and pops, the exit gate, one level after another, the Zombie King | `src/main.js` |
| `level.gd` | The scenery, sky, fog and sun, lamps, the Funfair's rides, the shop and gym, the gate, and what you can't walk through | `src/world.js` |
| `hero.gd` | You: walking, turning, and swinging, shooting, throwing or zapping your weapon at the nearest zombie in front of you | `src/player.js` |
| `zombie.gd` | A zombie: wandering, chasing, its silly walk, squashing and flashing when bonked, slimed, bubbled or frozen | `src/zombie.js` |
| `screens.gd` | The start screens and menus: 1 or 2 players, who's playing, how hard, pick a level, paused, game over | `src/main.js`, `index.html` |
| `creator.gd` | The character creator | `src/creator.js` |
| `save.gd` | Saves each hero's progress, and the settings (an autoload: `Save`) | `src/save.js` |
| `party.gd` | The party after beating the Zombie King | `src/main.js` |
| `floaters.gd` | Snow, sparkles and fireflies drifting about (they move in `floaters.gdshader`) | `src/themes.js` |
| `health_bar.gdshader` | A zombie's health bar, which turns to face whichever camera draws it | |
| `hero_body.gd` | A hero's whole body with her hair, colours, outfits and name, which her sister sees | `src/hero.js` |
| `shots.gd` | Everything that flies: squirts, goo, bubbles, snowballs, pumpkins and the boomerang banana | `src/weapons.js` |
| `beam.gd` | The Sparkle Star Laser Gun's beam and its swirling stars | `src/weapons.js` |
| `effects.gd` | Confetti and words that float up, like "POP!" | `src/effects.js` |
| `coins.gd` | Tag Bux coins: bursting out, bouncing, flying to you | `src/coins.js` |
| `hud.gd` | What's drawn over the game: hearts, Tag Bux, messages, the TAGGED! screen | `src/hud.js` |
| `hud_icon.gd` | The HUD's hearts, armour shields and coin, drawn as shapes | |
| `menu_screen.gd` | The screen you see inside a building: title, a list to choose from, a message | `src/style.css` |
| `shop.gd` | The shop: weapons, Heart Medicine, armour and outfits | `src/shop.js` |
| `gym.gd` | The gym: the treadmill and weights mini-games | `src/gym.js` |
| `data.gd` | Reads the exported numbers and helps with the models (an autoload: use it anywhere as `Data`) | |
| `controls.gd` | Each player's keys and joypad buttons and sticks, and the menus' buttons (an autoload: `Controls`) | `src/input.js` |
| `graphics.gd` | The graphics settings, and what each choice does | |
| `sound.gd` | Plays sound effects and music (an autoload: `Sound`) | `src/audio.js` |

## What's in the other folders

| Folder | What's in it |
| --- | --- |
| `icons/` | The app's icon (with the two halves of its Android "adaptive" icon) and its TV banner |
| `addons/tv_banner/` | Puts the TV banner into the Android app when it's exported |
| `fonts/` | [Fredoka](https://github.com/hafontia/Fredoka-One), the round font the browser game asks for, with just the emoji and arrows the game uses from Noto Color Emoji (`emoji.ttf`) and Noto Sans Symbols 2 (`symbols.ttf`) to fall back on. All free to use under the SIL Open Font License (the `OFL*.txt` files). `tools/subset-fonts.py` makes the two small ones again, if the game needs a new emoji |
| `data/config.json` | All the game's numbers, from `src/config.js`: speeds, prices, weapons, zombies, levels... |
| `data/levels/` | Each level's layout: colliders, where you start, the gate, the building spots, sky, fog and light colours |
| `data/models.json` | What's in each model: its parts' names, which materials to recolour, and which parts start hidden |
| `models/levels/` | Each level's scenery, already merged into a few big meshes so it draws quickly |
| `models/` | The shop, gym and gate, every zombie, heroes (one for each hair style, and each outfit on its own to put on any of them), the hand with every weapon, shots and the coin |
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
and a sun at `sunPosition`). `pointLights` lists the lamps and torches (the game makes each an `OmniLight3D`; the
Graphics menu's "Snow and lamps" turns them off).

**Floaters** (`floaters`: the snow, fireflies and sparkles) are little dots drifting about, with the
count, colour, size and heights listed. `scripts/floaters.gd` draws them, moving them in a shader.

**Sounds.** Sound effects are recorded at normal pitch. The game plays some higher or lower (the coin's
ka-ching goes up as you collect more), which in Godot is `pitch_scale` on the `AudioStreamPlayer`.
The tunes loop by themselves: each `.wav` says where its loop is, and Godot reads that when it imports
them.
