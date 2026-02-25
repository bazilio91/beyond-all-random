--BaRandom v5 by LoH
--Use with: !bset tweakdefs0 <mod.b64>
rename_list = {}
local rarities = {	"Uncommon","Rare","Exceptional","Epic","Exotic",
			"Legendary","Mythical","Miracle","Divine","Eternal",
			"Supreme","Omega","Unique", "Jackpot","Immortal",
			"Absurd","Godlike","TooRNG","Insanely Lucky","Dope",
			"Admin","GOD","ERROR","Super Sayan","Beyond",
			"MGGW","AMBO","Beyond All Reason"
}

local rarity_chance = 0.7

local MIN_FACTORY_RARITY = 7
local CURSE_CHANCE = 0.1
local TRAIT_CHANCE = 0.5
local TRAIT_MIN_RARITY = 5
local rf={0,0,0}
local rx={28,28,28}

local PH75 = {cancloak=true, cloakcost=5, cloakcostmoving=15, mincloakdistance=75}
local PH50 = {cancloak=true, cloakcost=5, cloakcostmoving=15, mincloakdistance=50}

local TRAIT_POOLS = {
	["Glass Cannon"] = {
		{"Phantom",    PH75, {hp=0.85}},
		{"Volatile",   {}, {dmg=1.3, hp=0.6}},
		{"Overcharged",{}, {rld=0.8, energypershot=1.5}},
		{"Plague",     {}, {fs=1.0, aoe=1.15, dmg=0.9}},
		{"Bouncer",    {}, {impf=6.0, impb=2.0, dmg=0.6}},
	},
	["Tank"] = {
		{"Juggernaut", {}, {hp=1.6, spd=0.7, turnrate=0.75}},
		{"Regenerator",{}, {autoheal=3.0}},
		{"Fortified",  {}, {hp=1.3, rld=1.2}},
		{"GravWell",   {}, {impf=-2.0, aoe=1.4, dmg=0.8}},
	},
	["Sniper"] = {
		{"Phantom",    PH75, {hp=0.9}},
		{"Marksman",   {}, {rng=1.3, acc=0.7, aoe=0.7}},
		{"Piercing",   {}, {dmg=1.2, aoe=0.5}},
		{"Drunk",      {}, {wob=4000, dnc=60, acc=2.5, aoe=1.3}},
	},
	["Brawler"] = {
		{"Swift",      {}, {spd=1.4, hp=0.7, maxacc=1.3}},
		{"Berserker",  {}, {dmg=1.2, aoe=1.3, acc=1.4}},
		{"Siege",      {}, {aoe=1.4, dmg=1.15, spd=0.85}},
		{"Plague",     {}, {fs=1.0, aoe=1.15, dmg=0.9}},
		{"Bouncer",    {}, {impf=6.0, impb=2.0, dmg=0.6}},
	},
	["Fortress"] = {
		{"Juggernaut", {}, {hp=1.6}},
		{"Shielded",   {}, {shield_power=1.4, shield_radius=1.2}},
		{"Siren",      {}, {impf=3.5, impb=1.0, dmg=0.7, aoe=1.15}},
	},
	["Watchtower"] = {
		{"Phantom",    PH50, {hp=0.9}},
		{"Marksman",   {}, {rng=1.3, acc=0.7, aoe=0.7}},
		{"GravWell",   {}, {impf=-2.0, aoe=1.4, dmg=0.8}},
	},
	["Suppressor"] = {
		{"Siege",      {}, {aoe=1.4, dmg=1.15, acc=1.3}},
		{"Berserker",  {}, {dmg=1.3, aoe=1.3}},
		{"Siren",      {}, {impf=3.5, impb=1.0, dmg=0.7, aoe=1.15}},
		{"Drunk",      {}, {wob=4000, dnc=60, acc=2.5, aoe=1.3}},
	},
}

local function get_rarity(x)
	local x = x or 0
	if x + 1 <= #rarities and math.random() < rarity_chance then
			x = get_rarity(x+1)
	end
	return x
end

