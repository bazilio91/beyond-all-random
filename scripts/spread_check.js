#!/usr/bin/env node
// Reference numbers for the builder's "Expected roll spread".
//
//   node scripts/spread_check.js
//
// Monte-Carlos mod.lua's actual assignment for combat units — pass 1a's
// guaranteed picks (never cursed, escalation starts at the min factory rarity),
// pass 1b's plain rolls with the curse check first, and the per-faction clamps
// both passes apply — then prints the band shares. Compare them against the
// legend the rail renders in docs/js/app.js for the same settings; the analytic
// model there should land within a percentage point of these.
const MAX = 28;
const BANDS = [['Common–Rare',0,2],['Exceptional–Epic',3,4],['Exotic–Legendary',5,6],
  ['Mythical–Eternal',7,10],['Supreme–Absurd',11,15],['Godlike–Dope',16,20],
  ['Admin–Beyond',21,25],['MGGW–BAR',26,28]];

function getRarity(rc, start) {            // mirrors get_rarity(x)
  let x = start || 0;
  while (x + 1 <= MAX && Math.random() < rc) x++;
  return x;
}

function run(cfg, N) {
  const COMBAT = 287, FACTORIES = 66;
  const counts = new Array(MAX + 1).fill(0);
  let cursed = 0, total = 0;
  for (let it = 0; it < N; it++) {
    for (let u = 0; u < COMBAT; u++) {
      const f = ['arm', 'cor', 'leg'][Math.floor(Math.random() * 3)];
      const lo = cfg.clamp[f].floor, hi = cfg.clamp[f].ceil;
      total++;
      if (u < FACTORIES) {                  // pass 1a — guaranteed, never cursed
        let r = getRarity(cfg.rc, Math.max(cfg.minFactory, lo));
        if (r > hi) r = hi;
        counts[r]++;
      } else if (Math.random() < cfg.curse) {   // pass 1b — curse first
        cursed++;
      } else {
        let r = getRarity(cfg.rc, 0);
        if (r < lo) r = lo;
        if (r > hi) r = hi;
        counts[r]++;
      }
    }
  }
  const out = { Cursed: cursed / total };
  BANDS.forEach(([label, a, b]) => {
    let s = 0;
    for (let n = a; n <= b; n++) s += counts[n] / total;
    out[label] = s;
  });
  return out;
}

const CASES = {
  'classic (0.75 / curse .2 / minF 7 / 0-28)':
    { rc: 0.75, curse: 0.2, minFactory: 7, clamp: { arm:{floor:0,ceil:28}, cor:{floor:0,ceil:28}, leg:{floor:0,ceil:28} } },
  'minFactory 20':
    { rc: 0.75, curse: 0.2, minFactory: 20, clamp: { arm:{floor:0,ceil:28}, cor:{floor:0,ceil:28}, leg:{floor:0,ceil:28} } },
  'no curse, minFactory 1':
    { rc: 0.75, curse: 0, minFactory: 1, clamp: { arm:{floor:0,ceil:28}, cor:{floor:0,ceil:28}, leg:{floor:0,ceil:28} } },
  'legion floor 10, arm ceil 4':
    { rc: 0.75, curse: 0.2, minFactory: 7, clamp: { arm:{floor:0,ceil:4}, cor:{floor:0,ceil:28}, leg:{floor:10,ceil:28} } },
  'tame (0.45 / curse .1 / minF 4)':
    { rc: 0.45, curse: 0.1, minFactory: 4, clamp: { arm:{floor:0,ceil:28}, cor:{floor:0,ceil:28}, leg:{floor:0,ceil:28} } }
};
const which = process.argv[2];
for (const [name, cfg] of Object.entries(CASES)) {
  if (which && name.indexOf(which) < 0) continue;
  const r = run(cfg, 400);
  console.log('== ' + name);
  console.log('   ' + Object.entries(r).filter(([, v]) => v > 0.0005)
    .map(([k, v]) => k + '=' + (v * 100).toFixed(1) + '%').join('  '));
}
