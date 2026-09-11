--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Utils
-- Character/Humanoid accessors, Inventory & Economy helpers
-- ============================================================
local ctx = ...

local function char() return LP.Character end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tap(alias, hold)
    if not IH then return false end
    pcall(function() IH:FireVirtualInput(alias, true) end)
    task.wait(hold or 0.1)
    pcall(function() IH:FireVirtualInput(alias, false) end)
    return true
end

local function spotPos(s)
    if not s then return nil end
    if typeof(s) == "Vector3" then return s end
    if typeof(s) == "CFrame" then return s.Position end
    if type(s) == "table" then
        if s.pos then return s.pos end
        if #s >= 3 then return Vector3.new(s[1], s[2], s[3]) end
    end
    return nil
end

local function spotLook(s)
    if not s then return nil end
    if typeof(s) == "CFrame" then return s.LookVector end
    if type(s) == "table" then
        if s.look then return s.look end
        if #s >= 6 then return Vector3.new(s[4], s[5], s[6]) end
    end
    return nil
end

-- ── inventory helpers ───────────────────────────────────────────────────────
local function baseName(n) return string.split(n, " (")[1] end

local function getToolQty(t)
    if not t then return 0 end
    local matchQty = tonumber(t.Name:match("%((%d+)%)"))
    if matchQty and matchQty > 0 then return matchQty end
    local attrQty = t:GetAttribute("Amount") or t:GetAttribute("Quantity") or t:GetAttribute("Count") or t:GetAttribute("Stack")
    if attrQty and tonumber(attrQty) and tonumber(attrQty) > 0 then
        return tonumber(attrQty)
    end
    local valObj = t:FindFirstChild("Amount") or t:FindFirstChild("Quantity") or t:FindFirstChild("Count") or t:FindFirstChild("Value")
    if valObj and valObj:IsA("ValueBase") and tonumber(valObj.Value) and tonumber(valObj.Value) > 0 then
        return tonumber(valObj.Value)
    end
    return 1
end

local function countTool(name)
    local n = 0
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and baseName(t.Name) == name then
                    n = n + getToolQty(t)
                end
            end
        end
    end
    return n
end
local function findTool(name)
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and baseName(t.Name) == name then return t end
            end
        end
    end
    return nil
end
local function equipTool(name)
    local c, h = char(), hum()
    if not c or not h then return false end
    local cur = c:FindFirstChildOfClass("Tool")
    if cur and baseName(cur.Name) == name then return true end
    local t = findTool(name)
    if not t then return false end
    pcall(function() h:EquipTool(t) end)
    task.wait(0.35)
    local now = c:FindFirstChildOfClass("Tool")
    return now ~= nil and baseName(now.Name) == name
end

local function moola()
    local g = LP:FindFirstChildOfClass("PlayerGui")
    local mc = g and g:FindFirstChild("MoolaCount")
    if not mc then return 0 end
    for _, v in ipairs(mc:GetDescendants()) do
        if v:IsA("TextLabel") and v.Name == "CoinAmount" then
            local raw = tostring(v.Text):gsub(",", ""):gsub("%s", "")
            local num, suf = raw:match("([%d%.]+)%s*([KkMmBb]?)")
            local n = tonumber(num)
            if not n then return 0 end
            suf = (suf or ""):upper()
            if suf == "K" then n = n * 1e3 elseif suf == "M" then n = n * 1e6 elseif suf == "B" then n = n * 1e9 end
            return math.floor(n)
        end
    end
    return 0
end

local NON_FISH_TOOLS = {
    ["fishingrod"] = true, ["bait"] = true, ["bandage"] = true, ["bandages"] = true,
    ["dogbane herb"] = true, ["dogbane"] = true, ["ammopack"] = true, ["ammo pack"] = true,
    ["pickaxe"] = true, ["miningpick"] = true, ["mining pick"] = true, ["lasso"] = true,
    ["canteen"] = true, ["horse whistle"] = true, ["whistle"] = true, ["knife"] = true,
    ["bow"] = true, ["arrow"] = true, ["arrows"] = true, ["dynamite"] = true,
    ["revolver"] = true, ["colt"] = true, ["pistol"] = true, ["rifle"] = true,
    ["shotgun"] = true, ["repeater"] = true, ["carbine"] = true, ["sawedoff"] = true,
    ["sawed-off"] = true, ["mares leg"] = true, ["mare's leg"] = true, ["evans"] = true,
    ["henry"] = true, ["schofield"] = true, ["peacemaker"] = true, ["navy revolver"] = true,
    ["coach gun"] = true, ["model 1873"] = true, ["cattleman"] = true, ["winchester"] = true,
    ["iron ore"] = true, ["coal"] = true, ["gold ore"] = true, ["copper ore"] = true,
    ["lead ore"] = true, ["silver ore"] = true, ["sulfur"] = true, ["gunpowder"] = true,
    ["wood"] = true, ["log"] = true, ["plank"] = true, ["lantern"] = true, ["torch"] = true,
}

