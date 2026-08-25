-- Offline smoke test for the tweakdefs modules.
--
--   lua5.1 scripts/smoke_test.lua [extra_defs_dir] [seed]
--   make test-docker            (runs it in the build image)
--
-- Builds a synthetic UnitDefs table that covers every branch the mods take
-- (lab, mobile con, bot, turret, mex, solar, radar, commander, raptor, scav,
-- critter), optionally merges real BAR unit defs from a directory of
-- `return { name = {...} }` files, then runs mod.lua -> mod_part2.lua ->
-- mod_tiers.lua in the same order the engine loads the slots.
-- Fails loudly on a Lua error and checks a few invariants afterwards.

local function copy(t)
	local r = {}
	for k, v in pairs(t) do
		if type(v) == "table" then r[k] = copy(v) else r[k] = v end
	end
	return r
end

--------------------------------------------------------------------------------
-- Synthetic defs
--------------------------------------------------------------------------------

local function gun(dmg, reload)
	return {
		range = 300, reloadtime = reload or 1.2, areaofeffect = 24,
		weaponvelocity = 400, damage = { default = dmg or 100, commanders = (dmg or 100)/2 },
		customparams = {},
	}
end

local UnitDefs = {
	armlab = { metalcost = 600, energycost = 1200, buildtime = 6000, health = 2000,
		buildoptions = { "armck", "armpw", "armrock", "armham", "armwar", "armflea" },
		workertime = 100, builddistance = 128, builder = true,
		customparams = { techlevel = 1 } },
	-- energymake is not a typo: every BAR construction unit trickles energy
	-- (armck 7, armack 14), which is exactly what used to get cons filed as
	-- eco buildings and exempted from the tier filter.
	armck = { metalcost = 110, energycost = 190, buildtime = 2000, health = 500, speed = 46,
		builder = true, workertime = 80, builddistance = 128, energymake = 7,
		-- T1 cons are what puts the T2 lab on the map, which is what makes it
		-- eligible for mod_tiers.lua's commander override
		buildoptions = { "armlab", "armalab", "armsolar", "armmex", "armllt",
			"armrad", "armanni" },
		customparams = { techlevel = 1 } },
	armpw = { metalcost = 46, energycost = 690, buildtime = 1000, health = 300, speed = 47,
		weapondefs = { arm_pw = gun(20, 0.4) }, customparams = { techlevel = 1 } },
	armrock = { metalcost = 90, energycost = 1000, buildtime = 1500, health = 380, speed = 39,
		weapondefs = { arm_rock = gun(70, 1.5) }, customparams = { techlevel = 1 } },
	armham = { metalcost = 130, energycost = 1400, buildtime = 2200, health = 590, speed = 33,
		weapondefs = { arm_ham = gun(115, 2.1) }, customparams = { techlevel = 1 } },
	armwar = { metalcost = 200, energycost = 2200, buildtime = 3000, health = 1000, speed = 30,
		weapondefs = { arm_war = gun(180, 1.1) }, customparams = { techlevel = 1 } },
	armflea = { metalcost = 35, energycost = 400, buildtime = 700, health = 90, speed = 90,
		weapondefs = { arm_flea = gun(9, 0.3) }, customparams = { techlevel = 1 } },
	armllt = { metalcost = 65, energycost = 300, buildtime = 900, health = 600,
		weapondefs = { arm_llt = gun(60, 0.8) }, customparams = { techlevel = 1 } },
	-- The T2 turret carries a battery and a radar, the two fields that used to
	-- get it filed as eco/utility and waved past the tier filter
	armanni = { metalcost = 1450, energycost = 22000, buildtime = 24000, health = 3000,
		energystorage = 1000, radardistance = 1500,
		weapondefs = { arm_anni = gun(420, 2.2) }, customparams = { techlevel = 2 } },
	armbeamer = { metalcost = 150, energycost = 1300, buildtime = 2000, health = 800,
		weapondefs = { arm_beam = { range = 320, reloadtime = 0.5, beamtime = 0.5,
			damage = { default = 40 }, customparams = {} } },
		customparams = { techlevel = 1 } },
	armmex = { metalcost = 50, energycost = 500, buildtime = 1800, health = 260,
		extractsmetal = 0.001, footprintx = 4, footprintz = 4,
		customparams = { techlevel = 1 } },
	armmoho = { metalcost = 620, energycost = 8000, buildtime = 12000, health = 1500,
		extractsmetal = 0.004, energyupkeep = 20, footprintx = 4, footprintz = 4,
		customparams = { techlevel = 2 } },
	-- Solars really do generate through a negative energyupkeep, not energymake
	-- 5x5 -> 4x4: the pairing the footprint guard has to reject
	armsolar = { metalcost = 155, energycost = 0, buildtime = 2800, health = 320,
		energyupkeep = -20, onoffable = true, footprintx = 5, footprintz = 5,
		customparams = { techlevel = 1 } },
	armadvsol = { metalcost = 350, energycost = 3000, buildtime = 8000, health = 480,
		energymake = 80, footprintx = 4, footprintz = 4,
		customparams = { techlevel = 2 } },
	armgeo = { metalcost = 560, energycost = 6000, buildtime = 9000, health = 1000,
		energymake = 300, energystorage = 1000, footprintx = 5, footprintz = 5,
		customparams = { techlevel = 1 } },
	armageo = { metalcost = 1600, energycost = 20000, buildtime = 30000, health = 2500,
		energymake = 1250, energystorage = 12000, footprintx = 5, footprintz = 5,
		customparams = { techlevel = 2 } },
	armfus = { metalcost = 4200, energycost = 20000, buildtime = 50000, health = 3000,
		energymake = 750, energystorage = 2500, customparams = { techlevel = 2 } },
	armestor = { metalcost = 170, energycost = 1500, buildtime = 2500, health = 800,
		energystorage = 6000, customparams = { techlevel = 1 } },
	armdrag = { metalcost = 8, energycost = 40, buildtime = 200, health = 1400,
		customparams = { techlevel = 1 } },
	armmakr = { metalcost = 1, energycost = 1150, buildtime = 3000, health = 260,
		energyupkeep = 70, customparams = { techlevel = 1,
			energyconv_capacity = 70, energyconv_efficiency = 0.014 } },
	armwin = { metalcost = 45, energycost = 175, buildtime = 1200, health = 180,
		windgenerator = 25, customparams = { techlevel = 1 } },
	armrad = { metalcost = 60, energycost = 600, buildtime = 1300, health = 200,
		radardistance = 2100, energyupkeep = 15, customparams = { techlevel = 1 } },
	armmstor = { metalcost = 130, energycost = 500, buildtime = 1500, health = 800,
		metalstorage = 3000, customparams = { techlevel = 1 } },
	armalab = { metalcost = 1100, energycost = 5000, buildtime = 12000, health = 3000,
		buildoptions = { "armzeus", "armfido" }, workertime = 200, builder = true,
		customparams = { techlevel = 2 } },
	armzeus = { metalcost = 400, energycost = 5000, buildtime = 6000, health = 2000, speed = 31,
		weapondefs = { arm_zeus = gun(280, 1.6) }, customparams = { techlevel = 2 } },
	armfido = { metalcost = 320, energycost = 4200, buildtime = 5200, health = 1300, speed = 40,
		weapondefs = { arm_fido = gun(210, 2.4) }, customparams = { techlevel = 2 } },
	-- BAR ships every commander with a hole in buildoptions -- armcom has no
	-- [19] -- and the whole naval half of the list sits behind it. ipairs()
	-- stops at the hole, so the gap here is load-bearing: it is the difference
	-- between filtering the list and amputating it.
	armcom = { metalcost = 2600, energycost = 26000, buildtime = 60000, health = 3700, speed = 24,
		builder = true, workertime = 300, builddistance = 128,
		buildoptions = { [1] = "armlab", [2] = "armllt",
			[4] = "armsolar", [5] = "armmex", [6] = "armrad" },
		weapondefs = { arm_disintegrator = gun(1000, 1.0) },
		customparams = { techlevel = 1, iscommander = true } },
	corcom = { metalcost = 2600, energycost = 26000, buildtime = 60000, health = 3700, speed = 24,
		builder = true, workertime = 300, builddistance = 128,
		buildoptions = { "corlab", "corsolar" },
		weapondefs = { cor_disintegrator = gun(1000, 1.0) },
		customparams = { techlevel = 1, iscommander = true } },
	corlab = { metalcost = 600, energycost = 1200, buildtime = 6000, health = 2000,
		buildoptions = { "corak" }, workertime = 100, builder = true,
		customparams = { techlevel = 1 } },
	corak = { metalcost = 50, energycost = 700, buildtime = 1100, health = 320, speed = 50,
		weapondefs = { cor_ak = gun(25, 0.4) }, customparams = { techlevel = 1 } },
	corsolar = { metalcost = 155, energycost = 0, buildtime = 2800, health = 320,
		energyupkeep = -20, onoffable = true, customparams = { techlevel = 1 } },
	-- PvE rosters: must come out of every module untouched
	raptor_land_swarmer_basic_t1_v1 = { metalcost = 50, energycost = 50, buildtime = 500,
		health = 400, speed = 90, weapondefs = { raptor_bite = gun(45, 0.7) },
		customparams = { subfolder = "other/raptors" } },
	raptor_turret_basic_t2_v1 = { metalcost = 100, energycost = 100, buildtime = 900,
		health = 2000, weapondefs = { raptor_spike = gun(120, 1.4) },
		customparams = { subfolder = "other/raptors" } },
	scavengerbossv4 = { metalcost = 90000, energycost = 900000, buildtime = 900000,
		health = 500000, speed = 20, buildoptions = { "corak" },
		weapondefs = { boss_gun = gun(2000, 0.9) },
		customparams = { subfolder = "other/scavengers" } },
	scavbeacon_t1 = { metalcost = 100, energycost = 1000, buildtime = 1000, health = 4000,
		customparams = { subfolder = "other/scavengers" } },
	critter_penguin = { metalcost = 1, energycost = 1, buildtime = 10, health = 10, speed = 30,
		customparams = {} },
}

