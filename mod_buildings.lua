--BaRandom Buildings v28 by LoH
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
local function tm_a(t,k,m,f) local v=tonumber(t[k])if m and v then t[k]=v*m;if f then t[k]=math.floor(t[k])end end end
local function fi(n) return n:byte()==99 and 2 or n:byte()==108 and 3 or 1 end

-- Building category detection (priority order)
local function get_category(ud)
	if ud.extractsmetal and ud.extractsmetal > 0 then return "mex" end
	local cp = ud.customparams
	if cp and cp.energyconv_capacity then return "converter" end
	if ud.windgenerator or ud.tidalgenerator then return "windtidal" end
	if ud.radardistancejam and ud.radardistancejam > 0 then return "jammer" end
	if ud.radardistance and ud.radardistance > 0 then return "radar" end
	if ud.sonardistance and ud.sonardistance > 0 then return "sonar" end
	if ud.buildoptions then return "factory" end
	if ud.builder == true then return "nano" end
	local ms = ud.metalstorage or 0
	local es = ud.energystorage or 0
	if ms > 500 or es > 500 then return "storage" end
	if ud.energymake and ud.energymake > 0 then return "energy" end
	return "generic"
end

-- Building archetypes: {name, m_hp, m_cost, m_output, m_upkeep}
local BAT = {
	{"Efficient",   0.9, 0.8, 1.15, 0.9},
	{"Fortified",   1.5, 1.1, 1.0,  1.0},
	{"Overclocked", 0.8, 1.0, 1.4,  1.3},
}

-- Evolution targets: T1 unit → T2 unit per faction
local EVO_MEX = {armmex="armmoho", cormex="cormoho", legmex="legmext15"}
local EVO_ENERGY = {armsolar="armadvsol", corsolar="coradvsol", legsolar="legadvsol"}

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
	factory = {
		{"Rush Order",     {wt=1.4, upk=1.5}},
		{"Long Arm",       {bd=1.8, los=1.3}},
		{"Bunker",         {hp=2.5, los=1.5}},
	},
	storage = {
		{"Vault",          {stor=3, hp=1.5}},
		{"Volatile Reserve",{stor=2, death=true}},
	},
	nano = {
		{"Precision",      {bd=1.8, wt=1.2}},
		{"Frenzy",         {wt=2, hp=0.6}},
		{"Fortified Builder",{hp=2, bd=1.3, wt=0.9}},
	},
}

-- Check if unit is a passive building (handled by this file)
local function is_passive(ud)
	local has_weapons = ud.weapondefs and next(ud.weapondefs) ~= nil
	return not ud.speed and not has_weapons and ud.builder ~= true
end

-- Roll rarities for passive buildings
local unit_rarities = {}
for name, ud in pairs(UnitDefs) do
	if is_passive(ud) then
		local r = get_rarity()
		local fci = fi(name)
		if r < rf[fci] then r = rf[fci] end
		if r > rx[fci] then r = rx[fci] end
		unit_rarities[name] = r
	end
end

-- Assign archetypes and traits
local unit_archetypes = {}
local unit_traits = {}
for name, ud in pairs(UnitDefs) do
	local r = unit_rarities[name] or 0
	if r >= TRAIT_MIN_RARITY and is_passive(ud) then
		unit_archetypes[name] = BAT[math.random(#BAT)]
		local cat = get_category(ud)
		local pool = BTRAITS[cat]
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
  if is_passive(ud) then
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
	sv(ud, "power", 1.2, r)
	sv(ud, Health, 1.1, r, true)
	sv(ud, "sightdistance", 1.05, r)
	sv(ud, "radardistance", 1.1, r)
	sv(ud, "idleautoheal", 1.1, r)
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
	sv(ud, "workertime", 1.05, r, true)
	sv(ud, "builddistance", 1.05, r, true)

	if cp then
		sv(cp, "energyconv_efficiency", 1.04, r)
		sv(cp, "energyconv_capacity", 1.04, r, true)
		sv(cp, "shield_power", 1.1, r, true)
		sv(cp, "shield_radius", 1.05, r, true)
		sv(cp, "energymultiplier", 1.04, r, true)
	end

	-- Apply building archetype
	local at = unit_archetypes[name]
	if at then
		local cat = get_category(ud)
		tm_a(ud, Health, at[2], true)
		tm_a(ud, MCost, at[3], true)
		tm_a(ud, ECost, at[3], true)
		tm_a(ud, "energyupkeep", at[5])
		-- Output multiplier applied to category-specific field
		local mo = at[4]
		if cat == "mex" then tm_a(ud, "extractsmetal", mo)
		elseif cat == "energy" then tm_a(ud, "energymake", mo)
		elseif cat == "windtidal" then tm_a(ud, "windgenerator", mo); tm_a(ud, "tidalgenerator", mo)
		elseif cat == "radar" then tm_a(ud, "radardistance", mo, true)
		elseif cat == "sonar" then tm_a(ud, "sonardistance", mo, true)
		elseif cat == "jammer" then tm_a(ud, "radardistancejam", mo, true)
		elseif cat == "factory" or cat == "nano" then tm_a(ud, "workertime", mo, true)
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
			local cat = get_category(ud)
			if cat == "mex" then tm_a(ud, "extractsmetal", tm.out)
			elseif cat == "energy" then tm_a(ud, "energymake", tm.out)
			elseif cat == "windtidal" then tm_a(ud, "windgenerator", tm.out); tm_a(ud, "tidalgenerator", tm.out)
			end
		end
		if tm.rd then tm_a(ud, "radardistance", tm.rd, true) end
		if tm.sd then tm_a(ud, "sonardistance", tm.sd, true) end
		if tm.jd then tm_a(ud, "radardistancejam", tm.jd, true) end
		if tm.los then tm_a(ud, "sightdistance", tm.los, true) end
		if tm.wt then tm_a(ud, "workertime", tm.wt, true) end
		if tm.bd then tm_a(ud, "builddistance", tm.bd, true) end
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

Spring.Echo("tweakdefs_rename_get_ready")
for i, entry in pairs(rename_list) do
	Spring.Echo("/("..entry[1].."/-"..entry[2].."/-"..entry[3].."/)")
end
Spring.Echo("tweakdefs_rename_end")
