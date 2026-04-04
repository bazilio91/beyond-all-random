#!/usr/bin/env node
// Generates buildings-template.js segments from minified mod_buildings.lua (stdin).
// Usage: luamin -c < mod_buildings.lua | node scripts/generate_buildings_segments.js

const fs = require("fs");

const min = fs.readFileSync("/dev/stdin", "utf8").trim();

// Split at parameter injection points:
//   local b=<rarity_chance>;local c=<trait_chance>;local d=<trait_min_rarity>;
//   local e={<arm_floor>,<cor_floor>,<leg_floor>}
//   local f={<arm_ceil>,<cor_ceil>,<leg_ceil>}

const anchor = "local b=0.75;";
const idx = min.indexOf(anchor);
if (idx === -1) {
  console.error("Cannot find 'local b=0.75;' in minified output");
  process.exit(1);
}

let pos = idx + "local b=".length;
const seg0 = min.substring(0, pos);

function advance(defaultVal, delimiter) {
  const expected = defaultVal + delimiter;
  const actual = min.substring(pos, pos + expected.length);
  if (actual !== expected) {
    console.error(`Expected '${expected}' at position ${pos}, got '${actual}'`);
    process.exit(1);
  }
  pos += defaultVal.length;
  const seg = min.substring(pos, pos + delimiter.length);
  pos += delimiter.length;
  return seg;
}

const seg1  = advance("0.75", ";local c=");
const seg2  = advance("0.5",  ";local d=");
const seg3  = advance("5",    ";local e={");
const seg4  = advance("0",    ",");
const seg5  = advance("0",    ",");
const seg6  = advance("0",    "}local f={");
const seg7  = advance("28",   ",");
const seg8  = advance("28",   ",");

const lastDefault = "28";
if (min.substring(pos, pos + lastDefault.length) !== lastDefault) {
  console.error(`Expected '${lastDefault}' at position ${pos}`);
  process.exit(1);
}
pos += lastDefault.length;
const seg9 = min.substring(pos);

const segments = [seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9];

// Verify round-trip
const defaults = {
  rarity_chance: 0.75, TRAIT_CHANCE: 0.5, TRAIT_MIN_RARITY: 5,
  arm_floor: 0, cor_floor: 0, leg_floor: 0,
  arm_ceil: 28, cor_ceil: 28, leg_ceil: 28
};
const reconstructed = segments[0] + defaults.rarity_chance
  + segments[1] + defaults.TRAIT_CHANCE
  + segments[2] + defaults.TRAIT_MIN_RARITY
  + segments[3] + defaults.arm_floor
  + segments[4] + defaults.cor_floor
  + segments[5] + defaults.leg_floor
  + segments[6] + defaults.arm_ceil
  + segments[7] + defaults.cor_ceil
  + segments[8] + defaults.leg_ceil
  + segments[9];

if (reconstructed !== min) {
  console.error("FATAL: reconstructed output does not match minified input");
  process.exit(1);
}

// Read current buildings-template.js to preserve header
const templatePath = "docs/js/buildings-template.js";
let header = '--BaRandom Buildings v0 by LoH';
try {
  const current = fs.readFileSync(templatePath, "utf8");
  const m = current.match(/header:\s*"([^"]+)"/);
  if (m) header = m[1];
} catch (e) {}

const segLines = segments.map((s, i) =>
  "    " + JSON.stringify(s) + (i < segments.length - 1 ? "," : "")
).join("\n");

const output = `const BuildingsTemplate = {
  header: ${JSON.stringify(header)},
  segments: [
${segLines}
  ],
  build: function(params) {
    var p = {
      rarity_chance: 0.75, TRAIT_CHANCE: 0.5, TRAIT_MIN_RARITY: 5,
      arm_floor: 0, cor_floor: 0, leg_floor: 0,
      arm_ceil: 28, cor_ceil: 28, leg_ceil: 28
    };
    for (var k in params) p[k] = params[k];
    var body = this.segments[0] + p.rarity_chance
             + this.segments[1] + p.TRAIT_CHANCE
             + this.segments[2] + p.TRAIT_MIN_RARITY
             + this.segments[3] + p.arm_floor
             + this.segments[4] + p.cor_floor
             + this.segments[5] + p.leg_floor
             + this.segments[6] + p.arm_ceil
             + this.segments[7] + p.cor_ceil
             + this.segments[8] + p.leg_ceil
             + this.segments[9];
    return Pipeline.build(this.header, body);
  }
};
`;

fs.writeFileSync(templatePath, output);
console.error("Generated " + templatePath + " (" + segments.length + " segments, verified)");
