import { CONFIG } from './config.js';
import { keyName, wasPressed } from './input.js';
import { sfx } from './audio.js';

// The gym one player sees while inside it: a treadmill for Speed and weights for Strength.
// Like the shop, it builds itself inside `root` so each player can have their own later on.

const G = CONFIG.gym;
const DUMBBELLS = G.weights.dumbbells;
const WEIGHT_IDS = Object.keys(DUMBBELLS);

export class GymMenu {
  constructor(root, player, building) {
    this.player = player;
    this.building = building;
    this.levelIndex = 0; // main sets this, since each level only lets you train so much
    this.el = document.createElement('div');
    this.el.className = 'shop gym hidden';
    root.appendChild(this.el);
    this.drawn = '';
  }

  open() {
    const p = this.player;
    p.inside = true;
    p.hand.visible = false;
    this.menu('Welcome to the gym! 💪 Training is free. Train Speed and Strength once in each place.', '');
    this.cursor = p.speedLevel <= p.strengthLevel ? 0 : 1;
    this.el.classList.remove('hidden');
    this.wait = 0.25; // ignore the key you were holding as you walked in
  }

  close() {
    const p = this.player;
    p.inside = false;
    p.hand.visible = true;
    p.reset(this.building.outside);
    p.safe = CONFIG.player.leaveShopSafeTime; // a moment to get past zombies waiting at the door
    this.el.classList.add('hidden');
  }

  menu(message, kind) {
    this.mode = 'menu';
    this.cursor = 0;
    this.message = message;
    this.messageKind = kind;
    this.drawn = '';
  }

  // Returns true when the player chose "Leave".
  update(dt) {
    const k = this.player.keys;
    this.wait -= dt;
    const ready = this.wait <= 0;
    if (this.mode === 'menu' || this.mode === 'pick') {
      const rows = this.rows();
      if (ready && wasPressed(k.forward)) this.cursor = (this.cursor + rows.length - 1) % rows.length;
      if (ready && wasPressed(k.back)) this.cursor = (this.cursor + 1) % rows.length;
      if (ready && (wasPressed(k.forward) || wasPressed(k.back))) sfx('tick');
      if (ready && wasPressed(k.attack) && this.choose(rows[this.cursor])) return true;
      if (this.mode === 'menu' || this.mode === 'pick') this.drawList(); // unless a mini-game just started
    } else if (this.mode === 'treadmill') {
      this.updateTreadmill(dt, ready);
    } else if (this.mode === 'lift') {
      this.updateLift(dt, ready);
    } else if (this.mode === 'result') {
      if (ready && wasPressed(k.attack)) {
        this.menu('Want to train some more?', '');
        this.cursor = this.lastRow;
      }
    }
    return false;
  }

  // ---------- the menus ----------

  rows() {
    const p = this.player;
    if (this.mode === 'menu') {
      // each stat shows MAX, done for this level, or what it goes up to
      const label = (stat, name, level) => {
        if (level >= G.maxLevel) return 'MAX ⭐';
        if (this.doneHere(stat)) return 'Done here ✔';
        return `${name} ${level} → ${level + 1}`;
      };
      const kind = (stat, level) => (level >= G.maxLevel || this.doneHere(stat) ? 'locked' : 'buy');
      return [
        {
          id: 'treadmill', icon: '🏃', name: 'Treadmill', about: 'Makes you faster',
          label: label('speed', 'Speed', p.speedLevel), kind: kind('speed', p.speedLevel),
        },
        {
          id: 'weights', icon: '🏋️', name: 'Weights', about: 'Makes your weapons hit harder',
          label: label('strength', 'Strength', p.strengthLevel), kind: kind('strength', p.strengthLevel),
        },
        { id: 'leave', icon: '🚪', name: 'Leave', label: 'Back outside', kind: 'leave' },
      ];
    }
    const rows = WEIGHT_IDS.map((id) => {
      const w = DUMBBELLS[id];
      const ok = p.strengthLevel < w.maxLevel;
      return {
        id, icon: w.icon, name: `${w.name} dumbbell`, about: `Strength up to ${w.maxLevel}`,
        label: ok ? 'Lift it!' : 'Too easy now!', kind: ok ? 'buy' : 'locked',
      };
    });
    rows.push({ id: 'back', icon: '↩️', name: 'Back', label: '', kind: 'leave' });
    return rows;
  }

