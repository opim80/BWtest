--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MAIN LOADER & ORCHESTRATOR
-- Clean Modular Architecture
-- ============================================================

-- Guard against multiple simultaneous executions
if getgenv().BW3_Unload then
    pcall(getgenv().BW3_Unload)
end

local GEN = (getgenv().BW3_Gen or 0) + 1
getgenv().BW3_Gen = GEN

-- Shared Context and Environment Bridge
local SHARED = {
    UI = { tabs = {} },
    FISH = { status = "idle", casts = 0, catches = 0, dead = 0 },
    COMBAT = {},
    SAINT = { status = "idle", detects = 0, grabs = 0, lastPart = "none" },
    FARM = {},
}
setmetatable(SHARED, {
    __index = getgenv(),
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end
})

-- Run loader with SHARED environment
setfenv(1, setmetatable({}, {
    __index = SHARED,
    __newindex = SHARED
}))

-- ============================================================
-- GITHUB REPO CONFIGURATION (For Remote Execution via game:HttpGet)
-- ============================================================
local GITHUB_USER_REPO = getgenv().BW_GITHUB_REPO or "opim80/BWtest"
local GITHUB_BRANCH = getgenv().BW_GITHUB_BRANCH or "main"

-- Module Loader
local function loadModule(name, ctx)
    local candidates = {
        "BW/modules/" .. name .. ".luau",
        "modules/" .. name .. ".luau",
        "BW/" .. name .. ".luau",
        name .. ".luau"
    }
    local content, matchedPath
    for _, path in ipairs(candidates) do
        if isfile and isfile(path) then
            content = readfile(path)
            matchedPath = path
            break
        end
    end

    -- GitHub Remote Fallback if running from web or missing on local disk
    if not content and (game and game.HttpGet) then
        local rawUrl = string.format("https://raw.githubusercontent.com/%s/%s/modules/%s.luau", GITHUB_USER_REPO, GITHUB_BRANCH, name)
        local ok, res = pcall(function()
            return game:HttpGet(rawUrl)
        end)
        if ok and typeof(res) == "string" and #res > 0 and not res:find("404: Not Found") then
            content = res
            matchedPath = rawUrl
            pcall(function()
                if writefile and makefolder then
                    pcall(makefolder, "BW")
                    pcall(makefolder, "BW/modules")
                    writefile("BW/modules/" .. name .. ".luau", res)
                end
            end)
        end
    end

    if not content then
        error(string.format("[BW Loader] Failed to locate module '%s' (checked local disk and %s/%s)", name, GITHUB_USER_REPO, GITHUB_BRANCH))
    end
    local fn, err = loadstring(content, "=" .. name)
    if not fn then
        error(string.format("[BW Loader] Compile error in %s: %s", name, tostring(err)))
    end
    setfenv(fn, setmetatable({}, {
        __index = SHARED,
        __newindex = SHARED
    }))
    local ok, res = pcall(fn, ctx)
    if not ok then
        error(string.format("[BW Loader] Runtime error in %s: %s", name, tostring(res)))
    end
    if type(res) == "table" then
        for k, v in pairs(res) do
            SHARED[k] = v
        end
    end
    return res
end

local ctx = {
    SHARED = SHARED,
    loadModule = loadModule,
}

-- 1. Core Module (Services, S defaults, tracking, loops)
local Core = loadModule("Core", ctx)
ctx.Core = Core
ctx.Services = Core.Services
ctx.S = Core.S
ctx.track = Core.track
ctx.loop = Core.loop
ctx.conns = Core.conns
ctx.loops = Core.loops
ctx.draws = Core.draws

-- 2. Utils Module (Character accessors, Inventory helpers)
local Utils = loadModule("Utils", ctx)
ctx.Utils = Utils

-- 3. Logging & Telemetry Engine
local Logging = loadModule("Logging", ctx)
ctx.Logging = Logging

-- 4. Config Persistence & Webhooks
local Config = loadModule("Config", ctx)
ctx.Config = Config

-- 5. Movement (Horse Travel & Ghost Fake Fly)
local Movement = loadModule("Movement", ctx)
ctx.Movement = Movement

-- 6. Safety (Friends Whitelist & Server Hopping)
local Safety = loadModule("Safety", ctx)
ctx.Safety = Safety

-- 7. Fishing Engine
local Fishing = loadModule("Fishing", ctx)
ctx.Fishing = Fishing

-- 8. Automation (Farm, Shop, Pickups)
local Automation = loadModule("Automation", ctx)
ctx.Automation = Automation

-- 9. Visuals (ESP)
local Visuals = loadModule("Visuals", ctx)
ctx.Visuals = Visuals

-- 10. Saint's Corpse Automation
local Saint = loadModule("Saint", ctx)
ctx.Saint = Saint

-- 11. UI System (Design Framework, Mini-HUD, Blackscreen, Main Window)
local UI = loadModule("UI", ctx)
ctx.UI = UI