local function isFishName(name)
    if not name then return false end
    local ln = name:lower()
    local bn = baseName(name):lower()
    if NON_FISH_TOOLS[bn] or NON_FISH_TOOLS[ln] then return false end
    if ln:find("bass") or ln:find("snapper") or ln:find("cod") or ln:find("fish")
       or ln:find("trout") or ln:find("salmon") or ln:find("carp") or ln:find("pike")
       or ln:find("perch") or ln:find("walleye") or ln:find("sturgeon") or ln:find("eel")
       or ln:find("bluegill") or ln:find("crappie") or ln:find("minnow") or ln:find("gar")
       or ln:find("char") or ln:find("herring") or ln:find("mackerel") or ln:find("flounder")
       or ln:find("halibut") or ln:find("sardine") or ln:find("anchovy") or ln:find("shad")
       or ln:find("sunfish") or ln:find("catfish") or ln:find("bullhead") or ln:find("muskie") then
        return true
    end
    return false
end

local function isFish(toolOrName)
    local name = typeof(toolOrName) == "Instance" and toolOrName.Name or tostring(toolOrName)
    if not name or name == "" then return false end
    local ln = name:lower()
    local bn = baseName(name):lower()
    if NON_FISH_TOOLS[bn] or NON_FISH_TOOLS[ln] then return false end
    return true
end

local function getFishCounts()
    local counts = {}
    local total = 0
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and isFish(t) then
                    local bn = baseName(t.Name)
                    local qty = getToolQty(t)
                    counts[bn] = (counts[bn] or 0) + qty
                    total = total + qty
                end
            end
        end
    end
    return counts, total
end

local function checkFishStack40()
    local counts, _ = getFishCounts()
    for name, cnt in pairs(counts) do
        if cnt >= 40 then
            return true, name, cnt
        end
    end
    return false
end

local function countDogbane()
    return countTool("Dogbane Herb") + countTool("Dogbane")
end

local function getStandInfo(player)
    player = player or LP
    -- For LocalPlayer, read directly from the in-game 'M' menu (StatsGui)
    if player == LP then
        local pg = LP:FindFirstChild("PlayerGui")
        local sg = pg and pg:FindFirstChild("StatsGui")
        local bg = sg and sg:FindFirstChild("Background")
        if bg then
            local pText = bg:FindFirstChild("PathText") and bg.PathText.Text or ""
            local tText = bg:FindFirstChild("TierText") and bg.TierText.Text or ""
            local aText = bg:FindFirstChild("AlignmentText") and bg.AlignmentText.Text or ""
            local eText = bg:FindFirstChild("ExpText") and bg.ExpText.Text or ""

            local path = pText:match("Path:%s*(.+)") or (pText ~= "" and pText) or nil
            local tier = tText:match("Tier:%s*(.+)") or (tText ~= "" and tText) or nil
            local align = aText:match("Alignment:%s*(.+)") or (aText ~= "" and aText) or "Neutral"
            local exp = eText:match("EXP:%s*(.+)") or (eText ~= "" and eText) or "0"

            if path or tier then
                return path or "None", tier or "1", align, exp
            end
        end
    end

    -- Attribute fallback or for other players:
    local sName = player:GetAttribute("EquippedStand")
    if not sName and player.Character then
        sName = player.Character:GetAttribute("EquippedStand")
    end
    if not sName and player.Character and player.Character:GetAttribute("Standless") then
        sName = "Standless"
    end
    if not sName or sName == "" then sName = "None" end

    local align = (player.Character and player.Character:GetAttribute("Alignment")) or "Neutral"
    return sName, "1", align, "0"
end

local FISH: any = { status = "idle", casts = 0, catches = 0, dead = 0 }
local COMBAT: any = nil
local FISH_SPOTS: any = nil
lastCatchTime = 0
lastKnownFishTotal = 0

function FISH.getSetNames()
    local list = {}
    if S.fishingSets then
        for name, _ in pairs(S.fishingSets) do
            table.insert(list, tostring(name))
        end
    end
    table.sort(list)
    if #list == 0 then
        list = { "Default" }
    end
    return list
end

function FISH.getActiveSetName()
    local val = S.activeFishingSet
    if val and type(val) == "string" and val ~= "" then
        if S.fishingSets and S.fishingSets[val] then return val end
    end
    local names = FISH.getSetNames()
    return names[1] or "Default"
end

function FISH.getActiveSetIdx()
    return FISH.getActiveSetName()
end

function FISH.getSelectedSlotIdx()
    local val = S.selectedSpotSlot
    if typeof(val) == "number" then return math.clamp(math.floor(val), 1, 3) end
    local n = tonumber(tostring(val):match("(%d+)"))
    return n and math.clamp(math.floor(n), 1, 3) or 1
end

-- Initialize catch counter and lastKnownFishTotal from current inventory
pcall(function()
    local _, initTot = getFishCounts()
    if initTot and initTot > 0 then
        FISH.catches = initTot
        lastKnownFishTotal = initTot
    end
end)



return {
    char = char,
    hum = hum,
    root = root,
    tap = tap,
    baseName = baseName,
    getToolQty = getToolQty,
    countTool = countTool,
    findTool = findTool,
    equipTool = equipTool,
    moola = moola,
    isFishName = isFishName,
    isFish = isFish,
    getFishCounts = getFishCounts,
    checkFishStack40 = checkFishStack40,
    countDogbane = countDogbane,
    getStandInfo = getStandInfo,
    NON_FISH_TOOLS = NON_FISH_TOOLS,
    FISH = FISH,
    lastCatchTime = lastCatchTime,
    lastKnownFishTotal = lastKnownFishTotal,
    spotPos = spotPos,
    spotLook = spotLook,
}