  choose(row) {
    const p = this.player;
    this.drawn = '';
    sfx(row.kind === 'locked' ? 'nope' : 'select');
    if (row.id === 'leave') return true;
    if (row.id === 'back') {
      this.menu('', '');
      this.cursor = 1;
      return false;
    }
    if (row.kind === 'locked') {
      const stat = row.id === 'treadmill' ? 'speed' : 'strength';
      const max = (stat === 'speed' ? p.speedLevel : p.strengthLevel) >= G.maxLevel;
      if (this.mode !== 'menu') this.message = 'You\'re too strong for this one! Try a heavier dumbbell';
      else if (max) this.message = 'That one is as high as it goes! ⭐';
      else this.message = 'You\'ve trained that here already! Train again on the next level 💪';
      this.messageKind = 'bad';
      return false;
    }
    if (row.id === 'treadmill') this.startTreadmill();
    else if (row.id === 'weights') {
      this.mode = 'pick';
      this.message = 'Heavier ones are harder to lift, but go higher';
      this.messageKind = '';
      // start on the lightest dumbbell that still helps
      this.cursor = Math.max(0, WEIGHT_IDS.findIndex((id) => p.strengthLevel < DUMBBELLS[id].maxLevel));
    } else this.startLift(row.id);
    return false;
  }

  // True once you've used up this level's training for Speed or Strength.
  doneHere(stat) {
    return this.player.trainedOn(this.levelIndex, stat) >= G.upgradesPerLevel;
  }

  drawList() {
    const p = this.player;
    const k = p.keys;
    const html = `<div class="shop-top"><h2>💪 The Gym</h2>`
      + `<div class="shop-bux">🏃 ${p.speedLevel} &nbsp; 🏋️ ${p.strengthLevel}</div></div>`
      + `<div class="rows">${this.rows().map((r, i) => `<div class="row ${r.kind}${i === this.cursor ? ' selected' : ''}">`
        + `<span class="icon">${r.icon}</span><span class="name">${r.name}${r.about ? `<small>${r.about}</small>` : ''}</span>`
        + `<span class="price">${r.label}</span></div>`).join('')}</div>`
      + `<div class="shop-msg ${this.messageKind}">${this.message}</div>`
      + `<div class="shop-help"><kbd>${keyName(k.forward[0])}</kbd> <kbd>${keyName(k.back[0])}</kbd> choose`
      + ` &nbsp; <kbd>${keyName(k.attack[0])}</kbd> go</div>`;
    if (html !== this.drawn) {
      this.el.innerHTML = html;
      this.drawn = html;
    }
  }

  // ---------- treadmill: press left, right, left, right... ----------

  startTreadmill() {
    const t = G.treadmill;
    this.mode = 'treadmill';
    this.lastRow = 0;
    this.need = t.presses + t.morePressesPerLevel * (this.player.speedLevel - 1);
    this.fill = 0;
    this.timeLeft = t.time;
    this.started = false;
    this.lastKey = null;
    this.sinceGood = 0;
    this.tempo = 0; // good presses per second, smoothed
    this.belt = 0;
    this.phase = 0;
    this.wait = 0.2;
    const k = this.player.keys;
    this.el.innerHTML = `<div class="shop-top"><h2>🏃 Treadmill</h2><div class="shop-bux timer">⏱ <b>${t.time}</b></div></div>`
      + `<div class="train"><div class="scene">`
      + `<div class="runner"><span class="sweat">💦</span><span class="who">🏃</span></div><div class="belt"></div></div>`
      + `<div class="meter"><div class="fill"></div></div></div>`
      + `<div class="shop-msg">Press <kbd class="key-l">${keyName(k.left[0])}</kbd> then <kbd class="key-r">${keyName(k.right[0])}</kbd>`
      + ` then <kbd>${keyName(k.left[0])}</kbd>… as fast as you can!</div>`
      + `<div class="shop-help">Fill the bar before the time runs out</div>`;
    this.parts();
  }

  updateTreadmill(dt, ready) {
    const t = G.treadmill;
    const k = this.player.keys;
    if (ready) {
      // only a different key from last time counts
      const key = wasPressed(k.left) ? 'L' : wasPressed(k.right) ? 'R' : null;
      if (key && key !== this.lastKey) {
        this.lastKey = key;
        this.started = true;
        this.sinceGood = 0;
        this.fill += 1 / this.need;
        this.tempo += 2;
        sfx('step', { pitch: key === 'L' ? 1 : 1.25 }); // left, right, left, right...
      }
    }
    if (this.started) {
      this.timeLeft -= dt;
      this.sinceGood += dt;
      if (this.sinceGood > t.drainAfter) this.fill = Math.max(0, this.fill - t.drainPerSecond * dt);
    }
    this.tempo *= Math.exp(-dt / 0.5);
    // the faster you press, the faster your hero runs
    this.belt += this.tempo * dt * 60;
    this.phase += this.tempo * dt * Math.PI;
    const ui = this.ui;
    ui.belt.style.backgroundPosition = `${this.belt}px 0`;
    ui.runner.style.transform = `translateY(${-Math.abs(Math.sin(this.phase)) * 22}px)`;
    ui.sweat.style.opacity = this.tempo > 4 ? 1 : 0;
    ui.keyL.classList.toggle('next', this.lastKey !== 'L');
    ui.keyR.classList.toggle('next', this.lastKey === 'L');
    this.showProgress();

    if (this.fill >= 1) this.finish(true, 'speed', 'treadmill', t.time - this.timeLeft);
    else if (this.timeLeft <= 0) this.finish(false, 'speed');
  }

