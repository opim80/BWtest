--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Core
-- Services, Capabilities, Adonis Bypass, Settings & Lifecycle
-- ============================================================
local ctx = ...
local SHARED = getfenv()

-- ── ADONIS ANTICHEAT BYPASS ────────────────────────────────────────────────
pcall(function()
    local getinfo = getinfo or debug.getinfo
    local DEBUG = false
    local Hooked = {}
    local Detected, Kill

    local syn = rawget(getfenv(), "syn"); local setidentity = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity)
    if setidentity then pcall(setidentity, 2) end

    local getgc_fn = getgc or get_gc_objects
    local hook_fn = hookfunction or replaceclosure

    if getgc_fn and hook_fn then
        for _, v in ipairs(getgc_fn(true)) do
            if typeof(v) == "table" then
                local DetectFunc = rawget(v, "Detected")
                local KillFunc = rawget(v, "Kill")

                if typeof(DetectFunc) == "function" and not Detected then
                    Detected = DetectFunc
                    local Old; Old = hook_fn(Detected, function(Action, Info, NoCrash)
                        if Action ~= "_" and DEBUG then
                            warn("Adonis AntiCheat flagged\nMethod: " .. tostring(Action) .. "\nInfo: " .. tostring(Info))
                        end
                        return true
                    end)
                    table.insert(Hooked, Detected)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
                    Kill = KillFunc
                    local Old; Old = hook_fn(Kill, function(Info)
                        if DEBUG then
                            warn("Adonis AntiCheat tried to kill (fallback): " .. tostring(Info))
                        end
                    end)
                    table.insert(Hooked, Kill)
                end
            end
        end
    end

    if getrenv and getrenv().debug and getrenv().debug.info and hook_fn then
        local Old; Old = hook_fn(getrenv().debug.info, newcclosure(function(...)
            local LevelOrFunc, Info = ...
            if Detected and LevelOrFunc == Detected then
                if DEBUG then
                    warn("Adonis Bypassed!")
                end
                return coroutine.yield(coroutine.running())
            end
            return Old(...)
        end))
    end

    if setidentity then pcall(setidentity, 7) end
end)


local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- Auto-spawn into game if currently on MainMenu
pcall(function()
    local wf = RS:FindFirstChild("WesternFramework")
    local remotes = wf and wf:FindFirstChild("Shared") and wf.Shared:FindFirstChild("Remotes")
    local spawnEv = remotes and remotes:FindFirstChild("SpawnPlayerEvent")
    if spawnEv then spawnEv:FireServer() end
end)
pcall(function()
    local pg = LP:FindFirstChild("PlayerGui")
    local mm = pg and pg:FindFirstChild("MainMenu")
    if mm then
        local bc = mm:FindFirstChild("ButtonContainer")
        local btn = bc and bc:FindFirstChild("PlayButton")
        if btn then
            local cons = getconnections and getconnections(btn.MouseButton1Click)
            if cons then
                for _, c in ipairs(cons) do
                    if c.Function then pcall(c.Function) end
                    if c.Fire then pcall(function() c:Fire() end) end
                end
            end
        end
    end
end)

-- Anti-Idle: Prevent 20-minute idle disconnects
pcall(function()
    local VU = game:GetService("VirtualUser")
    LP.Idled:Connect(function()
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.zero)
        end)
    end)
end)

local VERSION = "v3.2"

-- Global settings cache per place
getgenv().BWCache = getgenv().BWCache or {}
local PC = getgenv().BWCache[tostring(game.PlaceId)] or {}
getgenv().BWCache[tostring(game.PlaceId)] = PC

