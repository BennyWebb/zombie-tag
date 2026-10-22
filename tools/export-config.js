// Writes the game's numbers (src/config.js) to godot/data/config.json, so the Godot version
// is tuned from the same place. Run with: npm run export:config
//
// Colours stay as numbers (0xff4f8b is 16731019); in Godot use Color.hex((c << 8) | 0xff).

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CONFIG } from '../src/config.js';

const out = fileURLToPath(new URL('../godot/data/config.json', import.meta.url));
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, `${JSON.stringify(CONFIG, null, 2)}\n`);
console.log(`Wrote ${out}`);
