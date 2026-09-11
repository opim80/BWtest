--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Config
-- Config JSON persistence, Genv sync & Discord Webhooks
-- ============================================================
local ctx = ...


-- ── config persistence (without MCP) ───────────────────────────────────────
local CONFIG_FILE = "bridger_config.json"
local HttpService = game:GetService("HttpService")

local function saveConfig()
    if not writefile then
        logAction("CONFIG", "writefile not supported by executor", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
    local cfg = {}
    local keys = {
        "blackscreenOpaque", "fakeFlySpeed", "horseFlyKey", "silentAim", "martiniBallistics", "shootOverRocks", "chamsWhite", "aimTargetMode", "aimHitbox", "aimIgnoreFriends", "customFriends", "iHateYou", "iHateYouDistance", "martiniVantage", "onlyFireAtLowSpeeds", "maxFiringSpeed", "autoFish", "requireBait", "autoSellOutOfMoney", "lowMoneyThreshold",
        "autoQTE", "autoRestock", "baitKeep", "autoSell", "sellEvery",
        "castTimeout", "deadCastsBeforeMove", "reelDelay",
        "autoHopNearPlayer", "autoHopDistance", "autoHopIgnoreFriends",
        "autoChests", "autoHerbs", "promptRange", "autoBuy", "buyTarget", "buyReserve",
        "saintWatch", "saintGrab", "saintRetreat", "saintWindow",
        "espChest", "espHerb", "espHorse", "espPlayers", "espRange",
        "blackscreen", "showHud",
        "webhookUrl", "webhookIntervalEnabled", "webhookInterval", "webhookOnDogbane",
        "legitFishing", "visualizeLegit", "selectedSpotSlot", "activeFishingSet",
        "autoSwapSetNearPlayer", "autoSwapDistance",
        "saintPreHoldWait", "saintDefendGun", "saintGunSelect", "saintMergeTpPlayer",
    }
    S.activeFishingSet = FISH.getActiveSetName()
    S.selectedSpotSlot = FISH.getSelectedSlotIdx()
    for _, k in ipairs(keys) do
        if S[k] ~= nil then cfg[k] = S[k] end
    end
    if S.fishingSets then
        local rawSets = {}
        for setName, list in pairs(S.fishingSets) do
            if type(list) == "table" then
                rawSets[tostring(setName)] = {}
                for slotIdx = 1, 3 do
                    local pt = list[slotIdx]
                    if typeof(pt) == "Vector3" then
                        table.insert(rawSets[tostring(setName)], { pt.X, pt.Y, pt.Z })
                    end
                end
            end
        end
        cfg.savedFishingSets = rawSets
    end
    if S.stagingPoints then
        local rawStaging = {}
        for sName, pt in pairs(S.stagingPoints) do
            if typeof(pt) == "Vector3" then
                rawStaging[tostring(sName)] = { pt.X, pt.Y, pt.Z }
            end
        end
        cfg.savedStagingPoints = rawStaging
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok and encoded then
        pcall(writefile, CONFIG_FILE, encoded)
        logAction("CONFIG", "Config saved to " .. CONFIG_FILE, Color3.fromRGB(80, 220, 140), "SUCCESS")
        return true
    else
        logAction("CONFIG", "Failed to encode config to JSON", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
end

local syncActiveFeatures

local function loadConfig()
    if not (readfile and isfile and isfile(CONFIG_FILE)) then return false end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return false end
    local okDec, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDec or type(parsed) ~= "table" then return false end
    for k, v in pairs(parsed) do
        if S[k] ~= nil and k ~= "fishingSets" and k ~= "fishingSetNames" then
            S[k] = v
        end
    end
    if parsed.savedFishingSets and type(parsed.savedFishingSets) == "table" then
        S.fishingSets = {} :: any
        for rawKey, rawList in pairs(parsed.savedFishingSets) do
            local sName = tostring(rawKey)
            if tonumber(rawKey) and parsed.fishingSetNames and type(parsed.fishingSetNames) == "table" then
                local num = tonumber(rawKey)
                local mappedName = parsed.fishingSetNames[num] or parsed.fishingSetNames[tostring(num)]
                if mappedName and mappedName ~= "" then sName = mappedName end
            end
            if type(rawList) == "table" and #rawList > 0 then
                S.fishingSets[sName] = {}
                for _, pt in ipairs(rawList) do
                    if type(pt) == "table" and #pt >= 3 then
                        table.insert(S.fishingSets[sName], Vector3.new(pt[1], pt[2], pt[3]))
                    end
                end
            end
        end
    end
    if S.activeFishingSet ~= nil then
        local rawAct = tostring(S.activeFishingSet)
        if tonumber(rawAct) and parsed.fishingSetNames and type(parsed.fishingSetNames) == "table" then
            local num = tonumber(rawAct)
            local mappedName = parsed.fishingSetNames[num] or parsed.fishingSetNames[tostring(num)]
            if mappedName and mappedName ~= "" then rawAct = mappedName end
        end
        local m = rawAct:match(":%s*(.+)")
        if m and m ~= "" then rawAct = m end
        S.activeFishingSet = rawAct
    else
        S.activeFishingSet = "Default"
    end
    if S.selectedSpotSlot ~= nil then
        local n = tonumber(tostring(S.selectedSpotSlot):match("(%d+)")) or 1
        S.selectedSpotSlot = math.clamp(math.floor(n), 1, 3)
    else
        S.selectedSpotSlot = 1
    end
    if parsed.savedStagingPoints and type(parsed.savedStagingPoints) == "table" then
        S.stagingPoints = S.stagingPoints or {}
        for rawKey, pt in pairs(parsed.savedStagingPoints) do
            local sName = tostring(rawKey)
            if tonumber(rawKey) and parsed.fishingSetNames and type(parsed.fishingSetNames) == "table" then
                local num = tonumber(rawKey)
                local mappedName = parsed.fishingSetNames[num] or parsed.fishingSetNames[tostring(num)]
                if mappedName and mappedName ~= "" then sName = mappedName end
            end
            if type(pt) == "table" and #pt >= 3 then
                S.stagingPoints[sName] = Vector3.new(pt[1], pt[2], pt[3])
            end
        end
    end
    local activeName = FISH.getActiveSetName()
    S.activeFishingSet = activeName
    if S.fishingSets and S.fishingSets[activeName] then
        FISH_SPOTS = S.fishingSets[activeName]
    end
    logAction("CONFIG", "Config loaded from " .. CONFIG_FILE, Color3.fromRGB(80, 220, 140), "SUCCESS")
    if syncActiveFeatures then pcall(syncActiveFeatures) end
    return true
end

local function copyConfigAsGenv()
    local lines = { "getgenv().BW_Config = {" }
    table.insert(lines, ('    mode = %q,'):format(S.mode or "normal"))
    table.insert(lines, ("    blackscreenOpaque = %s,"):format(tostring(S.blackscreenOpaque ~= false)))
    local keys = {
        "autoFish", "requireBait", "autoSellOutOfMoney", "lowMoneyThreshold",
        "autoQTE", "autoRestock", "baitKeep", "autoSell", "sellEvery",
        "castTimeout", "deadCastsBeforeMove", "reelDelay",
        "autoHopNearPlayer", "autoHopDistance", "autoHopIgnoreFriends",
        "autoChests", "autoHerbs", "promptRange", "autoBuy", "buyTarget", "buyReserve",
        "saintWatch", "saintGrab", "saintRetreat", "saintWindow",
        "espChest", "espHerb", "espHorse", "espPlayers", "espRange",
        "blackscreen", "showHud",
        "webhookUrl", "webhookIntervalEnabled", "webhookInterval", "webhookOnDogbane",
    }
    for _, k in ipairs(keys) do
        local v = S[k]
        if v ~= nil then
            if type(v) == "string" then
                table.insert(lines, ("    %s = %q,"):format(k, v))
            elseif type(v) == "boolean" or type(v) == "number" then
                table.insert(lines, ("    %s = %s,"):format(k, tostring(v)))
            end
        end
    end
    table.insert(lines, "}")
    local str = table.concat(lines, "\n")
    if setclip then
        pcall(setclip, str)
        logAction("CONFIG", "Config copied to clipboard as getgenv().BW_Config!", Color3.fromRGB(80, 220, 140), "SUCCESS")
    else
        print(str)
        logAction("CONFIG", "Config printed to console (setclipboard unavailable)", Color3.fromRGB(245, 175, 60), "CONFIG")
    end
    return str
end

local function applyGenvConfig()
    local gcfg = getgenv().BW_Config or getgenv().BWConfig or getgenv().Config
    if type(gcfg) == "table" then
        for k, v in pairs(gcfg) do
            if S[k] ~= nil or k == "blackscreenOpaque" then
                S[k] = v
            end
        end
        logAction("CONFIG", "Configuration applied from getgenv().BW_Config", Color3.fromRGB(80, 220, 140), "SUCCESS")
        pcall(primeTeleportLoader)
        if syncActiveFeatures then pcall(syncActiveFeatures) end
    end
end

pcall(loadConfig)
pcall(applyGenvConfig)

-- ── serverhop loader priming ────────────────────────────────────────────────
primeTeleportLoader = function()
    local q = queue_on_teleport or queueonteleport or queue_on_tp or queueontp or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not q then return false end

    local clearQ = clear_teleport_queue or clearteleportqueue or clear_tp_queue or cleartpqueue or clearqueueonteleport or (syn and syn.clear_teleport_queue)
    if clearQ then pcall(clearQ) end

    local loaderPayload = [[
        repeat task.wait(0.5) until game:IsLoaded()
        local Players = game:GetService("Players")
        local LP = Players.LocalPlayer
        while not LP do
            task.wait(0.5)
            LP = Players.LocalPlayer
        end

        task.wait(1)
        -- Attempt direct remote spawn into game
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local wf = RS:WaitForChild("WesternFramework", 10)
            local shared = wf and wf:WaitForChild("Shared", 10)
            local remotes = shared and shared:WaitForChild("Remotes", 10)
            local spawnEv = remotes and remotes:WaitForChild("SpawnPlayerEvent", 10)
            if spawnEv then spawnEv:FireServer() end
        end)
        pcall(function()
            local pg = LP:WaitForChild("PlayerGui", 10)
            if pg then
                local mm = pg:WaitForChild("MainMenu", 8)
                if mm then
                    local bc = mm:FindFirstChild("ButtonContainer")
                    local btn = bc and bc:FindFirstChild("PlayButton")
                    if btn then
                        local cons = getconnections and getconnections(btn.MouseButton1Click)
                        if cons and #cons > 0 then
                            for _, c in ipairs(cons) do
                                if c.Function then pcall(c.Function) end
                                if c.Fire then pcall(function() c:Fire() end) end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(1.5)
        local loaded = false
        for i = 1, 30 do
            if isfile and isfile("scripty.luau") and readfile and loadstring then
                local src = readfile("scripty.luau")
                if src and #src > 100 then
                    local fn, err = loadstring(src, "scripty.luau")
                    if fn then
                        task.spawn(fn)
                        loaded = true
                        break
                    end
                end
            end
            task.wait(0.5)
        end
        if not loaded and isfile and isfile("test_scripty.luau") and readfile and loadstring then
            local src = readfile("test_scripty.luau")
            if src and #src > 100 then
                local fn = loadstring(src, "test_scripty.luau")
                if fn then task.spawn(fn) end
            end
        end
    ]]

    local ok = pcall(q, loaderPayload)
    if ok then
        logAction("SYSTEM", "Teleport auto-loader primed (scripty.luau auto-spawn)", Color3.fromRGB(150, 160, 255))
    end
    return ok
end

primeTeleportLoader()
pcall(function()
    track(LP.OnTeleport:Connect(function()
        primeTeleportLoader()
    end))
end)

-- ── discord webhook system ─────────────────────────────────────────────────
local lastDogbaneCount = -1
local lastWebhookSend = 0

local function sendDiscordWebhook(title, description, fields, color)
    local url = S.webhookUrl
    if not url or url == "" or not url:find("https?://") then return false end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return false end

    local embed = {
        title = title or "Bridger Telemetry Update",
        description = description or "",
        color = color or 0xE6A537,
        fields = fields or {},
        footer = { text = "Bridger " .. VERSION .. " • " .. os.date("%X") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    local payload = HttpService:JSONEncode({
        username = "Bridger Monitor",
        avatar_url = "https://i.imgur.com/8Qf9z8x.png",
        embeds = { embed },
    })

    task.spawn(function()
        pcall(function()
            req({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload,
            })
        end)
    end)
    return true
end

local function sendInventoryWebhook(reason)
    local fCounts, fTotal = getFishCounts()
    local dogbane = countDogbane()
    local curM = moola()
    local bait = countTool("Bait")
    local curRod = findTool("FishingRod") ~= nil

    local fields = {
        { name = "💰 Total Moola", value = "$" .. tostring(curM), inline = true },
        { name = "🌿 Dogbane Herbs", value = tostring(dogbane), inline = true },
        { name = "🎣 Total Fish", value = tostring(fTotal), inline = true },
        { name = "🐟 Fish Breakdown", value = string.format("Bass: %d | Snapper: %d | Cod: %d", fCounts.Bass or 0, fCounts.Snapper or 0, fCounts.Cod or 0), inline = false },
        { name = "🪱 Bait & Catches", value = string.format("Bait: %d | Catches: %d | Rod: %s", bait, FISH.catches, curRod and "Equipped" or "None"), inline = false },
        { name = "📍 Current Status", value = string.format("[%s] %s\n%s", Status.state, Status.action, Status.detail), inline = false },
    }

    local title = reason or "📊 Inventory & Status Report"
    local sent = sendDiscordWebhook(title, "Telemetry update for **" .. LP.Name .. "** (" .. (LP.DisplayName or LP.Name) .. ")", fields, 0xE6A537)
    if sent then
        lastWebhookSend = os.clock()
        logAction("WEBHOOK", "Dispatched inventory webhook to Discord", Color3.fromRGB(80, 220, 140), "WEBHOOK")
    else
        logAction("WEBHOOK", "Failed to send webhook (check URL/HTTP support)", Color3.fromRGB(245, 90, 90), "ERROR")
    end
    return sent
end


return {
    CONFIG_FILE = CONFIG_FILE,
    saveConfig = saveConfig,
    loadConfig = loadConfig,
    copyConfigAsGenv = copyConfigAsGenv,
    applyGenvConfig = applyGenvConfig,
    primeTeleportLoader = primeTeleportLoader,
    sendDiscordWebhook = sendDiscordWebhook,
    sendInventoryWebhook = sendInventoryWebhook,
    lastDogbaneCount = lastDogbaneCount,
    lastWebhookSend = lastWebhookSend,
}
