#!/usr/bin/env node
// Generates tiers-template.js from minified mod_tiers.lua (stdin).
// Usage: luamin -c < mod_tiers.lua | node scripts/generate_tiers_segments.js
//
// Unlike the units/buildings templates, tier-lock has no user-tunable
// parameters, so the whole minified Lua ships as a single string.

const fs = require("fs");

const min = fs.readFileSync(0, "utf8").trim();

const templatePath = "docs/js/tiers-template.js";
// Header line is the first line of mod_tiers.lua (keeps version in sync with the source).
let header = "--BaRandom Tiers v0 by LoH";
try {
	const src = fs.readFileSync("mod_tiers.lua", "utf8");
	const firstLine = src.split(/\r?\n/)[0];
	if (firstLine.startsWith("--")) header = firstLine;
} catch (e) {}

const output = `const TiersTemplate = {
  header: ${JSON.stringify(header)},
  body: ${JSON.stringify(min)},
  build: function() {
    return Pipeline.build(this.header, this.body);
  }
};
`;

fs.writeFileSync(templatePath, output);
console.error("Generated " + templatePath + " (" + min.length + " chars minified)");
