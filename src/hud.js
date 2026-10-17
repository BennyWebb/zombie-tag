import { CONFIG } from './config.js';

// One player's on-screen display: hearts and shields, Tag Bux, weapon, zombies left, messages.
// Each player has their own, so in 2-player mode each half of the screen has a full set.

export class Hud {
  constructor(root, player, number) {
    this.player = player;
    this.el = document.createElement('div');
    this.el.className = `view p${number}`;
    // everything sits in `inner`, which shrinks to fit half the screen in 2-player mode
    this.el.innerHTML = `<div class="inner">
      <div class="zombies-left pill"></div>
      <div class="boss hidden"><b>👑 Zombie King</b><div class="boss-bar"><i></i></div></div>
      <div class="top-left">
        <div class="hearts"></div>
        <div class="stats">
          <span class="badge">Speed <b class="stat-speed"></b></span>
          <span class="badge">Strength <b class="stat-strength"></b></span>
        </div>
      </div>
      <div class="bux pill"><span class="coin">T</span> <span class="bux-count">0</span></div>
      <div class="weapon pill"></div>
      <div class="crosshair"></div>
      <div class="hurt"></div>
      <div class="who pill">Player ${number}</div>
      <div class="tagged hidden">
        <h1>TAGGED!</h1>
        <p class="sub tagged-back">Back to the start in <b class="tagged-count"></b>…</p>
        <p class="sub tagged-keep"></p>
      </div>
      <div class="toast"></div>
    </div>`;
    root.appendChild(this.el);
    this.inner = this.el.querySelector('.inner'); // the shop and gym menus go in here
    this.toastTimer = 0;
    this.heartsShown = -1;
    this.shieldsShown = '';
  }

  q(sel) {
    return this.el.querySelector(sel);
  }

  toast(text, seconds = 2.5) {
    this.q('.toast').innerHTML = text;
    this.q('.toast').classList.add('show');
    this.toastTimer = seconds;
  }

  clearToast() {
    this.toastTimer = 0;
    this.q('.toast').classList.remove('show');
  }

  // The screen edges flash: blue when armour blocks a hit, pink when you lose a heart.
  flash(kind) {
    const el = this.q('.hurt');
    el.classList.toggle('shield', kind === 'shield');
    el.classList.add('show');
    void el.offsetWidth;
    el.classList.remove('show'); // fades back out
  }

  // What getting tagged costs depends on the difficulty: nothing on Easy, your weapons and armour
  // on Hard, and on Hardcore it's game over (in 2-player mode, until your sister finishes the level).
  showTagged(on, difficulty) {
    this.q('.tagged').classList.toggle('hidden', !on);
    if (!on) return;
    this.clearToast();
    const d = difficulty || {};
    this.q('.tagged h1').textContent = d.oneLife ? 'GAME OVER!' : 'TAGGED!';
    this.q('.tagged-back').classList.toggle('hidden', !!d.oneLife);
    let keep = 'You keep your Tag Bux and weapons';
    if (d.loseItems) keep = 'Your weapons and armour are gone! You keep your Tag Bux';
    if (d.oneLife) keep = 'Your weapons, armour and Tag Bux are all gone! 💀';
    this.q('.tagged-keep').textContent = keep;
  }

  // Makes the Tag Bux counter jump when coins go in.
  bumpBux() {
    const el = this.q('.bux');
    el.classList.remove('bump');
    void el.offsetWidth; // restart the animation
    el.classList.add('bump');
  }

  // `boss` is the Zombie King while he's about, so his health shows at the top.
  update(dt, zombiesLeft, gateOpen, boss) {
    const p = this.player;
    if (this.toastTimer > 0) {
      this.toastTimer -= dt;
      if (this.toastTimer <= 0) this.q('.toast').classList.remove('show');
    }
    if (p.tagged && !p.out) this.q('.tagged-count').textContent = Math.max(1, Math.ceil(p.tagged));

    let left = zombiesLeft === 1 ? '1 zombie left' : `${zombiesLeft} zombies left`;
    if (gateOpen) left = '✨ Go to the exit gate!';
    this.q('.zombies-left').classList.toggle('gate', gateOpen);
    this.q('.boss').classList.toggle('hidden', !boss);
    if (boss) this.q('.boss-bar i').style.width = `${Math.max(0, boss.health / boss.maxHealth) * 100}%`;
    if (this.q('.zombies-left').textContent !== left) this.q('.zombies-left').textContent = left;
    this.q('.stat-speed').textContent = p.speedLevel;
    this.q('.stat-strength').textContent = p.strengthLevel;
    if (p.statUp && !p.inside) {
      // the badge for the stat you just trained does a little jump
      const el = this.q(`.stat-${p.statUp}`).parentElement;
      el.classList.remove('bump');
      void el.offsetWidth;
      el.classList.add('bump');
      p.statUp = null;
    }
    if (this.q('.who').textContent !== p.name) this.q('.who').textContent = p.name;
    const bux = this.q('.bux-count');
    if (bux.textContent !== String(p.tagBux)) bux.textContent = p.tagBux;

    const hearts = this.q('.hearts');
    if (p.hearts !== this.heartsShown) {
      // the heart you just lost (or got back) does a little jump
      const changed = p.hearts < this.heartsShown ? p.hearts : this.heartsShown;
      let html = '';
      for (let i = 0; i < CONFIG.player.hearts; i++) {
        const jump = this.heartsShown >= 0 && i === changed ? ' lost' : '';
        html += `<span class="heart${i < p.hearts ? '' : ' empty'}${jump}"></span>`;
      }
      hearts.innerHTML = html;
      this.heartsShown = p.hearts;
      this.shieldsShown = '';
    }
    // blue armour shields go after the hearts
    const armour = p.bestArmour;
    const shieldKey = `${p.shields}/${armour ? armour.blocks : 0}`;
    if (shieldKey !== this.shieldsShown) {
      const old = this.shieldsShown ? Number(this.shieldsShown.split('/')[0]) : p.shields;
      hearts.querySelectorAll('.shield').forEach((el) => el.remove());
      for (let i = 0; i < (armour ? armour.blocks : 0); i++) {
        const el = document.createElement('span');
        el.className = `shield${i < p.shields ? '' : ' empty'}${i === p.shields && old > p.shields ? ' lost' : ''}`;
        hearts.appendChild(el);
      }
      this.shieldsShown = shieldKey;
    }
    hearts.classList.toggle('blink', p.safe > 0 && !p.tagged && !p.inside);

    const w = p.weapon;
    const weapon = this.q('.weapon');
    weapon.classList.toggle('hidden', p.inside || p.tagged > 0);
    weapon.classList.toggle('empty', !w);
    let text = 'No weapon! Get a free Spiky Stick at the 🛍️ shop';
    if (w) text = `${w.icon} ${w.name}`;
    if (w && w.maxHits) text += ` · ${w.hitsLeft} ${w.hitsLeft === 1 ? 'hit' : 'hits'} left`;
    if (weapon.innerHTML !== text) weapon.innerHTML = text;
  }
}
