import { CONFIG } from './config.js';
import { wasPressed } from './input.js';

// The shop menu one player sees while inside the shop.
// It builds itself inside `root`, so each player can have their own later on.

const KEY_NAMES = { Space: 'Space', Enter: 'Enter', Numpad0: '0', ArrowUp: '↑', ArrowDown: '↓' };
const keyName = (code) => KEY_NAMES[code] || code.replace(/^Key/, '');

const coin = '<span class="coin">T</span>';

export class ShopMenu {
  constructor(root, player) {
    this.player = player;
    this.el = document.createElement('div');
    this.el.className = 'shop hidden';
    root.appendChild(this.el);
    this.ids = [...Object.keys(CONFIG.weapons), 'leave'];
    this.cursor = 0;
    this.message = '';
    this.messageKind = '';
    this.drawn = '';
  }

  open() {
    const p = this.player;
    p.inShop = true;
    p.hand.visible = false;
    // start on something useful: a free stick if you need one, else the next thing to buy
    const unowned = this.ids.filter((id) => id !== 'leave' && id !== 'spikyStick' && !p.owns(id));
    const affordable = unowned.find((id) => CONFIG.weapons[id].price <= p.tagBux);
    const pick = !p.weapon ? 'spikyStick' : affordable || unowned[0] || 'leave';
    this.cursor = this.ids.indexOf(pick);
    this.say('Welcome to the shop! 🛍️', '');
    this.el.classList.remove('hidden');
    this.openTime = 0.25; // ignore the key you were holding as you walked in
  }

  close(world) {
    const p = this.player;
    p.inShop = false;
    p.hand.visible = true;
    const out = world.shop.outside;
    p.reset(out);
    this.el.classList.add('hidden');
  }

  say(text, kind) {
    this.message = text;
    this.messageKind = kind;
  }

  // What a row shows on its right, and whether Space does anything there.
  status(id) {
    const p = this.player;
    if (id === 'leave') return { label: 'Back outside', ok: true };
    const w = CONFIG.weapons[id];
    if (p.weapon && p.weapon.id === id) return { label: '✔ Holding', ok: false, kind: 'holding' };
    if (p.owns(id)) return { label: 'Hold it', ok: true, kind: 'owned' };
    if (w.price === 0) {
      return p.weapon
        ? { label: 'Free when you have no weapon', ok: false, kind: 'locked' }
        : { label: 'FREE!', ok: true, kind: 'free' };
    }
    return { label: `${coin} ${w.price}`, ok: p.tagBux >= w.price, kind: p.tagBux >= w.price ? 'buy' : 'dear' };
  }

  // Returns true when the player chose "Leave".
  update(dt) {
    const p = this.player;
    const k = p.keys;
    this.openTime -= dt;
    if (this.openTime <= 0) {
      if (wasPressed(k.forward)) this.cursor = (this.cursor + this.ids.length - 1) % this.ids.length;
      if (wasPressed(k.back)) this.cursor = (this.cursor + 1) % this.ids.length;
      if (wasPressed(k.attack) && this.choose()) return true;
    }
    this.draw();
    return false;
  }

  choose() {
    const p = this.player;
    const id = this.ids[this.cursor];
    if (id === 'leave') return true;
    const w = CONFIG.weapons[id];
    const s = this.status(id);
    if (s.kind === 'holding') this.say(`You're already holding the ${w.name}!`, '');
    else if (s.kind === 'owned') {
      p.hold(id);
      this.say(`Now you're holding the ${w.name} ${w.icon}`, 'good');
    } else if (s.kind === 'free') {
      p.giveStick();
      this.say('Here\'s a free Spiky Stick! 🪵', 'good');
    } else if (s.kind === 'locked') {
      this.say('You can have a free one when you have no weapon', 'bad');
    } else if (s.kind === 'dear') {
      const need = w.price - p.tagBux;
      this.say(`You need ${need} more Tag Bux. Go pop some zombies!`, 'bad');
    } else {
      p.tagBux -= w.price;
      p.addWeapon(id);
      this.say(`Ka-ching! You got the ${w.name}! ${w.icon}`, 'good');
    }
    this.drawn = ''; // redraw so the message animation plays again
    return false;
  }

  draw() {
    const p = this.player;
    const k = p.keys;
    const rows = this.ids.map((id, i) => {
      const s = this.status(id);
      const sel = i === this.cursor ? ' selected' : '';
      if (id === 'leave') {
        return `<div class="row leave${sel}"><span class="icon">🚪</span><span class="name">Leave</span>`
          + `<span class="price">${s.label}</span></div>`;
      }
      const w = CONFIG.weapons[id];
      const power = '💥'.repeat(w.damage);
      return `<div class="row ${s.kind}${sel}"><span class="icon">${w.icon}</span>`
        + `<span class="name">${w.name}<small>Power ${power} · ${w.about}</small></span>`
        + `<span class="price">${s.label}</span></div>`;
    }).join('');
    const html = `<div class="shop-top"><h2>🛍️ The Shop</h2><div class="shop-bux">${coin} ${p.tagBux}</div></div>`
      + `<div class="rows">${rows}</div>`
      + `<div class="shop-msg ${this.messageKind}">${this.message}</div>`
      + `<div class="shop-help"><kbd>${keyName(k.forward[0])}</kbd> <kbd>${keyName(k.back[0])}</kbd> choose`
      + ` &nbsp; <kbd>${keyName(k.attack[0])}</kbd> buy</div>`;
    // only touch the page when something changed, so the animations run smoothly
    if (html !== this.drawn) {
      this.el.innerHTML = html;
      this.drawn = html;
    }
  }
}
