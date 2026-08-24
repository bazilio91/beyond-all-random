--BaRandom Part 2 v28 by LoH
rename_list = {}
local rarities = {	"Uncommon","Rare","Exceptional","Epic","Exotic",
			"Legendary","Mythical","Miracle","Divine","Eternal",
			"Supreme","Omega","Unique", "Jackpot","Immortal",
			"Absurd","Godlike","TooRNG","Insanely Lucky","Dope",
			"Admin","GOD","ERROR","Super Sayan","Beyond",
			"MGGW","AMBO","Beyond All Reason"
}

local rarity_chance = 0.75
local TRAIT_CHANCE = 0.5
local TRAIT_MIN_RARITY = 5
local rf={0,0,0}
local rx={28,28,28}
-- XP knobs, injectable independently of the building ones above
local XP_CHANCE = 0.35
local XP_MIN_RARITY = 4
local MENTOR_CHANCE = 0.3

local FALLBACK_RARITY = 5        -- assumed rarity when mod.lua is not loaded
local ASCEND_MIN_COST = 1.25     -- ascension target must cost >= this x self
local ASCEND_XP_BASE = 0.35      -- xp threshold = BASE + metalcost * PER_METAL
local ASCEND_XP_PER_METAL = 0.00067
local ASCEND_XP_CAP = 5
local COMMANDERS = {armcom=true, corcom=true, legcom=true}

-- {name, power multiplier, label, {stat tweaks}, ascends?}
local SCHOOLS = {
	{"Prodigy",      0.08, "x12", {hp=0.92}},
	{"Bloodthirsty", 0.20, "x5",  {hp=0.85, dmg=1.06}},
	{"Ascendant",    0.15, "x7",  {hp=0.95}, true},
	{"Trophy",       8.00, "/8",  {hp=1.35, dmg=1.10}},
	{"Conscript",    3.00, "/3",  {hp=0.95, cost=0.85}},
}

local MENTOR_POWER = 0.25
local MENTOR_INHERIT = "0.5"
local MENTOR_TYPES = "MOBILEBUILT TURRET DRONE BOTCANNON"

local function get_rarity(x)
	local x = x or 0
	if x + 1 <= #rarities and math.random() < rarity_chance then
			x = get_rarity(x+1)
	end
	return x
end

local function set_v(x,m,r,f,em)
	x = tonumber(x)
	if x then
		local t = x*(m^r)+((m-1)*x)
		if x > 0 and t <= 0 then t = x*(m^r) end
		if f then t = math.floor(t) end
		return t*(em or 1)
	end
end

local function sv(t,k,m,r,f) t[k]=set_v(t[k],m,r,f) end
local function mck(ud) return ud.metalcost and "metalcost" or "buildcostmetal" end
local function tm_a(t,k,m,f) local v=tonumber(t[k])if m and v then t[k]=v*m;if f then t[k]=math.floor(t[k])end end end
local function fi(n) return n:byte()==99 and 2 or n:byte()==108 and 3 or 1 end

-- Which field carries a building's energy output. Solars have no energymake:
-- they generate through a *negative* energyupkeep, so upkeep is their output
-- field and multipliers meant for real upkeep must not touch it.
local function energy_out(ud)
	if ud.energymake and ud.energymake > 0 then return "energymake" end
	if ud.energyupkeep and ud.energyupkeep < 0 then return "energyupkeep" end
end

-- Building category detection (priority order)
local function get_category(ud)
	if ud.extractsmetal and ud.extractsmetal > 0 then return "mex" end
	local cp = ud.customparams
	if cp and cp.energyconv_capacity then return "converter" end
	if ud.windgenerator or ud.tidalgenerator then return "windtidal" end
	if ud.radardistancejam and ud.radardistancejam > 0 then return "jammer" end
	if ud.radardistance and ud.radardistance > 0 then return "radar" end
	if ud.sonardistance and ud.sonardistance > 0 then return "sonar" end
	-- BAR normalises buildoptions to an empty table before tweakdefs run, so a
	-- bare truthiness test files every passive building as a factory.
	if ud.buildoptions and next(ud.buildoptions) ~= nil then return "factory" end
	if ud.builder == true then return "nano" end
	-- Before storage: fusions, AFUS and geos ship 2.5k-90k energystorage and
	-- would otherwise be filed as storage buildings.
	if energy_out(ud) then return "energy" end
	local ms = ud.metalstorage or 0
	local es = ud.energystorage or 0
	if ms > 500 or es > 500 then return "storage" end
	return "generic"
