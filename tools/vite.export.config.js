// The dev server for tools/export.html (npm run export:godot). The page sends each file it makes
// to /__export/<path>, and this writes it to godot/<path>.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const godot = fileURLToPath(new URL('../godot', import.meta.url));

// Recording a tune twice can come out a tiny bit different (a few samples one step apart), which
// nobody can hear. Keeping the old file then saves git from storing the whole tune again.
function sameSound(path, data) {
  if (!path.endsWith('.wav') || !existsSync(path)) return false;
  const old = readFileSync(path);
  if (old.length !== data.length) return false;
  for (let i = 0; i < 44; i++) if (old[i] !== data[i]) return false; // the header
  for (let i = 44; i + 1 < data.length; i += 2) {
    if (Math.abs(old.readInt16LE(i) - data.readInt16LE(i)) > 1) return false;
  }
  return true;
}

function saveExports() {
  return {
    name: 'save-godot-exports',
    configureServer(server) {
      server.middlewares.use('/__export/', (req, res) => {
        const path = resolve(godot, decodeURIComponent(req.url.split('?')[0].replace(/^\/+/, '')));
        if (req.method !== 'POST' || !path.startsWith(godot + sep)) {
          res.statusCode = 400;
          res.end('Only POSTs to a file inside the godot folder');
          return;
        }
        const chunks = [];
        req.on('data', (c) => chunks.push(c));
        req.on('end', () => {
          const data = Buffer.concat(chunks);
          mkdirSync(dirname(path), { recursive: true });
          if (!sameSound(path, data)) writeFileSync(path, data);
          res.end('ok');
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [saveExports()],
  server: { open: '/tools/export.html' },
});