-- 12. Combat (Prediction Silent Aim, Ballistic Arc Visualizer, Gun Hooking)
local Combat = loadModule("Combat", ctx)
ctx.Combat = Combat
SHARED.COMBAT = Combat

-- 13. Tabs (All 9 UI Tabs)
local Tabs = loadModule("Tabs", ctx)
ctx.Tabs = Tabs

-- Initialize all tabs
Tabs.initTabs()

-- 14. Telemetry Loop, FAB, Hotkeys & Lifecycle Teardown

-- ── TELEMETRY LOOP ─────────────────────────────────────────────────────────
S.statusLoop = true


    loop("statusLoop", 0.35, function()
    local curM = moola()
    local curBait = countTool("Bait")
    local curCatches = FISH.catches
    local curRod = findTool("FishingRod") ~= nil
    local h = myHorse()
    local horseName = h and h.Name or "None"
    local hasCorpse = holdingCorpse()

    local myStand, myTier, myAlign, myExp = getStandInfo()
    if UI.quickStatsLabel then
        UI.quickStatsLabel.Text = ("$%d  •  %d Bait  •  %d Caught"):format(curM, curBait, curCatches)
    end
    if UI.infoStandPath then
        UI.infoStandPath:Set(myStand)
        UI.infoStandTier:Set("Tier " .. tostring(myTier))
        UI.infoStandAlign:Set(tostring(myAlign))
        UI.infoStandExp:Set(tostring(myExp))
        UI.infoCatches:Set(tostring(curCatches))
    end

    if isSellingFish then
        Status.state = "SELLING"
        Status.color = Color3.fromRGB(245, 175, 60)
    elseif isRestockingBait then
        Status.state = "RESTOCK"
        Status.color = Color3.fromRGB(245, 175, 60)
    elseif S.autoFish then
        Status.state = "FISHING"
        Status.color = Color3.fromRGB(70, 200, 140)
        local waitSecs = (castPhase == "casted" and lastCast > 0) and math.floor(os.clock() - lastCast) or 0
        local baitTag = S.requireBait and ("Bait: " .. curBait) or (curBait > 0 and ("Bait: " .. curBait) or "No Bait")
        Status.detail = ("%s | Spot #%d | Catches: %d | Rod: %s"):format(baitTag, spotIndex, curCatches, curRod and "Yes" or "No")
        if castPhase == "casted" then
            Status.action = ("Waiting for bite (%ds)..."):format(waitSecs)
        end
    elseif S.autoChests or S.autoHerbs then
        Status.detail = ("Chests/Herbs Opened: %d | Range: %d studs"):format(FARM.opened, S.promptRange)
    elseif S.saintWatch then
        Status.detail = ("Detects: %d | Grabs: %d | Holding Corpse: %s"):format(SAINT.detects, SAINT.grabs, tostring(hasCorpse))
    else
        Status.detail = ("Moola: $%d | Bait: %d | Horse: %s"):format(curM, curBait, horseName)
    end

    -- Webhook: Dogbane acquisition alert
    local curDogbane = countDogbane()
    if lastDogbaneCount == -1 then
        lastDogbaneCount = curDogbane
    elseif curDogbane > lastDogbaneCount then
        local diff = curDogbane - lastDogbaneCount
        lastDogbaneCount = curDogbane
        if S.webhookOnDogbane and S.webhookUrl and S.webhookUrl ~= "" then
            local fields = {
                { name = "🌿 Acquired", value = ("+%d Dogbane Herb(s)"):format(diff), inline = true },
                { name = "🎒 Total in Bag", value = tostring(curDogbane), inline = true },
                { name = "💰 Moola", value = "$" .. tostring(curM), inline = true },
                { name = "📍 Status", value = string.format("[%s] %s", Status.state, Status.action), inline = false },
            }
            sendDiscordWebhook("🌿 Dogbane Herb Acquired!", "New Dogbane Herb collected by **" .. LP.Name .. "**!", fields, 0xAF82FF)
            logAction("WEBHOOK", ("Dispatched Dogbane alert webhook (+%d herb(s))"):format(diff), Color3.fromRGB(175, 130, 255), "WEBHOOK")
        end
    elseif curDogbane < lastDogbaneCount then
        lastDogbaneCount = curDogbane
    end

    -- Webhook: Periodic inventory update
    if S.webhookIntervalEnabled and S.webhookUrl and S.webhookUrl ~= "" then
        local intervalSec = math.max(1, S.webhookInterval or 10) * 60
        if os.clock() - lastWebhookSend >= intervalSec then
            sendInventoryWebhook("⏱️ Periodic Telemetry (" .. tostring(S.webhookInterval) .. "m)")
        end
    end

    if UI.updateBanner then pcall(UI.updateBanner) end
    if UI.updateHud then pcall(UI.updateHud) end
    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
end)

