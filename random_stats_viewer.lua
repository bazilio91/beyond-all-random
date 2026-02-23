function widget:GetInfo()
    return {
        name    = "Random Rarities Viewer",
        desc    = "Shows economy buildings and factory unit rankings with icons. Toggle: /unitstats",
        author  = "Custom",
        date    = "2026",
        license = "GNU GPL, v2 or later",
        layer   = 200,
        enabled = true,
    }
end

--------------------------------------------------------------------------------
-- Rarity tiers (from BAR-Random-Rarities v0.7)
--------------------------------------------------------------------------------

local RARITIES = {
    "Uncommon","Rare","Exceptional","Epic","Exotic",
    "Legendary","Mythical","Miracle","Divine","Eternal",
    "Supreme","Omega","Unique","Jackpot","Immortal",
    "Absurd","Godlike","TooRNG","Insanely Lucky","Dope",
    "Admin","GOD","ERROR","Super Sayan","Beyond",
    "MGGW","AMBO","Beyond All Reason",
}

local rarityIndex = {}
for i, r in ipairs(RARITIES) do
    if not rarityIndex[r] then rarityIndex[r] = i end
end

--------------------------------------------------------------------------------
-- GL / Spring locals
--------------------------------------------------------------------------------

local glColor         = gl.Color
local glRect          = gl.Rect
local glScissor       = gl.Scissor
local glTexture       = gl.Texture
local glTexRect       = gl.TexRect
local spGetMouseState = Spring.GetMouseState
local spEcho          = Spring.Echo
local mathFloor       = math.floor
local mathMax         = math.max
local mathMin         = math.min
local strFormat       = string.format

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local PANEL_W      = 1340
local PANEL_H      = 840
local TITLE_H      = 36
local TAB_H        = 32
local SCROLLBAR_W  = 16
local RELOAD_BTN_W = 80
local CLOSE_BTN_W  = 30

local ROW_H        = 24
local SECTION_H    = 30
local FACTORY_H    = 28
local HEADER_H     = 20
local ICON_SZ      = 22

-- Toggle button (always visible on screen)
local TOGGLE_W     = 80
local TOGGLE_H     = 30

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy       = 0, 0
local panelX, panelY
local toggleX, toggleY  -- toggle button position
local visible        = true
local dragging       = false
local dragStartX, dragStartY = 0, 0
local dragPanelX, dragPanelY = 0, 0

local scrollOffset   = 0
local totalContentH  = 0
local viewportH      = 0

local dataByFaction  = {}
local factionList    = {}
local activeFaction  = nil
local displayRows    = {}

local font

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function round(n) return mathFloor((n or 0) + 0.5) end

local function inRect(mx, my, x1, y1, x2, y2)
    return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
end

local function printText(text, x, y, size, opts)
    if font then
        font:Print(text, x, y, size, opts or "o")
    elseif gl.Text then
        gl.Text(text, x, y, size, opts or "o")
    end
end

local function textWidth(text, size)
    if font and font.GetTextWidth then
        return font:GetTextWidth(text) * size
    elseif gl.GetTextWidth then
        return (gl.GetTextWidth(text) or 0.5) * size
    end
    return #text * size * 0.6
end

