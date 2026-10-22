// The dev server for tools/export.html (npm run export:godot). The page sends each file it makes
// to /__export/<path>, and this writes it to godot/<path>.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const godot = fileURLToPath(new URL('../godot', import.meta.url));

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
          mkdirSync(dirname(path), { recursive: true });
          writeFileSync(path, Buffer.concat(chunks));
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