--------------------------------------------------------------------------------
-- Optional: merge real BAR unit defs from a directory
--------------------------------------------------------------------------------

local extra_dir, seed = ...
if seed then math.randomseed(tonumber(seed)) end
if extra_dir then
	local p = io.popen('ls "' .. extra_dir .. '"/*.lua 2>/dev/null')
	local loaded = 0
	if p then
		for line in p:lines() do
			local chunk = loadfile(line)
			if chunk then
				local env = setmetatable({}, { __index = _G })
				env.Shared = {}
				env.GetFilename = function() return line end
				setfenv(chunk, env)
				local ok, defs = pcall(chunk)
				if ok and type(defs) == "table" then
					for n, d in pairs(defs) do
						if type(d) == "table" then UnitDefs[n] = d; loaded = loaded + 1 end
					end
				end
			end
		end
		p:close()
	end
	print(("merged %d real unit defs from %s"):format(loaded, extra_dir))
end

-- BAR normalises every def before tweakdefs run (gamedata/unitdefs_post.lua)
for _, ud in pairs(UnitDefs) do
	ud.customparams = ud.customparams or {}
	ud.buildoptions = ud.buildoptions or {}
	ud.weapondefs = ud.weapondefs or {}
	ud.weapons = ud.weapons or {}
end