local function extractBaseRarity(str)
    local bestName, bestIdx, bestLen = nil, 0, 0
    for i, name in ipairs(RARITIES) do
        if #name > bestLen and str:sub(1, #name) == name then
            local nextChar = str:sub(#name + 1, #name + 1)
            if nextChar == "" or nextChar == " " then
                bestName, bestIdx, bestLen = name, i, #name
            end
        end
    end
    return bestName, bestIdx
end

local function parseRarity(fullName)
    if not fullName or fullName == "" then
        return "Common", fullName or "???", 0
    end
    local bracket, clean = fullName:match("^%[(.-)%]%s*(.*)")
    if not bracket or not clean or clean == "" then
        return "Common", fullName, 0
    end
    -- Check for Cursed
    local cursedLevel = bracket:match("^Cursed Mk%.(%d+)")
    if cursedLevel then
        return bracket, clean, -(tonumber(cursedLevel) or 1)
    end
    -- Extract base rarity from composite string (e.g. "Mythical Phantom Brawler")
    local _, rIdx = extractBaseRarity(bracket)
    if rIdx > 0 then
        return bracket, clean, rIdx
    end
    return bracket, clean, rarityIndex[bracket] or 0
end

local function getDisplayName(def)
    local thn = def.translatedHumanName
    if type(thn) == "string" and thn ~= "" and not thn:find("^units%.") then
        return thn
    elseif type(def.humanName) == "string" and def.humanName ~= "" then
        return def.humanName
    end
    return def.name or "???"
end

local function getTooltip(def)
    local tt = def.translatedTooltip or def.tooltip
    if type(tt) == "string" and tt ~= "" and not tt:find("^units%.") then
        -- Strip rarity prefix from tooltip too if present
        local _, clean = tt:match("^%[.-%]%s*(.*)")
        if clean and clean ~= "" then return clean end
        return tt
    end
    return ""
end

local function rarityColor(idx)
    if idx < 0   then return "\255\180\060\060" end  -- Cursed
    if idx <= 0  then return "\255\150\150\150" end
    if idx <= 2  then return "\255\255\255\255" end
    if idx <= 4  then return "\255\030\200\030" end
    if idx <= 6  then return "\255\030\120\255" end
    if idx <= 10 then return "\255\200\050\255" end
    if idx <= 15 then return "\255\255\165\001" end
    if idx <= 20 then return "\255\255\215\001" end
    if idx <= 25 then return "\255\255\080\080" end
    return "\255\255\050\200"
end

local function fmtNum(n)
    n = n or 0
    if n >= 100000 then return strFormat("%.0fk", n / 1000) end
    if n >= 10000 then return strFormat("%.1fk", n / 1000) end
    return tostring(round(n))
end

local function rarityLabel(idx)
    if idx < 0 then return "Cursed" end
    if idx <= 0 then return "Common" end
    if idx <= #RARITIES then return RARITIES[idx] end
    return "???"
end

--------------------------------------------------------------------------------
-- Weapon stats
--------------------------------------------------------------------------------

local function getWeaponStats(def)
    local dps, maxRange = 0, 0
    if not def.weapons then return 0, 0 end
    for i = 1, #def.weapons do
        local w = def.weapons[i]
        if w and w.weaponDef then
            local wd = WeaponDefs[w.weaponDef]
            if wd then
                local dmg = 0
                if wd.damages then
                    for _, v in pairs(wd.damages) do
                        if type(v) == "number" and v > dmg then dmg = v end
                    end
                end
                local reload = wd.reload or 1
                if reload > 0 then dps = dps + dmg / reload end
                maxRange = mathMax(maxRange, wd.range or 0)
            end
        end
    end
    return round(dps), round(maxRange)
end

--------------------------------------------------------------------------------
-- Eco detection
--------------------------------------------------------------------------------

local function getEcoOutput(def)
    local eMake    = def.energyMake or 0
    local mExtract = def.extractsMetal or 0
    local wind     = def.windGenerator or 0
    local tidal    = def.tidalGenerator or 0
    local eStor    = def.energyStorage or 0
    local mStor    = def.metalStorage or 0

    local parts = {}
    local sortVal = 0

    if eMake > 5 then
        parts[#parts+1] = "E+" .. fmtNum(eMake)
        sortVal = sortVal + eMake
    end
    if mExtract > 0 then
        parts[#parts+1] = "Mex"
        sortVal = sortVal + mExtract * 10000
    end
    if wind > 0 then
        parts[#parts+1] = "Wind"
        sortVal = sortVal + wind
    end
    if tidal > 0 then
        parts[#parts+1] = "Tidal"
        sortVal = sortVal + tidal
    end
    if eStor > 500 then
        parts[#parts+1] = "E.Str " .. fmtNum(eStor)
        sortVal = sortVal + eStor * 0.01
    end
    if mStor > 100 then
        parts[#parts+1] = "M.Str " .. fmtNum(mStor)
        sortVal = sortVal + mStor * 0.1
    end
    if def.customParams and def.customParams.energyconv_capacity then
        local cap = tonumber(def.customParams.energyconv_capacity) or 0
        if cap > 0 then
            parts[#parts+1] = "Converter"
            sortVal = sortVal + cap
        end
    end

    if #parts == 0 then return nil, 0 end
    return table.concat(parts, ", "), sortVal
end

--------------------------------------------------------------------------------
-- Read rarity assignments directly from infolog.txt
-- This bypasses the bridge widget entirely so we always get rarity data
--------------------------------------------------------------------------------

local function parseInfologRarities()
    local rarityMap = {} -- unitInternalName -> rarity string
    local content = VFS.LoadFile("infolog.txt")
    if not content then
        spEcho("[RaritiesViewer] Could not read infolog.txt")
        return rarityMap
    end

    -- Find the LAST tweakdefs_rename block (in case of multiple loads)
    local lastStart = nil
    local pos = 1
    while true do
        local s = content:find("tweakdefs_rename_get_ready", pos, true)
        if not s then break end
        lastStart = s
        pos = s + 1
    end

    if not lastStart then
        spEcho("[RaritiesViewer] No tweakdefs_rename block found in infolog")
        return rarityMap
    end

    local blockEnd = content:find("tweakdefs_rename_end", lastStart, true)
    if not blockEnd then blockEnd = #content end

    local block = content:sub(lastStart, blockEnd)

    -- Parse entries: /(<unitname>/-prefix/-[<Rarity>]/)
    local count = 0
    for unitName, entryType, value in block:gmatch("/%((.-)/%-(.-)/%-(.-)/%)") do
        if entryType == "prefix" then
            local rarity = value:match("^%[(.-)%]$")
            if rarity then
                rarityMap[unitName] = rarity
                count = count + 1
            end
        end
    end

    spEcho("[RaritiesViewer] Parsed " .. count .. " rarity assignments from infolog")
    return rarityMap
end

--------------------------------------------------------------------------------
-- Data collection
--------------------------------------------------------------------------------

local buildDisplayRows  -- forward declaration

local function collectData()
    dataByFaction = {}
    factionList = {}
    activeFaction = nil

    -- Read rarity directly from infolog (don't depend on bridge)
    local infologRarities = parseInfologRarities()

    local facData = {}

    local function getFaction(def)
        if def.customParams and def.customParams.faction then
            local f = def.customParams.faction
            return f:sub(1,1):upper() .. f:sub(2):lower()
        end
        local n = def.name or ""
        if n:sub(1,3) == "arm" then return "Armada"
        elseif n:sub(1,3) == "cor" then return "Cortex"
        elseif n:sub(1,3) == "leg" then return "Legion"
        else return "Other" end
    end

    local function ensureFac(faction)
        if not facData[faction] then
            facData[faction] = { eco = {}, factories = {} }
        end
    end

    -- Helper: resolve rarity for a UnitDef
    -- First try parsing from translatedHumanName (bridge-patched)
    -- Then fall back to infolog data using internal name
    local function resolveRarity(def)
        local fullName = getDisplayName(def)
        local rarity, cleanName, rIdx = parseRarity(fullName)
        if rIdx ~= 0 then
            return rarity, cleanName, rIdx
        end
        -- Fallback: check infolog
        local internalName = def.name
        if internalName and infologRarities[internalName] then
            local rawRarity = infologRarities[internalName]
            -- Check for Cursed
            local cursedLevel = rawRarity:match("^Cursed Mk%.(%d+)")
            if cursedLevel then
                return rawRarity, cleanName, -(tonumber(cursedLevel) or 1)
            end
            -- Extract base rarity from composite string
            local _, idx = extractBaseRarity(rawRarity)
            if idx > 0 then
                return rawRarity, cleanName, idx
            end
            return rawRarity, cleanName, rarityIndex[rawRarity] or 0
        end
        return "Common", cleanName, 0
    end

    -- Identify factories
    local factoryIDs = {}
    for defID, def in pairs(UnitDefs) do
        if def.buildOptions and #def.buildOptions > 0 and (def.speed or 0) == 0 then
            factoryIDs[defID] = true
        end
    end

    -- Collect everything
    for defID, def in pairs(UnitDefs) do
        local faction = getFaction(def)
        ensureFac(faction)

        local rarity, cleanName, rIdx = resolveRarity(def)
        local desc = getTooltip(def)

        if factoryIDs[defID] then
            -- Factory: gather its buildable units
            local units = {}
            for i = 1, #def.buildOptions do
                local uid = def.buildOptions[i]
                local udef = UnitDefs[uid]
                if udef then
                    local uRar, uClean, uIdx = resolveRarity(udef)
                    local dps, range = getWeaponStats(udef)
                    units[#units+1] = {
                        rarity    = uRar,
                        rarityIdx = uIdx,
                        name      = uClean,
                        desc      = getTooltip(udef),
                        defID     = uid,
                        metalCost = round(udef.metalCost or 0),
                        hp        = round(udef.health or 0),
                        speed     = round(udef.speed or 0),
                        dps       = dps,
                        range     = range,
                    }
                end
            end
            table.sort(units, function(a, b) return a.rarityIdx > b.rarityIdx end)

            local sumIdx, maxIdx = 0, 0
            for _, u in ipairs(units) do
                sumIdx = sumIdx + u.rarityIdx
                if u.rarityIdx > maxIdx then maxIdx = u.rarityIdx end
            end
            local avgIdx = #units > 0 and (sumIdx / #units) or 0

            facData[faction].factories[#facData[faction].factories+1] = {
                rarity    = rarity,
                rarityIdx = rIdx,
                name      = cleanName,
                desc      = desc,
                defID     = defID,
                metalCost = round(def.metalCost or 0),
                units     = units,
                avgRarity = avgIdx,
                maxRarity = maxIdx,
                unitCount = #units,
            }
        else
            -- Check eco building: stationary, no DPS, has eco output
            local isStationary = (def.speed or 0) == 0
            local dps = getWeaponStats(def)
            if isStationary and dps == 0 then
                local output, sortVal = getEcoOutput(def)
                if output then
                    local isReactor = (def.energyMake or 0) > 50
                    local isConverter = false
                    if def.customParams and def.customParams.energyconv_capacity then
                        local cap = tonumber(def.customParams.energyconv_capacity) or 0
                        if cap > 0 then isConverter = true end
                    end
                    if isReactor or isConverter then
                        facData[faction].eco[#facData[faction].eco+1] = {
                            rarity    = rarity,
                            rarityIdx = rIdx,
                            name      = cleanName,
                            desc      = desc,
                            defID     = defID,
                            metalCost = round(def.metalCost or 0),
                            energyCost= round(def.energyCost or 0),
                            output    = output,
                            sortVal   = sortVal,
                        }
                    end
                end
            end
        end
    end

    -- Sort and store
    for faction, data in pairs(facData) do
        table.sort(data.eco, function(a, b) return a.metalCost > b.metalCost end)
        table.sort(data.factories, function(a, b)
            if a.maxRarity ~= b.maxRarity then return a.maxRarity > b.maxRarity end
            return a.avgRarity > b.avgRarity
        end)
        dataByFaction[faction] = data
        factionList[#factionList+1] = faction
    end

    table.sort(factionList)
    if factionList[1] then activeFaction = factionList[1] end

    buildDisplayRows()

    for _, f in ipairs(factionList) do
        local d = dataByFaction[f]
        spEcho("[RaritiesViewer] " .. f .. ": " .. #d.eco .. " eco, " .. #d.factories .. " factories")
    end
end

--------------------------------------------------------------------------------
-- Build flat display row list for current faction
--------------------------------------------------------------------------------

buildDisplayRows = function()
    displayRows = {}
    totalContentH = 0
    scrollOffset = 0

    local data = dataByFaction[activeFaction]
    if not data then return end

    local function addRow(row)
        displayRows[#displayRows+1] = row
        totalContentH = totalContentH + row.h
    end

    -- Economy section
    if #data.eco > 0 then
        addRow({ type = "section", label = "Economy Buildings (" .. #data.eco .. ")", h = SECTION_H })
        addRow({ type = "eco_header", h = HEADER_H })
        for _, e in ipairs(data.eco) do
            addRow({ type = "eco", rarity = e.rarity, rarityIdx = e.rarityIdx,
                     name = e.name, desc = e.desc, defID = e.defID,
                     metalCost = e.metalCost, energyCost = e.energyCost,
                     output = e.output, h = ROW_H })
        end
    end

    -- Factories section
    if #data.factories > 0 then
        addRow({ type = "section", label = "Factories - Ranked by Best Unit Rarity (" .. #data.factories .. ")", h = SECTION_H })
        for _, fac in ipairs(data.factories) do
            addRow({ type = "factory", rarity = fac.rarity, rarityIdx = fac.rarityIdx,
                     name = fac.name, desc = fac.desc, defID = fac.defID,
                     metalCost = fac.metalCost,
                     avgRarity = fac.avgRarity, maxRarity = fac.maxRarity,
                     unitCount = fac.unitCount, h = FACTORY_H })
            addRow({ type = "unit_header", h = HEADER_H })
            for _, u in ipairs(fac.units) do
                addRow({ type = "unit", rarity = u.rarity, rarityIdx = u.rarityIdx,
                         name = u.name, desc = u.desc, defID = u.defID,
                         metalCost = u.metalCost, hp = u.hp,
                         speed = u.speed, dps = u.dps, range = u.range, h = ROW_H })
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local textBuffer = {}

local function bufText(text, x, y, size, opts)
    textBuffer[#textBuffer+1] = { t = text, x = x, y = y, s = size, o = opts }
end

local function flushText()
    for _, e in ipairs(textBuffer) do
        printText(e.t, e.x, e.y, e.s, e.o)
    end
    textBuffer = {}
end

-- Column positions for eco rows (after icon)
local ECO_COLS = {
    { name = "Rarity",   w = 210, align = "l" },
    { name = "Name",     w = 190, align = "l" },
    { name = "Description", w = 140, align = "l" },
    { name = "Metal",    w = 80,  align = "r" },
    { name = "Energy",   w = 80,  align = "r" },
    { name = "Output",   w = 180, align = "l" },
}

-- Column positions for unit rows (after icon)
local UNIT_COLS = {
    { name = "Rarity",   w = 210, align = "l" },
    { name = "Name",     w = 190, align = "l" },
    { name = "Description", w = 140, align = "l" },
    { name = "Metal",    w = 75,  align = "r" },
    { name = "HP",       w = 75,  align = "r" },
    { name = "Speed",    w = 60,  align = "r" },
    { name = "DPS",      w = 70,  align = "r" },
    { name = "Range",    w = 65,  align = "r" },
}

local ICON_COL_W = ICON_SZ + 4  -- icon column width (icon + padding)
local ECO_INDENT = 8
local UNIT_INDENT = 24

local function drawIcon(defID, x, y, sz)
    glColor(1, 1, 1, 1)
    if glTexture('#' .. defID) then
        glTexRect(x, y, x + sz, y + sz)
        glTexture(false)
    end
end

--------------------------------------------------------------------------------
-- Toggle button (always on screen)
--------------------------------------------------------------------------------

local function drawToggleButton()
    if not toggleX or not toggleY then return end
    local tx, ty = toggleX, toggleY
    if visible then
        glColor(0.15, 0.20, 0.35, 0.90)
    else
        glColor(0.12, 0.14, 0.25, 0.85)
    end
    glRect(tx, ty, tx + TOGGLE_W, ty + TOGGLE_H)

    -- border
    glColor(0.4, 0.45, 0.6, 0.7)
    glRect(tx, ty, tx + TOGGLE_W, ty + 1)
    glRect(tx, ty + TOGGLE_H - 1, tx + TOGGLE_W, ty + TOGGLE_H)
    glRect(tx, ty, tx + 1, ty + TOGGLE_H)
    glRect(tx + TOGGLE_W - 1, ty, tx + TOGGLE_W, ty + TOGGLE_H)

    if visible then
        printText("\255\200\220\255Stats", tx + TOGGLE_W * 0.5, ty + 9, 14, "oc")
    else
        printText("\255\160\170\200Stats", tx + TOGGLE_W * 0.5, ty + 9, 14, "oc")
    end
end

--------------------------------------------------------------------------------
-- Main panel drawing
--------------------------------------------------------------------------------

local function drawPanel()
    local px, py = panelX, panelY
    local pw, ph = PANEL_W, PANEL_H

    local contentTop = py + ph - TITLE_H - TAB_H
    local contentBot = py
    viewportH = contentTop - contentBot
    local contentW = pw - SCROLLBAR_W

    textBuffer = {}

    ----- Chrome backgrounds -----

    glColor(0.05, 0.05, 0.08, 0.93)
    glRect(px, py, px + pw, py + ph)

    glColor(0.3, 0.35, 0.5, 0.6)
    glRect(px, py, px + pw, py + 1)
    glRect(px, py + ph - 1, px + pw, py + ph)
    glRect(px, py, px + 1, py + ph)
    glRect(px + pw - 1, py, px + pw, py + ph)

    glColor(0.10, 0.12, 0.20, 1)
    glRect(px, py + ph - TITLE_H, px + pw, py + ph)

    local closeX1 = px + pw - CLOSE_BTN_W - 4
    local closeX2 = px + pw - 4
    local btnY1 = py + ph - TITLE_H + 4
    local btnY2 = py + ph - 4
    glColor(0.55, 0.15, 0.15, 0.9)
    glRect(closeX1, btnY1, closeX2, btnY2)

    local rlX2 = closeX1 - 6
    local rlX1 = rlX2 - RELOAD_BTN_W
    glColor(0.15, 0.35, 0.20, 0.9)
    glRect(rlX1, btnY1, rlX2, btnY2)

    local tabY = py + ph - TITLE_H - TAB_H
    local tabX = px + 4
    for _, faction in ipairs(factionList) do
        local d = dataByFaction[faction]
        local count = d and (#d.eco + #d.factories) or 0
        local label = faction .. " (" .. count .. ")"
        local tw = mathMax(textWidth(label, 14) + 28, 90)
        if faction == activeFaction then
            glColor(0.22, 0.27, 0.42, 1)
        else
            glColor(0.12, 0.14, 0.22, 0.9)
        end
        glRect(tabX, tabY + 2, tabX + tw, tabY + TAB_H - 2)
        tabX = tabX + tw + 4
    end

    ----- Content backgrounds + icons (inside scissor) -----

    glScissor(px, contentBot, contentW, viewportH)

    local y = contentTop + scrollOffset
    local rowIdx = 0
    for _, row in ipairs(displayRows) do
        local rowTop = y
        local rowBot = y - row.h
        y = rowBot

        if rowBot < contentTop and rowTop > contentBot then
            -- Background
            if row.type == "section" then
                glColor(0.14, 0.16, 0.26, 1)
                glRect(px, rowBot, px + contentW, rowTop)
            elseif row.type == "factory" then
                glColor(0.10, 0.13, 0.22, 0.95)
                glRect(px, rowBot, px + contentW, rowTop)
            elseif row.type == "eco_header" or row.type == "unit_header" then
                glColor(0.08, 0.09, 0.14, 0.9)
                glRect(px, rowBot, px + contentW, rowTop)
            elseif row.type == "eco" or row.type == "unit" then
                rowIdx = rowIdx + 1
                if rowIdx % 2 == 0 then
                    glColor(0.11, 0.11, 0.15, 0.55)
                else
                    glColor(0.07, 0.07, 0.10, 0.35)
                end
                glRect(px, rowBot, px + contentW, rowTop)
            end

            -- Icons (GL texture calls are fine alongside rects, before text)
            if row.defID then
                local indent = 0
                if row.type == "eco" then indent = ECO_INDENT
                elseif row.type == "unit" then indent = UNIT_INDENT
                elseif row.type == "factory" then indent = 8
                end
                drawIcon(row.defID, px + indent, rowBot + 1, ICON_SZ)
            end
        end
    end

    glScissor(false)

    -- Scrollbar
    local sbX = px + pw - SCROLLBAR_W
    glColor(0.08, 0.08, 0.12, 0.8)
    glRect(sbX, contentBot, sbX + SCROLLBAR_W, contentTop)
    if totalContentH > viewportH then
        local scrollRange = contentTop - contentBot
        local handleH = mathMax(20, scrollRange * (viewportH / totalContentH))
        local scrollMax = totalContentH - viewportH
        local ratio = scrollOffset / scrollMax
        local handleY = contentTop - handleH - (scrollRange - handleH) * ratio
        glColor(0.30, 0.35, 0.50, 0.9)
        glRect(sbX + 2, handleY, sbX + SCROLLBAR_W - 2, handleY + handleH)
    end

    ----- Chrome text (flush BEFORE scissor) -----

    bufText("\255\230\230\255Random Rarities Viewer", px + 12, py + ph - TITLE_H + 10, 16, "o")
    bufText("\255\255\200\200X", closeX1 + CLOSE_BTN_W * 0.5, py + ph - TITLE_H + 10, 15, "oc")
    bufText("\255\200\255\200Reload", rlX1 + RELOAD_BTN_W * 0.5, py + ph - TITLE_H + 10, 13, "oc")

    tabX = px + 4
    for _, faction in ipairs(factionList) do
        local d = dataByFaction[faction]
        local count = d and (#d.eco + #d.factories) or 0
        local label = faction .. " (" .. count .. ")"
        local tw = mathMax(textWidth(label, 14) + 28, 90)
        if faction == activeFaction then
            bufText("\255\255\255\255" .. label, tabX + tw * 0.5, tabY + 10, 14, "oc")
        else
            bufText("\255\170\170\185" .. label, tabX + tw * 0.5, tabY + 10, 14, "oc")
        end
        tabX = tabX + tw + 4
    end

    flushText()

    ----- Content text (inside scissor) -----

    glScissor(px, contentBot, contentW, viewportH)

    y = contentTop + scrollOffset
    for _, row in ipairs(displayRows) do
        local rowTop = y
        local rowBot = y - row.h
        y = rowBot

        if rowBot >= contentTop or rowTop <= contentBot then
            -- off screen

        elseif row.type == "section" then
            printText("\255\255\220\100" .. row.label, px + 12, rowBot + 8, 15, "o")

        elseif row.type == "eco_header" then
            local cx = px + ECO_INDENT + ICON_COL_W
            for _, col in ipairs(ECO_COLS) do
                if col.align == "r" then
                    printText("\255\200\180\060" .. col.name, cx + col.w - 6, rowBot + 3, 12, "or")
                else
                    printText("\255\200\180\060" .. col.name, cx + 2, rowBot + 3, 12, "o")
                end
                cx = cx + col.w
            end

        elseif row.type == "eco" then
            local rCol = rarityColor(row.rarityIdx)
            local vals = { row.rarity, row.name, row.desc, fmtNum(row.metalCost), fmtNum(row.energyCost), row.output }
            local colors = { rCol, "\255\220\225\240", "\255\160\170\180", "\255\190\195\210", "\255\190\195\210", "\255\140\200\140" }
            local cx = px + ECO_INDENT + ICON_COL_W
            for ci, col in ipairs(ECO_COLS) do
                if col.align == "r" then
                    printText(colors[ci] .. vals[ci], cx + col.w - 6, rowBot + 5, 12.5, "or")
                else
                    printText(colors[ci] .. vals[ci], cx + 2, rowBot + 5, 12.5, "o")
                end
                cx = cx + col.w
            end

        elseif row.type == "factory" then
            local rCol = rarityColor(row.rarityIdx)
            local bestLabel = rarityLabel(round(row.maxRarity))
            local bestCol = rarityColor(round(row.maxRarity))
            local textX = px + 8 + ICON_SZ + 4
            printText(rCol .. row.rarity .. "  \255\220\225\240" .. row.name,
                      textX, rowBot + 6, 14, "o")
            if row.desc ~= "" then
                printText("\255\140\150\165" .. row.desc,
                          textX + 350, rowBot + 6, 12.5, "o")
            end
            printText("\255\180\180\200" .. fmtNum(row.metalCost) .. "M",
                      px + 680, rowBot + 6, 13, "o")
            printText("\255\180\180\200" .. row.unitCount .. " units   best: " .. bestCol .. bestLabel,
                      px + 780, rowBot + 6, 13, "o")

        elseif row.type == "unit_header" then
            local cx = px + UNIT_INDENT + ICON_COL_W
            for _, col in ipairs(UNIT_COLS) do
                if col.align == "r" then
                    printText("\255\200\180\060" .. col.name, cx + col.w - 6, rowBot + 3, 12, "or")
                else
                    printText("\255\200\180\060" .. col.name, cx + 2, rowBot + 3, 12, "o")
                end
                cx = cx + col.w
            end

        elseif row.type == "unit" then
            local rCol = rarityColor(row.rarityIdx)
            local vals = { row.rarity, row.name, row.desc, fmtNum(row.metalCost),
                           fmtNum(row.hp), tostring(row.speed), fmtNum(row.dps), fmtNum(row.range) }
            local colors = { rCol, "\255\220\225\240", "\255\160\170\180", "\255\190\195\210",
                             "\255\190\195\210", "\255\190\195\210", "\255\190\195\210", "\255\190\195\210" }
            local cx = px + UNIT_INDENT + ICON_COL_W
            for ci, col in ipairs(UNIT_COLS) do
                if col.align == "r" then
                    printText(colors[ci] .. vals[ci], cx + col.w - 6, rowBot + 5, 12.5, "or")
                else
                    printText(colors[ci] .. vals[ci], cx + 2, rowBot + 5, 12.5, "o")
                end
                cx = cx + col.w
            end
        end
    end

    glScissor(false)
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
    vsx, vsy = Spring.GetViewGeometry()
    if WG and WG['fonts'] then
        font = WG['fonts'].getFont()
    end
    panelX = mathFloor((vsx - PANEL_W) / 2)
    panelY = mathFloor((vsy - PANEL_H) / 2)
    toggleX = vsx - TOGGLE_W - 10
    toggleY = mathFloor(vsy * 0.5)
    collectData()
    visible = true
    spEcho("[RaritiesViewer] Loaded. /unitstats to toggle, click Stats button on screen edge.")
end

function widget:GameStart()
    collectData()
    visible = true
end

function widget:ViewResize(newX, newY)
    vsx, vsy = newX, newY
    panelX = mathFloor((vsx - PANEL_W) / 2)
    panelY = mathFloor((vsy - PANEL_H) / 2)
    toggleX = vsx - TOGGLE_W - 10
    toggleY = mathFloor(vsy * 0.5)
end

function widget:DrawScreen()
    -- Toggle button is ALWAYS drawn, even if panel is hidden
    local ok, err = pcall(drawToggleButton)
    if not ok then spEcho("[RaritiesViewer] Toggle draw error: " .. tostring(err)) end

    if not visible then return end
    local ok2, err2 = pcall(drawPanel)
    if not ok2 then spEcho("[RaritiesViewer] Panel draw error: " .. tostring(err2)) end
end

function widget:IsAbove(x, y)
    -- Toggle button is always active
    if inRect(x, y, toggleX, toggleY, toggleX + TOGGLE_W, toggleY + TOGGLE_H) then
        return true
    end
    if not visible then return false end
    return inRect(x, y, panelX, panelY, panelX + PANEL_W, panelY + PANEL_H)
end

function widget:MousePress(x, y, button)
    -- Toggle button (always active)
    if inRect(x, y, toggleX, toggleY, toggleX + TOGGLE_W, toggleY + TOGGLE_H) then
        visible = not visible
        return true
    end

    if not visible then return false end
    if not inRect(x, y, panelX, panelY, panelX + PANEL_W, panelY + PANEL_H) then
        return false
    end

    local px, py = panelX, panelY
    local pw, ph = PANEL_W, PANEL_H

    -- Close
    local closeX1 = px + pw - CLOSE_BTN_W - 4
    local closeX2 = px + pw - 4
    local btnY1 = py + ph - TITLE_H + 4
    local btnY2 = py + ph - 4
    if inRect(x, y, closeX1, btnY1, closeX2, btnY2) then
        visible = false
        return true
    end

    -- Reload
    local rlX2 = closeX1 - 6
    local rlX1 = rlX2 - RELOAD_BTN_W
    if inRect(x, y, rlX1, btnY1, rlX2, btnY2) then
        spEcho("[RaritiesViewer] Reloading...")
        collectData()
        return true
    end

    -- Title bar drag
    if inRect(x, y, px, py + ph - TITLE_H, rlX1 - 4, py + ph) then
        dragging = true
        dragStartX, dragStartY = x, y
        dragPanelX, dragPanelY = px, py
        return true
    end

    -- Faction tabs
    local tabY = py + ph - TITLE_H - TAB_H
    if y >= tabY and y <= tabY + TAB_H then
        local tabX = px + 4
        for _, faction in ipairs(factionList) do
            local d = dataByFaction[faction]
            local count = d and (#d.eco + #d.factories) or 0
            local label = faction .. " (" .. count .. ")"
            local tw = mathMax(textWidth(label, 14) + 28, 90)
            if inRect(x, y, tabX, tabY, tabX + tw, tabY + TAB_H) then
                activeFaction = faction
                buildDisplayRows()
                return true
            end
            tabX = tabX + tw + 4
        end
    end

    return true
end

function widget:MouseRelease(x, y, button)
    dragging = false
end

function widget:MouseMove(x, y, dx, dy, button)
    if dragging then
        panelX = dragPanelX + (x - dragStartX)
        panelY = dragPanelY + (y - dragStartY)
        panelX = mathMax(0, mathMin(panelX, vsx - PANEL_W))
        panelY = mathMax(0, mathMin(panelY, vsy - PANEL_H))
        return true
    end
end

function widget:MouseWheel(up, value)
    if not visible then return false end
    local mx, my = spGetMouseState()
    if not inRect(mx, my, panelX, panelY, panelX + PANEL_W, panelY + PANEL_H) then
        return false
    end
    local scrollStep = ROW_H * 3
    scrollOffset = scrollOffset + value * -scrollStep
    local scrollMax = mathMax(0, totalContentH - viewportH)
    scrollOffset = mathMax(0, mathMin(scrollOffset, scrollMax))
    return true
end

function widget:TextCommand(cmd)
    if cmd == "unitstats" then
        visible = not visible
        return true
    end
    if cmd == "unitstats_reload" then
        collectData()
        visible = true
        return true
    end
    return false
end

function widget:GetConfigData()
    return { panelX = panelX, panelY = panelY }
end

function widget:SetConfigData(data)
    if data.panelX then panelX = data.panelX end
    if data.panelY then panelY = data.panelY end
end

function widget:Shutdown()
end