end

-- Building archetypes: {name, m_hp, m_cost, m_output, m_upkeep}
local BAT = {
	{"Efficient",   0.9, 0.8, 1.15, 0.9},
	{"Fortified",   1.5, 1.1, 1.0,  1.0},
	{"Overclocked", 0.8, 1.0, 1.4,  1.3},
}

-- Evolution targets: T1 unit → T2 unit per faction.
-- unit_evolution.lua re-creates the unit at the same position, so a target with
-- a different footprint overlaps its neighbours and — when the parity changes
-- (5x5 -> 4x4) — lands off the build grid. same_footprint() drops those pairs:
-- armsolar/corsolar -> advsol is exactly that case, hence the geo pairs below.
local EVO_MEX = {armmex="armmoho", cormex="cormoho", legmex="legmext15"}
local EVO_ENERGY = {
	armsolar="armadvsol", corsolar="coradvsol", legsolar="legadvsol",
	armgeo="armageo", corgeo="corageo", leggeo="legageo",
}

local function same_fp(a, b)
	return a ~= nil and b ~= nil
	   and (tonumber(a.footprintx) or 1) == (tonumber(b.footprintx) or 1)
	   and (tonumber(a.footprintz) or 1) == (tonumber(b.footprintz) or 1)
end

-- Validated once at load: drops pairs with a footprint mismatch and pairs whose
-- target is not in this game (Legion off, unit list trimmed). The surviving list
-- is echoed so a bad pair is visible without waiting for the roll to hit it.
local evo_pairs = {}
local function prune_evo(t)
	for from, to in pairs(t) do
		if same_fp(UnitDefs[from], UnitDefs[to]) then
			evo_pairs[#evo_pairs+1] = from .. ">" .. to
		else
			t[from] = nil
		end
	end
end
prune_evo(EVO_MEX)
prune_evo(EVO_ENERGY)
table.sort(evo_pairs)
Spring.Echo("[BaRandom Part 2] evo: " .. table.concat(evo_pairs, " "))

-- Building trait pools keyed by category
local BTRAITS = {
	mex = {
		{"Deep Bore",      {em=1.5, bt=1.3}},
		{"Volatile Vein",  {em=1.3, death=true}},
		{"Metamorphic",    {evo="mex"}},
	},
	energy = {
		{"Surge",          {out=1.6, death=true}},
		{"Efficient Core", {mc=0.7, out=1.2}},
		{"Metamorphic",    {evo="energy"}},
	},
	windtidal = {
		{"Gale Force",     {out=1.8, hp=0.7}},
		{"Anchored",       {hp=1.5, out=1.2, mc=0.8}},
	},
	converter = {
		{"Refined Process",{eff=1.3, cap=1.2}},
		{"Bulk Conversion",{cap=2.0, eff=0.9}},
	},
	radar = {
		{"All-Seeing",     {rd=2, los=2}},
		{"Shroud",         {jam=0.5}},
		{"Resilient",      {hp=3, pz=0.3}},
	},
	sonar = {
		{"Deep Scan",      {sd=2, los=1.5}},
		{"Resilient",      {hp=3, pz=0.3}},
	},
	jammer = {
		{"Blackout",       {jd=1.8, upk=1.4}},
		{"Stealth Field",  {jd=1.3, hp=1.5, upk=0.9}},
	},
	storage = {
		{"Vault",          {stor=3, hp=1.5}},
		{"Volatile Reserve",{stor=2, death=true}},
	},
	-- Walls, dragon teeth, targeting facilities, effigies: no output to tune.
	generic = {
		{"Bunker",         {hp=2.5, los=1.5}},
		{"Resilient",      {hp=3, pz=0.3}},
	},
}
-- No "factory"/"nano" pools: every lab and nano turret sets builder = true, so
-- is_passive() hands them to mod.lua and those pools could never fire here.

-- PvE units (raptors, scavenger-only defs, critters) opt out of the roll
local SKIP_PVE = true
local function is_pve(n)
	return SKIP_PVE and (n:find("raptor") or n:find("scav") or n:find("critter")) ~= nil
end

-- Check if unit is a passive building (handled by this file)
local function is_passive(name, ud)
	local has_weapons = ud.weapondefs and next(ud.weapondefs) ~= nil
	return not ud.speed and not has_weapons and ud.builder ~= true and not is_pve(name)
end

-- Roll rarities for passive buildings, classifying each one once
local unit_rarities = {}
local unit_cats = {}
local cat_counts = {}
for name, ud in pairs(UnitDefs) do
	if is_passive(name, ud) then
		local r = get_rarity()
		local fci = fi(name)
		if r < rf[fci] then r = rf[fci] end
		if r > rx[fci] then r = rx[fci] end
		unit_rarities[name] = r
		local cat = get_category(ud)
		unit_cats[name] = cat
		cat_counts[cat] = (cat_counts[cat] or 0) + 1
	end
end

-- Category histogram: the trait pools hang off it, so a silent misclassification
-- (empty buildoptions reading as a factory, fusions filed as storage) shows up
-- here instead of as missing traits nobody notices.
local cat_line = {}
for cat, n in pairs(cat_counts) do cat_line[#cat_line+1] = cat .. "=" .. n end
table.sort(cat_line)
Spring.Echo("[BaRandom Part 2] categories: " .. table.concat(cat_line, " "))

-- Assign archetypes and traits
local unit_archetypes = {}
local unit_traits = {}
for name, ud in pairs(UnitDefs) do
	local r = unit_rarities[name] or 0
	if r >= TRAIT_MIN_RARITY and is_passive(name, ud) then
		unit_archetypes[name] = BAT[math.random(#BAT)]
		local pool = BTRAITS[unit_cats[name]]
		if pool and math.random() < TRAIT_CHANCE then
			local trait = pool[math.random(#pool)]
			-- Skip Metamorphic if no valid evolution target or not T1
			local tm = trait[2]
			if tm.evo then
				local cp = ud.customparams
				local tl = cp and tonumber(cp.techlevel) or 1
				local targets = tm.evo == "mex" and EVO_MEX or EVO_ENERGY
				if tl > 1 or not targets[name] then
					trait = nil
				end
			end
			if trait then unit_traits[name] = trait end
		end
	end
end

-- Apply scaling
for name, ud in pairs(UnitDefs) do
  if is_passive(name, ud) then
	local r = unit_rarities[name] or 0
	if r > #rarities then r = #rarities end
	if r <= 0 then
		if name then
			table.insert(rename_list, {name, "prefix", "[Common]"})
			table.insert(rename_list, {name, "desc_prefix", "Mk.0 "})
		end
	else

	local MCost = ud.metalcost and "metalcost" or "buildcostmetal"
	local ECost = ud.energycost and "energycost" or "buildcostenergy"
	local Health = ud.health and "health" or "maxdamage"
	local cp = ud.customparams
	if cp then cp.rarity = tostring(r) end

	-- Base stat scaling
	if not ud.power then ud.power = ud[MCost] + (ud[ECost]/60) end
	-- power left at its base value on purpose, see mod.lua
	sv(ud, Health, 1.1, r, true)
	sv(ud, "sightdistance", 1.05, r)
	sv(ud, "radardistance", 1.1, r)
	sv(ud, "energymake", 1.04, r)
	sv(ud, "extractsmetal", 1.1, r)
	sv(ud, "energyupkeep", 1.04, r)
	sv(ud, "tidalgenerator", 1.04, r)
	sv(ud, "windgenerator", 1.04, r)

	-- Eco scaling (buildings get cheaper)
	-- Intentional double-dip: basic wind gens get 0.97^R twice on metalcost
	if ud.windgenerator and (not cp or not cp.energymultiplier) then sv(ud, MCost, 0.97, r, true) end
	sv(ud, MCost, 0.97, r, true)
	sv(ud, ECost, 0.98, r, true)
	sv(ud, "buildtime", 0.98, r)

	if cp then
		sv(cp, "energyconv_efficiency", 1.04, r)
		sv(cp, "energyconv_capacity", 1.04, r, true)
		sv(cp, "energymultiplier", 1.04, r, true)
	end

	-- Apply building archetype
	local at = unit_archetypes[name]
	if at then
		local cat = unit_cats[name]
		tm_a(ud, Health, at[2], true)
		tm_a(ud, MCost, at[3], true)
		tm_a(ud, ECost, at[3], true)
		-- at[5] is an upkeep multiplier; on a solar it would flip into an
		-- output multiplier, so skip the buildings that produce via upkeep.
		if energy_out(ud) ~= "energyupkeep" then tm_a(ud, "energyupkeep", at[5]) end
		-- Output multiplier applied to category-specific field
		local mo = at[4]
		if cat == "mex" then tm_a(ud, "extractsmetal", mo)
		elseif cat == "energy" then tm_a(ud, energy_out(ud), mo)
		elseif cat == "windtidal" then tm_a(ud, "windgenerator", mo); tm_a(ud, "tidalgenerator", mo)
		elseif cat == "radar" then tm_a(ud, "radardistance", mo, true)
		elseif cat == "sonar" then tm_a(ud, "sonardistance", mo, true)
		elseif cat == "jammer" then tm_a(ud, "radardistancejam", mo, true)
		elseif cat == "converter" and cp then tm_a(cp, "energyconv_capacity", mo, true)
		elseif cat == "storage" then tm_a(ud, "metalstorage", mo, true); tm_a(ud, "energystorage", mo, true)
		end
	end

	-- Apply building trait
	local trait = unit_traits[name]
	if trait then
		local tm = trait[2]
		-- Stat multipliers
		if tm.hp then tm_a(ud, Health, tm.hp, true) end
		if tm.mc then tm_a(ud, MCost, tm.mc, true) end
		if tm.bt then tm_a(ud, "buildtime", tm.bt) end
		if tm.em then tm_a(ud, "extractsmetal", tm.em) end
		if tm.out then
			local cat = unit_cats[name]
			if cat == "mex" then tm_a(ud, "extractsmetal", tm.out)
			elseif cat == "energy" then tm_a(ud, energy_out(ud), tm.out)
			elseif cat == "windtidal" then tm_a(ud, "windgenerator", tm.out); tm_a(ud, "tidalgenerator", tm.out)
			end
		end
		if tm.rd then tm_a(ud, "radardistance", tm.rd, true) end
		if tm.sd then tm_a(ud, "sonardistance", tm.sd, true) end
		if tm.jd then tm_a(ud, "radardistancejam", tm.jd, true) end
		if tm.los then tm_a(ud, "sightdistance", tm.los, true) end
		if tm.upk then tm_a(ud, "energyupkeep", tm.upk) end
		if tm.stor then tm_a(ud, "metalstorage", tm.stor, true); tm_a(ud, "energystorage", tm.stor, true) end
		if tm.eff and cp then tm_a(cp, "energyconv_efficiency", tm.eff) end
		if tm.cap and cp then tm_a(cp, "energyconv_capacity", tm.cap, true) end
		-- Structural effects
		if tm.pz and cp then cp.paralyzemultiplier = tostring(tm.pz) end
		if tm.jam then
			local rd = ud.radardistance or 0
			ud.radardistancejam = math.floor(rd * tm.jam)
		end
		if tm.death then
			if cp then
				local hp = tonumber(ud[Health]) or 1000
				cp.area_ondeath_damage = tostring(math.floor(hp * 0.5))
				cp.area_ondeath_range = "200"
				cp.area_ondeath_time = "3"
			end
		end
		if tm.evo and cp then
			local targets = tm.evo == "mex" and EVO_MEX or EVO_ENERGY
			local target = targets[name]
			if target then
				cp.evolution_target = target
				cp.evolution_condition = "timer"
				cp.evolution_timer = "300"
				-- Default is "flat": a 400hp mex would arrive as a 400/1500 moho
				cp.evolution_health_transfer = "percentage"
			end
		end
	end

	-- Rename
	if name then
		local at_name = at and (" " .. at[1]) or ""
		local trait_name = trait and (" " .. trait[1]) or ""
		table.insert(rename_list, {name, "prefix", "[" .. rarities[r] .. trait_name .. at_name .. "]"})
		table.insert(rename_list, {name, "desc_prefix", "Mk." .. r .. "   "})
	end
	end -- end r > 0
  end -- end is_passive
end

--------------------------------------------------------------------------------
-- Veterancy schools (was mod_xp.lua)
--------------------------------------------------------------------------------

local function armed(ud)
	return ud.weapondefs and next(ud.weapondefs) ~= nil
end

-- mod.lua and mod_part2.lua leave `power` at its base value, so the schools
-- below are the only thing that decides how fast a unit learns.
local function scale_power(ud, m)
	ud.power = (tonumber(ud.power) or 1) * m
end

-- The build list a unit comes off, kept by reference (no per-unit copies) — its
-- other entries are the unit's siblings. Read live, so it follows
-- mod_tiers.lua's roster filter and picks up any lab the game adds.
local from_lab = {}
for _, ud in pairs(UnitDefs) do
	local bo = ud.buildoptions
	if bo and #bo > 1 then
		for i = 1, #bo do
			-- raw buildoptions can be sparse; mod_tiers.lua only repacks them
			-- later, and this file runs before it
			local o = bo[i]
			if o and not from_lab[o] then from_lab[o] = bo end
		end
	end
end

-- Pick something in the same lab that is strictly a step up.
local function techlevel(ud)
	local cp = ud.customparams
	return cp and tonumber(cp.techlevel) or 1
end

local function pick_target(name, ud)
	local lst = from_lab[name]
	if not lst then return nil end
	local cost = (tonumber(ud[mck(ud)]) or 0) * ASCEND_MIN_COST
	local mobile = ud.speed and true or false
	-- Same tech level only. This file runs before mod_tiers.lua, so the build
	-- lists are not filtered yet and without this an ascension could hand the
	-- player a unit the rolled tier is supposed to lock away.
	local tl = techlevel(ud)
	local cand = {}
	for i = 1, #lst do
		local o = lst[i]
		local oud = o ~= nil and o ~= name and UnitDefs[o]
		if oud and not COMMANDERS[o] and not is_pve(o)
		   and oud.builder ~= true and armed(oud)
		   and ((oud.speed and true or false) == mobile)
		   and (mobile or same_fp(ud, oud)) and techlevel(oud) == tl
		   and (tonumber(oud[mck(oud)]) or 0) >= cost then
			cand[#cand+1] = o
		end
	end
	if #cand == 0 then return nil end
	return cand[math.random(#cand)]
end

local function apply_school(ud, s)
	local m = s[4]
	tm_a(ud, ud.health and "health" or "maxdamage", m.hp, true)
	tm_a(ud, mck(ud), m.cost, true)
	tm_a(ud, ud.energycost and "energycost" or "buildcostenergy", m.cost, true)
	if m.dmg then
		for _, wd in pairs(ud.weapondefs) do
			if wd.interceptor ~= 1 and wd.targetable ~= 1 and wd.damage then
				for k, v in pairs(wd.damage) do wd.damage[k] = v * m.dmg end
			end
		end
	end
	scale_power(ud, s[2])
end

-- Cheap units promote quickly, expensive ones need a real career. Also stops
-- a carried-over xp pool from chain-evolving a unit twice in the same second.
local function apply_ascend(ud, target)
	local cp = ud.customparams
	local thr = ASCEND_XP_BASE + (tonumber(ud[mck(ud)]) or 0) * ASCEND_XP_PER_METAL
	if thr > ASCEND_XP_CAP then thr = ASCEND_XP_CAP end
	cp.evolution_target = target
	cp.evolution_condition = "xp"
	cp.evolution_xp_threshold = string.format("%.2f", thr)
	cp.evolution_health_transfer = "percentage"
	return thr
end

-- A Mentor lab banks the xp of everything it built and stamps half of it onto
-- the next unit off the line: veterans roll out of the factory pre-trained.
local function apply_mentor(ud)
	local cp = ud.customparams
	cp.inheritxpratemultiplier = MENTOR_INHERIT
	cp.inheritcreationxpmultiplier = MENTOR_INHERIT
	cp.childreninheritxp = MENTOR_TYPES
	cp.parentsinheritxp = MENTOR_TYPES
	scale_power(ud, MENTOR_POWER)
end

local function rename(name, tag, desc)
	table.insert(rename_list, {name, "prefix", "[" .. tag .. "]"})
	table.insert(rename_list, {name, "desc_prefix", desc})
end

-- No rename block printed yet means no rarity slot ran before us: this file is
-- being tested on its own, so treat every unit as eligible.
local STANDALONE = (rawget(_G, "BAR_RENAME_BLOCKS") or 0) == 0
local schools_rolled, mentors_rolled = 0, 0

for name, ud in pairs(UnitDefs) do
	local cp = ud.customparams
	if cp and not is_pve(name) and not COMMANDERS[name] then
		local r = tonumber(cp.rarity) or (STANDALONE and FALLBACK_RARITY or 0)
		-- Units the game already drives through an evolution chain (evocom
		-- levels, mod_part2.lua's Metamorphic) keep their own script.
		if r >= XP_MIN_RARITY and not cp.evolution_target then
			local builder = ud.builder == true
				or (ud.buildoptions and #ud.buildoptions > 0)
			if armed(ud) and not builder and math.random() < XP_CHANCE then
				local s = SCHOOLS[math.random(#SCHOOLS)]
				local target = s[5] and pick_target(name, ud)
				if s[5] and not target then s = SCHOOLS[1] end
				apply_school(ud, s)
				schools_rolled = schools_rolled + 1
				local rate = s[3]
				if target then
					local thr = apply_ascend(ud, target)
					rename(name, "+" .. s[1],
						"XP " .. rate .. ", ascends into " .. target ..
						" at " .. string.format("%.2f", thr) .. " xp.   ")
				else
					rename(name, "+" .. s[1], "XP " .. rate .. ".   ")
				end
			-- 30-odd BAR units (drone carriers, botcannons) already ship an
			-- xp-sharing setup; leave theirs alone.
			elseif builder and not cp.inheritxpratemultiplier
			       and math.random() < MENTOR_CHANCE then
				apply_mentor(ud)
				mentors_rolled = mentors_rolled + 1
				rename(name, "+Mentor", "XP x4, its units inherit " ..
					MENTOR_INHERIT .. " of its xp.   ")
			end
		end
	end
end

Spring.Echo("[BaRandom Part 2] xp: " .. schools_rolled .. " schools, " .. mentors_rolled .. " mentors")

Spring.Echo("tweakdefs_rename_get_ready")
for i, entry in pairs(rename_list) do
	Spring.Echo("/("..entry[1].."/-"..entry[2].."/-"..entry[3].."/)")
end
Spring.Echo("tweakdefs_rename_end")

-- Tweakdefs Bridge v6 count protocol: the widget only reads the last N rename
-- blocks, where N comes from the newest count line. Every tweakdefs slot runs in
-- the same Lua state, so we keep a running total and each block re-prints it.
local rename_blocks = (rawget(_G, "BAR_RENAME_BLOCKS") or 0) + 1
rawset(_G, "BAR_RENAME_BLOCKS", rename_blocks)
Spring.Echo("tweakdefs_rename_block_count:" .. rename_blocks)