-- ── FLOATING ACTION BUTTON (FAB) & HOTKEYS ─────────────────────────────────
do
    local fab = mk("TextButton", {
        Size = UDim2.fromOffset(42, 42),
        Position = UDim2.new(0, 14, 0.5, -21),
        BackgroundColor3 = TH.bg,
        Font = Enum.Font.GothamBold,
        Text = "B",
        TextColor3 = TH.accent,
        TextSize = 18,
        AutoButtonColor = false,
    }, UI.gui)
    corner(fab, 12)
    stroke(fab, TH.accent)
    UI.fab = fab
    track(fab.MouseButton1Click:Connect(function()
        if S.blackscreen then
            UI.setBlackscreen(false)
        else
            UI.main.Visible = not UI.main.Visible
        end
    end))
    do
        local drag, ds, sp
        track(fab.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = true; ds = i.Position; sp = fab.Position
            end
        end))
        track(UIS.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - ds
                fab.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
            end
        end))
        track(UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
        end))
    end

    track(UIS.InputBegan:Connect(function(i, gp)
        if gp or S._rebinding then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            if S.blackscreen then
                UI.setBlackscreen(false)
            else
                UI.main.Visible = not UI.main.Visible
            end
        elseif S.horseFlyKey and S.horseFlyKey ~= "None" and i.KeyCode.Name == S.horseFlyKey then
            S.fakeHorseFly = not S.fakeHorseFly
            if S.fakeHorseFly then
                startFakeHorseFly()
            else
                stopFakeHorseFly(true)
            end
            if UI.updateToggles then pcall(UI.updateToggles) end
        end
    end))

    syncActiveFeatures = function()
        if updateAllTogglesUI then
            pcall(updateAllTogglesUI)
        end

        if S.autoFish then
            if not loops["autoFish"] then
                startFishing()
            end
        else
            if loops["autoFish"] then
                stopFishing()
            end
        end

        if S.silentAim then
            COMBAT.start()
        end

        if S.iHateYou then
            COMBAT.startIHateYou()
        end

        if S.autoHopNearPlayer then
            if not loops["autoHopNearPlayer"] then
                loop("autoHopNearPlayer", 0.5, playerProximityTick)
            end
        end

        if S.autoChests and not loops["autoChests"] then
            loop("autoChests", 0.8, function() farmTick("Chests", "chest", false) end)
        end

        if S.autoHerbs and not loops["autoHerbs"] then
            loop("autoHerbs", 0.8, function() farmTick("SpawnedHerbs", "herb", false) end)
        end

        if S.autoBuy and not loops["autoBuy"] then
            loop("autoBuy", 1.5, autoBuyTick)
        end

        if S.saintWatch and not loops["saintWatch"] then
            loop("saintWatch", 2, saintTick)
        end

        if ensureESP then
            pcall(ensureESP)
        end

        if UI.setBlackscreen and S.blackscreen ~= nil then
            pcall(function()
                UI.setBlackscreen(S.blackscreen)
            end)
        end
    end

    getgenv().BW3 = {
        S = S,
        UI = UI,
        Status = Status,
        COMBAT = COMBAT,
        startFakeHorseFly = startFakeHorseFly,
        stopFakeHorseFly = stopFakeHorseFly,
        mountHorse = mountHorse,
        summonHorse = summonHorse,
        dismount = dismount,
        isMounted = isMounted,
        setBlackscreen = UI.setBlackscreen,
        serverHop = serverHop,
        playerProximityTick = playerProximityTick,
        syncActiveFeatures = syncActiveFeatures,
        loadConfig = loadConfig,
        applyGenvConfig = applyGenvConfig,
    }
end


-- ── CLEANUP / UNLOAD ───────────────────────────────────────────────────────
local function destroy()
    if not S.running then return end
    S.running = false
    getgenv().BW3_Gen = (getgenv().BW3_Gen or 0) + 1
    for k, v in pairs(S) do if type(v) == "boolean" then S[k] = false end end
    if COMBAT.stop then pcall(COMBAT.stop) end
    if COMBAT.stopIHateYou then pcall(COMBAT.stopIHateYou) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    pcall(clearDraws)
    if UI.gui then pcall(function() UI.gui:Destroy() end) end
    if UI.hudGui then pcall(function() UI.hudGui:Destroy() end) end
    if UI.bsGui then pcall(function() UI.bsGui:Destroy() end) end
    getgenv().BW3 = nil
    getgenv().BW3_Unload = nil
end
getgenv().BW3_Unload = destroy
track(UI.closeBtn.MouseButton1Click:Connect(destroy))
track(UI.gui.Destroying:Once(destroy))
track(UI.gui.AncestryChanged:Connect(function(_, par)
    if par then return end
    if not S.running then return end
    task.defer(function()
        if S.running and not UI.gui.Parent then pcall(parentGui, UI.gui) end
    end)
end))

logAction("SYSTEM", "Bridger initialized and ready", TH.accent, "IDLE")
syncActiveFeatures()

