// Reference content for the builder page.
// Trait/tree data mirrors the design system's Reference card
// (ui_kits/web_builder/RedesignParts.jsx); prose is the site's own.

var DocsContent = {

  RARITIES: [
    'Common', 'Uncommon', 'Rare', 'Exceptional', 'Epic', 'Exotic', 'Legendary',
    'Mythical', 'Miracle', 'Divine', 'Eternal', 'Supreme', 'Omega', 'Unique',
    'Jackpot', 'Immortal', 'Absurd', 'Godlike', 'TooRNG', 'Insanely Lucky', 'Dope',
    'Admin', 'GOD', 'ERROR', 'Super Sayan', 'Beyond', 'MGGW', 'AMBO', 'Beyond All Reason'
  ],

  // tier -> rarity colour token, matching rarityColor() in the in-game viewer
  rarityToken: function(tier) {
    if (tier < 0) return 'var(--rarity-cursed)';
    if (tier === 0) return 'var(--rarity-common)';
    if (tier <= 2) return 'var(--rarity-low)';
    if (tier <= 4) return 'var(--rarity-mid)';
    if (tier <= 6) return 'var(--rarity-high)';
    if (tier <= 10) return 'var(--rarity-epic)';
    if (tier <= 15) return 'var(--rarity-mythic)';
    if (tier <= 20) return 'var(--rarity-divine)';
    if (tier <= 25) return 'var(--rarity-absurd)';
    return 'var(--rarity-beyond)';
  },

  // Distribution bands: [label, lowest tier, highest tier, colour token]
  BANDS: [
    ['Common – Rare', 0, 2, 'var(--rarity-low)', 'var(--text-2)'],
    ['Exceptional – Epic', 3, 4, 'var(--rarity-mid)'],
    ['Exotic – Legendary', 5, 6, 'var(--rarity-high)'],
    ['Mythical – Eternal', 7, 10, 'var(--rarity-epic)'],
    ['Supreme – Absurd', 11, 15, 'var(--rarity-mythic)'],
    ['Godlike – Dope', 16, 20, 'var(--rarity-divine)'],
    ['Admin – Beyond', 21, 25, 'var(--rarity-absurd)'],
    ['MGGW – Beyond All Reason', 26, 28, 'var(--rarity-beyond)']
  ],

  COMBAT_TRAITS: [
    ['Phantom', 'Glass Cannon, Sniper, Watchtower', 'Cloaking while stationary or slow-moving. Reduced HP.'],
    ['Volatile', 'Glass Cannon', '+30% damage, −40% HP. Extreme glass cannon.'],
    ['Overcharged', 'Glass Cannon', '+20% faster reload, +50% energy per shot.'],
    ['Juggernaut', 'Tank, Fortress', '+60% HP, −30% speed, −25% turn rate (Tank only).'],
    ['Regenerator', 'Tank', '3× idle auto-heal (15 hp/s).'],
    ['Fortified', 'Tank', '+30% HP, +20% slower reload.'],
    ['Marksman', 'Sniper, Watchtower', '+30% range, +30% better accuracy, −30% AoE.'],
    ['Piercing', 'Sniper', '+20% damage, −50% AoE. Single-target focus.'],
    ['Swift', 'Brawler', '+40% speed, +30% acceleration, −30% HP.'],
    ['Berserker', 'Brawler, Suppressor', '+20–30% damage, +30% AoE, worse accuracy.'],
    ['Siege', 'Brawler, Suppressor', '+40% AoE, +15% damage, −15% speed or worse accuracy.'],
    ['Shielded', 'Fortress', '+40% shield power, +20% shield radius.'],
    ['Siren', 'Fortress, Suppressor', 'Extreme knockback on hit. +15% AoE, −30% damage.']
  ],

  BUILDING_TRAITS: [
    ['Deep Bore', 'Metal Extractor', '+50% extraction, +30% build time.'],
    ['Volatile Vein', 'Metal Extractor', '+30% extraction, explodes on death.'],
    ['Metamorphic', 'Metal Extractor, Energy', 'Auto-evolves into the T2 version after 5 minutes.'],
    ['Surge', 'Energy', '+60% energy output, explodes on death.'],
    ['Efficient Core', 'Energy', '−30% cost, +20% energy output.'],
    ['Gale Force', 'Wind/Tidal', '+80% output, −30% HP. Fragile but productive.'],
    ['Anchored', 'Wind/Tidal', '+50% HP, +20% output, −20% cost.'],
    ['Refined Process', 'Converter', '+30% efficiency, +20% capacity.'],
    ['Bulk Conversion', 'Converter', '2× capacity, −10% efficiency.'],
    ['All-Seeing', 'Radar', '2× radar range, 2× LOS.'],
    ['Shroud', 'Radar', 'Gains radar jamming at half radar range.'],
    ['Resilient', 'Radar, Sonar, Generic', '3× HP, 70% EMP resistance.'],
    ['Deep Scan', 'Sonar', '2× sonar range, +50% LOS.'],
    ['Blackout', 'Jammer', '+80% jam range, +40% energy upkeep.'],
    ['Stealth Field', 'Jammer', '+30% jam range, +50% HP, −10% upkeep.'],
    ['Vault', 'Storage', '3× capacity, +50% HP.'],
    ['Volatile Reserve', 'Storage', '2× capacity, explodes on death.'],
    ['Bunker', 'Walls, teeth, misc', '2.5× HP, +50% LOS.']
  ],

  XP_SCHOOLS: [
    ['Prodigy', 'power ×0.08', 'Learns ~12× faster, HP ×0.92. Ramps to +250% HP and +125% rate of fire.'],
    ['Bloodthirsty', 'power ×0.20', 'HP ×0.85, damage ×1.06. Fragile duelist that snowballs on kills.'],
    ['Ascendant', 'power ×0.15', 'Evolves into a costlier unit from the same lab once it earns enough xp.'],
    ['Trophy', 'power ×8', 'Never veterans and feeds the killer xp, but +35% HP and +10% damage.'],
    ['Conscript', 'power ×3', 'Cheap fodder: −15% cost, slow learner.'],
    ['Mentor', 'builders', 'A lab banks the xp of everything it built and stamps half of it on the next unit.']
  ],

  TREE: [
    ['branch', 'Combat Unit', '', [
      ['arch', 'Glass Cannon', 'HP 0.88 · Dmg 1.12 · Rld 0.91', ['Phantom — cloak, −15% HP', 'Volatile — +30% dmg, −40% HP', 'Overcharged — −20% reload']],
      ['arch', 'Tank', 'HP 1.22 · Dmg 1.01 · Rld 0.97', ['Juggernaut — +60% HP, −30% spd', 'Regenerator — 3× autoheal', 'Fortified — +30% HP']],
      ['arch', 'Sniper', 'HP 1.03 · Rng 1.14 · Acc 0.91', ['Marksman — +30% rng, +30% acc', 'Piercing — +20% dmg, −50% AoE']],
      ['arch', 'Brawler', 'Spd 1.10 · AoE 1.10 · Rld 0.88', ['Swift — +40% spd, −30% HP', 'Siege — +40% AoE, +15% dmg']],
      ['arch', 'Fortress', 'HP 1.20 · Dmg 1.08', ['Shielded — +40% shield', 'Siren — knockback']],
      ['arch', 'Watchtower', 'HP 1.03 · Rng 1.14', ['Marksman — +30% rng']],
      ['arch', 'Suppressor', 'AoE 1.12 · Rld 0.88', ['Berserker — +30% dmg']]
    ]],
    ['branch', 'Passive Building', '', [
      ['cat', 'Metal Extractor', '', ['Deep Bore — +50% extraction', 'Metamorphic — evolves to T2']],
      ['cat', 'Energy', '', ['Surge — +60% output', 'Efficient Core — −30% cost']],
      ['cat', 'Wind / Tidal', '', ['Gale Force — +80% output', 'Anchored — +50% HP']],
      ['cat', 'Radar', '', ['All-Seeing — 2× radar', 'Shroud — gains jamming']],
      ['cat', 'Storage', '', ['Vault — 3× capacity', 'Volatile Reserve — explodes']]
    ]]
  ],

  tierLock: [
    '<p>Rolls a random tech tier (T1, T2 or T3) at load and locks the buildable combat roster to that tier. Eco and utility &mdash; mex, solar, wind/tidal, fusion, geo, converter, storage, radar, sonar, jammer, nano turret, commander &mdash; stay available at every tier. Only <strong>combat, labs and defensive turrets</strong> get capped.</p>',
    '<ul>',
    '<li><strong>T1 roll</strong> &mdash; only T1 labs, combat and defense. Classic slugfest.</li>',
    '<li><strong>T2 roll</strong> &mdash; commanders build T2 labs directly, at T1 cost. No T1 units, no gantries.</li>',
    '<li><strong>T3 roll</strong> &mdash; commanders build gantries at T1 bot lab cost, and gantries get T2 cons appended so the economy stays reachable. Experimentals only.</li>',
    '</ul>',
    '<p>Costs of surviving higher-tier labs are flattened to their T1 equivalent per category, so the opening stays smooth. The roll is client-synced &mdash; everyone in the match plays the same tier.</p>'
  ].join(''),

  installSteps: [
    '<h3>Paste order</h3>',
    '<ol>',
    '<li>Configure the roll &mdash; the payloads rebuild as you go.</li>',
    '<li>Units payload &rarr; <code>!bset tweakdefs &lt;paste&gt;</code></li>',
    '<li>Part 2 payload (buildings + veterancy) &rarr; <code>!bset tweakdefs1 &lt;paste&gt;</code></li>',
    '<li>Faction buff, if you want one &rarr; <code>!bset tweakdefs2 &lt;paste&gt;</code></li>',
    '<li>Tier lock, if you want it &rarr; <code>!bset tweakdefs3 &lt;paste&gt;</code></li>',
    '<li>Install the renamer widget to see rarities in-game.</li>',
    '</ol>',
    '<p>Each payload must stay under 16,384 characters &mdash; the budget on the right tracks every slot live. ',
    'New here? The <a href="how-it-works.html">how it works</a> page answers the rest.</p>'
  ].join(''),

  widgetInfo: [
    '<h3>Renamer widgets</h3>',
    '<p>Drop these into <code>data/LuaUI/Widgets/</code> in your BAR install folder, then enable them in Settings &rarr; Custom.</p>',
    '<p><strong>Required:</strong> <a href="widgets/Tweakdefs_bridge.lua" download>Tweakdefs Bridge</a> v6 (2026-05-17 or newer) &mdash; renames units to show rarity, archetype and trait. Older builds read only one half of the mod, so half the prefixes go missing; replace any bridge installed before May 2026.</p>',
    '<p><strong>Optional:</strong> <a href="widgets/random_stats_viewer.lua" download>Stats Viewer</a> &mdash; in-game panel listing every unit with its roll. Toggle with <code>/unitstats</code>.</p>'
  ].join('')
};