local function get_rarity_min(min)
	local r = get_rarity(min)
	if r < min then r = min end
	return r
end

local function set_v(x,m,r,f,em)
	if x then
		local t = x*(m^r)+((m-1)*x)
		if x > 0 and t <= 0 then t = x*(m^r) end
		if f then t = math.floor(t) end
		return t*(em or 1)
	end
end

local function tm_a(t,k,m,f) if m and t[k] then t[k]=t[k]*m;if f then t[k]=math.floor(t[k])end end end
local function fi(n) return n:byte()==99 and 2 or n:byte()==108 and 3 or 1 end

-- {name, m_hp, m_spd, m_dmg, m_rng, m_rld, m_aoe, m_acc}
local AT = {
	{"Glass Cannon",  0.88,1.05,1.12,1.05,0.91,1.05,0.96},
	{"Tank",          1.22,1.0, 1.01,1.04,0.97,1.04,0.97},
	{"Sniper",        1.03,1.04,1.07,1.14,0.98,0.95,0.91},
	{"Brawler",       1.06,1.10,1.05,1.0, 0.88,1.10,0.97},
}

local TAT = {
	{"Fortress",    1.20, 1.0, 1.08, 1.04, 0.97, 1.04, 0.97},
	{"Watchtower",  1.03, 1.0, 1.05, 1.14, 0.98, 0.95, 0.91},
	{"Suppressor",  1.06, 1.0, 1.04, 1.0,  0.88, 1.12, 0.97},
}

-- Flat list of factory combat unit groups (no faction/factory name keys needed)
local factory_units = {
	{"armthund","armkam"},
	{"armpw","armrock","armham","armwar","armflea"},
	{"armmlv","armfav","armflash","armpincer","armstump","armart","armjanus"},
	{"armdecade","armpt","armpship","armroy","armsub"},
	{"armsh","armanac","armmh"},
	{"armsaber","armsb","armseap"},
	{"armbrawl","armpnix","armlance","armdfly","armblade","armstil","armliche"},
	{"armfast","armamph","armzeus","armmav","armsptk","armfido","armsnipe","armfboy","armspid","armvader","armscab"},
	{"armcroc","armlatnk","armbull","armgremlin","armmart","armmerl","armmanni"},
	{"armcrus","armsubk","armserp","armantiship","armbats","armmship","armepoch","armlship"},
	{"armbanth","armraz","armmar","armvang","armlun","armthor"},
	{"corshad","corbw"},
	{"corak","corstorm","corthud"},
	{"cormlv","corfav","corgator","corgarp","corraid","corlevlr","corwolv"},
	{"coresupp","corpt","corpship","corroy","corsub"},
	{"corsh","corsnap","cormh","corhal"},
	{"corcut","corsb","corseap"},
	{"corape","corhurc","cortitan","corcrwh"},
	{"corpyro","coramph","corcan","corsumo","cortermite","cormort","corhrk","corroach","corsktl","cormando"},
	{"corsala","correap","corparrow","corgol","corban","cormart","corvroc","cortrem"},
	{"corcrus","corshark","corssub","corantiship","corbats","cormship","corblackhy","corfship"},
	{"corkorg","corkarg","corjugg","corshiva","corcat","corsok","cordemon"},
	{"legkam","legcib","legmos"},
	{"leggob","leglob","legcen","legbal","legkark"},
	{"legscout","leghades","leghelios","leggat","legbar","legmlv","legamphtank"},
	{"legnavyscout","legnavyfrigate","legnavydestro","legnavysub","legnavyartyship"},
	{"legsh","legner","legmh","legcar"},
	{"legspsurfacegunship","legspcarrier","legspbomber","legsptorpgunship"},
	{"legstronghold","legmineb","legatorpbomber","legfort","legphoenix"},
	{"legstr","legamph","legshot","leginc","legsrail","legbart","leginfestor","leghrk","legsnapper"},
	{"legmrv","legaskirmtank","legfloat","legaheattank","legmed","legamcluster","legvcarry","legavroc","leginf"},
	{"leganavycruiser","leganavyheavysub","leganavybattlesub","leganavybattleship","leganavyartyship","leganavymissileship","leganavyflagship","leganavyantiswarm"},
	{"legeheatraymech","legeallterrainmech","legjav","legelrpcmech","legehovertank","legerailtank","legeshotgunmech","legkeres"},
}

