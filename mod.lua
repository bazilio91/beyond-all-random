--BaRandom v19 by LoH
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

local function sv(t,k,m,r,f) t[k]=set_v(t[k],m,r,f) end
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

-- Pass 2b: assign archetype-specific traits to rarity 5+ units
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
		if cp then cp.cursed = tostring(cl) end
		sv(ud, Health, 0.93, cl, true)
		sv(ud, "speed", 0.97, cl, true)
		sv(ud, "maxacc", 0.97, cl)
		sv(ud, "turnrate", 0.97, cl)
		sv(ud, "sightdistance", 0.97, cl)
		sv(ud, "radardistance", 0.97, cl)
		sv(ud, MCost, 0.85, cl, true)
		sv(ud, ECost, 0.85, cl, true)
		sv(ud, "buildtime", 0.88, cl)
		if ud.weapondefs then
			for _, wd in pairs(ud.weapondefs) do
				if wd.interceptor ~= 1 and wd.targetable ~= 1 then
					sv(wd, "range", 0.97, cl, true)
					sv(wd, "reloadtime", 1.04, cl)
					if wd.damage then
						for k, v in pairs(wd.damage) do
							wd.damage[k] = set_v(v, 0.94, cl)
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
		local R = unit_rarity
		sv(ud, "power", 1.2, R)
		sv(ud, "speed", m_spd, R, true)
		sv(ud, "maxacc", 1.05, R)
		sv(ud, "maxdec", 1.05, R)
		sv(ud, "turnrate", 1.05, R)
		sv(ud, "sightdistance", 1.05, R)
		sv(ud, "radardistance", 1.1, R)
		sv(ud, Health, m_hp, R, true)
		sv(ud, "idleautoheal", 1.1, R)
		sv(ud, "energymake", 1.04, R)
		sv(ud, "extractsmetal", 1.1, R)
		sv(ud, "energyupkeep", 1.04, R)
		sv(ud, "tidalgenerator", 1.04, R)
		sv(ud, "windgenerator", 1.04, R)
		if ud.windgenerator and not cp.energymultiplier then sv(ud, MCost, 0.97, R, true) end
		if ud.tidalgenerator or ud.windgenerator or ud.builder == true or (not ud.speed and not ud.weapondefs) then
			sv(ud, MCost, 0.97, R, true)
			sv(ud, ECost, 0.98, R, true)
			sv(ud, "buildtime", 0.98, R)
			sv(ud, "workertime", 1.05, R, true)
			sv(ud, "builddistance", 1.05, R, true)
		else
			sv(ud, MCost, 1.035, R, true)
			sv(ud, ECost, 1.04, R, true)
			sv(ud, "buildtime", 1.05, R)
			sv(ud, "workertime", 1.05, R, true)
			sv(ud, "builddistance", 1.05, R, true)
		end
		if cp then
			sv(cp, "energyconv_efficiency", 1.04, R)
			sv(cp, "energyconv_capacity", 1.04, R, true)
			sv(cp, "shield_power", 1.1, R, true)
			sv(cp, "shield_radius", 1.05, R, true)
			sv(cp, "energymultiplier", 1.04, R, true)
		end
		if ud.weapondefs then
			for _, wd in pairs(ud.weapondefs) do
				if wd.interceptor == 1 or wd.targetable == 1 then
					sv(wd, "coverage", 1.02, R, true)
					sv(wd.damage, "default", 1.1, R)
					sv(wd, "areaofeffect", 1.01, R)
				else
					local wcp = wd.customparams
					if not wd.reloadtime or wd.reloadtime < 0.034 then wd.reloadtime = 0.034 end
					if wd.burstrate and wd.burstrate < 0.034 then wd.burstrate = 0.034 end
					if wd.burst and wd.burstrate then
						if wd.burst*wd.burstrate > wd.reloadtime then wd.reloadtime = wd.burst*wd.burstrate end
					end
					if wd.beamtime then
						if wd.beamtime > wd.reloadtime then wd.reloadtime = wd.beamtime end
					end

					local is_cont = false
					if wd.burstrate and wd.burst and wd.reloadtime then
						local brb = wd.burstrate*wd.burst
						if brb/wd.reloadtime >= 0.98 or brb >= wd.reloadtime then
							is_cont = true
						end
					end
					local is_cont_b = false
					if wd.beamtime and wd.reloadtime then
						if wd.beamtime/wd.reloadtime >= 0.90 or wd.beamtime >= wd.reloadtime then
							is_cont_b = true
						end
					end
					sv(wd, "reloadtime", m_rld, R)
					sv(wd, "burstrate", m_rld, R)
					sv(wd, "areaofeffect", m_aoe, R)
					sv(wd, "weaponvelocity", 1.05, R)
					sv(wd, "range", m_rng, R, true)
					sv(wd, "flighttime", 1.05, R)
					sv(wd, "sprayangle", m_acc, R)
					sv(wd, "accuracy", m_acc, R)
					sv(wd, "energypershot", 1.1, R, true)
					sv(wd, "metalpershot", 1.05, R, true)
					sv(wd, "stockpiletime", 0.96, R, true)
					sv(wd, "startvelocity", 1.05, R)
					sv(wd, "turnrate", 1.03, R)
					sv(wd, "weaponacceleration", 1.05, R)
					sv(wd, "laserflaresize", 1.04, R)
					sv(wd, "size", 1.09, R)
					sv(wd, "thickness", 1.06, R)

					if wcp then
						sv(wcp, "overrange_distance", m_rng, R, true)
						sv(wcp, "controlradius", m_rng, R, true)
						sv(wcp, "engagementrange", m_rng, R, true)
						local sr = tonumber(wcp.spark_range)
						if sr then wcp.spark_range = tostring(set_v(sr, 1.05, R, true)) end
						sv(wcp, "area_onhit_damage", 1.05, R, true)
						sv(wcp, "area_onhit_range", 1.05, R, true)
					end

					if wd.damage then
						local dm = 1
						local dsm = 0
						local rt = wd.reloadtime or 1
						local bt = wd.beamtime or 0
						local br = wd.burstrate or 1
						local b = wd.burst or 1

						if rt < 0.034 then
							dm = dm + (0.034/rt) -1
							wd.reloadtime = 0.034
							rt = 0.034
						end
						local is_sweepfire = wcp and wcp.sweepfire
						if is_sweepfire or name == "armbeamer" then
							wd.reloadtime = wd.reloadtime or rt
							rt = wd.reloadtime
						end
						if bt > rt then
							dm = dm + (bt/rt) -1
							wd.reloadtime = bt
							rt = bt
						end
						if br < 0.034 then
							dm = dm + (0.034/br) -1
							wd.burstrate = 0.034
							br = 0.034
						end
						local brb = br*b
						if wd.burstrate and wd.burst and brb > rt then
							dm = dm + (brb/rt) -1
							wd.reloadtime = brb
						end
						for k, v in pairs(wd.damage) do
							if v == "commanders" then
								wd.damage[k] = set_v(v, 1.02+dsm, R, false, dm)
							else
								wd.damage[k] = set_v(v, m_dmg+dsm, R, false, dm)
							end
						end
					end
					local sh = wd.shield
					if sh then
						sv(sh, "power", 1.1, R, true)
						sv(sh, "powerregen", 1.1, R, true)
						sv(sh, "radius", 1.05, R, true)
						sv(sh, "force", 1.05, R)
						sv(sh, "powerregenenergy", 0.99, R, true)
					end
					if is_cont then wd.reloadtime = wd.burst*wd.burstrate end
					if is_cont_b then wd.reloadtime = wd.beamtime end
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