local pristine = copy(UnitDefs)

--------------------------------------------------------------------------------
-- Engine stubs
--------------------------------------------------------------------------------

local echoes = {}
Spring = { Echo = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts+1] = tostring((select(i, ...))) end
	echoes[#echoes+1] = table.concat(parts, " ")
end }
VFS = { LoadFile = function() return nil end }
_G.UnitDefs = UnitDefs

--------------------------------------------------------------------------------
-- Run the slots in load order
--------------------------------------------------------------------------------

local slots = { "mod.lua", "mod_part2.lua", "mod_tiers.lua" }
for _, f in ipairs(slots) do
	local chunk, err = loadfile(f)
	if not chunk then error("syntax error in " .. f .. ": " .. tostring(err)) end
	local ok, run_err = pcall(chunk)
	if not ok then error("runtime error in " .. f .. ": " .. tostring(run_err)) end
	print(("ok   %-20s"):format(f))
end

--------------------------------------------------------------------------------
-- Report + invariants
--------------------------------------------------------------------------------

local renames, blocks, pve_renames = {}, 0, {}
local last_count = nil
for _, line in ipairs(echoes) do
	local n, kind, val = line:match("^/%((.-)/%-(.-)/%-(.-)/%)$")
	if n and kind == "prefix" then
		renames[n] = (renames[n] and renames[n] .. " " or "") .. val
		if n:find("raptor") or n:find("scav") or n:find("critter") then
			pve_renames[#pve_renames+1] = n
		end
	end
	local bc = line:match("^tweakdefs_rename_block_count:(%d+)$")
	if bc then blocks = blocks + 1; last_count = tonumber(bc) end
	if line:match("^%[BaRandom") then print("     " .. line) end
end

local failures = {}
local function check(cond, msg)
	if not cond then failures[#failures+1] = msg end
end

check(#pve_renames == 0, "PvE units were renamed: " .. table.concat(pve_renames, ", "))
for n, ud in pairs(UnitDefs) do
	if n:find("raptor") or n:find("scav") or n:find("critter") then
		local before = pristine[n]
		check(ud.health == before.health, n .. ": health changed (" ..
			tostring(before.health) .. " -> " .. tostring(ud.health) .. ")")
		check(#ud.buildoptions == #before.buildoptions, n .. ": buildoptions filtered")
		check(ud.customparams.rarity == nil, n .. ": got a rarity")
	end
end
-- Eco classification: energy producers must draw from the energy trait pool and
-- pure storages from the storage one (fusions used to be filed as storage
-- because of their energystorage, solars fell through to "generic").
local STORAGE_TRAITS = { "Vault", "Volatile Reserve" }
local ENERGY_TRAITS = { "Surge", "Efficient Core" }
local function produces_energy(ud)
	return (tonumber(ud.energymake) or 0) > 0 or (tonumber(ud.energyupkeep) or 0) < 0
end
for n, ud in pairs(UnitDefs) do
	local was = pristine[n]
	local tag = renames[n] or ""
	if produces_energy(was) then
		for _, t in ipairs(STORAGE_TRAITS) do
			check(not tag:find(t, 1, true), n .. ": energy building got storage trait " .. t)
		end
		if ud.customparams.rarity then
			local before = tonumber(was.energymake) or tonumber(was.energyupkeep)
			local after = tonumber(ud.energymake) or tonumber(ud.energyupkeep)
			local grew = before > 0 and after >= before or before < 0 and after <= before
			check(grew, n .. ": energy output shrank (" .. tostring(before) ..
				" -> " .. tostring(after) .. ") " .. tag)
		end
	elseif (tonumber(was.energystorage) or 0) > 500 or (tonumber(was.metalstorage) or 0) > 500 then
		for _, t in ipairs(ENERGY_TRAITS) do
			check(not tag:find(t, 1, true), n .. ": storage building got energy trait " .. t)
		end
	end
end

-- Every building trait belongs to a category pool; an independent copy of the
-- classifier catches the whole class of "wrong pool" bugs (fusions filed as
-- storage, solars as generic, everything as factory because buildoptions is an
-- empty table rather than nil).
local TRAIT_CATS = {
	["Deep Bore"] = "mex", ["Volatile Vein"] = "mex",
	["Surge"] = "energy", ["Efficient Core"] = "energy",
	["Metamorphic"] = "mex energy",
	["Gale Force"] = "windtidal", ["Anchored"] = "windtidal",
	["Refined Process"] = "converter", ["Bulk Conversion"] = "converter",
	["All-Seeing"] = "radar", ["Shroud"] = "radar",
	["Deep Scan"] = "sonar",
	["Resilient"] = "radar sonar generic",
	["Blackout"] = "jammer", ["Stealth Field"] = "jammer",
	["Vault"] = "storage", ["Volatile Reserve"] = "storage",
	["Bunker"] = "generic",
}
local function category_of(ud)
	local cp = ud.customparams or {}
	if (tonumber(ud.extractsmetal) or 0) > 0 then return "mex" end
	if cp.energyconv_capacity then return "converter" end
	if ud.windgenerator or ud.tidalgenerator then return "windtidal" end
	if (tonumber(ud.radardistancejam) or 0) > 0 then return "jammer" end
	if (tonumber(ud.radardistance) or 0) > 0 then return "radar" end
	if (tonumber(ud.sonardistance) or 0) > 0 then return "sonar" end
	if ud.buildoptions and #ud.buildoptions > 0 then return "factory" end
	if ud.builder == true then return "nano" end
	if produces_energy(ud) then return "energy" end
	if (tonumber(ud.metalstorage) or 0) > 500 or (tonumber(ud.energystorage) or 0) > 500 then
		return "storage"
	end
	return "generic"
end
for n, ud in pairs(UnitDefs) do
	local was = pristine[n]
	local tag = renames[n]
	local passive = not was.speed and next(was.weapondefs) == nil and was.builder ~= true
	if tag and passive then
		local cat = category_of(was)
		for trait, allowed in pairs(TRAIT_CATS) do
			if tag:find(trait, 1, true) then
				check(allowed:find(cat, 1, true),
					n .. " (" .. cat .. ") got the " .. trait .. " trait [" .. allowed .. "]")
			end
		end
	end
end

-- Compare mod_part2.lua's own category histogram against this file's
-- independent classifier. This is what makes a misclassification loud: with the
-- wrong test the bug just showed up as "those buildings quietly get no traits".
local hist = nil
for _, line in ipairs(echoes) do
	local h = line:match("^%[BaRandom Part 2%] categories: (.+)$")
	if h then hist = h end
end
check(hist ~= nil, "mod_part2.lua printed no category histogram")
if hist then
	local reported = {}
	for cat, n in hist:gmatch("(%a+)=(%d+)") do reported[cat] = tonumber(n) end
	local expected = {}
	for n, was in pairs(pristine) do
		local passive = not was.speed and next(was.weapondefs) == nil and was.builder ~= true
		if passive and not (n:find("raptor") or n:find("scav") or n:find("critter")) then
			local c = category_of(was)
			expected[c] = (expected[c] or 0) + 1
		end
	end
	for c, n in pairs(expected) do
		check(reported[c] == n, ("category %s: mod says %s, test says %d")
			:format(c, tostring(reported[c]), n))
	end
	for c, n in pairs(reported) do
		check(expected[c] == n, ("category %s: mod says %d, test says %s")
			:format(c, n, tostring(expected[c])))
	end
	print("     categories: " .. hist)
end

-- mod_tiers.lua must recognise every producer as eco; anything it cannot place
-- silently becomes all-tier, which is fine for transports and walls but would
-- hide an eco building falling through the cracks.
local unclassified = ""
for _, line in ipairs(echoes) do
	local u = line:match("^%[BaRandom Tiers%] unclassified, kept all%-tier: (.+)$")
	if u then unclassified = u end
end
for n, was in pairs(pristine) do
	if not was.speed and (produces_energy(was) or (tonumber(was.extractsmetal) or 0) > 0
	   or was.windgenerator or was.tidalgenerator) then
		check(not unclassified:find(n, 1, true),
			n .. ": eco building unclassified by mod_tiers.lua")
	end
end

local rolled_tier = nil
for _, line in ipairs(echoes) do
	local t = line:match("^%[BaRandom Tiers%] T(%d)$")
	if t then rolled_tier = tonumber(t) end
end
check(rolled_tier ~= nil, "mod_tiers.lua never echoed its roll")

local function pve(n)
	return n:find("raptor") or n:find("scav") or n:find("critter")
end
local function tech(d)
	local t = math.floor(tonumber(d.customparams and d.customparams.techlevel) or 1)
	if t < 1 then return 1 elseif t > 3 then return 3 end
	return t
end
-- What mod_tiers.lua is allowed to gate: things that come off a build list and
-- belong to a tech tier. Everything else -- eco, radar, nano turrets,
-- transports, walls -- is all-tier and has to survive every roll. Read off the
-- pristine defs, so a factory the filter emptied is still recognised as one.
local function gated(d)
	if d.customparams and d.customparams.iscommander then return false end
	local armed = d.weapondefs and next(d.weapondefs) ~= nil
	if d.speed then return (armed or d.builder == true) and true or false end
	if next(d.buildoptions) ~= nil then return true end  -- factory
	if d.builder == true then return false end           -- nano turret
	return armed and true or false                       -- defence
end

-- Raw buildoptions are sparse and ipairs() stops at the first hole, taking the
-- rest of the list with it. Walk the original indices and account for every
-- entry: gated ones survive only at the rolled tier, the rest always survive.
-- The one exception is the T3 escape hatch, which hands the gantries T2
-- construction units on purpose.
for n, was in pairs(pristine) do
	if rolled_tier and not pve(n) then
		local now = {}
		for _, o in ipairs(UnitDefs[n].buildoptions) do now[o] = true end
		local hi = 0
		for k in pairs(was.buildoptions) do
			if type(k) == "number" and k > hi then hi = k end
		end
		for i = 1, hi do
			local o = was.buildoptions[i]
			local d = o and pristine[o]
			if d and gated(d) then
				local hatch = rolled_tier == 3 and d.speed and d.builder == true
				check(not now[o] or tech(d) == rolled_tier or hatch,
					("%s still offers T%d %s on a T%d roll")
						:format(n, tech(d), o, rolled_tier))
			elseif d then
				check(now[o], n .. ": dropped all-tier build option " .. o)
			end
		end
	end
end

-- On a T2/T3 roll the commander trades its T1 labs for the rolled tier's
if rolled_tier and rolled_tier ~= 1 then
	local com = {}
	for _, o in ipairs(UnitDefs.armcom.buildoptions) do com[o] = true end
	check(not com.armlab, "armcom kept the T1 lab on a T" .. rolled_tier .. " roll")
	if rolled_tier == 2 then
		check(com.armalab, "armcom never got the T2 lab on a T2 roll")
	end
end

-- Deterministic (no roll involved): every evolution pair mod_part2.lua kept
-- must resolve and keep the footprint. A mismatch moves the rebuilt structure
-- off the build grid — armsolar 5x5 -> armadvsol 4x4 was exactly that.
local evo_line = ""
for _, line in ipairs(echoes) do
	local e = line:match("^%[BaRandom Part 2%] evo: (.*)$")
	if e then evo_line = e end
end
local evo_seen = 0
for from, to in evo_line:gmatch("(%w+)>(%w+)") do
	evo_seen = evo_seen + 1
	local a, b = UnitDefs[from], UnitDefs[to]
	check(a ~= nil and b ~= nil, "evo pair " .. from .. ">" .. to .. ": missing def")
	if a and b then
		local ax, az = tonumber(a.footprintx) or 1, tonumber(a.footprintz) or 1
		local bx, bz = tonumber(b.footprintx) or 1, tonumber(b.footprintz) or 1
		check(ax == bx and az == bz, ("evo pair %s (%dx%d) > %s (%dx%d): footprint changes")
			:format(from, ax, az, to, bx, bz))
	end
end
check(evo_seen > 0, "mod_part2.lua kept no evolution pairs at all")

-- The factory list is derived from the live build tree now, so a broken
-- derivation would silently drop every guaranteed high-rarity pick.
local factories = nil
for _, line in ipairs(echoes) do
	local f = line:match("^%[BaRandom%] factories: (%d+)$")
	if f then factories = tonumber(f) end
end
check(factories ~= nil, "mod.lua printed no factory count")
if factories then
	local expected = 0
	for n, was in pairs(pristine) do
		if #was.buildoptions > 0 and not was.speed
		   and not (n:find("raptor") or n:find("scav") or n:find("critter")) then
			for i = 1, #was.buildoptions do
				local o = pristine[was.buildoptions[i]]
				if o and o.speed and o.builder ~= true and next(o.weapondefs) ~= nil then
					expected = expected + 1
					break
				end
			end
		end
	end
	check(factories == expected,
		("factories: mod says %d, test says %d"):format(factories, expected))
	print("     factories: " .. factories)
end
print("     evo pairs: " .. evo_line)

check(blocks == 2, "expected 2 rename block counters (mod, buildings+xp), got " .. blocks)
check(last_count == 2, "last block_count should be 2, got " .. tostring(last_count))

local schooled, ascend, mentor = 0, 0, 0
local ascenders = {}
for n, ud in pairs(UnitDefs) do
	local cp = ud.customparams
	if cp.evolution_condition == "xp" then
		ascend = ascend + 1
		ascenders[#ascenders+1] = ("%s -> %s @ %s xp"):format(n,
			tostring(cp.evolution_target), tostring(cp.evolution_xp_threshold))
		check(tonumber(cp.evolution_xp_threshold) ~= nil, n .. ": bad xp threshold")
	end
	-- Any evolution we wire up (Metamorphic or Ascendant) must resolve, and a
	-- static unit is re-created on its own footprint: a target of a different
	-- size overlaps its neighbours, and a parity change (5x5 -> 4x4) puts it off
	-- the build grid.
	if cp.evolution_target and not pristine[n].customparams.evolution_target then
		local target = UnitDefs[cp.evolution_target]
		check(target ~= nil,
			n .. ": evolves into unknown unit " .. tostring(cp.evolution_target))
		-- Ascendant only: it must stay inside the rolled tier. Metamorphic is
		-- deliberately a T1 -> T2 eco upgrade, and eco is all-tier by design.
		if target and cp.evolution_condition == "xp" then
			local function tl(d)
				return (d.customparams and tonumber(d.customparams.techlevel)) or 1
			end
			check(tl(target) == tl(ud), ("%s (T%d) ascends into %s (T%d)")
				:format(n, tl(ud), cp.evolution_target, tl(target)))
		end
		if target and not ud.speed then
			local fx, fz = tonumber(ud.footprintx) or 1, tonumber(ud.footprintz) or 1
			local tx, tz = tonumber(target.footprintx) or 1, tonumber(target.footprintz) or 1
			check(fx == tx and fz == tz, ("%s (%dx%d) evolves into %s (%dx%d)")
				:format(n, fx, fz, cp.evolution_target, tx, tz))
		end
	end
	if cp.inheritxpratemultiplier then mentor = mentor + 1 end
	local was = pristine[n].customparams
	if was.evolution_target then
		check(cp.evolution_target == was.evolution_target,
			n .. ": pre-existing evolution chain was overwritten")
	end
	if was.inheritxpratemultiplier then
		check(cp.inheritxpratemultiplier == was.inheritxpratemultiplier,
			n .. ": pre-existing xp inheritance was overwritten")
	end
	if renames[n] and renames[n]:find("%+") then schooled = schooled + 1 end
	if cp.rarity then
		check(tonumber(ud.power) and tonumber(ud.power) > 0, n .. ": bad power " .. tostring(ud.power))
	end
end

print(("     %d units renamed, %d with an xp school, %d ascend, %d mentors")
	:format((function() local c = 0 for _ in pairs(renames) do c = c + 1 end return c end)(),
		schooled, ascend, mentor))

for _, a in ipairs(ascenders) do print("     ascend: " .. a) end

-- A few named samples, handy when eyeballing a run
for _, n in ipairs({ "armpw", "armwar", "armzeus", "armlab", "armllt",
                     "armmex", "armsolar", "armfus", "armgeo", "armestor" }) do
	local ud = UnitDefs[n]
	if ud then
		local out = ""
		if produces_energy(ud) then
			out = (" E=%s"):format(tostring(ud.energymake or -ud.energyupkeep))
		elseif tonumber(ud.extractsmetal) then
			out = (" M=%s"):format(tostring(ud.extractsmetal))
		elseif (tonumber(ud.energystorage) or 0) > 0 then
			out = (" stor=%s"):format(tostring(ud.energystorage))
		end
		print(("     %-10s %-46s hp=%-9s%s%s"):format(n, renames[n] or "-",
			tostring(ud.health or ud.maxdamage), out,
			ud.customparams.evolution_target and (" -> " .. ud.customparams.evolution_target) or ""))
	end
end

if #failures > 0 then
	print("\nFAILED:")
	for _, f in ipairs(failures) do print("  - " .. f) end
	os.exit(1)
end
print("\nall checks passed")
