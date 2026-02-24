-- AI Rarity Advisor: nudges engine AIs (BARbarian) toward building higher-rarity units
-- Install to: <BAR>/data/games/BAR.sdd/luarules/gadgets/ai_rarity_advisor.lua

function gadget:GetInfo()
	return {
		name    = "AI Rarity Advisor",
		desc    = "Makes engine AIs prefer higher-rarity combat units",
		author  = "random-bar",
		date    = "2026",
		license = "GPL",
		layer   = 100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local spGetTeamList     = Spring.GetTeamList
local spGetTeamInfo     = Spring.GetTeamInfo
local spGetTeamLuaAI    = Spring.GetTeamLuaAI
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spEcho            = Spring.Echo

local aiTeams = {}
local factoryBest = {} -- factoryDefID -> sorted list of {id=defID, rarity=n}

-- Probability of swapping a build order to a higher-rarity unit
local SWAP_CHANCE = 0.5

function gadget:Initialize()
	-- Find engine AI teams (BARbarian etc), skip Lua AIs (Scavengers, STAI)
	for _, teamID in ipairs(spGetTeamList()) do
		local _, _, _, isAI = spGetTeamInfo(teamID, false)
		local luaAI = spGetTeamLuaAI(teamID)
		if isAI and (not luaAI or luaAI == "") then
			aiTeams[teamID] = true
			spEcho("[RarityAdvisor] Tracking AI team " .. teamID)
		end
	end

	if not next(aiTeams) then
		spEcho("[RarityAdvisor] No engine AI teams found, removing gadget")
		gadgetHandler:RemoveGadget()
		return
	end

	-- Build factory -> best combat units lookup
	for defID, def in ipairs(UnitDefs) do
		if def.isFactory and def.buildOptions and #def.buildOptions > 0 then
			local opts = {}
			for _, buildDefID in ipairs(def.buildOptions) do
				local bdef = UnitDefs[buildDefID]
				local r = tonumber(bdef.customParams and bdef.customParams.rarity) or 0
				-- Only consider mobile combat units (have weapons, can move)
				if bdef.weapons and #bdef.weapons > 0 and bdef.speed and bdef.speed > 0 and not bdef.isBuilder then
					opts[#opts + 1] = { id = buildDefID, rarity = r }
				end
			end
			table.sort(opts, function(a, b) return a.rarity > b.rarity end)
			if #opts > 0 then
				factoryBest[defID] = opts
				spEcho("[RarityAdvisor] " .. def.name .. ": best=" .. UnitDefs[opts[1].id].name .. " (rarity " .. opts[1].rarity .. ")")
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- Allow our own redirected commands
	if fromLua then return true end

	-- Only intercept build orders (negative cmdID)
	if cmdID >= 0 then return true end

	-- Only for engine AI teams
	if not aiTeams[teamID] then return true end

	-- Only for factories we have data on
	if not factoryBest[unitDefID] then return true end

	local buildDefID = -cmdID
	local bdef = UnitDefs[buildDefID]

	-- Don't interfere with constructor/builder production
	if bdef and bdef.isBuilder then return true end

	-- Roll the dice — let some builds through unchanged
	if math.random() > SWAP_CHANCE then return true end

	-- Pick the best rarity combat unit this factory can build
	local best = factoryBest[unitDefID][1]
	if best.id == buildDefID then return true end -- already building the best

	spEcho("[RarityAdvisor] Swap: " .. (bdef and bdef.name or "?") .. " -> " .. UnitDefs[best.id].name .. " (rarity " .. best.rarity .. ")")
	spGiveOrderToUnit(unitID, -best.id, cmdParams, cmdOptions)
	return false -- block original command
end
