// Beyond All Random — builder.
// Vanilla port of the design system's redesigned two-column builder
// (ui_kits/web_builder/RedesignApp.jsx). Tool first, reference collapsed below,
// sticky rail with the expected roll spread and the per-slot character budget.

(function () {
  'use strict';

  var LIMIT = 16384;

  var FACTIONS = [
    { key: 'arm', label: 'Armada' },
    { key: 'cor', label: 'Cortex' },
    { key: 'leg', label: 'Legion' }
  ];

  var PRESETS = [
    { key: 'classic', label: 'Classic', hint: 'The shipped defaults',
      p: { rarity_chance: 0.75, curse_chance: 0.2, trait_chance: 0.5, min_factory_rarity: 7, trait_min_rarity: 5 } },
    { key: 'tame', label: 'Tame', hint: 'Closer to vanilla balance',
      p: { rarity_chance: 0.45, curse_chance: 0.1, trait_chance: 0.3, min_factory_rarity: 4, trait_min_rarity: 8 } },
    { key: 'chaos', label: 'Chaos', hint: 'Absurd tiers everywhere',
      p: { rarity_chance: 0.92, curse_chance: 0.3, trait_chance: 0.9, min_factory_rarity: 12, trait_min_rarity: 5 } },
    { key: 'traits', label: 'Trait hunt', hint: 'Rare tiers, but traits almost guaranteed',
      p: { rarity_chance: 0.6, curse_chance: 0.15, trait_chance: 1, min_factory_rarity: 9, trait_min_rarity: 5 } }
  ];

  var SITE = 'https://bazilio91.github.io/beyond-all-random/';
  var BRIDGE = SITE + 'widgets/Tweakdefs_bridge.lua';

  // The lobby message describes the settings actually configured above, so what
  // players read matches what they will be playing.
  function welcomeText() {
    var p = state.p, a = state.adv, w = state.welcome;
    var parts = ['Welcome to BEYOND ALL RANDOM! Every unit rolls a random rarity tier, ' +
      'from Common up to Beyond All Reason — higher tier means stronger stats and a higher price.'];

    parts.push('Each roll escalates a tier with a ' + pct(p.rarity_chance) + ' chance, up to 28 tiers.');
    parts.push('Every factory is guaranteed one unit at ' + rarityName(p.min_factory_rarity) + ' or better.');

    if (p.curse_chance > 0) {
      parts.push(pct(p.curse_chance) + ' of combat units come out cursed: weaker across the board, but much cheaper.');
    }

    var traitLine = 'Rarity 5+ combat units roll an archetype (Glass Cannon, Tank, Sniper, Brawler; ' +
      'turrets get Fortress, Watchtower, Suppressor)';
    if (p.trait_chance > 0) {
      traitLine += ', and from ' + rarityName(p.trait_min_rarity) + ' up they have a ' + pct(p.trait_chance) +
        ' chance of a trait like Phantom (cloak) or Juggernaut (+60% HP)';
    }
    parts.push(traitLine + '.');

    var p2Trait = a.mirror ? p.trait_chance : a.trait_chance;
    if (p2Trait > 0) {
      parts.push('Buildings roll their own traits — Metamorphic mexes and geos evolve into their T2 version on their own.');
    }
    if (a.xp_chance > 0) {
      parts.push(pct(a.xp_chance) + ' of eligible units also get a veterancy school: Prodigy learns about 12x faster, ' +
        'Ascendant evolves into a bigger unit from the same lab once it earns enough xp.');
    }
    if (w.faction) {
      var fl = FACTIONS.filter(function (f) { return f.key === state.faction; })[0].label;
      parts.push(fl + ' is buffed by ' + (state.multiplier >= 1 ? '+' : '') +
        Math.round((state.multiplier - 1) * 100) + '% this game.');
    }
    if (w.tiers) {
      parts.push('Tier lock is on: one random tech tier is rolled for everyone, and only that tier can be built.');
    }

    parts.push('To see rarity names on units in-game, install the Tweakdefs Bridge widget (v6+): ' + BRIDGE);
    parts.push('Config builder: ' + SITE);
    return '!welcome-message ' + parts.join(' ');
  }

  var MODES = [
    { key: 'rarity', label: 'Rarity mod' },
    { key: 'faction', label: 'Faction buff' },
    { key: 'tiers', label: 'Tier lock' },
    { key: 'welcome', label: 'Welcome message' }
  ];

  var state = {
    mode: 'rarity',
    preset: 'classic',
    p: copy(PRESETS[0].p),
    clamp: { arm: { floor: 0, ceil: 28 }, cor: { floor: 0, ceil: 28 }, leg: { floor: 0, ceil: 28 } },
    adv: {
      open: false,
      mirror: true,
      rarity_chance: 0.75, trait_chance: 0.5, trait_min_rarity: 5,
      clamp: { arm: { floor: 5, ceil: 28 }, cor: { floor: 5, ceil: 28 }, leg: { floor: 5, ceil: 28 } },
      xp_chance: 0.35, xp_min_rarity: 4, mentor_chance: 0.3
    },
    faction: 'leg',
    multiplier: 1.5,
    welcome: { faction: false, tiers: false },
    refView: 'combat',
    refOpen: false,
    output: null
  };

  function copy(o) { var r = {}; for (var k in o) r[k] = o[k]; return r; }
  function el(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function rarityName(tier) {
    return DocsContent.RARITIES[tier] || DocsContent.RARITIES[DocsContent.RARITIES.length - 1];
  }
  function badge(tier) {
    return '<span style="color:' + DocsContent.rarityToken(tier) + ';font-weight:bold">' + esc(rarityName(tier)) + '</span>';
  }
  function pct(v) { return Math.round(v * 100) + '%'; }

  // ---- templates -----------------------------------------------------------

  function unitParams() {
    return {
      rarity_chance: state.p.rarity_chance,
      MIN_FACTORY_RARITY: state.p.min_factory_rarity,
      CURSE_CHANCE: state.p.curse_chance,
      TRAIT_CHANCE: state.p.trait_chance,
      TRAIT_MIN_RARITY: state.p.trait_min_rarity,
      arm_floor: state.clamp.arm.floor, cor_floor: state.clamp.cor.floor, leg_floor: state.clamp.leg.floor,
      arm_ceil: state.clamp.arm.ceil, cor_ceil: state.clamp.cor.ceil, leg_ceil: state.clamp.leg.ceil
    };
  }

  function part2Params() {
    var a = state.adv;
    var c = a.mirror ? state.clamp : a.clamp;
    return {
      rarity_chance: a.mirror ? state.p.rarity_chance : a.rarity_chance,
      TRAIT_CHANCE: a.mirror ? state.p.trait_chance : a.trait_chance,
      TRAIT_MIN_RARITY: a.mirror ? state.p.trait_min_rarity : a.trait_min_rarity,
      arm_floor: c.arm.floor, cor_floor: c.cor.floor, leg_floor: c.leg.floor,
      arm_ceil: c.arm.ceil, cor_ceil: c.cor.ceil, leg_ceil: c.leg.ceil,
      XP_CHANCE: a.xp_chance, XP_MIN_RARITY: a.xp_min_rarity, MENTOR_CHANCE: a.mentor_chance
    };
  }

  // Building a payload is a string concat plus a btoa of ~10 KB, so there is no
  // reason to make people press a button for it: every change rebuilds, and the
  // output blocks and budget meters are always in sync with the controls.
  function build() {
    if (state.mode === 'rarity') {
      return [
        { slot: 'units', title: 'Units', command: '!bset tweakdefs', limit: LIMIT, value: RarityTemplate.build(unitParams()) },
        { slot: 'part2', title: 'Part 2 — buildings + veterancy', command: '!bset tweakdefs1', limit: LIMIT, value: Part2Template.build(part2Params()) }
      ];
    }
    if (state.mode === 'faction') {
      return [{ slot: 'faction', title: 'Faction buff', command: '!bset tweakdefs2', limit: LIMIT,
        value: FactionTemplate.build(state.faction, state.multiplier) }];
    }
    if (state.mode === 'tiers') {
      return [{ slot: 'tiers', title: 'Tier lock', command: '!bset tweakdefs3', limit: LIMIT, value: TiersTemplate.build() }];
    }
    return [{ slot: 'welcome', title: 'Welcome message', command: null, limit: null, value: welcomeText() }];
  }

  var refreshTimer = null;
  function refresh(now) {
    if (refreshTimer) clearTimeout(refreshTimer);
    var run = function () {
      refreshTimer = null;
      state.output = build();
      updateOutput();
      updateMeters();
    };
    if (now) run(); else refreshTimer = setTimeout(run, 120);
  }

  // ---- small builders ------------------------------------------------------

  function slider(id, min, max, step, value) {
    return '<div class="slider-row">' +
      '<input type="range" id="' + id + '" min="' + min + '" max="' + max + '" step="' + step + '" value="' + value + '">' +
      '<input type="number" class="num" id="' + id + '_num" min="' + min + '" max="' + max + '" step="' + step + '" value="' + value + '">' +
      '</div>';
  }

  function field(id, label, readout, desc, min, max, step, value) {
    return '<div class="field">' +
      '<div class="field-label"><strong>' + label + '</strong>' +
      '<span class="field-value" id="' + id + '_out">' + readout + '</span></div>' +
      slider(id, min, max, step, value) +
      '<div class="field-desc" id="' + id + '_desc">' + desc + '</div></div>';
  }

  function clampGrid(prefix, clamps) {
    return '<div class="clamp-grid">' + FACTIONS.map(function (f) {
      var c = clamps[f.key];
      return '<div class="clamp">' +
        '<span class="faction">' + f.label + '</span>' +
        '<label>Floor <input type="number" class="num" id="' + prefix + f.key + '_floor" min="0" max="28" value="' + c.floor + '"></label>' +
        '<label>Ceiling <input type="number" class="num" id="' + prefix + f.key + '_ceil" min="0" max="28" value="' + c.ceil + '"></label>' +
        '</div>';
    }).join('') + '</div>';
  }

  // ---- controls ------------------------------------------------------------

  function rarityControls() {
    var p = state.p;
    return '' +
      '<section class="step-card">' +
        '<div class="step-head"><span class="step-num">1</span><span>Pick a starting point</span>' +
        '<span class="step-hint">then adjust anything below</span></div>' +
        '<div class="presets" id="presets">' + PRESETS.map(function (x) {
          return '<button type="button" data-preset="' + x.key + '"' +
            (state.preset === x.key ? ' class="on"' : '') + '>' +
            '<span class="preset-name">' + x.label + '</span>' +
            '<span class="preset-hint">' + esc(x.hint) + '</span></button>';
        }).join('') + '</div>' +
      '</section>' +

      '<section class="step-card">' +
        '<div class="step-head"><span class="step-num">2</span><span>Tune the roll</span>' +
        '<span class="step-hint">every unit rolls independently</span></div>' +
        '<div class="field-grid">' +
          field('rarity_chance', 'Rarity chance', p.rarity_chance.toFixed(2),
            'Probability to escalate one tier on each roll, up to 28 tiers.', 0, 1, 0.01, p.rarity_chance) +
          field('curse_chance', 'Curse chance', pct(p.curse_chance),
            'Cursed combat units are weaker across the board but much cheaper. 0 disables them.', 0, 0.5, 0.01, p.curse_chance) +
          field('trait_chance', 'Trait chance', pct(p.trait_chance),
            'Chance an archetyped unit also rolls a trait, e.g. Phantom or Juggernaut.', 0, 1, 0.01, p.trait_chance) +
          field('min_factory_rarity', 'Min factory rarity', p.min_factory_rarity,
            'Guaranteed pick per factory, floored at ' + badge(p.min_factory_rarity) + '.', 1, 28, 1, p.min_factory_rarity) +
          field('trait_min_rarity', 'Min trait rarity', p.trait_min_rarity,
            'Traits unlock at ' + badge(p.trait_min_rarity) + ' and above.', 1, 28, 1, p.trait_min_rarity) +
        '</div>' +
      '</section>' +

      '<section class="step-card">' +
        '<div class="step-head"><span class="step-num">3</span><span>Clamp factions</span>' +
        '<span class="step-hint">optional — leave 0–28 for no override</span></div>' +
        clampGrid('u_', state.clamp) +
        '<div class="note">Set one faction’s floor high to build a tougher AI opponent without touching everyone else’s rolls.</div>' +
      '</section>' +

      advancedCard();
  }

  function advancedCard() {
    var a = state.adv;
    return '<section class="card collapsible" id="advanced">' +
      '<button type="button" id="adv-toggle">' +
        '<span class="sign">' + (a.open ? '−' : '+') + '</span>Advanced — Part 2' +
        '<span class="meta">buildings + veterancy schools · slot tweakdefs1</span>' +
      '</button>' +
      '<div class="body" id="adv-body"' + (a.open ? '' : ' hidden') + '>' +
        '<div class="check-row"><label>' +
          '<input type="checkbox" id="adv-mirror"' + (a.mirror ? ' checked' : '') + '>' +
          'Mirror the roll settings above (rarity chance, trait chance, min trait rarity, faction clamps)' +
        '</label></div>' +
        '<div id="adv-own"' + (a.mirror ? ' hidden' : '') + '>' +
          '<div class="field-grid">' +
            field('p2_rarity_chance', 'Rarity chance', a.rarity_chance.toFixed(2),
              'Escalation chance for passive buildings.', 0, 1, 0.01, a.rarity_chance) +
            field('p2_trait_chance', 'Trait chance', pct(a.trait_chance),
              'Chance a high-rarity building with an archetype rolls a category trait.', 0, 1, 0.01, a.trait_chance) +
            field('p2_trait_min_rarity', 'Min trait rarity', a.trait_min_rarity,
              'Buildings unlock traits at ' + badge(a.trait_min_rarity) + ' and above.', 1, 28, 1, a.trait_min_rarity) +
          '</div>' +
          '<div class="sub-label" style="margin-top:var(--sp-11)">Faction clamps for Part 2</div>' +
          clampGrid('p_', a.clamp) +
        '</div>' +
        '<div class="field-grid">' +
          field('xp_chance', 'XP school chance', pct(a.xp_chance),
            'Chance an eligible unit rolls a veterancy school: Prodigy, Bloodthirsty, Ascendant, Trophy or Conscript.',
            0, 1, 0.01, a.xp_chance) +
          field('xp_min_rarity', 'Min XP school rarity', a.xp_min_rarity,
            'Schools unlock at ' + badge(a.xp_min_rarity) + ' and above.', 1, 28, 1, a.xp_min_rarity) +
          field('mentor_chance', 'Mentor chance', pct(a.mentor_chance),
            'Chance a lab or construction unit banks the xp of everything it builds and passes half of it on.',
            0, 1, 0.01, a.mentor_chance) +
        '</div>' +
      '</div>' +
    '</section>';
  }

  function factionControls() {
    var m = state.multiplier;
    var p = Math.round((m - 1) * 100);
    return '<section class="step-card">' +
      '<div class="step-head"><span class="step-num">1</span><span>Buff one faction</span>' +
      '<span class="step-hint">loads into tweakdefs2</span></div>' +
      '<div class="toggles" id="faction-toggles">' + FACTIONS.map(function (f) {
        return '<button type="button" data-faction="' + f.key + '"' +
          (state.faction === f.key ? ' class="on"' : '') + '>' + f.label + '</button>';
      }).join('') + '</div>' +
      '<div class="pct-row"><span class="pct" id="mult_out">' + (p >= 0 ? '+' : '') + p + '%</span>' +
      '<span class="pct-note">to HP, speed, damage, range, AoE and shields · reload divided by ' +
      '<span id="mult_raw">' + m.toFixed(2) + '</span></span></div>' +
      slider('multiplier', 1, 3, 0.05, m) +
      '<div class="note">Use it for players vs boosted AI, or asymmetric PvP handicaps. It does not change rarity rolls.</div>' +
      '</section>';
  }

  function tierControls() {
    return '<section class="step-card">' +
      '<div class="step-head"><span class="step-num">1</span><span>Tier lock</span>' +
      '<span class="step-hint">meme mode · no parameters</span></div>' +
      '<div class="ref-panel">' + DocsContent.tierLock + '</div>' +
      '</section>';
  }

  function welcomeControls() {
    var w = state.welcome;
    return '<section class="step-card">' +
      '<div class="step-head"><span class="step-num">1</span><span>Announce the mod in lobby chat</span>' +
      '<span class="step-hint">built from the settings above</span></div>' +
      '<div class="note" style="margin-top:0;margin-bottom:var(--sp-7)">One <code>!welcome-message</code> line, ' +
      'shown to everyone who joins. It quotes the roll you configured on the ' +
      '<strong>Rarity mod</strong> tab, so what people read is what they play.</div>' +
      '<div class="check-row" style="margin-bottom:var(--sp-7)">' +
        '<label><input type="checkbox" id="w-faction"' + (w.faction ? ' checked' : '') +
          '>Mention the faction buff</label>' +
        '<label><input type="checkbox" id="w-tiers"' + (w.tiers ? ' checked' : '') +
          '>Mention the tier lock</label>' +
      '</div>' +
      '<div class="note" style="margin-top:0">The finished line is in the block below, ' +
      'ready to paste into lobby chat.</div>' +
      '</section>';
  }

  // ---- rail ----------------------------------------------------------------

  // Expected roll spread, modelled on what mod.lua actually does to a combat unit.
  //
  //   get_rarity()      escalates one tier with probability rc, so the raw tier is
  //                     geometric: P(T >= n) = rc^n, capped at MAX_TIER.
  //   pass 1a           one unit per factory is rolled with get_rarity_min(m),
  //                     which starts the escalation at m = max(min factory rarity,
  //                     that faction's floor) — those units are never cursed.
  //   pass 1b           every other combat unit rolls plain, and is cursed first
  //                     with probability CURSE_CHANCE.
  //   both passes       clamp the result into the faction's [floor, ceiling].
  //
  // GUARANTEED_SHARE is measured against the live BAR unit list: 66 factories
  // with a combat option against 287 mobile armed non-builders.
  var MAX_TIER = 28;
  var GUARANTEED_SHARE = 66 / 287;

  // P(tier = n) for a plain roll clamped into [lo, hi]
  function clampedPMF(rc, lo, hi, start) {
    var pmf = [];
    var i;
    for (i = 0; i <= MAX_TIER; i++) pmf.push(0);
    if (lo > hi) { pmf[hi] = 1; return pmf; }
    var from = Math.max(start || 0, lo);
    if (from >= hi) { pmf[hi] = 1; return pmf; }
    for (i = from; i <= hi; i++) {
      if (i === hi) {
        pmf[i] = Math.pow(rc, hi - (start || 0));            // everything that would overshoot
      } else if (i === from && from > (start || 0)) {
        pmf[i] = 1 - Math.pow(rc, from - (start || 0) + 1);  // everything the floor lifts up
      } else {
        pmf[i] = Math.pow(rc, i - (start || 0)) * (1 - rc);
      }
    }
    return pmf;
  }

  function spread() {
    var rc = state.p.rarity_chance;
    var curse = state.p.curse_chance;
    var g = GUARANTEED_SHARE;
    var pmf = [];
    for (var i = 0; i <= MAX_TIER; i++) pmf.push(0);

    // units split roughly evenly across the three factions, each with its own clamp
    FACTIONS.forEach(function (f) {
      var lo = Math.max(0, Math.min(MAX_TIER, state.clamp[f.key].floor));
      var hi = Math.max(0, Math.min(MAX_TIER, state.clamp[f.key].ceil));
      var plain = clampedPMF(rc, lo, hi, 0);
      var guar = clampedPMF(rc, lo, hi, Math.max(state.p.min_factory_rarity, lo));
      for (var n = 0; n <= MAX_TIER; n++) {
        pmf[n] += ((1 - g) * (1 - curse) * plain[n] + g * guar[n]) / FACTIONS.length;
      }
    });
    return { pmf: pmf, cursed: (1 - g) * curse };
  }

  function distribution() {
    var s = spread();
    var rows = DocsContent.BANDS.map(function (b) {
      var share = 0;
      for (var n = b[1]; n <= Math.min(b[2], MAX_TIER); n++) share += s.pmf[n];
      return { label: b[0], token: b[3], text: b[4] || b[3], share: share };
    });
    if (s.cursed > 0) {
      rows.unshift({ label: 'Cursed', token: 'var(--rarity-cursed)', text: 'var(--rarity-cursed)', share: s.cursed });
    }
    rows = rows.filter(function (r) { return r.share > 0.0005; });
    var fmt = function (n) { return (n * 100 < 1 && n > 0 ? '<1' : Math.round(n * 100)) + '%'; };
    return '<div class="dist-bar">' + rows.map(function (r) {
        return '<div style="width:' + (r.share * 100) + '%;background:' + r.token + '"></div>';
      }).join('') + '</div>' +
      '<div class="dist-legend">' + rows.map(function (r) {
        return '<div title="' + esc(r.label) + '"><span class="swatch" style="background:' + r.token + '"></span>' +
          '<span class="label" style="color:' + r.text + '">' + esc(r.label) + '</span>' +
          '<span class="pct">' + fmt(r.share) + '</span></div>';
      }).join('') + '</div>';
  }

  function meterClass(len, limit) {
    if (len > limit) return 'danger';
    return len > limit * 0.855 ? 'warn' : 'ok';
  }

  function renderRail() {
    var out = state.output;
    var html = '';

    if (state.mode === 'rarity') {
      html += '<section class="card"><div class="rail-title">Expected roll spread</div>' +
        '<div id="dist">' + distribution() + '</div></section>';
    }

    html += '<section class="card"><div class="rail-title">Character budget</div>' +
      '<div id="meters"></div>' +
      '<div class="rail-hint">Payloads rebuild as you change the settings. ' +
      'Every lobby slot must stay under 16,384 characters.</div></section>';

    html += '<section class="card paste-order"><div class="head">Paste order</div>' +
      '<div>Units <code>!bset tweakdefs</code></div>' +
      '<div>Part 2 <code>!bset tweakdefs1</code></div>' +
      '<div>Faction buff <code>!bset tweakdefs2</code></div>' +
      '<div>Tier lock <code>!bset tweakdefs3</code></div>' +
      '<div class="tail">To see rarity names on units in-game you need the renamer widget: ' +
      '<a href="widgets/Tweakdefs_bridge.lua" download>download Tweakdefs Bridge</a> (v6+), ' +
      '<a href="how-it-works.html#widget">how to install it</a>.</div>' +
      '</section>';

    el('rail').innerHTML = html;
    updateMeters();
  }

  function updateMeters() {
    var box = el('meters');
    if (!box) return;
    box.innerHTML = (state.output || []).map(function (s) {
      if (!s.limit) return '';
      var cls = meterClass(s.value.length, s.limit);
      return '<div class="meter"><div class="row"><span>' + esc(s.title.split('—')[0].trim()) + '</span>' +
        '<span class="count ' + cls + '">' + s.value.length.toLocaleString() + ' / ' + s.limit.toLocaleString() + '</span></div>' +
        '<div class="track"><div class="fill fill-' + cls + '" style="width:' +
        Math.min(s.value.length / s.limit, 1) * 100 + '%"></div></div></div>';
    }).join('');
  }

  // ---- output --------------------------------------------------------------

  function renderOutput() {
    var out = state.output || [];
    el('output').innerHTML = out.map(function (s, i) {
      return '<section class="card">' +
        '<div class="out-head"><strong>' + esc(s.title) + '</strong>' +
        (s.command ? '<code>' + esc(s.command) + ' &lt;paste&gt;</code>' : '') +
        '<span class="count" id="cnt_' + i + '"></span></div>' +
        '<textarea class="out-area" readonly id="out_' + i + '"></textarea>' +
        '<button type="button" class="btn btn-copy" data-copy="' + i + '">Copy to clipboard</button>' +
        '</section>';
    }).join('');

    el('output').querySelectorAll('[data-copy]').forEach(function (b) {
      b.addEventListener('click', function () {
        var ta = el('out_' + b.dataset.copy);
        ta.select();
        if (navigator.clipboard) navigator.clipboard.writeText(ta.value);
        else document.execCommand('copy');
        b.textContent = 'Copied!';
        b.classList.add('copied');
        setTimeout(function () { b.textContent = 'Copy to clipboard'; b.classList.remove('copied'); }, 2000);
      });
    });
    updateOutput();
  }

  // Values only — the cards keep their identity so nothing flickers or jumps
  // while a slider is being dragged.
  function updateOutput() {
    (state.output || []).forEach(function (s, i) {
      var ta = el('out_' + i), cnt = el('cnt_' + i);
      if (!ta || !cnt) return;
      ta.value = s.command ? s.command + ' ' + s.value : s.value;
      cnt.textContent = s.value.length.toLocaleString() +
        (s.limit ? ' / ' + s.limit.toLocaleString() : '') + ' chars';
      cnt.className = 'count ' + (s.limit ? meterClass(s.value.length, s.limit) : '');
    });
  }

  // ---- reference -----------------------------------------------------------

  var REF_VIEWS = [
    { key: 'combat', label: 'Combat traits' },
    { key: 'buildings', label: 'Building traits' },
    { key: 'xp', label: 'Veterancy' },
    { key: 'tree', label: 'Archetype tree' },
    { key: 'install', label: 'Install' }
  ];

  function traitTable(cols, rows) {
    return '<div class="table-scroll"><table class="traits"><thead><tr>' + cols.map(function (c) { return '<th>' + c + '</th>'; }).join('') +
      '</tr></thead><tbody>' + rows.map(function (r) {
        return '<tr>' + r.map(function (c) { return '<td>' + esc(c) + '</td>'; }).join('') + '</tr>';
      }).join('') + '</tbody></table></div>';
  }

  function tree() {
    var out = ['<div class="tree"><div class="row">Rarity 5+ unit</div>'];
    DocsContent.TREE.forEach(function (branch, bi) {
      var lastBranch = bi === DocsContent.TREE.length - 1;
      out.push('<div class="row">' + (lastBranch ? '└─ ' : '├─ ') +
        '<span class="branch">' + esc(branch[1]) + '</span></div>');
      var pad = lastBranch ? '   ' : '│  ';
      branch[3].forEach(function (node, ni) {
        var lastNode = ni === branch[3].length - 1;
        out.push('<div class="row">' + pad + (lastNode ? '└─ ' : '├─ ') +
          '<span class="' + node[0] + '">' + esc(node[1]) + '</span>' +
          (node[2] ? '  <span class="stats">' + esc(node[2]) + '</span>' : '') + '</div>');
        var pad2 = pad + (lastNode ? '   ' : '│  ');
        node[3].forEach(function (t, ti) {
          var parts = t.split('—');
          out.push('<div class="row">' + pad2 + (ti === node[3].length - 1 ? '└─ ' : '├─ ') +
            '<span class="trait">' + esc(parts[0].trim()) + '</span>' +
            (parts[1] ? ' <span class="effect">' + esc(parts[1].trim()) + '</span>' : '') + '</div>');
        });
      });
    });
    return out.join('') + '</div>';
  }

  function refBody() {
    switch (state.refView) {
      case 'combat': return traitTable(['Trait', 'Archetypes', 'Effect'], DocsContent.COMBAT_TRAITS);
      case 'buildings': return traitTable(['Trait', 'Category', 'Effect'], DocsContent.BUILDING_TRAITS);
      case 'xp': return traitTable(['School', 'Effect on power', 'What it does'], DocsContent.XP_SCHOOLS);
      case 'tree': return tree();
      default: return '<div class="ref-panel">' + DocsContent.installSteps + DocsContent.widgetInfo + '</div>';
    }
  }

  function renderReference() {
    el('reference').innerHTML = '<section class="card collapsible">' +
      '<button type="button" id="ref-toggle"><span class="sign">' + (state.refOpen ? '−' : '+') + '</span>Reference' +
      '<span class="meta">13 combat traits · 18 building traits · 6 schools · archetype tree · install</span></button>' +
      '<div class="body" id="ref-body"' + (state.refOpen ? '' : ' hidden') + '>' +
        '<div class="segmented ref-switch" id="ref-switch">' + REF_VIEWS.map(function (v) {
          return '<button type="button" data-ref="' + v.key + '"' +
            (state.refView === v.key ? ' class="on"' : '') + '>' + v.label + '</button>';
        }).join('') + '</div>' +
        '<div id="ref-panel">' + refBody() + '</div>' +
      '</div></section>';

    el('ref-toggle').addEventListener('click', function () {
      state.refOpen = !state.refOpen;
      renderReference();
    });
    el('ref-switch').addEventListener('click', function (e) {
      var b = e.target.closest('[data-ref]');
      if (!b) return;
      state.refView = b.dataset.ref;
      renderReference();
    });
  }

  // ---- wiring --------------------------------------------------------------

  function bindSlider(id, apply, readout, desc) {
    var range = el(id), num = el(id + '_num');
    if (!range) return;
    var push = function (v) {
      v = parseFloat(v);
      if (isNaN(v)) return;
      range.value = v; num.value = v;
      apply(v);
      if (readout) el(id + '_out').innerHTML = readout(v);
      if (desc) el(id + '_desc').innerHTML = desc(v);
      redrawSpread();
      refresh();
    };
    range.addEventListener('input', function () { push(range.value); });
    num.addEventListener('input', function () { push(num.value); });
  }

  function redrawSpread() {
    if (state.mode === 'rarity' && el('dist')) el('dist').innerHTML = distribution();
  }

  function bindClamps(prefix, target, affectsSpread) {
    FACTIONS.forEach(function (f) {
      ['floor', 'ceil'].forEach(function (k) {
        var input = el(prefix + f.key + '_' + k);
        if (!input) return;
        input.addEventListener('input', function () {
          var v = parseInt(input.value, 10);
          if (isNaN(v)) return;
          target[f.key][k] = Math.max(0, Math.min(28, v));
          // the unit clamps are part of the spread; Part 2's own clamps are not
          if (affectsSpread) redrawSpread();
          refresh();
        });
      });
    });
  }

  function unpreset() {
    state.preset = null;
    var on = document.querySelector('#presets .on');
    if (on) on.classList.remove('on');
  }

  function renderControls() {
    var html = state.mode === 'rarity' ? rarityControls()
      : state.mode === 'faction' ? factionControls()
      : state.mode === 'tiers' ? tierControls() : welcomeControls();
    el('controls').innerHTML = html;

    if (state.mode === 'rarity') {
      el('presets').addEventListener('click', function (e) {
        var b = e.target.closest('[data-preset]');
        if (!b) return;
        var preset = PRESETS.filter(function (x) { return x.key === b.dataset.preset; })[0];
        state.preset = preset.key;
        state.p = copy(preset.p);
        renderControls();
        renderRail();
        refresh(true);
      });

      bindSlider('rarity_chance', function (v) { unpreset(); state.p.rarity_chance = v; },
        function (v) { return v.toFixed(2); });
      bindSlider('curse_chance', function (v) { unpreset(); state.p.curse_chance = v; }, pct);
      bindSlider('trait_chance', function (v) { unpreset(); state.p.trait_chance = v; }, pct);
      bindSlider('min_factory_rarity', function (v) { unpreset(); state.p.min_factory_rarity = v; },
        function (v) { return v; },
        function (v) { return 'Guaranteed pick per factory, floored at ' + badge(v) + '.'; });
      bindSlider('trait_min_rarity', function (v) { unpreset(); state.p.trait_min_rarity = v; },
        function (v) { return v; },
        function (v) { return 'Traits unlock at ' + badge(v) + ' and above.'; });
      bindClamps('u_', state.clamp, true);

      el('adv-toggle').addEventListener('click', function () {
        state.adv.open = !state.adv.open;
        renderControls();
      });
      el('adv-mirror').addEventListener('change', function (e) {
        state.adv.mirror = e.target.checked;
        el('adv-own').hidden = state.adv.mirror;
        refresh(true);
      });
      bindSlider('p2_rarity_chance', function (v) { state.adv.rarity_chance = v; }, function (v) { return v.toFixed(2); });
      bindSlider('p2_trait_chance', function (v) { state.adv.trait_chance = v; }, pct);
      bindSlider('p2_trait_min_rarity', function (v) { state.adv.trait_min_rarity = v; },
        function (v) { return v; },
        function (v) { return 'Buildings unlock traits at ' + badge(v) + ' and above.'; });
      bindSlider('xp_chance', function (v) { state.adv.xp_chance = v; }, pct);
      bindSlider('xp_min_rarity', function (v) { state.adv.xp_min_rarity = v; },
        function (v) { return v; },
        function (v) { return 'Schools unlock at ' + badge(v) + ' and above.'; });
      bindSlider('mentor_chance', function (v) { state.adv.mentor_chance = v; }, pct);
      bindClamps('p_', state.adv.clamp, false);
    }

    if (state.mode === 'welcome') {
      ['faction', 'tiers'].forEach(function (k) {
        el('w-' + k).addEventListener('change', function (e) {
          state.welcome[k] = e.target.checked;
          refresh(true);
        });
      });
    }

    if (state.mode === 'faction') {
      el('faction-toggles').addEventListener('click', function (e) {
        var b = e.target.closest('[data-faction]');
        if (!b) return;
        state.faction = b.dataset.faction;
        renderControls();
        refresh(true);
      });
      bindSlider('multiplier', function (v) {
        state.multiplier = v;
        var p = Math.round((v - 1) * 100);
        el('mult_out').textContent = (p >= 0 ? '+' : '') + p + '%';
        el('mult_raw').textContent = v.toFixed(2);
      });
    }
  }

  function renderModes() {
    el('mode-switch').innerHTML = MODES.map(function (m) {
      return '<button type="button" data-mode="' + m.key + '"' +
        (state.mode === m.key ? ' class="on"' : '') + '>' + m.label + '</button>';
    }).join('');
    el('mode-switch').addEventListener('click', function (e) {
      var b = e.target.closest('[data-mode]');
      if (!b || b.dataset.mode === state.mode) return;
      state.mode = b.dataset.mode;
      state.output = build();
      renderModes();
      renderControls();
      renderOutput();
      renderRail();
    });
  }

  function loadVersion() {
    fetch('https://api.github.com/repos/bazilio91/beyond-all-random/releases/latest')
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.tag_name) return;
        el('version').textContent = d.tag_name;
        el('changelog').href = d.html_url;
      })
      .catch(function () { el('version').hidden = true; });
  }

  state.output = build();
  renderModes();
  renderControls();
  renderOutput();
  renderRail();
  renderReference();
  loadVersion();
})();
