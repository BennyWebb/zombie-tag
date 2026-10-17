import { CONFIG } from './config.js';
import { keyName, wasPressed } from './input.js';

// The shop menu one player sees while inside the shop.
// It builds itself inside `root`, so each player can have their own later on.

const coin = '<span class="coin">T</span>';
const thing = (id) => CONFIG.weapons[id] || CONFIG.items[id] || CONFIG.armour[id] || CONFIG.outfits[id];
const ROWS_SHOWN = 5; // the list scrolls to show this many rows at a time

// Power as little bangs, or a number for the really strong weapons.
function power(damage) {
  const n = Math.max(1, Math.round(damage));
  return n <= 5 ? '💥'.repeat(n) : `💥×${n}`;
}

export class ShopMenu {
  constructor(root, player, building) {
    this.player = player;
    this.building = building;
    this.el = document.createElement('div');
    this.el.className = 'shop hidden';
    root.appendChild(this.el);
    this.partner = null; // your sister, in 2-player mode, so you can give her Tag Bux
    this.onGive = null; // called after giving, to show the coins flying across
    this.cursor = 0;
    this.scroll = 0; // the first row shown
    this.message = '';
    this.messageKind = '';
    this.drawn = '';
  }

  get ids() {
    const give = this.partner ? ['give'] : [];
    return [
      ...Object.keys(CONFIG.weapons), ...Object.keys(CONFIG.items), ...Object.keys(CONFIG.armour),
      ...Object.keys(CONFIG.outfits), ...give, 'leave',
    ];
  }

  open() {
    const p = this.player;
    p.inside = true;
    p.hand.visible = false;
    // start on something useful: a free stick if you need one, medicine if you're hurt,
    // else the next weapon or armour to buy (the dearest you can afford, or the cheapest you can't yet)
    const upgrades = this.ids.filter((id) => thing(id) && ['buy', 'dear'].includes(this.status(id).kind) && !thing(id).hearts && !thing(id).covers)
      .sort((a, b) => thing(a).price - thing(b).price);
    const affordable = upgrades.filter((id) => thing(id).price <= p.tagBux);
    const hurt = p.hearts < CONFIG.player.hearts && CONFIG.items.medicine.price <= p.tagBux;
    let pick = affordable[affordable.length - 1] || upgrades[0] || 'leave';
    if (hurt) pick = 'medicine';
    if (!p.weapon) pick = 'spikyStick';
    this.cursor = this.ids.indexOf(pick);
    this.say('Welcome to the shop! 🛍️', '');
    this.el.classList.remove('hidden');
    this.openTime = 0.25; // ignore the key you were holding as you walked in
  }