-- Pass 1a: guaranteed spicy combat units per factory
local unit_rarities = {}
local guaranteed = {}

for _, combat in ipairs(factory_units) do
	local available = {}
	for _, bn in ipairs(combat) do
		if not guaranteed[bn] then available[#available+1] = bn end
	end
	if #available == 0 then available = combat end
	local pick = available[math.random(#available)]
	local fci=fi(pick)
	local r = get_rarity_min(math.max(MIN_FACTORY_RARITY, rf[fci]))
	if r > rx[fci] then r = rx[fci] end
	unit_rarities[pick] = r
	guaranteed[pick] = true
end

-- Pass 1b: roll remaining units, 10% curse chance for combat units
local cursed_units = {}
for name, ud in pairs(UnitDefs) do
	if not unit_rarities[name] then
		local is_combat = ud.weapondefs and ud.builder ~= true
		if is_combat and math.random() < CURSE_CHANCE then
			local cl = get_rarity()
			if cl < 1 then cl = 1 end
			cursed_units[name] = cl
			unit_rarities[name] = 0
		else
			local r=get_rarity()
			local fci=fi(name)
			if r<rf[fci] then r=rf[fci] end
			if r>rx[fci] then r=rx[fci] end
			unit_rarities[name] = r
		end
	end
end

-- Pass 2a: assign archetypes to armed units at rarity 5+
local unit_archetypes = {}
for name, ud in pairs(UnitDefs) do
	local r = unit_rarities[name] or 0
	if r >= 5 and ud.weapondefs then
		if ud.speed then
			unit_archetypes[name] = AT[math.random(#AT)]
		elseif ud.builder ~= true then
			unit_archetypes[name] = TAT[math.random(#TAT)]
		end
	end
end

-- Pass 2b: assign archetype-specific traits to rarity 7+ units
local unit_traits = {}
for name, ud in pairs(UnitDefs) do
	local r = unit_rarities[name] or 0
	local at = unit_archetypes[name]
	if r >= TRAIT_MIN_RARITY and at then
		local pool = TRAIT_POOLS[at[1]]
		if pool and math.random() < TRAIT_CHANCE then
			unit_traits[name] = pool[math.random(#pool)]
		end
	end
end

-- Pass 3: apply stat scaling
for name, ud in pairs(UnitDefs) do
	local unit_rarity = unit_rarities[name] or 0
	local MCost = ud.metalcost and "metalcost" or "buildcostmetal"
	local ECost = ud.energycost and "energycost" or "buildcostenergy"
	local Health = ud.health and "health" or "maxdamage"
	if not ud.power then ud.power = ud[MCost] + (ud[ECost]/60) end
	local cp = ud.customparams
	local bugfix = unit_rarity
	if not (unit_rarity <= #rarities) then unit_rarity = #rarities end
	if not (unit_rarity <= 6) and (name == "armcom" or name == "corcom" or name == "legcom") then
		unit_rarity = 6
	end
	local cl = cursed_units[name]
	if cl then
		if cp then
			cp.cursed = tostring(cl)
		end
		ud[Health] = set_v(ud[Health], 0.93, cl, true)
		ud.speed = set_v(ud.speed, 0.97, cl, true)
		ud.maxacc = set_v(ud.maxacc, 0.97, cl)
		ud.turnrate = set_v(ud.turnrate, 0.97, cl)
		ud.sightdistance = set_v(ud.sightdistance, 0.97, cl)
		ud.radardistance = set_v(ud.radardistance, 0.97, cl)
		ud[MCost] = set_v(ud[MCost], 0.85, cl, true)
		ud[ECost] = set_v(ud[ECost], 0.85, cl, true)
		ud.buildtime = set_v(ud.buildtime, 0.88, cl)
		if ud.weapondefs then
			for weapon_name, weapon_def in pairs(ud.weapondefs) do
				if weapon_def.interceptor ~= 1 and weapon_def.targetable ~= 1 then
					weapon_def.range = set_v(weapon_def.range, 0.97, cl, true)
					weapon_def.reloadtime = set_v(weapon_def.reloadtime, 1.04, cl)
					if weapon_def.damage then
						for k, v in pairs(weapon_def.damage) do
							weapon_def.damage[k] = set_v(weapon_def.damage[k], 0.94, cl)
						end
					end
				end
			end
		end
		if name then
			table.insert(rename_list, {name, "prefix", "[Cursed Mk." .. cl .. "]"})
			table.insert(rename_list, {name, "desc_prefix", "Cursed Mk." .. cl .. " "})
		end
	elseif bugfix > 0 then
		if cp then cp.rarity = tostring(unit_rarity) end
		local at = unit_archetypes[name]
		local m_hp  = at and at[2] or 1.1
		local m_spd = at and at[3] or 1.05
		local m_dmg = at and at[4] or 1.05
		local m_rng = at and at[5] or 1.05
		local m_rld = at and at[6] or 0.95
		local m_aoe = at and at[7] or 1.05
		local m_acc = at and at[8] or 0.97
		ud.power = set_v(ud.power, 1.2, unit_rarity)
		ud.speed = set_v(ud.speed, m_spd, unit_rarity, true)
		ud.maxacc = set_v(ud.maxacc, 1.05, unit_rarity)
		ud.maxdec = set_v(ud.maxdec, 1.05, unit_rarity)
		ud.turnrate = set_v(ud.turnrate, 1.05, unit_rarity)
		ud.sightdistance = set_v(ud.sightdistance, 1.05, unit_rarity)
		ud.radardistance = set_v(ud.radardistance, 1.1, unit_rarity)
		ud[Health] = set_v(ud[Health], m_hp, unit_rarity, true)
		ud.idleautoheal = set_v(ud.idleautoheal, 1.1, unit_rarity)
		ud.energymake = set_v(ud.energymake, 1.04, unit_rarity)
		ud.extractsmetal = set_v(ud.extractsmetal, 1.1, unit_rarity)
		ud.energyupkeep = set_v(ud.energyupkeep, 1.04, unit_rarity)
		ud.tidalgenerator = set_v(ud.tidalgenerator, 1.04, unit_rarity)
		ud.windgenerator = set_v(ud.windgenerator, 1.04, unit_rarity)
		if ud.windgenerator and not cp.energymultiplier then ud[MCost] = set_v(ud[MCost], 0.97, unit_rarity, true) end
		if ud.tidalgenerator or ud.windgenerator or ud.builder == true or (not ud.speed and not ud.weapondefs) then
			ud[MCost] = set_v(ud[MCost], 0.97, unit_rarity, true)
			ud[ECost] = set_v(ud[ECost], 0.98, unit_rarity, true)
			ud.buildtime = set_v(ud.buildtime, 0.98, unit_rarity)
			ud.workertime = set_v(ud.workertime, 1.05, unit_rarity, true)
			ud.builddistance = set_v(ud.builddistance, 1.05, unit_rarity, true)
		else
			ud[MCost] = set_v(ud[MCost], 1.035, unit_rarity, true)
			ud[ECost] = set_v(ud[ECost], 1.04, unit_rarity, true)
			ud.buildtime = set_v(ud.buildtime, 1.05, unit_rarity)
			ud.workertime = set_v(ud.workertime, 1.05, unit_rarity, true)
			ud.builddistance = set_v(ud.builddistance, 1.05, unit_rarity, true)
		end
		if cp then
			cp.energyconv_efficiency = set_v(cp.energyconv_efficiency, 1.04, unit_rarity)
			cp.energyconv_capacity = set_v(cp.energyconv_capacity, 1.04, unit_rarity, true)
			cp.shield_power = set_v(cp.shield_power, 1.1, unit_rarity, true)
			cp.shield_radius = set_v(cp.shield_radius, 1.05, unit_rarity, true)
			cp.energymultiplier = set_v(cp.energymultiplier, 1.04, unit_rarity, true)
		end
		if ud.weapondefs then
			for weapon_name, weapon_def in pairs(ud.weapondefs) do
				if weapon_def.interceptor == 1 or weapon_def.targetable == 1 then
					weapon_def.coverage = set_v(weapon_def.coverage, 1.02, unit_rarity, true)
					weapon_def.damage.default = set_v(weapon_def.damage.default, 1.1, unit_rarity)
					weapon_def.areaofeffect = set_v(weapon_def.areaofeffect, 1.01, unit_rarity)
				else
					local wcp = weapon_def.customparams
					if not weapon_def.reloadtime or weapon_def.reloadtime < 0.034 then weapon_def.reloadtime = 0.034 end
					if weapon_def.burstrate and weapon_def.burstrate < 0.034 then weapon_def.burstrate = 0.034 end
					if weapon_def.burst and weapon_def.burstrate then
						if weapon_def.burst *weapon_def.burstrate > weapon_def.reloadtime then weapon_def.reloadtime = weapon_def.burst *weapon_def.burstrate end
					end
					if weapon_def.beamtime then
						if weapon_def.beamtime > weapon_def.reloadtime then weapon_def.reloadtime = weapon_def.beamtime end
					end

					local is_continuous = false
					if weapon_def.burstrate and weapon_def.burst and weapon_def.reloadtime then
						local brb = (weapon_def.burstrate*weapon_def.burst)
						local brbr = brb/weapon_def.reloadtime
						if brbr >= 0.98 or brb >= weapon_def.reloadtime then
							is_continuous = true
						end
					end
					local is_continuous_b = false
					if weapon_def.beamtime and weapon_def.reloadtime then
						if weapon_def.beamtime/weapon_def.reloadtime >= 0.90 or weapon_def.beamtime >= weapon_def.reloadtime then
							is_continuous_b = true
						end
					end
					weapon_def.reloadtime = set_v(weapon_def.reloadtime, m_rld, unit_rarity)
					weapon_def.burstrate = set_v(weapon_def.burstrate, m_rld, unit_rarity)

					weapon_def.areaofeffect = set_v(weapon_def.areaofeffect, m_aoe, unit_rarity)
					weapon_def.weaponvelocity = set_v(weapon_def.weaponvelocity, 1.06, unit_rarity)
					weapon_def.range = set_v(weapon_def.range, m_rng, unit_rarity, true)
					weapon_def.flighttime = set_v(weapon_def.flighttime, m_rng, unit_rarity)
					weapon_def.sprayangle = set_v(weapon_def.sprayangle, m_acc, unit_rarity)
					weapon_def.accuracy = set_v(weapon_def.accuracy, m_acc, unit_rarity)

					if wcp then
						wcp.overrange_distance = set_v(wcp.overrange_distance, m_rng, unit_rarity, true)
						wcp.controlradius = set_v(wcp.controlradius, m_rng, unit_rarity, true)
						wcp.engagementrange = set_v(wcp.engagementrange, m_rng, unit_rarity, true)
					end

					if weapon_def.damage then
						local dm = 1
						local dsm = 0
						local rt = weapon_def.reloadtime or 1
						local bt = weapon_def.beamtime or 0
						local br = weapon_def.burstrate or 1
						local b = weapon_def.burst or 1

						if rt < 0.034 then
							dm = dm + (0.034/rt) -1
							weapon_def.reloadtime = 0.034
							rt = 0.034
						end
						local is_sweepfire = wcp and wcp.sweepfire
						if is_sweepfire or name == "armbeamer" then
							weapon_def.reloadtime = weapon_def.reloadtime or rt
							rt = weapon_def.reloadtime
						end
						if bt > rt then
							dm = dm + (bt/rt) -1
							weapon_def.reloadtime = bt
							rt = bt
						end
						if br < 0.034 then
							dm = dm + (0.034/br) -1
							weapon_def.burstrate = 0.034
							br = 0.034
						end
						local brb = br*b
						if weapon_def.burstrate and weapon_def.burst and brb > rt then
							dm = dm + (brb/rt) -1
							weapon_def.reloadtime = brb
						end
						for k, v in pairs(weapon_def.damage) do
							if v == "commanders" then
								weapon_def.damage[k] = set_v(weapon_def.damage[k], 1.02+dsm, unit_rarity, false,dm)
							else
								weapon_def.damage[k] = set_v(weapon_def.damage[k], m_dmg+dsm, unit_rarity, false,dm)
							end
						end
					end
					if weapon_def.shield then
						weapon_def.shield.power = set_v(weapon_def.shield.power, 1.1, unit_rarity, true)
						weapon_def.shield.powerregen = set_v(weapon_def.shield.powerregen, 1.1, unit_rarity, true)
						weapon_def.shield.radius = set_v(weapon_def.shield.radius, 1.05, unit_rarity, true)
						weapon_def.shield.force = set_v(weapon_def.shield.force, 1.05, unit_rarity)
						weapon_def.shield.powerregenenergy = set_v(weapon_def.shield.powerregenenergy, 0.99, unit_rarity, true)
					end
					if is_continuous == true then weapon_def.reloadtime = weapon_def.burst *weapon_def.burstrate end
					if is_continuous_b == true then weapon_def.reloadtime = weapon_def.beamtime end
				end
			end
		end
		-- Apply trait flat multipliers after rarity+archetype scaling
		local trait = unit_traits[name]
		if trait then
			for k, v in pairs(trait[2]) do ud[k] = v end
			local tm = trait[3]
			tm_a(ud, Health, tm.hp, true)
			tm_a(ud, "speed", tm.spd, true)
			tm_a(ud, "turnrate", tm.turnrate)
			tm_a(ud, "maxacc", tm.maxacc)
			tm_a(ud, "idleautoheal", tm.autoheal)
			if cp then
				tm_a(cp, "shield_power", tm.shield_power, true)
				tm_a(cp, "shield_radius", tm.shield_radius, true)
			end
			if ud.weapondefs then
				for wn, wd in pairs(ud.weapondefs) do
					if wd.interceptor ~= 1 and wd.targetable ~= 1 then
						tm_a(wd, "areaofeffect", tm.aoe, true)
						tm_a(wd, "range", tm.rng, true)
						tm_a(wd, "reloadtime", tm.rld)
						tm_a(wd, "energypershot", tm.energypershot)
						tm_a(wd, "sprayangle", tm.acc)
						tm_a(wd, "accuracy", tm.acc)
						if tm.dmg and wd.damage then
							for k, v in pairs(wd.damage) do wd.damage[k] = v * tm.dmg end
						end
						if tm.impf then wd.impulsefactor = tm.impf end
						if tm.impb then wd.impulseboost = tm.impb end
						if tm.fs then wd.firestarter = tm.fs end
						if tm.wob then wd.wobble = tm.wob end
						if tm.dnc then wd.dance = tm.dnc end
					end
				end
			end
		end
		if name then
			local at_name = at and (" " .. at[1]) or ""
			local trait_name = trait and (" " .. trait[1]) or ""
			table.insert(rename_list, {name, "prefix", "[" .. rarities[unit_rarity] .. trait_name .. at_name .. "]"})
			table.insert(rename_list, {name, "desc_prefix", "Mk." .. unit_rarity .. "   "})
		end
	else
		if name then
			table.insert(rename_list, {name, "prefix", "[Common]"})
			table.insert(rename_list, {name, "desc_prefix", "Mk." .. unit_rarity .. " "})
		end
	end
end

Spring.Echo("tweakdefs_rename_get_ready")
for i, entry in pairs(rename_list) do
	Spring.Echo("/("..entry[1].."/-"..entry[2].."/-"..entry[3].."/)")
end
Spring.Echo("tweakdefs_rename_end")
