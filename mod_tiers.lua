--BaRandom Tiers v32 by LoH
local TIER = math.random(1, 3)
Spring.Echo("[BaRandom Tiers] T" .. TIER)

-- PvE rosters (raptors, scavenger-only defs, critters) are left untouched:
-- their build trees belong to the PvE AI, not to the player's tech tree.
local SKIP_PVE = true
local function is_pve(n)
	return SKIP_PVE and (n:find("raptor") or n:find("scav") or n:find("critter")) ~= nil
end

-- Faction index: 1=arm, 2=cor, 3=leg (matches mod.lua convention)
local function fi(n) return n:byte()==99 and 2 or n:byte()==108 and 3 or 1 end

-- Raw buildoptions are sparse -- armcom/corcom/legcom have no [19], armhacs is
-- missing five indices -- and ipairs() stops dead at the first hole. Walking
-- the integer keys instead is the difference between filtering a commander's
-- build list and amputating its whole naval half.
local function bo_list(bo)
	local n = 0
	for k in pairs(bo) do
		if type(k) == "number" and k > n then n = k end
	end
	local out = {}
	for i = 1, n do
		local v = bo[i]
		if v then out[#out+1] = v end
	end
	return out
end

-- Cost map: T2/T3 lab -> T1 equivalent in same faction & (best-fit) category.
-- T3 gantries fall back to the faction's T1 bot lab.
local COST_MAP = {
	armalab="armlab", armavp="armvp", armaap="armap", armasy="armsy",
	armhalab="armlab", armhavp="armvp", armhaap="armap", armhasy="armsy",
	armhaapuw="armplat", armsalab="armamsub", armsavp="armfhp",
	armsaap="armplat", armsasy="armsy",
	armshltx="armlab", armshltxuw="armlab",
	coralab="corlab", coravp="corvp", coraap="corap", corasy="corsy",
	corhalab="corlab", corhavp="corvp", corhaap="corap", corhasy="corsy",
	corhaapuw="corplat", corsalab="coramsub", corsavp="corfhp",
	corsaap="corplat", corsasy="corsy",
	corgant="corlab", corgantuw="corlab",
	legalab="leglab", legavp="legvp", legaap="legap", legadvshipyard="legsy",
	leghalab="leglab", leghavp="legvp", leghaap="legap",
	legamphlab="leglab", legsplab="leglab",
	leggant="leglab", leggantuw="leglab",
}

-- techlevel is 1.5 on the hover / amphib / seaplane platforms and 4 on the
-- scav bosses; a bare "== TIER" test would lock those out of every roll.
local function tier_from(ud)
	local cp = ud.customparams
	local tl = cp and tonumber(cp.techlevel)
	if not tl then return 1 end
	tl = math.floor(tl)
	if tl < 1 then return 1 end
	if tl > 3 then return 3 end
	return tl
end

-- Every commander variant carries customparams.iscommander -- the three
-- starters, the con-coms, the Legion loadouts and all nine evocom levels.
-- The name table is the fallback for defs that predate the flag.
local COMMANDERS = {armcom=true, corcom=true, legcom=true}
local function is_com(name, ud)
	local cp = ud.customparams
	if COMMANDERS[name] then return true end
	return (cp and cp.iscommander) and true or false
end

-- Walls, targeting facilities and cosmetic statics match no gate; they fall
-- back to all-tier, which is what we want. Reported once instead of per unit.
local unclassified = {}

-- Order is load-bearing. Construction units carry energymake (armck 7,
-- armack 14) so the eco test has to come after the mobile one; every lab sets
-- builder = true so the lab test has to come before the nano-turret one; and
-- armanni carries energystorage 1000 + radardistance 1500 so defences have to
-- be claimed before eco and radar. Getting any of those backwards leaves the
-- matching gate permanently empty.
local function classify(name, ud)
	if is_com(name, ud) or is_pve(name) then return "all", "utility" end
	local t = tier_from(ud)
	local armed = ud.weapondefs and next(ud.weapondefs) ~= nil
	-- Mobile: combat units and construction units. Everything else that moves
	-- (transports, drones, lootboxes) is deliberately all-tier and is not worth
	-- reporting -- the unclassified line is there to catch statics.
	if ud.speed then
		if armed or ud.builder == true then return t, "combat" end
		return "all", "utility"
	end
	-- Static builder that offers something = factory
	if ud.buildoptions and next(ud.buildoptions) ~= nil then return t, "lab" end
	if ud.builder == true then return "all", "utility" end -- nano turrets
	-- Static and armed = defence
	if armed then return t, "defense" end
	-- Eco
	if (ud.extractsmetal and ud.extractsmetal > 0)
	   or (ud.energymake and ud.energymake > 0)
	   or (ud.energyupkeep and ud.energyupkeep < 0)  -- solars generate via negative upkeep
	   or ud.windgenerator or ud.tidalgenerator
	   or (ud.metalstorage and ud.metalstorage > 500)
	   or (ud.energystorage and ud.energystorage > 500) then
		return "all", "eco"
	end
	local cp = ud.customparams
	if cp and cp.energyconv_capacity then return "all", "eco" end
	-- Radar / sonar / jammer
	if (ud.radardistance and ud.radardistance > 0)
	   or (ud.sonardistance and ud.sonardistance > 0)
	   or (ud.radardistancejam and ud.radardistancejam > 0) then
		return "all", "utility"
	end
	unclassified[#unclassified+1] = name
	return "all", "utility"
end

-- Classify every UnitDef once
local unit_tier = {}
local unit_gate = {}
local gate_counts = {}
for name, ud in pairs(UnitDefs) do
	local t, g = classify(name, ud)
	unit_tier[name] = t
	unit_gate[name] = g
	gate_counts[g] = (gate_counts[g] or 0) + 1
end

-- What the live build tree can actually reach, read before we start filtering.
-- Scav-only factories (armapt3) sit in UnitDefs but in nobody's build list;
-- without this the commander override would hand the player scavenger labs.
local buildable = {}
for name, ud in pairs(UnitDefs) do
	if not is_pve(name) and ud.buildoptions then
		for _, opt in ipairs(bo_list(ud.buildoptions)) do buildable[opt] = true end
	end
end

local gate_line = {}
for g, n in pairs(gate_counts) do gate_line[#gate_line+1] = g .. "=" .. n end
table.sort(gate_line)
Spring.Echo("[BaRandom Tiers] " .. table.concat(gate_line, " "))
if #unclassified > 0 then
	table.sort(unclassified)
	Spring.Echo("[BaRandom Tiers] unclassified, kept all-tier: " .. table.concat(unclassified, " "))
end

-- Generic buildoptions filter
local function keep(opt)
	local g = unit_gate[opt]
	if g == "eco" or g == "utility" then return true end
	if g == "lab" or g == "combat" or g == "defense" then
		return unit_tier[opt] == TIER
	end
	return true
end

for name, ud in pairs(UnitDefs) do
	if not is_pve(name) and ud.buildoptions and next(ud.buildoptions) ~= nil then
		local filtered = {}
		for _, opt in ipairs(bo_list(ud.buildoptions)) do
			if keep(opt) then filtered[#filtered+1] = opt end
		end
		ud.buildoptions = filtered
	end
end

-- Faction-indexed lists for overrides and escape hatches
local rolled_labs_by_f = {{},{},{}}
local t3_gantries_by_f = {{},{},{}}
local t2_cons_by_f = {{},{},{}}
local t1_cons_set = {}

for name, ud in pairs(UnitDefs) do
	local t = unit_tier[name]
	local g = unit_gate[name]
	local f = fi(name)
	if g == "lab" and buildable[name] then
		if t == TIER then
			local lst = rolled_labs_by_f[f]
			lst[#lst+1] = name
		end
		if t == 3 then
			local lst = t3_gantries_by_f[f]
			lst[#lst+1] = name
		end
	end
	if g == "combat" and ud.builder == true and ud.speed then
		if t == 2 then
			local lst = t2_cons_by_f[f]
			lst[#lst+1] = name
		elseif t == 1 then
			t1_cons_set[name] = true
		end
	end
end

-- Commander overrides (skip on T1 roll: nothing to change)
if TIER ~= 1 then
	for name, ud in pairs(UnitDefs) do
		if is_com(name, ud) and not is_pve(name) then
			local f = fi(name)
			local new_bo = {}
			local seen = {}
			for _, opt in ipairs(bo_list(ud.buildoptions or {})) do
				if not t1_cons_set[opt] and not seen[opt] then
					new_bo[#new_bo+1] = opt
					seen[opt] = true
				end
			end
			for _, lab in ipairs(rolled_labs_by_f[f]) do
				if not seen[lab] then
					new_bo[#new_bo+1] = lab
					seen[lab] = true
				end
			end
			ud.buildoptions = new_bo
		end
	end
end

-- T3 escape hatch: T3 gantries get T2 cons appended
if TIER == 3 then
	for _, f in ipairs({1,2,3}) do
		for _, gantry in ipairs(t3_gantries_by_f[f]) do
			local ud = UnitDefs[gantry]
			if ud then
				local bo = bo_list(ud.buildoptions or {})
				local seen = {}
				for _, opt in ipairs(bo) do seen[opt] = true end
				for _, con in ipairs(t2_cons_by_f[f]) do
					if not seen[con] then
						bo[#bo+1] = con
						seen[con] = true
					end
				end
				ud.buildoptions = bo
			end
		end
	end
end

-- Flatten costs of surviving T2/T3 labs to T1 equivalents
if TIER ~= 1 then
	for _, f in ipairs({1,2,3}) do
		for _, name in ipairs(rolled_labs_by_f[f]) do
			local ud = UnitDefs[name]
			local src = COST_MAP[name]
			if src then
				local sud = UnitDefs[src]
				if sud then
					local mc_s = sud.metalcost and "metalcost" or "buildcostmetal"
					local ec_s = sud.energycost and "energycost" or "buildcostenergy"
					local mc_d = ud.metalcost and "metalcost" or "buildcostmetal"
					local ec_d = ud.energycost and "energycost" or "buildcostenergy"
					ud[mc_d] = sud[mc_s]
					ud[ec_d] = sud[ec_s]
					ud.buildtime = sud.buildtime
				end
			else
				Spring.Echo("[BaRandom Tiers] Lab without cost map: " .. name)
			end
		end
	end
end