local MISSING = {}
local function cap(name)
    local f = rawget(getfenv(), name)
    if typeof(f) ~= "function" then
        local ok, v = pcall(function() return getfenv()[name] end)
        f = ok and v or nil
    end
    if typeof(f) ~= "function" then MISSING[#MISSING + 1] = name; return nil end
    return f
end
local firepp = cap("fireproximityprompt")
local fireclick = cap("fireclickdetector")
local _mouseabs = cap("mousemoveabs")
local keyclickFn = cap("keyclick")
local keypressFn = cap("keypress")
local keyreleaseFn = cap("keyrelease")
local rbxActive = cap("isrbxactive")
local getcons = cap("getconnections")
local syn = rawget(getfenv(), "syn")
local http = rawget(getfenv(), "http")
local setclip = cap("setclipboard") or cap("toclipboard") or cap("set_clipboard")

local IH: any
do
    local ok, m = pcall(function()
        local req = require
        return req(RS:WaitForChild("Modules", 3):WaitForChild("CoreModules", 3):WaitForChild("InputHandlerClient", 3))
    end)
    IH = ok and m or nil
end

local S = {
    running = true,
    fakeHorseFly = false, fakeFlySpeed = 75, horseFlyKey = "H", _rebinding = false,
    silentAim = false, martiniBallistics = false, shootOverRocks = false, chamsWhite = false, aimTargetMode = "Closest to Cursor", aimHitbox = "Head", aimIgnoreFriends = false, customFriends = "", iHateYou = false, iHateYouDistance = 190, martiniVantage = false, onlyFireAtLowSpeeds = false, maxFiringSpeed = 25, minHitChance = 0,
    humanPredictor = true, smartHitboxEV = true, peakConfidenceFire = false, peakFireThreshold = 75,
    autoFish = false, autoRestock = true, baitKeep = 15,
    autoSell = false, sellEvery = 10,
    autoSellOutOfMoney = true, lowMoneyThreshold = 10,
    requireBait = false,
    blackscreen = false, blackscreenOpaque = true,
    saintWatch = false, saintGrab = true, saintRetreat = true, saintWindow = 300,
    autoChests = false, autoHerbs = false, promptRange = 25,
    autoBuy = false, buyTarget = "AmmoPack", buyReserve = 50,
    espChest = false, espHerb = false, espHorse = false, espPlayers = false, espRange = 1500,
    autoQTE = true,
    autoHopNearPlayer = false, autoHopDistance = 150, autoHopIgnoreFriends = true,
    webhookUrl = "", webhookIntervalEnabled = false, webhookInterval = 10, webhookOnDogbane = true,
    castTimeout = 22, deadCastsBeforeMove = 4, reelDelay = 0.25,
    showHud = true,
    legitFishing = true,
    visualizeLegit = true,
    selectedSpotSlot = 1,
    activeFishingSet = "Default",
    stagingPoints = {
        ["Default"] = Vector3.new(-3125.0, 47.0, -3685.0),
    },
    fishingSets = {
        ["Default"] = {
            Vector3.new(-3131.6, 47.12, -3717.2),
            Vector3.new(-3139.6, 47.12, -3717.2),
            Vector3.new(-3147.6, 47.12, -3709.2),
        },
    } :: any,
    autoSwapSetNearPlayer = false,
    autoSwapDistance = 150,
    saintPreHoldWait = 0,
    saintDefendGun = false,
    saintGunSelect = "None",
    saintMergeTpPlayer = "None",
}
getgenv().BW3 = S

local conns, loops, draws = {}, {}, {}
local lastCast = 0
local castPhase = "idle"
local _lastReelTap = 0
local tappedThisCast = false
local biteWatchStarted = false
local lastCatchTime = 0
local lastKnownFishTotal = 0
local isSellingFish = false
local isRestockingBait = false
local primeTeleportLoader
local GEN = (getgenv().BW3_Gen or 0) + 1
getgenv().BW3_Gen = GEN
local function track(c) conns[#conns + 1] = c; return c end
local function loop(key, iv, fn)
    if loops[key] then return end
    loops[key] = true
    task.spawn(function()
        while GEN == getgenv().BW3_Gen and S.running and S[key] do
            pcall(fn)
            if iv and iv > 0 then task.wait(iv) else RunService.Heartbeat:Wait() end
        end
        loops[key] = false
    end)
end



return {
    Services = {
        Players = Players,
        RS = RS,
        RunService = RunService,
        UIS = UIS,
        WS = WS,
        TS = TS,
        LP = LP,
        Camera = WS.CurrentCamera,
    },
    Players = Players,
    RS = RS,
    RunService = RunService,
    UIS = UIS,
    WS = WS,
    TS = TS,
    LP = LP,
    VERSION = VERSION,
    PC = PC,
    MISSING = MISSING,
    cap = cap,
    firepp = firepp,
    fireclick = fireclick,
    _mouseabs = _mouseabs,
    keyclickFn = keyclickFn,
    keypressFn = keypressFn,
    keyreleaseFn = keyreleaseFn,
    rbxActive = rbxActive,
    getcons = getcons,
    syn = syn,
    http = http,
    setclip = setclip,
    S = S,
    conns = conns,
    loops = loops,
    draws = draws,
    track = track,
    loop = loop,
    lastCast = lastCast,
    castPhase = castPhase,
    _lastReelTap = _lastReelTap,
    tappedThisCast = tappedThisCast,
    biteWatchStarted = biteWatchStarted,
    isRestockingBait = isRestockingBait,
    isSellingFish = isSellingFish,
    lastCatchTime = lastCatchTime,
    lastKnownFishTotal = lastKnownFishTotal,
}