  // ---------- weights: tap fast to lift the dumbbell ----------

  startLift(id) {
    const w = DUMBBELLS[id];
    this.mode = 'lift';
    this.lastRow = 1;
    this.weight = id;
    this.fill = 0;
    this.timeLeft = G.weights.time;
    this.started = false;
    this.wait = 0.2;
    const k = this.player.keys;
    this.el.innerHTML = `<div class="shop-top"><h2>🏋️ ${w.name} dumbbell</h2>`
      + `<div class="shop-bux timer">⏱ <b>${G.weights.time}</b></div></div>`
      + `<div class="train"><div class="scene lift ${id}"><div class="bell"><span></span><i></i><span></span></div>`
      + `<div class="lifter"><span class="sweat">💦</span><span class="who">😐</span></div></div>`
      + `<div class="meter"><div class="fill"></div></div></div>`
      + `<div class="shop-msg">Tap <kbd class="key-l next">${keyName(k.attack[0])}</kbd> super fast to lift it!</div>`
      + `<div class="shop-help">Get it to the top before the time runs out. It sinks if you stop!</div>`;
    this.parts();
  }

  updateLift(dt, ready) {
    const w = DUMBBELLS[this.weight];
    if (ready && wasPressed(this.player.keys.attack)) {
      this.started = true;
      this.fill += w.rise;
      sfx('lift', { pitch: 1 + Math.min(1, this.fill) }); // higher as it goes up
      this.ui.keyL.classList.remove('tap');
      void this.ui.keyL.offsetWidth;
      this.ui.keyL.classList.add('tap');
    }
    if (this.started) {
      this.timeLeft -= dt;
      this.fill = Math.max(0, this.fill - w.sink * dt);
    }
    const ui = this.ui;
    ui.bell.style.bottom = `${42 + Math.min(1, this.fill) * 40}%`; // from just above your head up high
    ui.who.textContent = this.fill < 0.3 ? '😐' : this.fill < 0.7 ? '😣' : '😤';
    ui.sweat.style.opacity = this.fill > 0.5 ? 1 : 0;
    this.showProgress();

    if (this.fill >= 1) this.finish(true, 'strength', this.weight, G.weights.time - this.timeLeft);
    else if (this.timeLeft <= 0) this.finish(false, 'strength');
  }

  // ---------- shared bits ----------

  parts() {
    const q = (sel) => this.el.querySelector(sel);
    this.ui = {
      fill: q('.fill'), timer: q('.timer b'), belt: q('.belt'), runner: q('.runner'), sweat: q('.sweat'),
      who: q('.who'), bell: q('.bell'), keyL: q('.key-l'), keyR: q('.key-r'),
    };
    this.showProgress();
  }

  showProgress() {
    const f = Math.min(1, this.fill);
    this.ui.fill.style.height = `${f * 100}%`;
    this.ui.fill.classList.toggle('nearly', f > 0.75);
    const secs = Math.max(0, Math.ceil(this.timeLeft));
    if (this.ui.timer.textContent !== String(secs)) this.ui.timer.textContent = secs;
    this.ui.timer.parentElement.classList.toggle('hurry', this.started && this.timeLeft < 4);
  }

  finish(won, stat, what, time) {
    const p = this.player;
    this.mode = 'result';
    this.wait = 0.8; // so a last frantic tap doesn't skip the result
    const name = stat === 'speed' ? 'Speed' : 'Strength';
    sfx(won ? 'levelUp' : 'aww');
    if (!won) {
      this.el.innerHTML = '<div class="result"><div class="big">😅</div><h2>So close!</h2>'
        + '<p>Try again? It\'s free!</p>'
        + `<p class="go">Press <kbd>${keyName(p.keys.attack[0])}</kbd></p></div>`;
      return;
    }
    const level = stat === 'speed' ? ++p.speedLevel : ++p.strengthLevel;
    p.addTraining(this.levelIndex, stat);
    // a personal best is beating your own fastest time on this one
    const best = p.bests[what];
    const isBest = best !== undefined && time < best;
    if (best === undefined || time < best) p.bests[what] = time;
    const what2 = stat === 'speed' ? 'You\'ll run faster now!' : 'Your weapons hit harder now!';
    this.el.innerHTML = `<div class="result win">${isBest ? '<div class="pb">PERSONAL BEST!</div>' : ''}`
      + `<div class="big flex">💪</div><h2>⭐ ${name.toUpperCase()} UP! ⭐</h2>`
      + `<p class="level">${name} ${level - 1} → <b>${level}</b></p><p>${what2}</p>`
      + `<p class="go">Press <kbd>${keyName(p.keys.attack[0])}</kbd></p></div>`;
    p.statUp = stat; // lets the HUD badge do a little jump
  }
}
