--BaRandom Tiers v31 by LoH
local COMMANDERS = {armcom=true, corcom=true, legcom=true}

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

local function tier_from(ud, name)
	local cp = ud.customparams
	if cp and cp.techlevel then
		local tl = tonumber(cp.techlevel)
		if tl then return tl end
	end
	return 1
end

-- Transports, walls, targeting facilities and cosmetics match no gate; they fall
-- back to all-tier, which is what we want. Reported once instead of per unit.
local unclassified = {}

local function classify(name, ud)
	if COMMANDERS[name] or is_pve(name) then return "all", "utility" end
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
	-- Utility: radar/sonar/jammer/nano turret
	if (ud.radardistance and ud.radardistance > 0)
	   or (ud.sonardistance and ud.sonardistance > 0)
	   or (ud.radardistancejam and ud.radardistancejam > 0) then
		return "all", "utility"
	end
	if ud.builder == true and not ud.speed then
		return "all", "utility"
	end
	-- Tier-gated roles
	local t = tier_from(ud, name)
	local has_weapons = ud.weapondefs and next(ud.weapondefs) ~= nil
	local has_build = ud.buildoptions ~= nil and next(ud.buildoptions) ~= nil
	if not ud.speed and has_build then return t, "lab" end
	if not ud.speed and has_weapons then return t, "defense" end
	if ud.speed and (has_weapons or ud.builder == true) then return t, "combat" end
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
		for _, opt in ipairs(ud.buildoptions) do
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
	if g == "lab" and t == TIER then
		local lst = rolled_labs_by_f[f]
		lst[#lst+1] = name
	end
	if g == "lab" and t == 3 then
		local lst = t3_gantries_by_f[f]
		lst[#lst+1] = name
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
		if COMMANDERS[name] then
			local f = fi(name)
			local new_bo = {}
			local seen = {}
			for _, opt in ipairs(ud.buildoptions or {}) do
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
				local bo = ud.buildoptions or {}
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
	for name, ud in pairs(UnitDefs) do
		if unit_gate[name] == "lab" and unit_tier[name] == TIER then
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