  close() {
    const p = this.player;
    p.inside = false;
    p.hand.visible = true;
    p.reset(this.building.outside);
    p.safe = CONFIG.player.leaveShopSafeTime; // a moment to get past zombies waiting at the door
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
    if (id === 'give') {
      const ok = p.tagBux >= CONFIG.giveTagBux;
      return { label: `${coin} ${CONFIG.giveTagBux}`, ok, kind: ok ? 'buy' : 'dear' };
    }
    const w = thing(id);
    if (w.hearts && p.hearts >= CONFIG.player.hearts) return { label: 'Hearts full', ok: false, kind: 'full' };
    if (w.covers) {
      if (p.wearing.includes(id)) return { label: '✔ Wearing', ok: true, kind: 'wearing' };
      if (p.outfits.includes(id)) return { label: 'Wear it', ok: true, kind: 'owned' };
      return { label: `${coin} ${w.price}`, ok: p.tagBux >= w.price, kind: p.tagBux >= w.price ? 'buy' : 'dear' };
    }
    if (w.blocks) {
      const best = p.bestArmour;
      if (best && best.id === id) return { label: '✔ Wearing', ok: false, kind: 'holding' };
      if (best && best.blocks >= w.blocks) return { label: 'You have better', ok: false, kind: 'locked' };
      return { label: `${coin} ${w.price}`, ok: p.tagBux >= w.price, kind: p.tagBux >= w.price ? 'buy' : 'dear' };
    }
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
    const s = this.status(id);
    this.drawn = ''; // redraw so the message animation plays again
    if (id === 'give') {
      const amount = CONFIG.giveTagBux;
      if (s.kind === 'dear') this.say(`You need ${amount} Tag Bux to give`, 'bad');
      else {
        p.tagBux -= amount;
        this.partner.tagBux += amount;
        this.say(`You gave ${amount} Tag Bux to ${this.partner.name}! 🎁`, 'good');
        if (this.onGive) this.onGive(p, this.partner);
      }
      return false;
    }
    const w = thing(id);
    if (s.kind === 'holding') this.say(`You're already ${w.blocks ? 'wearing' : 'holding'} the ${w.name}!`, '');
    else if (s.kind === 'wearing') {
      p.takeOff(id);
      this.say(`You took off the ${w.name}`, '');
    } else if (s.kind === 'owned' && w.covers) {
      p.wear(id);
      this.say(`Looking good in the ${w.name}! ${w.icon}`, 'good');
    } else if (s.kind === 'owned') {
      p.hold(id);
      this.say(`Now you're holding the ${w.name} ${w.icon}`, 'good');
    } else if (s.kind === 'free') {
      p.giveStick();
      this.say('Here\'s a free Spiky Stick! 🪵', 'good');
    } else if (s.kind === 'locked') {
      this.say(w.blocks ? 'You\'ve already got better armour!' : 'You can have a free one when you have no weapon', 'bad');
    } else if (s.kind === 'full') {
      this.say('Your hearts are already full! ❤️❤️❤️', '');
    } else if (s.kind === 'dear') {
      const need = w.price - p.tagBux;
      this.say(`You need ${need} more Tag Bux. Go pop some zombies!`, 'bad');
    } else if (w.covers) {
      p.tagBux -= w.price;
      p.outfits.push(id);
      p.wear(id);
      this.say(`Ka-ching! You're wearing the ${w.name}! ${w.icon}`, 'good');
    } else if (w.blocks) {
      p.tagBux -= w.price;
      p.addArmour(id);
      this.say(`Ka-ching! ${w.icon} It blocks ${w.blocks} ${w.blocks === 1 ? 'hit' : 'hits'} every level!`, 'good');
    } else if (w.hearts) {
      p.tagBux -= w.price;
      p.hearts = Math.min(CONFIG.player.hearts, p.hearts + w.hearts);
      this.say('Yum! You got a heart back ❤️', 'good');
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
    // scroll so the chosen row is always on screen
    if (this.cursor < this.scroll) this.scroll = this.cursor;
    if (this.cursor >= this.scroll + ROWS_SHOWN) this.scroll = this.cursor - ROWS_SHOWN + 1;
    const shown = this.ids.slice(this.scroll, this.scroll + ROWS_SHOWN);
    const rows = shown.map((id, j) => {
      const i = j + this.scroll;
      const s = this.status(id);
      const sel = i === this.cursor ? ' selected' : '';
      if (id === 'give') {
        return `<div class="row ${s.kind}${sel}"><span class="icon">🎁</span>`
          + `<span class="name">Give ${CONFIG.giveTagBux} Tag Bux to ${this.partner.name}<small>As many times as you like</small></span>`
          + `<span class="price">${s.label}</span></div>`;
      }
      if (id === 'leave') {
        return `<div class="row leave${sel}"><span class="icon">🚪</span><span class="name">Leave</span>`
          + `<span class="price">${s.label}</span></div>`;
      }
      const w = thing(id);
      let about = w.about;
      if (w.damage) about = `Power ${power(w.damage)} · ${w.about}`;
      if (w.blocks) about = `Blocks ${w.blocks} ${w.blocks === 1 ? 'hit' : 'hits'} every level`;
      if (w.covers) {
        about = this.partner ? `Just for looks. ${this.partner.name} will see it!` : 'Just for looks!';
        if (s.kind === 'wearing') about += ` (${keyName(p.keys.attack[0])} takes it off)`;
      }
      return `<div class="row ${s.kind}${sel}"><span class="icon">${w.icon}</span>`
        + `<span class="name">${w.name}<small>${about}</small></span>`
        + `<span class="price">${s.label}</span></div>`;
    }).join('');
    const armour = p.bestArmour;
    const hearts = '<span class="heart"></span>'.repeat(p.hearts)
      + '<span class="heart empty"></span>'.repeat(CONFIG.player.hearts - p.hearts)
      + '<span class="shield"></span>'.repeat(p.shields)
      + '<span class="shield empty"></span>'.repeat((armour ? armour.blocks : 0) - p.shields);
    const more = (show, arrow) => `<div class="more${show ? '' : ' none'}">${arrow}</div>`;
    const html = `<div class="shop-top"><h2>🛍️ The Shop</h2><div class="shop-hearts">${hearts}</div>`
      + `<div class="shop-bux">${coin} ${p.tagBux}</div></div>`
      + `<div class="rows">${more(this.scroll > 0, '▲ more')}${rows}`
      + `${more(this.scroll + ROWS_SHOWN < this.ids.length, '▼ more')}</div>`
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
