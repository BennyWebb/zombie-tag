import { CONFIG } from './config.js';
import { keyName, wasPressed } from './input.js';
import { sfx } from './audio.js';

// The character creator: type a name, then pick skin, hair and clothes from big buttons
// while your hero turns round on the right. In 2-player mode Player 1 goes first, then Player 2.

const C = CONFIG.creator;
const hex = (c) => `#${c.toString(16).padStart(6, '0')}`;

const ROWS = [
  { key: 'skin', label: 'Skin', options: C.skins },
  { key: 'hairStyle', label: 'Hair', options: C.hairStyles.map((h) => h.id), names: C.hairStyles.map((h) => h.name) },
  { key: 'hair', label: 'Hair colour', options: C.hairColours },
  { key: 'outfit', label: 'Clothes', options: C.outfitColours },
  { key: 'done', label: '' },
];

export class Creator {
  constructor(el) {
    this.el = el;
    this.player = null;
  }

  // Runs the creator for each of `players` in turn, then calls onDone.
  start(players, onDone) {
    this.queue = [...players];
    this.onDone = onDone;
    this.next();
  }

  next() {
    this.player = this.queue.shift();
    if (!this.player) {
      this.onDone();
      return;
    }
    this.step = 'name';
    this.drawName();
  }

  drawName() {
    const p = this.player;
    this.el.innerHTML = `<div class="panel">
      <div class="who-badge p${p.index + 1}">Player ${p.index + 1}</div>
      <h2>What's your name?</h2>
      <input class="name-box" maxlength="${C.maxNameLength}" autocomplete="off" spellcheck="false" />
      <p class="hint">Type your name, then press <kbd>Enter</kbd></p>
    </div>`;
    const box = this.el.querySelector('.name-box');
    box.value = p.created ? p.name : '';
    box.addEventListener('input', () => {
      // letters only, up to 12
      box.value = box.value.replace(/[^A-Za-z]/g, '').slice(0, C.maxNameLength);
      if (box.value) box.value = box.value[0].toUpperCase() + box.value.slice(1);
    });
    box.addEventListener('keydown', (e) => {
      if (e.code === 'Enter' || e.code === 'NumpadEnter') this.finishName(box.value);
    });
    setTimeout(() => box.focus(), 50);
  }

  finishName(name) {
    if (this.step !== 'name') return;
    const p = this.player;
    p.setLook({ name: name || `Player ${p.index + 1}` });
    this.step = 'look';
    this.row = 0;
    this.wait = 0.3; // so the Enter that finished the name doesn't also press a button
    this.drawn = '';
    document.activeElement.blur();
  }

  update(dt) {
    if (this.step !== 'look') return;
    const p = this.player;
    const k = p.keys;
    this.wait -= dt;
    if (this.wait <= 0) {
      if (wasPressed(k.forward)) this.row = Math.max(0, this.row - 1);
      if (wasPressed(k.back)) this.row = Math.min(ROWS.length - 1, this.row + 1);
      const r = ROWS[this.row];
      const step = (wasPressed(k.right) ? 1 : 0) - (wasPressed(k.left) ? 1 : 0);
      if (wasPressed(k.forward) || wasPressed(k.back) || step) sfx('tick');
      if (step && r.options) {
        const i = r.options.indexOf(p.look[r.key]);
        const next = r.options[(Math.max(0, i) + step + r.options.length) % r.options.length];
        p.setLook({ [r.key]: next });
      }
      if (wasPressed(k.attack)) {
        sfx('select');
        if (r.key === 'done') {
          p.created = true;
          this.next();
          return;
        }
        this.row += 1; // on to the next choice
      }
    }
    this.drawLook();
  }

  drawLook() {
    const p = this.player;
    const k = p.keys;
    const rows = ROWS.map((r, i) => {
      const sel = i === this.row ? ' current' : '';
      if (r.key === 'done') return `<div class="crow done${sel}">✔ Done!</div>`;
      const opts = r.options.map((o, j) => {
        const on = p.look[r.key] === o ? ' on' : '';
        return r.names
          ? `<span class="opt text${on}">${r.names[j]}</span>`
          : `<span class="opt${on}" style="background:${hex(o)}"></span>`;
      }).join('');
      return `<div class="crow${sel}"><span class="label">${r.label}</span><span class="opts">${opts}</span></div>`;
    }).join('');
    const html = `<div class="panel">
      <div class="who-badge p${p.index + 1}">Player ${p.index + 1}</div>
      <h2>Hi ${p.name}!</h2>
      ${rows}
      <p class="hint"><kbd>${keyName(k.forward[0])}</kbd> <kbd>${keyName(k.back[0])}</kbd> choose
        &nbsp; <kbd>${keyName(k.left[0])}</kbd> <kbd>${keyName(k.right[0])}</kbd> change
        &nbsp; <kbd>${keyName(k.attack[0])}</kbd> next</p>
    </div>`;
    if (html !== this.drawn) {
      this.el.innerHTML = html;
      this.drawn = html;
    }
  }
}
