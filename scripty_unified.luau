--!nocheck
-- ── ADONIS ANTICHEAT BYPASS (RAW & UN-PCALLED) ─────────────────────────────
do
    local getinfo = getinfo or debug.getinfo
    local DEBUG = false
    local Hooked = {}
    local Detected, Kill

    setthreadidentity(2)

    for i, v in getgc(true) do
        if typeof(v) == "table" then
            local DetectFunc = rawget(v, "Detected")
            local KillFunc = rawget(v, "Kill")

            if typeof(DetectFunc) == "function" and not Detected then
                Detected = DetectFunc

                local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
                    if Action ~= "_" then
                        if DEBUG then
                            warn(`Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`)
                        end
                    end

                    return true
                end)

                table.insert(Hooked, Detected)
            end

            if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
                Kill = KillFunc
                local Old; Old = hookfunction(Kill, function(Info)
                    if DEBUG then
                        warn(`Adonis AntiCheat tried to kill (fallback): {Info}`)
                    end
                end)

                table.insert(Hooked, Kill)
            end
        end
    end

    local Old; Old = hookfunction(getrenv().debug.info, newcclosure(function(...)
        local LevelOrFunc, Info = ...

        if Detected and LevelOrFunc == Detected then
            if DEBUG then
                warn(`Adonis Bypassed!`)
            end

            return coroutine.yield(coroutine.running())
        end

        return Old(...)
    end))
    setthreadidentity(7)
end

-- Guard against multiple simultaneous executions
if getgenv().BW3_Unload then
    pcall(getgenv().BW3_Unload)
end

-- ============================================================
-- BRIDGER HUB (BW) — UNIFIED ENGINE v3.5
-- High-Efficiency Single-File Edition with Modern D.R.Y. UI
-- ============================================================
local VERSION = "3.5"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer or Players:GetPlayers()[1]
local WS = Workspace
local UIS = UserInputService
local TS = TweenService
local Mouse = LP and LP:GetMouse()
local Camera = WS.CurrentCamera or WS:FindFirstChildOfClass("Camera")

-- Character & Spatial Helpers
local function char() return LP and LP.Character end
local function root() local c = char(); return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart) end
local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end

local function groundY(pos, ignore)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { char() }
    if ignore then table.insert(ex, ignore) end
    rp.FilterDescendantsInstances = ex
    local hit = WS:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), rp)
    return hit and (hit.Position.Y + 3.0) or nil
end

-- Cross-Section Forward Declarations
local UI: any = {}
local FISH: any = {}
local COMBAT: any = {}

-- Executor Compatibility Resolvers
local syn = rawget(_G, "syn") or (rawget(getgenv and getgenv() or {}, "syn"))
local fluxus = rawget(_G, "fluxus") or (rawget(getgenv and getgenv() or {}, "fluxus"))

-- Executor Hardware Keyboard Drivers
local keypressFn = keypress or (syn and syn.keypress) or (fluxus and fluxus.keypress)
local keyreleaseFn = keyrelease or (syn and syn.keyrelease) or (fluxus and fluxus.keyrelease)
local keyclickFn = keyclick
local firepp = fireproximityprompt

local function tapSpace()
    if keyclickFn then
        pcall(keyclickFn, 0x20)
    elseif keypressFn and keyreleaseFn then
        pcall(keypressFn, 0x20)
        task.wait(0.035)
        pcall(keyreleaseFn, 0x20)
    end
    if keyreleaseFn then pcall(keyreleaseFn, 0x20) end
    local h = hum()
    if h then pcall(function() h.Jump = false end) end
end

local function releaseAllKeys()
    if keyreleaseFn then
        pcall(keyreleaseFn, 0x20)
        pcall(keyreleaseFn, 0x45)
        pcall(keyreleaseFn, 0x10)
    end
    local h = hum()
    if h then pcall(function() h.Jump = false end) end
end

-- Game Internal Input Handler
local function tap(alias, duration)
    pcall(function()
        local ih = require(ReplicatedStorage.Modules.CoreModules.InputHandlerClient)
        ih:FireVirtualInput(alias, true)
        task.wait(duration or 0.1)
        ih:FireVirtualInput(alias, false)
    end)
end

-- UI Choice / Dialog Clicker
local function pressChoice(b)
    if not b then return false end
    local getcons = getconnections or get_signal_cons
    if getcons then
        local ok, cons = pcall(getcons, b.MouseButton1Click)
        if ok and cons then
            for _, c in ipairs(cons) do
                if c.Function then pcall(c.Function) end
            end
        end
        local ok2, cons2 = pcall(getcons, b.Activated)
        if ok2 and cons2 then
            for _, c in ipairs(cons2) do
                if c.Function then pcall(c.Function) end
            end
        end
    end
    if firesignal then
        pcall(firesignal, b.MouseButton1Click)
        pcall(firesignal, b.Activated)
    end
    return true
end

-- Inventory & Stats Helpers
local function findTool(name)
    local c = char()
    local t = c and c:FindFirstChild(name)
    if t then return t end
    local bp = LP and LP:FindFirstChildOfClass("Backpack")
    return bp and bp:FindFirstChild(name)
end

local function countTool(name)
    local cnt = 0
    for _, container in ipairs({ char(), LP and LP:FindFirstChildOfClass("Backpack") }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item.Name == name or item.Name:find(name) then cnt = cnt + 1 end
            end
        end
    end
    return cnt
end

local function countDogbane()
    local cnt = 0
    for _, container in ipairs({ char(), LP and LP:FindFirstChildOfClass("Backpack") }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item.Name:lower():find("dogbane") then cnt = cnt + 1 end
            end
        end
    end
    return cnt
end

local function moola()
    local val = LP and (LP:FindFirstChild("Moola") or LP:FindFirstChild("Money") or LP:FindFirstChild("Cash")
        or (LP:FindFirstChild("leaderstats") and (LP.leaderstats:FindFirstChild("Moola") or LP.leaderstats:FindFirstChild("Money"))))
    if val and val:IsA("ValueBase") then return tonumber(val.Value) or 0 end
    local attr = LP and (LP:GetAttribute("Moola") or LP:GetAttribute("Money") or LP:GetAttribute("Cash"))
    if attr then return tonumber(attr) or 0 end
    return 0
end

local function getFishCounts()
    local counts = { Bass = 0, Snapper = 0, Cod = 0 }
    local total = 0
    for _, container in ipairs({ char(), LP and LP:FindFirstChildOfClass("Backpack") }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                local n = item.Name
                if counts[n] ~= nil then
                    counts[n] = counts[n] + 1
                    total = total + 1
                elseif n:find("Fish") or n:find("Trout") or n:find("Salmon") then
                    total = total + 1
                end
            end
        end
    end
    return counts, total
end

local function getStandInfo()
    local standName, tier, alignment, exp = "None", "-", "-", "-"
    local c = char()
    if c then
        local stAttr = c:GetAttribute("Stand") or c:GetAttribute("StandName") or LP:GetAttribute("Stand")
        if stAttr then standName = tostring(stAttr) end
        local tAttr = c:GetAttribute("Tier") or LP:GetAttribute("Tier")
        if tAttr then tier = tostring(tAttr) end
        local aAttr = c:GetAttribute("Alignment") or LP:GetAttribute("Alignment")
        if aAttr then alignment = tostring(aAttr) end
        local eAttr = c:GetAttribute("Exp") or LP:GetAttribute("EXP")
        if eAttr then exp = tostring(eAttr) end
    end
    return standName, tier, alignment, exp
end


-- ============================================================
-- 2. STATE, TELEMETRY, CONFIG PERSISTENCE & WEBHOOKS
-- ============================================================
local Status = {
    state = "IDLE",
    action = "Ready",
    detail = "All systems operational",
    color = Color3.fromRGB(80, 220, 140),
}

local logHistory = {}
local function logAction(sys, msg, col, tag, detail)
    local entry = { sys = sys, msg = msg, col = col or Color3.fromRGB(240, 243, 250), tag = tag or sys, detail = detail or "", time = os.date("%X") }
    table.insert(logHistory, 1, entry)
    if #logHistory > 100 then table.remove(logHistory) end
    Status.state = sys
    Status.action = msg
    Status.detail = detail or ""
    Status.color = col or Color3.fromRGB(80, 220, 140)
    if UI and UI.updateStatus then pcall(UI.updateStatus) end
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
    },
    autoSwapSetNearPlayer = false,
    autoSwapDistance = 150,
    saintPreHoldWait = 0,
    saintDefendGun = false,
    saintGunSelect = "None",
    saintMergeTpPlayer = "None",
}
getgenv().BW3 = S

local conns, loops = {}, {}
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

-- Configuration Persistence
local CONFIG_FILE = "bridger_config.json"
local function saveConfig()
    if not writefile then return false end
    local cfg = {}
    for k, v in pairs(S) do
        if type(v) ~= "table" and type(v) ~= "function" and not k:find("^_") then
            cfg[k] = v
        end
    end
    if S.fishingSets then
        local rawSets = {}
        for setName, list in pairs(S.fishingSets) do
            if type(list) == "table" then
                rawSets[tostring(setName)] = {}
                for slotIdx = 1, 3 do
                    local pt = list[slotIdx]
                    local p = (typeof(pt) == "Vector3" and pt) or (typeof(pt) == "table" and pt.pos) or (typeof(pt) == "CFrame" and pt.Position)
                    if p then
                        local l = (typeof(pt) == "table" and pt.look)
                        if l then
                            table.insert(rawSets[tostring(setName)], { p.X, p.Y, p.Z, l.X, l.Y, l.Z })
                        else
                            table.insert(rawSets[tostring(setName)], { p.X, p.Y, p.Z })
                        end
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
        logAction("CONFIG", "Config saved to " .. CONFIG_FILE, Color3.fromRGB(80, 220, 140))
        return true
    end
    return false
end

local function loadConfig()
    if not (readfile and isfile and isfile(CONFIG_FILE)) then return false end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return false end
    local okDec, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDec or type(parsed) ~= "table" then return false end
    for k, v in pairs(parsed) do
        if S[k] ~= nil and k ~= "fishingSets" and k ~= "stagingPoints" then
            S[k] = v
        end
    end
    if parsed.savedFishingSets and type(parsed.savedFishingSets) == "table" then
        for rawKey, rawList in pairs(parsed.savedFishingSets) do
            local sName = tostring(rawKey)
            S.fishingSets[sName] = {}
            for _, coord in ipairs(rawList) do
                if type(coord) == "table" and #coord >= 3 then
                    local p = Vector3.new(coord[1], coord[2], coord[3])
                    local l = (#coord >= 6) and Vector3.new(coord[4], coord[5], coord[6]) or nil
                    table.insert(S.fishingSets[sName], l and { pos = p, look = l } or p)
                end
            end
        end
    end
    if parsed.savedStagingPoints and type(parsed.savedStagingPoints) == "table" then
        for rawKey, coord in pairs(parsed.savedStagingPoints) do
            if type(coord) == "table" and #coord >= 3 then
                S.stagingPoints[tostring(rawKey)] = Vector3.new(coord[1], coord[2], coord[3])
            end
        end
    end
    logAction("CONFIG", "Config loaded from disk", Color3.fromRGB(80, 220, 140))
    return true
end

local function applyGenvConfig()
    local gcfg = getgenv().BW_Config or getgenv().BWConfig or getgenv().Config
    if type(gcfg) == "table" then
        for k, v in pairs(gcfg) do
            if S[k] ~= nil then S[k] = v end
        end
        logAction("CONFIG", "Applied getgenv().BW_Config", Color3.fromRGB(80, 220, 140))
    end
end

-- Teleport auto-loader
local primeTeleportLoader = function()
    local q = queue_on_teleport or queueonteleport or queue_on_tp or queueontp or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not q then return false end
    local loaderPayload = [[
        repeat task.wait(0.5) until game:IsLoaded()
        local Players = game:GetService("Players")
        local LP = Players.LocalPlayer
        while not LP do task.wait(0.5); LP = Players.LocalPlayer end
        task.wait(1)
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local wf = RS:WaitForChild("WesternFramework", 10)
            local remotes = wf and wf:WaitForChild("Shared", 10) and wf.Shared:WaitForChild("Remotes", 10)
            local spawnEv = remotes and remotes:WaitForChild("SpawnPlayerEvent", 10)
            if spawnEv then spawnEv:FireServer() end
        end)
        pcall(function()
            local pg = LP:WaitForChild("PlayerGui", 10)
            local mm = pg and pg:WaitForChild("MainMenu", 8)
            local btn = mm and mm:FindFirstChild("ButtonContainer") and mm.ButtonContainer:FindFirstChild("PlayButton")
            if btn then
                local cons = getconnections and getconnections(btn.MouseButton1Click)
                if cons then for _, c in ipairs(cons) do if c.Function then pcall(c.Function) elseif c.Fire then pcall(function() c:Fire() end) end end end
            end
        end)
    ]]
    return pcall(q, loaderPayload)
end
primeTeleportLoader()
pcall(function() track(LP.OnTeleport:Connect(primeTeleportLoader)) end)

-- Discord Webhooks
local lastWebhookSend = 0
local function sendDiscordWebhook(title, desc, fields, col)
    local url = S.webhookUrl
    if not url or url == "" or not url:find("https?://") then return false end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return false end
    local embed = {
        title = title or "Bridger Monitor",
        description = desc or "",
        color = col or 0x6366F1,
        fields = fields or {},
        footer = { text = "Bridger Western v" .. VERSION .. " • " .. os.date("%X") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    local body = HttpService:JSONEncode({ username = "Bridger Monitor", embeds = { embed } })
    task.spawn(function()
        pcall(req, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
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
        { name = "💰 Moola", value = "$" .. tostring(curM), inline = true },
        { name = "🌿 Dogbane", value = tostring(dogbane), inline = true },
        { name = "🎣 Total Fish", value = tostring(fTotal), inline = true },
        { name = "🐟 Fish Breakdown", value = string.format("Bass: %d | Snapper: %d | Cod: %d", fCounts.Bass or 0, fCounts.Snapper or 0, fCounts.Cod or 0), inline = false },
        { name = "🪱 Bait & Gear", value = string.format("Bait: %d | Catches: %d | Rod: %s", bait, (FISH and FISH.catches or 0), curRod and "Yes" or "No"), inline = false },
        { name = "📍 Status", value = string.format("[%s] %s\\n%s", Status.state, Status.action, Status.detail), inline = false },
    }
    local sent = sendDiscordWebhook(reason or "📊 Inventory & Telemetry Report", "Telemetry for **" .. LP.Name .. "**", fields, 0x6366F1)
    if sent then lastWebhookSend = os.clock() end
    return sent
end


-- ============================================================
-- 3. BARITONE WEIGHTED A* NAVIGATION ENGINE
-- ============================================================
local GRID_SIZE = 3.5
local MAX_STEP_UP = 2.4
local MAX_SINGLE_JUMP = 5.2
local MAX_DOUBLE_JUMP = 8.5
local MAX_DROP_DOWN = 18.0
local VIZ_FOLDER_NAME = "_BaritoneNavVisuals"

local function getVizFolder()
    local f = WS:FindFirstChild(VIZ_FOLDER_NAME)
    if not f then
        f = Instance.new("Folder")
        f.Name = VIZ_FOLDER_NAME
        f.Parent = WS
    end
    return f
end

local function clearAllVisuals()
    local f = WS:FindFirstChild(VIZ_FOLDER_NAME)
    if f then pcall(function() f:ClearAllChildren() end) end
end

local function clearRouteVisuals()
    local f = WS:FindFirstChild(VIZ_FOLDER_NAME)
    if f then
        for _, c in ipairs(f:GetChildren()) do
            if c.Name ~= "TargetBeacon" then pcall(function() c:Destroy() end) end
        end
    end
end

local function drawTargetBeacon(targetPos)
    if not S.visualizeLegit then return end
    local f = getVizFolder()
    local beacon = f:FindFirstChild("TargetBeacon")
    if not beacon then
        beacon = Instance.new("Part")
        beacon.Name = "TargetBeacon"
        beacon.Shape = Enum.PartType.Cylinder
        beacon.Size = Vector3.new(0.4, 7, 7)
        beacon.Material = Enum.Material.Neon
        beacon.Color = Color3.fromRGB(99, 102, 241)
        beacon.Transparency = 0.4
        beacon.Anchored = true
        beacon.CanCollide = false
        beacon.CastShadow = false
        beacon.Parent = f
    end
    local floorY = groundY(targetPos) or targetPos.Y
    beacon.CFrame = CFrame.new(targetPos.X, floorY + 0.2, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
end

local function drawRouteVisuals(waypoints)
    if not S.visualizeLegit or not waypoints or #waypoints < 2 then return end
    clearRouteVisuals()
    local f = getVizFolder()
    for i = 1, #waypoints - 1 do
        local p1 = waypoints[i].pos or waypoints[i]
        local p2 = waypoints[i + 1].pos or waypoints[i + 1]
        local dist = (p2 - p1).Magnitude
        if dist > 0.1 then
            local beam = Instance.new("Part")
            beam.Name = "RouteLine"
            beam.Size = Vector3.new(0.25, 0.25, dist)
            beam.CFrame = CFrame.new(p1:Lerp(p2, 0.5), p2)
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(52, 211, 153)
            beam.Transparency = 0.35
            beam.Anchored = true
            beam.CanCollide = false
            beam.CastShadow = false
            beam.Parent = f
        end
    end
end

local function findWalkableFloor(probeOrigin, maxDrop)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char(), getVizFolder() }
    local result = WS:Raycast(probeOrigin, Vector3.new(0, -maxDrop, 0), rp)
    if result and result.Instance and result.Instance.CanCollide then
        return result.Position.Y, result.Instance
    end
    return nil, nil
end

local function checkWalkability(fromPos, toPos, fromFloorY)
    local horizDist = Vector2.new(toPos.X - fromPos.X, toPos.Z - fromPos.Z).Magnitude
    local goalFloorY, floorInst = findWalkableFloor(Vector3.new(toPos.X, fromFloorY + MAX_DOUBLE_JUMP + 1.5, toPos.Z), MAX_DROP_DOWN + MAX_DOUBLE_JUMP + 2.5)
    if not goalFloorY then return false end

    local heightDiff = goalFloorY - fromFloorY
    if heightDiff > MAX_DOUBLE_JUMP or heightDiff < -MAX_DROP_DOWN then return false end

    local jumpType = "none"
    if heightDiff > MAX_STEP_UP and heightDiff <= MAX_SINGLE_JUMP then
        jumpType = "single"
    elseif heightDiff > MAX_SINGLE_JUMP and heightDiff <= MAX_DOUBLE_JUMP then
        jumpType = "double"
    end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char(), getVizFolder() }

    local originRay = Vector3.new(fromPos.X, fromFloorY + 2.0, fromPos.Z)
    local targetRay = Vector3.new(toPos.X, goalFloorY + 2.0, toPos.Z)
    local dir = targetRay - originRay
    local bodyHit = WS:Raycast(originRay, dir, rp)

    if bodyHit and bodyHit.Instance and bodyHit.Instance.CanCollide then
        local obsHeight = bodyHit.Position.Y - fromFloorY
        if obsHeight > MAX_DOUBLE_JUMP then return false end
        jumpType = (obsHeight <= MAX_SINGLE_JUMP) and "single" or "double"
    end

    return true, jumpType, goalFloorY
end

local function smoothPath(rawWaypoints)
    if not rawWaypoints or #rawWaypoints <= 2 then return rawWaypoints end
    local smoothed = { rawWaypoints[1] }
    local i = 1
    while i < #rawWaypoints do
        local furthest = i + 1
        for j = #rawWaypoints, i + 2, -1 do
            local wpA = rawWaypoints[i]
            local wpB = rawWaypoints[j]
            local dist = (wpB.pos - wpA.pos).Magnitude
            if dist <= 35 then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { char(), getVizFolder() }
                local hit = WS:Raycast(wpA.pos + Vector3.new(0, 2, 0), (wpB.pos - wpA.pos), rp)
                if not hit or not hit.Instance or not hit.Instance.CanCollide then
                    furthest = j
                    break
                end
            end
        end
        table.insert(smoothed, rawWaypoints[furthest])
        i = furthest
    end
    return smoothed
end

local function aStarSearch(startPos, goalPos)
    local startFloorY = groundY(startPos) or startPos.Y
    local goalFloorY = groundY(goalPos) or goalPos.Y
    local directDist = (goalPos - startPos).Magnitude

    if directDist < 25 then
        local ok, jType = checkWalkability(startPos, goalPos, startFloorY)
        if ok then
            return { { pos = startPos, floorY = startFloorY }, { pos = goalPos, floorY = goalFloorY, jumpType = jType } }, true
        end
    end

    local function toGrid(v, y)
        return math.floor(v.X / GRID_SIZE + 0.5), math.floor(y / 2.0 + 0.5), math.floor(v.Z / GRID_SIZE + 0.5)
    end
    local function nodeKey(gx, gy, gz) return string.format("%d,%d,%d", gx, gy, gz) end

    local sgx, sgy, sgz = toGrid(startPos, startFloorY)
    local ggx, ggy, ggz = toGrid(goalPos, goalFloorY)
    local startKey = nodeKey(sgx, sgy, sgz)

    local openSet = { [startKey] = { gx = sgx, gy = sgy, gz = sgz, pos = startPos, floorY = startFloorY, g = 0, f = directDist } }
    local closedSet = {}
    local cameFrom = {}
    local jumpReq = {}
    local iterations = 0

    local DIRS = {
        { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
        { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 }
    }

    while next(openSet) and iterations < 450 do
        iterations = iterations + 1
        local bestKey, curr = nil, nil
        for k, node in pairs(openSet) do
            if not curr or node.f < curr.f then bestKey, curr = k, node end
        end
        openSet[bestKey] = nil
        closedSet[bestKey] = true

        local distToGoal = (Vector2.new(curr.pos.X, curr.pos.Z) - Vector2.new(goalPos.X, goalPos.Z)).Magnitude
        if distToGoal < GRID_SIZE * 1.5 then
            local path = { { pos = goalPos, floorY = goalFloorY, jumpType = "none" } }
            local traceKey = bestKey
            while cameFrom[traceKey] do
                local parent = cameFrom[traceKey]
                table.insert(path, 1, { pos = parent.pos, floorY = parent.floorY, jumpType = jumpReq[traceKey] or "none" })
                traceKey = nodeKey(parent.gx, parent.gy, parent.gz)
            end
            return smoothPath(path), true
        end

        for _, d in ipairs(DIRS) do
            local ngx, ngz = curr.gx + d[1], curr.gz + d[2]
            local candWorldX = ngx * GRID_SIZE
            local candWorldZ = ngz * GRID_SIZE
            local okWalk, jType, nextFloorY = checkWalkability(curr.pos, Vector3.new(candWorldX, curr.floorY, candWorldZ), curr.floorY)
            if okWalk and nextFloorY then
                local ngy = math.floor(nextFloorY / 2.0 + 0.5)
                local nKey = nodeKey(ngx, ngy, ngz)
                if not closedSet[nKey] then
                    local stepCost = (d[1] ~= 0 and d[2] ~= 0) and (GRID_SIZE * 1.414) or GRID_SIZE
                    local jumpPenalty = (jType == "double" and 4.0) or (jType == "single" and 1.5) or 0
                    local tentG = curr.g + stepCost + jumpPenalty
                    local existing = openSet[nKey]
                    if not existing or tentG < existing.g then
                        cameFrom[nKey] = curr
                        jumpReq[nKey] = jType
                        local hDist = (Vector2.new(candWorldX, candWorldZ) - Vector2.new(goalPos.X, goalPos.Z)).Magnitude
                        openSet[nKey] = {
                            gx = ngx, gy = ngy, gz = ngz,
                            pos = Vector3.new(candWorldX, nextFloorY, candWorldZ),
                            floorY = nextFloorY,
                            g = tentG,
                            f = tentG + hDist
                        }
                    end
                end
            end
        end
    end

    return { { pos = startPos, floorY = startFloorY }, { pos = goalPos, floorY = goalFloorY, jumpType = "single" } }, false
end

-- Jump Climb Controller
local function executeJumpClimb(targetPos, requiredY, isDouble, token, nav)
    local r = root()
    local h = hum()
    if not r or not h or h.Health <= 0 then return false end
    h:Move(Vector3.zero, false)
    local start = os.clock()
    local cleared = false
    while (os.clock() - start < 3.2) and (nav.token == token) do
        r = root()
        h = hum()
        if not r or not h or h.Health <= 0 then break end
        if (r.Position.Y - 2.2) >= requiredY - 0.3 then cleared = true; break end
        h:Move(Vector3.zero, false)
        tapSpace()
        if isDouble then task.wait(0.20); tapSpace(); task.wait(0.45) else task.wait(0.65) end
    end
    if cleared and nav.token == token then
        local push = os.clock()
        while (os.clock() - push < 0.40) and (nav.token == token) do
            r = root()
            h = hum()
            if not r or not h or h.Health <= 0 then break end
            h:MoveTo(targetPos)
            task.wait(0.05)
        end
    end
    return cleared
end

-- Public Navigation Controller
local NAV = {
    token = 0,
    isWalking = false,
    tapSpace = tapSpace,
    drawBeacon = drawTargetBeacon,
    clearVisuals = clearAllVisuals,
}

function NAV.cancel()
    NAV.token = NAV.token + 1
    NAV.isWalking = false
    clearAllVisuals()
    local h = hum()
    if h then
        pcall(function()
            h:Move(Vector3.zero, false)
            h.WalkSpeed = 16
            h.Jump = false
        end)
    end
    releaseAllKeys()
end

function NAV.walkTo(targetPos, options)
    if not targetPos then return false end
    local opt = options or {}
    local timeout = opt.timeout or 120
    local completionDist = opt.completionDist or 4.0
    local r = root()
    local h = hum()
    if not r or not h or h.Health <= 0 then return false end

    NAV.cancel()
    NAV.token = NAV.token + 1
    local myToken = NAV.token
    NAV.isWalking = true

    drawTargetBeacon(targetPos)
    local waypoints, solved = aStarSearch(r.Position, targetPos)
    if not waypoints or #waypoints == 0 then NAV.cancel(); return false end
    drawRouteVisuals(waypoints)

    local startT = os.clock()
    local wpIdx = 2
    if #waypoints == 1 then wpIdx = 1 end

    local sprintSpeed = opt.sprintSpeed or 24
    if keypressFn and sprintSpeed > 16 then pcall(keypressFn, 0x10) end

    local success = false
    while (os.clock() - startT < timeout) and (NAV.token == myToken) do
        r = root()
        h = hum()
        if not r or not h or h.Health <= 0 then break end
        local distFinal = (r.Position - targetPos).Magnitude
        if distFinal <= completionDist then success = true; break end
        if wpIdx > #waypoints then success = (distFinal <= completionDist * 1.5); break end

        local targetWp = waypoints[wpIdx]
        local wpPos = targetWp.pos or targetWp
        local wpDist = (r.Position - wpPos).Magnitude

        if targetWp.jumpType and targetWp.jumpType ~= "none" and wpDist < 6.0 then
            executeJumpClimb(wpPos, targetWp.floorY or wpPos.Y, targetWp.jumpType == "double", myToken, NAV)
            wpIdx = wpIdx + 1
        else
            h:MoveTo(wpPos)
            if wpDist < 3.8 then wpIdx = wpIdx + 1 end
        end
        task.wait(0.04)
    end

    releaseAllKeys()
    local hFinal = hum()
    if hFinal then
        hFinal:Move(Vector3.zero, false)
        hFinal.WalkSpeed = 16
        hFinal.Jump = false
    end
    if NAV.token == myToken then
        NAV.isWalking = false
        clearAllVisuals()
    end
    return success
end


-- ============================================================
-- 4. MOVEMENT, HORSE TRAVEL & GHOST FAKE FLY
-- ============================================================
local function myHorse()
    local f = WS:FindFirstChild("Entities")
    if not f then return nil end
    for _, e in ipairs(f:GetChildren()) do
        local o = e:FindFirstChild("Owner")
        if o and (o.Value == LP or o.Value == LP.Name or tostring(o.Value) == tostring(LP.UserId)) then return e end
        local attr = e:GetAttribute("Owner") or e:GetAttribute("OwnerUserId") or e:GetAttribute("OwnerName")
        if attr and (attr == LP.Name or attr == LP.UserId or tostring(attr) == tostring(LP.UserId)) then return e end
    end
    return nil
end

local function horseRoot()
    local h = myHorse()
    return h and h:FindFirstChild("HumanoidRootPart"), h
end

local function isMounted(h)
    local c = char()
    local hm = hum()
    if not c or not hm then return false end
    if hm.Sit then return true end
    h = h or myHorse()
    if not h then return false end
    for _, d in ipairs(c:GetDescendants()) do
        if (d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")) and ((d.Part0 and d.Part0:IsDescendantOf(h)) or (d.Part1 and d.Part1:IsDescendantOf(h))) then
            return true
        end
    end
    return false
end

local function summonHorse(timeout)
    local r = root()
    local h = myHorse()
    local hp = h and h:FindFirstChild("HumanoidRootPart")
    if h and hp and r and (hp.Position - r.Position).Magnitude <= 25 then return h end

    logAction("HORSE", "Calling horse via whistle...", Color3.fromRGB(245, 175, 60))
    pcall(function()
        local hc = require(ReplicatedStorage.Modules.HorseController)
        local uvs = debug.getupvalues(hc.Init)
        for _, uv in pairs(uvs) do
            if typeof(uv) == "table" and typeof(rawget(uv, "FireServer")) == "function" then
                uv:FireServer()
                break
            end
        end
    end)
    tap("HorseCallInput", 0.15)

    local t0 = os.clock()
    local maxWait = timeout or 8
    while os.clock() - t0 < maxWait do
        h = myHorse()
        hp = h and h:FindFirstChild("HumanoidRootPart")
        r = root()
        if h and hp and r and (hp.Position - r.Position).Magnitude <= 35 then return h end
        task.wait(0.3)
    end
    return myHorse()
end

local function mountHorse()
    local h = myHorse() or summonHorse(6)
    if not h then return false end
    if isMounted(h) then return true end

    local hp = h:FindFirstChild("HumanoidRootPart")
    local r = root()
    if hp and r and (hp.Position - r.Position).Magnitude > 18 then
        r.CFrame = hp.CFrame * CFrame.new(0, 2, -3)
        task.wait(0.2)
    end

    for _ = 1, 8 do
        if isMounted(h) then return true end
        tap("ActionInput2", 0.15)
        for _, d in ipairs(h:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText:lower():find("ride") then
                pcall(firepp, d, 0)
            end
        end
        task.wait(0.25)
    end
    return isMounted(h)
end

local function dismount()
    logAction("HORSE", "Dismounting horse...", Color3.fromRGB(160, 165, 180))
    local hm = hum()
    local hObj = myHorse()
    local c = char()

    for _ = 1, 6 do
        if not isMounted(hObj) and not (hm and hm.Sit) then break end
        tap("HorseDismountInput", 0.15)
        tap("ActionInput2", 0.15)
        tapSpace()

        pcall(function()
            if keyclickFn then keyclickFn(0x45)
            elseif keypressFn and keyreleaseFn then
                keypressFn(0x45); task.wait(0.035); keyreleaseFn(0x45)
            end
            if keyreleaseFn then keyreleaseFn(0x45) end
        end)

        if hObj and firepp then
            for _, d in ipairs(hObj:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then pcall(firepp, d, 0) end
            end
        end

        if c and hObj then
            for _, d in ipairs(c:GetDescendants()) do
                if (d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")) and ((d.Part0 and d.Part0:IsDescendantOf(hObj)) or (d.Part1 and d.Part1:IsDescendantOf(hObj))) then
                    pcall(function() d:Destroy() end)
                end
            end
            for _, d in ipairs(hObj:GetDescendants()) do
                if (d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")) and ((d.Part0 and d.Part0:IsDescendantOf(c)) or (d.Part1 and d.Part1:IsDescendantOf(c))) then
                    pcall(function() d:Destroy() end)
                end
            end
        end

        if hm then
            if hm.SeatPart then
                for _, ch in ipairs(hm.SeatPart:GetChildren()) do
                    if ch:IsA("Weld") or ch:IsA("WeldConstraint") or ch.Name == "SeatWeld" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
            hm.Sit = false
            hm.Jump = false
            pcall(function() hm:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        task.wait(0.20)
    end

    releaseAllKeys()
    local hCleanup = hum()
    if hCleanup then
        hCleanup.Sit = false
        hCleanup.Jump = false
        pcall(function() hCleanup:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    task.wait(0.15)
end

local function horseTeleport(dest)
    if not dest then return false end
    if typeof(dest) == "CFrame" then dest = dest.Position end
    local r = root()
    if not r then return false end
    if (r.Position - dest).Magnitude < 15 then return true end

    local distInitial = math.floor((r.Position - dest).Magnitude)
    logAction("TRAVEL", ("Initiating horse travel (%d studs)..."):format(distInitial), Color3.fromRGB(90, 180, 255))

    local mounted = false
    local hp, hObj
    for _ = 1, 3 do
        mounted = mountHorse()
        hp, hObj = horseRoot()
        if mounted and hp and hp.Parent and isMounted(hObj) then break end
        task.wait(0.5)
    end

    if not mounted or not hp or not hp.Parent or not isMounted(hObj) then
        logAction("TRAVEL", "Cannot travel: horse not mounted", Color3.fromRGB(245, 90, 90))
        return false
    end

    local t = dest
    local rpTele = RaycastParams.new()
    rpTele.FilterType = Enum.RaycastFilterType.Exclude
    rpTele.FilterDescendantsInstances = { char(), hObj }
    local hit = WS:Raycast(dest + Vector3.new(0, 8, 0), Vector3.new(0, -25, 0), rpTele)
    if hit and hit.Material ~= Enum.Material.Water then
        t = Vector3.new(dest.X, hit.Position.Y + 3.0, dest.Z)
    else
        local g = groundY(dest, hObj)
        if g and math.abs(g - dest.Y) < 20 then t = Vector3.new(dest.X, g + 3.0, dest.Z) end
    end

    for _ = 1, 15 do
        local rr = root()
        if hp and hp.Parent then hp.CFrame = CFrame.new(t); hp.AssemblyLinearVelocity = Vector3.zero end
        if rr then rr.CFrame = CFrame.new(t + Vector3.new(0, 2.0, 0)); rr.AssemblyLinearVelocity = Vector3.zero end
        RunService.Heartbeat:Wait()
    end
    task.wait(0.4)
    local rr = root()
    local offset = rr and math.floor((rr.Position - dest).Magnitude) or 999
    if rr and offset < 45 then
        logAction("TRAVEL", ("Arrived at destination (%d studs off)"):format(offset), Color3.fromRGB(80, 220, 140))
        return true
    end
    logAction("TRAVEL", "Horse travel failed to reach destination", Color3.fromRGB(245, 90, 90))
    return false
end

local function landBeside(pos, offset)
    dismount()
    task.wait(0.3)
    local r = root()
    if not r then return false end
    if typeof(pos) == "CFrame" then pos = pos.Position end
    offset = offset or 5

    local best
    for _, dir in ipairs({ Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1) }) do
        local cand = pos + dir * offset
        local g = groundY(cand)
        if g and math.abs(g - pos.Y) < 12 then best = Vector3.new(cand.X, g + 3.5, cand.Z); break end
    end
    if not best then
        local g = groundY(pos) or pos.Y
        best = Vector3.new(pos.X, g + 3.5, pos.Z)
    end

    for _ = 1, 10 do
        local rr = root()
        if rr then rr.CFrame = CFrame.new(best); rr.AssemblyLinearVelocity = Vector3.zero end
        RunService.Heartbeat:Wait()
    end
    local hm = hum()
    if hm then
        hm.Jump = false
        pcall(function() hm:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    releaseAllKeys()
    task.wait(0.3)
    return true
end

-- Fake Horse Fly (Ghost Desync Flight)
local fakeFly = {
    active = false,
    ghostModel = nil,
    landingCircle = nil,
    savedTransparency = {},
    conn = nil,
    inputBeganConn = nil,
    inputEndedConn = nil,
    inputConn = nil,
}

local function getPlayerControls()
    local ps = LP and LP:FindFirstChild("PlayerScripts")
    local pm = ps and ps:FindFirstChild("PlayerModule")
    if pm then
        local ok, mod = pcall(require, pm)
        if ok and mod and mod.GetControls then return mod:GetControls() end
    end
    return nil
end

local function cleanupFakeFlyVisuals()
    if fakeFly.conn then pcall(function() fakeFly.conn:Disconnect() end); fakeFly.conn = nil end
    if fakeFly.inputBeganConn then pcall(function() fakeFly.inputBeganConn:Disconnect() end); fakeFly.inputBeganConn = nil end
    if fakeFly.inputEndedConn then pcall(function() fakeFly.inputEndedConn:Disconnect() end); fakeFly.inputEndedConn = nil end
    if fakeFly.inputConn then pcall(function() fakeFly.inputConn:Disconnect() end); fakeFly.inputConn = nil end

    pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    if fakeFly.landingCircle then pcall(function() fakeFly.landingCircle:Destroy() end); fakeFly.landingCircle = nil end
    if fakeFly.ghostModel then pcall(function() fakeFly.ghostModel:Destroy() end); fakeFly.ghostModel = nil end

    for part, trans in pairs(fakeFly.savedTransparency) do
        if part and part.Parent then pcall(function() part.Transparency = trans end) end
    end
    table.clear(fakeFly.savedTransparency)

    local ctrl = getPlayerControls()
    if ctrl then pcall(function() ctrl:Enable() end) end

    local cam = WS.CurrentCamera
    local hm = hum()
    if cam and hm then
        pcall(function() cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = hm end)
    end
end

local function stopFakeHorseFly(teleportToFloor)
    if not fakeFly.active then return end
    fakeFly.active = false
    S.fakeHorseFly = false

    local landingPos = nil
    if fakeFly.ghostModel and fakeFly.ghostModel.PrimaryPart then
        landingPos = fakeFly.ghostModel.PrimaryPart.Position
    end

    cleanupFakeFlyVisuals()

    if teleportToFloor and landingPos then
        local floorY = groundY(landingPos, char())
        if floorY then
            local dest = Vector3.new(landingPos.X, floorY, landingPos.Z)
            logAction("TRAVEL", ("Landing Horsefly to floor (%.0f, %.0f, %.0f)..."):format(dest.X, dest.Y, dest.Z), Color3.fromRGB(80, 220, 140))
            task.spawn(function() horseTeleport(dest) end)
        end
    end
    if UI and UI.updateToggles then pcall(UI.updateToggles) end
end

local function startFakeHorseFly()
    if fakeFly.active then return end
    local c = char()
    local r = root()
    local hm = hum()
    local h = myHorse()
    if not c or not r or not hm then S.fakeHorseFly = false; return end

    if not h or not isMounted(h) then
        if not mountHorse() then S.fakeHorseFly = false; return end
        h = myHorse()
    end
    local hp = h and h:FindFirstChild("HumanoidRootPart")
    if not hp then S.fakeHorseFly = false; return end

    fakeFly.active = true
    logAction("TRAVEL", "Horsefly ACTIVE (RMB orbit, WASD fly, Space Up, Shift Down)", Color3.fromRGB(80, 220, 140))

    table.clear(fakeFly.savedTransparency)
    for _, inst in ipairs({ c, h }) do
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                fakeFly.savedTransparency[d] = d.Transparency
                d.Transparency = math.max(0.65, d.Transparency)
            end
        end
    end

    local ctrl = getPlayerControls()
    if ctrl then pcall(function() ctrl:Disable() end) end

    local ghostModel = Instance.new("Model")
    ghostModel.Name = "GhostHorseFlight"
    local ghostRoot = Instance.new("Part")
    ghostRoot.Name = "GhostRoot"
    ghostRoot.Size = Vector3.new(2, 2, 2)
    ghostRoot.Transparency = 1
    ghostRoot.CanCollide = false
    ghostRoot.Anchored = true
    ghostRoot.CFrame = hp.CFrame
    ghostRoot.Parent = ghostModel
    ghostModel.PrimaryPart = ghostRoot

    c.Archivable = true
    local cClone = c:Clone()
    cClone.Name = "VisualRider"
    for _, d in ipairs(cClone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.Anchored = true
            d.Transparency = (d.Name == "HumanoidRootPart") and 1 or 0
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
            d:Destroy()
        end
    end
    cClone.Parent = ghostModel

    h.Archivable = true
    local hClone = h:Clone()
    hClone.Name = "VisualHorse"
    for _, d in ipairs(hClone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.Anchored = true
            d.Transparency = (d.Name == "HumanoidRootPart") and 1 or 0
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
            d:Destroy()
        end
    end
    hClone.Parent = ghostModel

    local cam = WS.CurrentCamera
    ghostModel.Parent = cam or WS
    fakeFly.ghostModel = ghostModel

    local landingCircle = Instance.new("Part")
    landingCircle.Name = "HorseflyLandingCircle"
    landingCircle.Shape = Enum.PartType.Cylinder
    landingCircle.Size = Vector3.new(0.08, 6.5, 6.5)
    landingCircle.Color = Color3.fromRGB(52, 211, 153)
    landingCircle.Material = Enum.Material.Neon
    landingCircle.Transparency = 1
    landingCircle.CanCollide = false
    landingCircle.Anchored = true
    landingCircle.Parent = cam or WS
    fakeFly.landingCircle = landingCircle

    local circleParams = RaycastParams.new()
    circleParams.FilterType = Enum.RaycastFilterType.Exclude
    circleParams.FilterDescendantsInstances = { c, h, ghostModel, landingCircle, cam }

    local curCF = hp.CFrame
    local yaw = 0
    local pitch = 0
    local camDist = 14

    if cam then
        local rx, ry, _ = cam.CFrame:ToEulerAnglesYXZ()
        yaw = ry
        pitch = math.clamp(rx, -1.2, 1.2)
        cam.CameraType = Enum.CameraType.Scriptable
    end

    fakeFly.inputBeganConn = UIS.InputBegan:Connect(function(input)
        if not fakeFly.active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end)
    fakeFly.inputEndedConn = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end)
    fakeFly.inputConn = UIS.InputChanged:Connect(function(input)
        if not fakeFly.active then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            camDist = math.clamp(camDist - input.Position.Z * 2.5, 4, 40)
        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
                yaw = yaw - input.Delta.X * 0.0035
                pitch = math.clamp(pitch - input.Delta.Y * 0.0035, -1.35, 1.35)
            end
        end
    end)

    fakeFly.conn = RunService.RenderStepped:Connect(function(dt)
        if not fakeFly.active or not S.fakeHorseFly then cleanupFakeFlyVisuals(); return end
        local cNow = char()
        local hmNow = hum()
        if not cNow or not hmNow or hmNow.Health <= 0 then stopFakeHorseFly(false); return end
        local curCam = WS.CurrentCamera
        if not curCam then return end

        local rotCF = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        local camOffset = rotCF:PointToWorldSpace(Vector3.new(0, 3, camDist))
        local camCF = CFrame.lookAt(curCF.Position + camOffset, curCF.Position + Vector3.new(0, 2, 0))
        curCam.CFrame = camCF

        local moveDir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.yAxis end

        local speed = S.fakeFlySpeed or 75
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            curCF = curCF + moveDir * (speed * dt)
            local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            if flatDir.Magnitude > 0.05 then
                curCF = CFrame.new(curCF.Position, curCF.Position + flatDir.Unit)
            end
        end

        if fakeFly.ghostModel and fakeFly.ghostModel.PrimaryPart then
            fakeFly.ghostModel:PivotTo(curCF)
        end

        if fakeFly.landingCircle then
            local rayResult = WS:Raycast(curCF.Position, Vector3.new(0, -3000, 0), circleParams)
            if rayResult then
                local norm = rayResult.Normal
                local ref = math.abs(norm.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis
                local right = norm:Cross(ref).Unit
                local forward = norm:Cross(right).Unit
                fakeFly.landingCircle.CFrame = CFrame.fromMatrix(rayResult.Position + norm * 0.06, norm, right, forward)
                fakeFly.landingCircle.Transparency = 0.45
            else
                fakeFly.landingCircle.Transparency = 1
            end
        end
    end)
end


-- ============================================================
-- 5. COMBAT, SILENT AIM & BALLISTICS PREDICTION ENGINE
-- ============================================================
COMBAT = {
    hooked = false,
    currentTarget = nil,
    targetStatus = "None",
    u62Table = nil,
    iHateYouRunning = false,
    iHateYouTarget = nil,
    currentVantagePos = nil,
    targetHistory = {},
}

function COMBAT.getEffectiveVelocity(targetChar, targetPart)
    if not targetChar then return Vector3.zero end
    local vel = Vector3.zero
    local tHum = targetChar:FindFirstChildOfClass("Humanoid")
    local tHorse = tHum and tHum.SeatPart and tHum.SeatPart.Parent
    local hRoot = tHorse and tHorse:FindFirstChild("HumanoidRootPart")

    if hRoot and hRoot.AssemblyLinearVelocity.Magnitude > 1 then
        vel = hRoot.AssemblyLinearVelocity
    elseif targetPart and targetPart.AssemblyLinearVelocity.Magnitude > 1 then
        vel = targetPart.AssemblyLinearVelocity
    end

    if tHum and tHum.MoveDirection.Magnitude > 0.05 then
        local moveVel = tHum.MoveDirection * (tHum.WalkSpeed or 16)
        if vel.Magnitude < 2 then
            vel = Vector3.new(moveVel.X, vel.Y, moveVel.Z)
        else
            local horizVel = Vector3.new(vel.X, 0, vel.Z)
            if horizVel.Magnitude < (tHum.WalkSpeed or 16) * 0.7 then
                vel = Vector3.new(moveVel.X, vel.Y, moveVel.Z)
            end
        end
    end
    return vel
end

function COMBAT.recordTargetState(targetChar, targetPart)
    if not targetChar or not targetPart then return end
    local now = tick()
    local hist = COMBAT.targetHistory[targetChar]
    if not hist then
        hist = { samples = {}, lastSampleTime = 0 }
        COMBAT.targetHistory[targetChar] = hist
    end
    if now - hist.lastSampleTime < 0.033 then return end
    hist.lastSampleTime = now

    local vel = COMBAT.getEffectiveVelocity(targetChar, targetPart)
    local h = targetChar:FindFirstChildOfClass("Humanoid")
    local state = h and h:GetState() or Enum.HumanoidStateType.Running
    table.insert(hist.samples, { time = now, pos = targetPart.Position, vel = vel, state = state })
    if #hist.samples > 30 then table.remove(hist.samples, 1) end
end

function COMBAT.analyzeMotionProfile(targetChar, targetPart)
    local hist = COMBAT.targetHistory[targetChar]
    local prof = { mode = "Normal", confidence = 0.5, apexProb = 0, turnProb = 0, driftProb = 0, dampFactor = 1.0, vertDampFactor = 1.0 }
    if not hist or #hist.samples < 3 then return prof end

    local s = hist.samples
    local latest = s[#s]
    local currentVel = latest.vel
    local state = latest.state

    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        local apexWeight = 1.0 - math.clamp(math.abs(currentVel.Y) / 18, 0, 1.0)
        prof.apexProb = apexWeight
        if apexWeight > 0.65 then
            prof.mode = "Jump Apex (Peak)"
            prof.confidence = 0.75 + (apexWeight * 0.2)
            prof.vertDampFactor = 0.25
            prof.dampFactor = 0.70
        else
            prof.mode = currentVel.Y > 0 and "Jumping Up" or "Falling Down"
            prof.confidence = 0.60
            prof.vertDampFactor = 0.85
        end
        return prof
    end

    local hVelCurrent = Vector2.new(currentVel.X, currentVel.Z)
    if hVelCurrent.Magnitude > 1.5 and #s >= 4 then
        local older = s[math.max(1, #s - 3)]
        local hVelOlder = Vector2.new(older.vel.X, older.vel.Z)
        if hVelOlder.Magnitude > 1.5 then
            local dot = (hVelCurrent.Unit:Dot(hVelOlder.Unit))
            local headingDelta = math.deg(math.acos(math.clamp(dot, -1, 1)))
            if headingDelta > 28 then
                prof.turnProb = math.clamp(headingDelta / 90, 0, 1)
                prof.mode = "Turning Arc"
                prof.confidence = 0.55
                prof.dampFactor = 0.55
                return prof
            end
        end
    end

    if hVelCurrent.Magnitude < 2.0 then
        prof.mode = "Stationary / Micro"
        prof.confidence = 0.88
        prof.dampFactor = 0.35
    else
        prof.mode = "Linear Drift"
        prof.confidence = 0.72
        prof.dampFactor = 0.95
    end
    return prof
end

function COMBAT.getShooterSpeed()
    local r = root()
    return r and r.AssemblyLinearVelocity.Magnitude or 0
end

function COMBAT.getMuzzlePosition()
    local c = char()
    if not c then return nil end
    local gun = c:FindFirstChildOfClass("Tool")
    if gun then
        local muzzle = gun:FindFirstChild("Muzzle") or gun:FindFirstChild("Barrel") or gun:FindFirstChild("Tip") or gun:FindFirstChild("Handle")
        if muzzle and muzzle:IsA("BasePart") then return muzzle.Position end
    end
    local head = c:FindFirstChild("Head")
    return head and (head.Position + Vector3.new(0, 0.2, 0)) or (root() and root().Position)
end

function COMBAT.calculateTrajectory(targetChar, targetPart)
    if not targetChar or not targetPart then return nil end
    local muzzlePos = COMBAT.getMuzzlePosition()
    local r = root()
    local originPos = muzzlePos or (r and r.Position)
    if not originPos then return nil end

    local targetPos = targetPart.Position
    local targetVel = COMBAT.getEffectiveVelocity(targetChar, targetPart)
    local bulletSpeed = 900
    local gravityVal = 196.2

    local bulletMod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("CoreGunClientModule")
    if bulletMod then
        pcall(function()
            local bm = require(bulletMod)
            if bm and bm.CurrentWeapon and bm.CurrentWeapon.Config then
                local cfg = bm.CurrentWeapon.Config
                bulletSpeed = tonumber(cfg.BulletSpeed or cfg.Speed or cfg.MuzzleVelocity) or bulletSpeed
                gravityVal = tonumber(cfg.BulletGravity or cfg.Gravity) or gravityVal
            end
        end)
    end
    if S.martiniBallistics then bulletSpeed = math.max(bulletSpeed, 1400) end

    local ping = 0.05
    pcall(function() ping = math.clamp(Players.LocalPlayer:GetNetworkPing(), 0.02, 0.35) end)

    local directDist = (targetPos - originPos).Magnitude
    local tFlight = directDist / bulletSpeed
    local totalLeadTime = tFlight + ping

    local prof = COMBAT.analyzeMotionProfile(targetChar, targetPart)
    local effVel = targetVel
    if S.humanPredictor then
        effVel = Vector3.new(targetVel.X * prof.dampFactor, targetVel.Y * prof.vertDampFactor, targetVel.Z * prof.dampFactor)
    end

    local leadOffset = effVel * totalLeadTime
    local predictedPos = targetPos + leadOffset
    local dropCompY = 0

    if S.martiniBallistics or directDist > 75 then
        dropCompY = 0.5 * gravityVal * (tFlight * tFlight)
        if S.martiniBallistics and directDist > 400 then dropCompY = dropCompY * 1.12 end
        predictedPos = predictedPos + Vector3.new(0, dropCompY, 0)
    end

    return predictedPos, tFlight, dropCompY, ping
end

function COMBAT.hasLineOfSight(fromPos, toPos, ignoreModel)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char(), ignoreModel }
    rp.IgnoreWater = true
    local dir = toPos - fromPos
    local hit = WS:Raycast(fromPos, dir, rp)
    return not hit or not hit.Instance or not hit.Instance.CanCollide
end

function COMBAT.getTarget()
    local myRoot = root()
    if not myRoot then return nil, nil, "NoRoot" end
    local cam = WS.CurrentCamera
    local mousePos = UIS:GetMouseLocation()

    local bestChar, bestPart = nil, nil
    local bestMetric = math.huge
    local targetMode = S.aimTargetMode or "Closest to Cursor"
    local hitboxName = S.aimHitbox or "Head"

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tChar = p.Character
            local tHum = tChar:FindFirstChildOfClass("Humanoid")
            local tRoot = tChar:FindFirstChild("HumanoidRootPart")

            if tHum and tHum.Health > 0 and tRoot then
                local isFriend = false
                if S.aimIgnoreFriends then
                    pcall(function() isFriend = LP:IsFriendsWith(p.UserId) end)
                    if not isFriend and S.customFriends and S.customFriends ~= "" then
                        for fName in S.customFriends:gmatch("[^,]+") do
                            if p.Name:lower() == fName:match("^%s*(.-)%s*$"):lower() then isFriend = true; break end
                        end
                    end
                end

                if not isFriend then
                    local tPart = tChar:FindFirstChild(hitboxName) or tRoot
                    local pos = tPart.Position
                    local dist = (myRoot.Position - pos).Magnitude

                    if dist <= (S.martiniBallistics and 5000 or 1200) then
                        local hasLOS = COMBAT.hasLineOfSight(myRoot.Position + Vector3.new(0, 2, 0), pos, tChar)
                        if hasLOS or S.shootOverRocks then
                            if targetMode == "Closest to Cursor" and cam then
                                local scrPos, onScreen = cam:WorldToViewportPoint(pos)
                                if onScreen then
                                    local screenDist = (Vector2.new(scrPos.X, scrPos.Y) - mousePos).Magnitude
                                    if screenDist < bestMetric then bestMetric = screenDist; bestChar = tChar; bestPart = tPart end
                                end
                            elseif targetMode == "Lowest Health" then
                                if tHum.Health < bestMetric then bestMetric = tHum.Health; bestChar = tChar; bestPart = tPart end
                            elseif targetMode == "Lowest Distance" then
                                if dist < bestMetric then bestMetric = dist; bestChar = tChar; bestPart = tPart end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestChar and bestPart then return bestChar, bestPart, "Valid" end
    return nil, nil, "NoTarget"
end

function COMBAT.ensureHook()
    if COMBAT.hooked and COMBAT.u62Table then return true end
    local equipFn
    local okMod, gunMod = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("CoreGunClientModule", 3))
    end)
    if okMod and typeof(gunMod) == "table" and typeof(gunMod.Equip) == "function" then
        equipFn = gunMod.Equip
    end
    if not equipFn then return false end

    local getupvaluesFn = getupvalues or (debug and debug.getupvalues)
    local uvs = getupvaluesFn and getupvaluesFn(equipFn)
    if uvs then
        for _, uv in pairs(uvs) do
            if typeof(uv) == "table" and typeof(rawget(uv, "FireServer")) == "function" then
                COMBAT.u62Table = uv
                local oldFire = uv.FireServer
                local hookFunc = function(self, action, targetPos, isAiming, ...)
                    if action == "Fire" and (S.silentAim or S.iHateYou) then
                        local tChar, tPart, status = COMBAT.getTarget()
                        if S.iHateYou and COMBAT.iHateYouTarget and COMBAT.iHateYouTarget.Parent then
                            tChar = COMBAT.iHateYouTarget
                            tPart = tChar:FindFirstChild(S.aimHitbox or "Head") or tChar:FindFirstChild("HumanoidRootPart")
                            status = tPart and "Valid" or "NoPart"
                        end
                        if status == "Valid" and tPart then
                            if S.onlyFireAtLowSpeeds then
                                local maxSpd = S.maxFiringSpeed or 25
                                if COMBAT.getShooterSpeed() > maxSpd then return end
                            end
                            local predPos = COMBAT.calculateTrajectory(tChar, tPart)
                            if predPos then targetPos = predPos end
                            if S.martiniBallistics then isAiming = true end
                        end
                    end
                    return oldFire(self, action, targetPos, isAiming, ...)
                end
                rawset(uv, "FireServer", hookFunc)
                COMBAT.hooked = true
                logAction("COMBAT", "Silent Aim hooked into CoreGunClientModule", Color3.fromRGB(80, 220, 140))
                return true
            end
        end
    end
    return false
end

-- I Hate You (Stalking & Silent Auto-Spam)
function COMBAT.startIHateYou()
    if COMBAT.iHateYouRunning then return end
    COMBAT.iHateYouRunning = true
    logAction("COMBAT", "I Hate You ACTIVE: Stalking nearest player...", Color3.fromRGB(245, 90, 90))

    task.spawn(function()
        while COMBAT.iHateYouRunning and S.iHateYou do
            local tChar = COMBAT.getTarget()
            COMBAT.iHateYouTarget = tChar
            if tChar and tChar.Parent then
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                local r = root()
                if tRoot and r then
                    if isMounted() then
                        dismount()
                        task.wait(0.2)
                    end
                    if not isMounted() then
                        local behindOffset = -tRoot.CFrame.LookVector * (S.iHateYouDistance or 190) + Vector3.new(0, 35, 0)
                        local vantagePos = tRoot.Position + behindOffset
                        if S.martiniVantage then
                            local highPos = groundY(vantagePos)
                            if highPos then vantagePos = Vector3.new(vantagePos.X, math.max(vantagePos.Y, highPos + 25), vantagePos.Z) end
                        end
                        r.CFrame = CFrame.new(vantagePos, tRoot.Position)
                        r.AssemblyLinearVelocity = Vector3.zero

                        -- Auto-fire trigger: verify firearm tool is equipped before firing
                        local curChar = char()
                        local curTool = curChar and curChar:FindFirstChildOfClass("Tool")
                        if not curTool then
                            local bp = LP and LP:FindFirstChildOfClass("Backpack")
                            local hm = hum()
                            if bp and hm then
                                for _, t in ipairs(bp:GetChildren()) do
                                    if t:IsA("Tool") and (t:FindFirstChild("GunScript") or t:FindFirstChild("Config") or t.Name:lower():find("gun") or t.Name:lower():find("rifle") or t.Name:lower():find("revolver") or t.Name:lower():find("pistol")) then
                                        hm:EquipTool(t)
                                        break
                                    end
                                end
                            end
                            curChar = char()
                            curTool = curChar and curChar:FindFirstChildOfClass("Tool")
                        end

                        if curTool and COMBAT.u62Table and typeof(COMBAT.u62Table.FireServer) == "function" then
                            local predPos = COMBAT.calculateTrajectory(tChar, tChar:FindFirstChild(S.aimHitbox or "Head") or tRoot)
                            if predPos then
                                pcall(function() COMBAT.u62Table:FireServer("Fire", predPos, true) end)
                            end
                        end
                    end
                end
            end
            task.wait(0.12)
        end
        COMBAT.iHateYouRunning = false
    end)
end

function COMBAT.stopIHateYou()
    COMBAT.iHateYouRunning = false
    COMBAT.iHateYouTarget = nil
end


-- ============================================================
-- 6. FISHING ENGINE, SPOT MANAGER & MINIGAME SOLVERS
-- ============================================================
FISH = {
    status = "idle",
    casts = 0,
    catches = 0,
    dead = 0,
    lastCast = 0,
    isFishing = false,
    isSelling = false,
    isRestocking = false,
}

local DANIEL_POS = Vector3.new(-3124.6, 45.3, -3740.2)

local function spotPos(pt)
    if not pt then return nil end
    if typeof(pt) == "Vector3" then return pt end
    if typeof(pt) == "CFrame" then return pt.Position end
    if type(pt) == "table" then
        if typeof(pt.pos) == "Vector3" then return pt.pos end
        if typeof(pt.pos) == "CFrame" then return pt.pos.Position end
        if #pt >= 3 then return Vector3.new(pt[1], pt[2], pt[3]) end
    end
    return nil
end

local function spotLook(pt)
    if type(pt) == "table" and typeof(pt.look) == "Vector3" then return pt.look end
    return nil
end

function FISH.getActiveSetName()
    return S.activeFishingSet or "Default"
end

function FISH.getSpotsList()
    local name = FISH.getActiveSetName()
    return (S.fishingSets and S.fishingSets[name]) or S.fishingSets["Default"]
end

function FISH.getSelectedSlotIdx()
    return math.clamp(tonumber(S.selectedSpotSlot) or 1, 1, 3)
end

function FISH.getActiveSpot()
    local list = FISH.getSpotsList()
    local idx = FISH.getSelectedSlotIdx()
    return list and list[idx]
end

function FISH.getStagingPoint()
    local name = FISH.getActiveSetName()
    return (S.stagingPoints and S.stagingPoints[name]) or S.stagingPoints["Default"]
end

-- Water Sector Scanner
local function findDeepWaterSector()
    local r = root()
    if not r then return nil end
    local myPos = r.Position
    local bestWaterPos = nil
    local bestDist = 0

    local angles = { 0, 15, -15, 30, -30, 45, -45, 60, -60 }
    for _, deg in ipairs(angles) do
        local cf = r.CFrame * CFrame.Angles(0, math.rad(deg), 0)
        local fwd = cf.LookVector
        for dist = 15, 65, 10 do
            local probePos = myPos + fwd * dist
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = { char() }
            rp.IgnoreWater = false

            local hit = WS:Raycast(probePos + Vector3.new(0, 10, 0), Vector3.new(0, -35, 0), rp)
            if hit and (hit.Material == Enum.Material.Water or (hit.Instance and hit.Instance.Name:lower():find("water"))) then
                if dist > bestDist then
                    bestDist = dist
                    bestWaterPos = hit.Position
                end
            end
        end
    end
    return bestWaterPos
end

-- Minigame Solvers
local function solveMashingMinigame()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local mg = pg and (pg:FindFirstChild("MashingMinigame") or pg:FindFirstChild("MashingSystem") or pg:FindFirstChild("FishQTE"))
    if not mg or not mg.Enabled then return false end

    logAction("FISHING", "Solving Mashing Minigame...", Color3.fromRGB(80, 220, 140))
    local t0 = os.clock()
    while os.clock() - t0 < 8 and mg.Parent and mg.Enabled do
        if keyclickFn then keyclickFn(0x47) -- G
        elseif keypressFn and keyreleaseFn then
            keypressFn(0x47); task.wait(0.03); keyreleaseFn(0x47)
        end
        local btn = mg:FindFirstChildWhichIsA("TextButton", true) or mg:FindFirstChildWhichIsA("ImageButton", true)
        if btn then pressChoice(btn) end
        task.wait(0.06)
    end
    return true
end

local function solveReactionMinigame()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local rc = pg and (pg:FindFirstChild("ReactionCircle") or pg:FindFirstChild("CircleMinigame"))
    if not rc or not rc.Enabled then return false end

    logAction("FISHING", "Solving Reaction Circle...", Color3.fromRGB(80, 220, 140))
    local marker = rc:FindFirstChild("Marker", true)
    local target = rc:FindFirstChild("TargetZone", true) or rc:FindFirstChild("GreenZone", true)
    if marker and target then
        local t0 = os.clock()
        while os.clock() - t0 < 6 and rc.Parent and rc.Enabled do
            local diff = math.abs(marker.AbsolutePosition.X - target.AbsolutePosition.X)
            if diff < 18 then
                if keyclickFn then keyclickFn(0x20) end
                pressChoice(marker)
                break
            end
            task.wait(0.02)
        end
    end
    return true
end

local function solveDotMinigame()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local dotGui = pg and pg:FindFirstChild("DotMinigameGui")
    if not dotGui or not dotGui.Enabled then return false end

    logAction("FISHING", "Solving Dot Minigame...", Color3.fromRGB(80, 220, 140))
    local dot = dotGui:FindFirstChild("Dot", true) or dotGui:FindFirstChild("FishDot", true)
    local bar = dotGui:FindFirstChild("Bar", true) or dotGui:FindFirstChild("CatchBar", true)
    if dot and bar then
        local t0 = os.clock()
        while os.clock() - t0 < 10 and dotGui.Parent and dotGui.Enabled do
            local targetY = dot.AbsolutePosition.Y + dot.AbsoluteSize.Y / 2
            local currentY = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y / 2
            local dy = targetY - currentY
            if mousemoverel then
                mousemoverel(0, math.clamp(dy * 0.4, -25, 25))
            end
            task.wait(0.03)
        end
    end
    return true
end

local function solveAnyMinigame()
    if not S.autoQTE then return false end
    return solveMashingMinigame() or solveReactionMinigame() or solveDotMinigame()
end

-- Bite Watcher
local function watchForBite(timeout)
    local t0 = os.clock()
    local maxWait = timeout or S.castTimeout or 22
    local c = char()

    while os.clock() - t0 < maxWait do
        if not S.autoFish then return false end
        solveAnyMinigame()

        -- Check sound cues on character
        if c then
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Sound") and d.IsPlaying then
                    local n = d.Name:lower()
                    if n:find("bite") or n:find("splash") or n:find("catch") or n:find("hook") or n:find("fish") then
                        return true
                    end
                end
            end
        end

        -- Check water ripple / bobber splashes nearby
        local r = root()
        if r then
            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Exclude
            overlap.FilterDescendantsInstances = { c }
            overlap.MaxParts = 25
            local parts = WS:GetPartBoundsInRadius(r.Position, 65, overlap)
            for _, p in ipairs(parts) do
                if p.Name:lower():find("ripple") or p.Name:lower():find("splash") or p.Name:lower():find("bite") then
                    return true
                end
            end
        end

        task.wait(0.08)
    end
    return false
end

-- Vendor Automation (Daniel Selling & Restocking)
local function visitDaniel(actionType)
    logAction("FISHING", "Riding horse to Daniel (" .. actionType .. ")...", Color3.fromRGB(90, 180, 255))
    if horseTeleport(DANIEL_POS) then
        landBeside(DANIEL_POS, 4)
    else
        NAV.walkTo(DANIEL_POS, { timeout = 60 })
    end
    task.wait(0.5)

    -- Interact with Daniel ProximityPrompt
    local daniel = WS:FindFirstChild("Daniel", true) or WS:FindFirstChild("FishBuyer", true)
    if daniel then
        for _, d in ipairs(daniel:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                pcall(firepp, d, 0)
                task.wait(0.3)
            end
        end
    end

    -- Process UI dialog
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        local shopGui = pg:FindFirstChild("ShopGui") or pg:FindFirstChild("VendorGui") or pg:FindFirstChild("FishShop")
        if shopGui then
            if actionType == "sell" then
                local sellBtn = shopGui:FindFirstChild("SellAll", true) or shopGui:FindFirstChild("SellFish", true)
                if sellBtn then pressChoice(sellBtn) end
            elseif actionType == "restock" then
                local baitBtn = shopGui:FindFirstChild("BuyBait", true) or shopGui:FindFirstChild("Bait", true)
                if baitBtn then
                    for _ = 1, math.min(10, math.floor((S.baitKeep or 15) / 5)) do
                        pressChoice(baitBtn)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
    task.wait(0.4)
end

-- Main Fishing Cycle
function FISH.step()
    if not S.autoFish or FISH.isFishing or FISH.isSelling or FISH.isRestocking then return end
    FISH.isFishing = true

    -- 1. Check Bait Restock
    local curBait = countTool("Bait")
    if curBait < 3 and S.autoRestock then
        FISH.isRestocking = true
        visitDaniel("restock")
        FISH.isRestocking = false
        FISH.isFishing = false
        return
    end

    -- 2. Check Fish Selling
    local _, fTotal = getFishCounts()
    if fTotal >= (S.sellEvery or 10) and S.autoSell then
        FISH.isSelling = true
        visitDaniel("sell")
        FISH.isSelling = false
        FISH.isFishing = false
        return
    end

    -- 3. Navigate to Active Fishing Spot
    local spot = FISH.getActiveSpot()
    local spotP = spotPos(spot)
    local r = root()
    if not r or not spotP then FISH.isFishing = false; return end

    local dist = (r.Position - spotP).Magnitude
    if dist > 8 then
        if dist > 45 then
            local staging = FISH.getStagingPoint()
            if staging and (r.Position - staging).Magnitude > 25 then
                horseTeleport(staging)
                landBeside(staging, 4)
            end
        end
        dismount()
        NAV.walkTo(spotP, { timeout = 90 })
    end

    -- 4. Equip Fishing Rod
    local rod = findTool("FishingRod")
    if rod and rod.Parent ~= char() then
        local h = hum()
        if h then h:EquipTool(rod) end
        task.wait(0.4)
    end

    -- 5. Face Water & Cast
    local waterPos = findDeepWaterSector()
    if waterPos then
        r.CFrame = CFrame.new(r.Position, Vector3.new(waterPos.X, r.Position.Y, waterPos.Z))
    elseif spotLook(spot) then
        r.CFrame = CFrame.new(r.Position, r.Position + spotLook(spot))
    end
    task.wait(0.2)

    logAction("FISHING", "Charging rod cast...", Color3.fromRGB(80, 170, 255))
    tap("PrimaryInput", 0.35)
    FISH.casts = FISH.casts + 1
    FISH.lastCast = os.clock()

    -- 6. Watch For Bite
    local bit = watchForBite(S.castTimeout or 22)
    if bit then
        task.wait(S.reelDelay or 0.25)
        logAction("FISHING", "Fish bite detected! Reeling in...", Color3.fromRGB(80, 255, 140))
        tap("PrimaryInput", 0.15)
        task.wait(0.3)
        solveAnyMinigame()
        FISH.catches = FISH.catches + 1
        FISH.dead = 0
    else
        logAction("FISHING", "Cast timed out (no bite)", Color3.fromRGB(245, 175, 60))
        FISH.dead = FISH.dead + 1
        tap("PrimaryInput", 0.15)
        if FISH.dead >= (S.deadCastsBeforeMove or 4) then
            FISH.dead = 0
            S.selectedSpotSlot = (FISH.getSelectedSlotIdx() % 3) + 1
            logAction("FISHING", "Switching to Spot Slot " .. S.selectedSpotSlot, Color3.fromRGB(175, 130, 255))
        end
    end

    task.wait(0.5)
    FISH.isFishing = false
end


-- ============================================================
-- 7. AUTOMATION, SAINT CORPSE TRACKER & SAFETY SERVER HOP
-- ============================================================
local SAINT = {
    detects = 0,
    grabs = 0,
    lastCorpsePos = nil,
    announcementTime = 0,
}

local function holdingCorpse()
    local c = char()
    if not c then return false end
    for _, d in ipairs(c:GetDescendants()) do
        if d.Name:lower():find("corpse") or d.Name:lower():find("saint") then return true end
    end
    return false
end

local function holdE(seconds)
    if keypressFn and keyreleaseFn then
        pcall(keypressFn, 0x45)
        local t0 = os.clock()
        while os.clock() - t0 < seconds do
            if holdingCorpse() then break end
            task.wait(0.05)
        end
        pcall(keyreleaseFn, 0x45)
        return true
    end
    return false
end

-- Saint Corpse Finder & Grabber
local function checkSaintCorpse()
    if not S.saintWatch then return end
    local f = WS:FindFirstChild("Entities") or WS
    local corpsePart = nil
    for _, e in ipairs(f:GetChildren()) do
        local n = e.Name:lower()
        if n:find("corpse") or n:find("saint") then
            corpsePart = e:IsA("BasePart") and e or e:FindFirstChildWhichIsA("BasePart")
            if corpsePart then break end
        end
    end

    if corpsePart then
        SAINT.lastCorpsePos = corpsePart.Position
        SAINT.detects = SAINT.detects + 1
        logAction("SAINT", "Saint's Corpse detected at (" .. math.floor(corpsePart.Position.X) .. ", " .. math.floor(corpsePart.Position.Z) .. ")", Color3.fromRGB(175, 130, 255))

        if S.saintGrab and not holdingCorpse() then
            if S.saintPreHoldWait and S.saintPreHoldWait > 0 then
                task.wait(S.saintPreHoldWait)
            end
            logAction("SAINT", "Traveling to Saint's Corpse...", Color3.fromRGB(175, 130, 255))
            if horseTeleport(corpsePart.Position) then
                landBeside(corpsePart.Position, 4)
            else
                NAV.walkTo(corpsePart.Position, { timeout = 60 })
            end
            holdE(10)
            if holdingCorpse() then
                SAINT.grabs = SAINT.grabs + 1
                logAction("SAINT", "Successfully acquired Saint's Corpse!", Color3.fromRGB(80, 255, 140))
                if S.saintRetreat then
                    local staging = FISH.getStagingPoint()
                    if staging then horseTeleport(staging); landBeside(staging, 4) end
                end
            end
        end
    end
end

-- World Harvesting (Chests & Herbs)
local function stepAutomation()
    local r = root()
    if not r then return end
    local range = S.promptRange or 25

    if S.autoChests or S.autoHerbs then
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = { char() }
        overlap.MaxParts = 40
        local parts = WS:GetPartBoundsInRadius(r.Position, range, overlap)

        for _, part in ipairs(parts) do
            local parent = part.Parent
            local pName = (parent and parent.Name:lower()) or part.Name:lower()
            local isChest = S.autoChests and (pName:find("chest") or pName:find("crate") or pName:find("safe"))
            local isHerb = S.autoHerbs and (pName:find("herb") or pName:find("dogbane") or pName:find("plant") or pName:find("flower"))

            if isChest or isHerb then
                local prompt = part:FindFirstChildOfClass("ProximityPrompt") or (parent and parent:FindFirstChildOfClass("ProximityPrompt"))
                if prompt and prompt.Enabled then
                    pcall(firepp, prompt, 0)
                    task.wait(0.2)
                end
            end
        end
    end

    -- Pad Auto-Buy
    if S.autoBuy and moola() >= (S.buyReserve or 50) then
        local pad = WS:FindFirstChild("AmmoPad", true) or WS:FindFirstChild("RefillPad", true)
        if pad then
            local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.Enabled and (r.Position - pad.Position).Magnitude < range then
                pcall(firepp, prompt, 0)
            end
        end
    end
end

-- Safety: Proximity Server Hop
local function stepSafety()
    local r = root()
    if not r then return end

    if S.autoHopNearPlayer or S.autoSwapSetNearPlayer then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local dist = (r.Position - tRoot.Position).Magnitude
                    local isFriend = false
                    if S.autoHopIgnoreFriends then
                        pcall(function() isFriend = LP:IsFriendsWith(p.UserId) end)
                    end

                    if not isFriend then
                        -- Auto swap fishing set
                        if S.autoSwapSetNearPlayer and dist <= (S.autoSwapDistance or 150) then
                            logAction("SAFETY", "Player near (" .. p.Name .. " - " .. math.floor(dist) .. "s). Swapping spot slot...", Color3.fromRGB(245, 175, 60))
                            S.selectedSpotSlot = (FISH.getSelectedSlotIdx() % 3) + 1
                            task.wait(5)
                        end

                        -- Server Hop
                        if S.autoHopNearPlayer and dist <= (S.autoHopDistance or 150) then
                            logAction("SAFETY", "Player within danger proximity (" .. p.Name .. " - " .. math.floor(dist) .. "s)! Server hopping...", Color3.fromRGB(245, 90, 90))
                            local ts = game:GetService("TeleportService")
                            pcall(function()
                                ts:Teleport(game.PlaceId)
                            end)
                            task.wait(10)
                        end
                    end
                end
            end
        end
    end
end


-- ============================================================
-- 8. VISUALS & ESP ENGINE
-- ============================================================
local draws = {}
local espOn = false

local function getDraw(i)
    local d = draws[i]
    if d then return d end
    local ok, o = pcall(function() return Drawing.new("Text") end)
    if not ok or not o then return nil end
    o.Size = 14; o.Center = true; o.Outline = true; o.Font = 2; o.Visible = false
    draws[i] = o
    return o
end

local function hideDraws(from)
    for i = from, #draws do
        if draws[i] then pcall(function() draws[i].Visible = false end) end
    end
end

local function isPlayerFriend(p)
    if not p then return false end
    local ok, f = pcall(function() return LP:IsFriendsWith(p.UserId) end)
    return ok and f
end

local function espTick()
    local camv, r = WS.CurrentCamera, root()
    if not camv or not r then hideDraws(1); return end
    local idx = 0

    local function put(pos, txt, col)
        local sp, on = camv:WorldToViewportPoint(pos)
        if not on then return end
        idx = idx + 1
        local d = getDraw(idx)
        if not d then return end
        d.Text = txt; d.Color = col; d.Position = Vector2.new(sp.X, sp.Y); d.Visible = true
    end

    local function folder(name, col, tag)
        local f = WS:FindFirstChild(name)
        if not f then return end
        for _, v in ipairs(f:GetChildren()) do
            local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local d = (part.Position - r.Position).Magnitude
                if d <= (S.espRange or 1500) then put(part.Position, tag .. " [" .. math.floor(d) .. "m]", col) end
            end
        end
    end

    if S.espHerb then folder("SpawnedHerbs", Color3.fromRGB(120, 255, 140), "HERB") end
    if S.espChest then folder("Chests", Color3.fromRGB(255, 200, 80), "CHEST") end

    if S.espHorse then
        local f = WS:FindFirstChild("Entities")
        if f then
            for _, e in ipairs(f:GetChildren()) do
                local p = e:FindFirstChildWhichIsA("ProximityPrompt", true)
                if p and p.ActionText:lower():find("ride") then
                    local part = e:FindFirstChild("HumanoidRootPart")
                    if part then
                        local d = (part.Position - r.Position).Magnitude
                        local o = e:FindFirstChild("Owner")
                        local mine = o and (o.Value == LP or o.Value == LP.Name)
                        if d <= (S.espRange or 1500) then
                            put(part.Position, (mine and "[MY HORSE] " or "HORSE ") .. math.floor(d) .. "m",
                                mine and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(210, 170, 120))
                        end
                    end
                end
            end
        end
    end

    if S.espPlayers then
        for _, o in ipairs(Players:GetPlayers()) do
            if o ~= LP and o.Character then
                local hh = o.Character:FindFirstChildOfClass("Humanoid")
                local hd = o.Character:FindFirstChild("Head")
                if hh and hd and hh.Health > 0 then
                    local d = (hd.Position - r.Position).Magnitude
                    if d <= (S.espRange or 1500) then
                        local isF = isPlayerFriend(o)
                        local nameTag = isF and ("[FRIEND] " .. o.Name) or o.Name
                        local espCol = isF and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(140, 190, 255)
                        put(hd.Position + Vector3.new(0, 2.5, 0),
                            string.format("%s (%d HP) [%dm]", nameTag, math.floor(hh.Health), math.floor(d)),
                            espCol)
                    end
                end
            end
        end
    end

    hideDraws(idx + 1)
end

local function ensureESP()
    local want = S.espChest or S.espHerb or S.espHorse or S.espPlayers
    if want and not espOn then
        espOn = true
        task.spawn(function()
            while S.running and (S.espChest or S.espHerb or S.espHorse or S.espPlayers) do
                pcall(espTick)
                RunService.RenderStepped:Wait()
            end
            espOn = false
            pcall(hideDraws, 1)
        end)
    end
end


-- ============================================================
-- 9. MODERN D.R.Y. UI FRAMEWORK & DECLARATIVE SCHEMA
-- ============================================================
UI = {
    tabs = {},
    activeTab = nil,
    gui = nil,
    main = nil,
    hudGui = nil,
    bsGui = nil,
}

local TH = {
    bg = Color3.fromRGB(15, 17, 23),
    header = Color3.fromRGB(20, 23, 31),
    card = Color3.fromRGB(24, 28, 38),
    border = Color3.fromRGB(36, 42, 56),
    accent = Color3.fromRGB(99, 102, 241),
    green = Color3.fromRGB(52, 211, 153),
    text = Color3.fromRGB(240, 243, 250),
    dim = Color3.fromRGB(130, 138, 158),
    cardHover = Color3.fromRGB(30, 35, 48),
}

local function mk(cls, props, parent)
    local inst = Instance.new(cls)
    for k, v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(p, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p) end
local function stroke(p, col, th)
    return mk("UIStroke", { Color = col or TH.border, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function parentGui(g)
    pcall(function() g.Parent = gethui and gethui() end)
    if not g.Parent then pcall(function() g.Parent = game:GetService("CoreGui") end) end
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
end

-- Universal Widget Builders
local toggleVisuals = {}

local function createToggle(parent, label, key, onChange)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = TH.card }, parent)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local switch = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = S[key] and TH.green or TH.header,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(switch, 10)
    stroke(switch, TH.border)

    local knob = mk("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = S[key] and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = TH.text,
    }, switch)
    corner(knob, 7)

    local function updateVisual(val)
        switch.BackgroundColor3 = val and TH.green or TH.header
        knob.Position = val and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    end

    toggleVisuals[key] = toggleVisuals[key] or {}
    table.insert(toggleVisuals[key], updateVisual)

    switch.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        for _, fn in ipairs(toggleVisuals[key]) do fn(S[key]) end
        if onChange then task.spawn(onChange, S[key]) end
        if S.autoSaveConfig then pcall(saveConfig) end
    end)
    return row
end

local function createSlider(parent, label, key, minVal, maxVal, stepVal, suffix, onChange)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = TH.card }, parent)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(0.6, 0, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local valLabel = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.6, 0, 0, 6),
        Size = UDim2.new(0.4, -12, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = tostring(S[key] or minVal) .. (suffix and (" " .. suffix) or ""),
        TextColor3 = TH.accent,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local barBg = mk("Frame", {
        Position = UDim2.new(0, 12, 0, 30),
        Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = TH.header,
    }, row)
    corner(barBg, 3)

    local initFrac = math.clamp(((S[key] or minVal) - minVal) / (maxVal - minVal), 0, 1)
    local barFill = mk("Frame", {
        Size = UDim2.new(initFrac, 0, 1, 0),
        BackgroundColor3 = TH.accent,
    }, barBg)
    corner(barFill, 3)

    local trigger = mk("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
    }, barBg)

    local dragging = false
    local function applySlider(inputX)
        local relX = math.clamp(inputX - barBg.AbsolutePosition.X, 0, barBg.AbsoluteSize.X)
        local frac = relX / barBg.AbsoluteSize.X
        local raw = minVal + frac * (maxVal - minVal)
        local stepped = math.floor(raw / stepVal + 0.5) * stepVal
        S[key] = stepped
        barFill.Size = UDim2.new(frac, 0, 1, 0)
        valLabel.Text = tostring(stepped) .. (suffix and (" " .. suffix) or "")
        if onChange then task.spawn(onChange, stepped) end
    end

    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            applySlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            applySlider(input.Position.X)
        end
    end)
    return row
end

local function createDropdown(parent, label, key, options, onChange)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = TH.card }, parent)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.5, -12, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local btn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0.5, 0, 0, 24),
        BackgroundColor3 = TH.header,
        Font = Enum.Font.GothamMedium,
        Text = tostring(S[key] or options[1]) .. "  ▼",
        TextColor3 = TH.accent,
        TextSize = 11,
        AutoButtonColor = false,
    }, row)
    corner(btn, 4)
    stroke(btn, TH.border)

    local optIdx = 1
    for i, o in ipairs(options) do if S[key] == o then optIdx = i; break end end

    btn.MouseButton1Click:Connect(function()
        optIdx = (optIdx % #options) + 1
        local chosen = options[optIdx]
        S[key] = chosen
        btn.Text = tostring(chosen) .. "  ▼"
        if onChange then task.spawn(onChange, chosen) end
    end)
    return row
end

local function createKeybind(parent, label, key)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = TH.card }, parent)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local btn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(60, 22),
        BackgroundColor3 = TH.header,
        Font = Enum.Font.GothamBold,
        Text = "[" .. tostring(S[key] or "H") .. "]",
        TextColor3 = TH.accent,
        TextSize = 11,
        AutoButtonColor = false,
    }, row)
    corner(btn, 4)
    stroke(btn, TH.border)

    local rebinding = false
    btn.MouseButton1Click:Connect(function()
        rebinding = true
        btn.Text = "[ ... ]"
        local conn
        conn = UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local kName = input.KeyCode.Name
                S[key] = kName
                btn.Text = "[" .. kName .. "]"
                conn:Disconnect()
                rebinding = false
            end
        end)
    end)
    return row
end

local function createButton(parent, label, fn)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = label,
        TextColor3 = TH.text,
        TextSize = 12,
        AutoButtonColor = false,
    }, parent)
    corner(btn, 6)
    stroke(btn, TH.border)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = TH.cardHover; btn.TextColor3 = TH.accent end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = TH.card; btn.TextColor3 = TH.text end)
    btn.MouseButton1Click:Connect(function() if fn then task.spawn(fn) end end)
    return btn
end

local function createDualButton(parent, lbl1, fn1, lbl2, fn2)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, parent)
    local b1 = mk("TextButton", {
        Size = UDim2.new(0.5, -4, 1, 0),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = lbl1,
        TextColor3 = TH.text,
        TextSize = 11,
        AutoButtonColor = false,
    }, row)
    corner(b1, 6)
    stroke(b1, TH.border)
    b1.MouseButton1Click:Connect(function() if fn1 then task.spawn(fn1) end end)

    local b2 = mk("TextButton", {
        Position = UDim2.new(0.5, 4, 0, 0),
        Size = UDim2.new(0.5, -4, 1, 0),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = lbl2,
        TextColor3 = TH.text,
        TextSize = 11,
        AutoButtonColor = false,
    }, row)
    corner(b2, 6)
    stroke(b2, TH.border)
    b2.MouseButton1Click:Connect(function() if fn2 then task.spawn(fn2) end end)
    return row
end

-- ── MINI-HUD FLOATING BUBBLE ───────────────────────────────────────────────
local function initMiniHud()
    local hudGui = mk("ScreenGui", { Name = "Bridger_MiniHUD", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(hudGui)
    UI.hudGui = hudGui

    local pill = mk("Frame", {
        Position = UDim2.new(0.5, -220, 0, 10),
        Size = UDim2.fromOffset(440, 32),
        BackgroundColor3 = TH.bg,
        Active = true,
        Draggable = true,
        Visible = S.showHud and not S.blackscreen,
    }, hudGui)
    corner(pill, 16)
    stroke(pill, TH.border)

    local dot = mk("Frame", {
        Position = UDim2.fromOffset(10, 11),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = TH.green,
    }, pill)
    corner(dot, 5)

    local badge = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(26, 0),
        Size = UDim2.fromOffset(60, 32),
        Font = Enum.Font.GothamBold,
        Text = "[IDLE]",
        TextColor3 = TH.green,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, pill)

    local txt = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(90, 0),
        Size = UDim2.new(1, -98, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = "Ready to start",
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)

    UI.updateStatus = function()
        if not hudGui.Parent then return end
        pill.Visible = S.showHud and not S.blackscreen
        dot.BackgroundColor3 = Status.color
        badge.Text = "[" .. Status.state .. "]"
        badge.TextColor3 = Status.color
        local line = Status.action
        if Status.detail and Status.detail ~= "" then line = line .. " • " .. Status.detail end
        txt.Text = line
    end
end

-- ── BLACKSCREEN AFK CANVAS ─────────────────────────────────────────────────
local function initBlackscreen()
    local bsGui = mk("ScreenGui", { Name = "Bridger_Blackscreen", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(bsGui)
    UI.bsGui = bsGui

    local frame = mk("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 10, 14),
        BorderSizePixel = 0,
        Visible = S.blackscreen,
        Active = (S.blackscreenOpaque ~= false),
    }, bsGui)

    local card = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(480, 260),
        BackgroundColor3 = TH.bg,
    }, frame)
    corner(card, 10)
    stroke(card, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -32, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = "BRIDGER WESTERN • AFK MONITOR",
        TextColor3 = TH.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)

    local statsTxt = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 45),
        Size = UDim2.new(1, -32, 0, 160),
        Font = Enum.Font.GothamMedium,
        Text = "Loading stats...",
        TextColor3 = TH.dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, card)

    local exitBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 12),
        Size = UDim2.fromOffset(80, 22),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = "Exit AFK",
        TextColor3 = TH.accent,
        TextSize = 11,
    }, card)
    corner(exitBtn, 4)
    exitBtn.MouseButton1Click:Connect(function()
        S.blackscreen = false
        frame.Visible = false
        if UI.main then UI.main.Visible = true end
        if UI.updateStatus then UI.updateStatus() end
    end)

    task.spawn(function()
        while true do
            if S.blackscreen and frame.Visible then
                local counts, total = getFishCounts()
                local m = moola()
                local dog = countDogbane()
                local bait = countTool("Bait")
                statsTxt.Text = string.format([[
Status: [%s] %s
Detail: %s

💰 Total Moola: $%d
🌿 Dogbane Herbs: %d
🪱 Bait Remaining: %d
🎣 Total Fish Caught: %d
🐟 Bass: %d  |  Snapper: %d  |  Cod: %d

Press RightShift or click 'Exit AFK' to return]],
                    Status.state, Status.action, Status.detail,
                    m, dog, bait, (FISH and FISH.catches or 0),
                    counts.Bass, counts.Snapper, counts.Cod)
            end
            task.wait(1.5)
        end
    end)
end

-- ── DECLARATIVE UI SCHEMA DEFINITION ───────────────────────────────────────
local UI_SCHEMA = {
    {
        name = "Combat",
        sections = {
            {
                title = "Silent Aim & Ballistics",
                items = {
                    { "toggle", "Prediction Silent Aim", "silentAim", function(v) if v then COMBAT.ensureHook() end end },
                    { "toggle", "Martini Ballistics (5k Range)", "martiniBallistics" },
                    { "dropdown", "Target Mode", "aimTargetMode", { "Closest to Cursor", "Lowest Health", "Lowest Distance" } },
                    { "dropdown", "Target Hitbox", "aimHitbox", { "Head", "HumanoidRootPart", "UpperTorso" } },
                    { "toggle", "Ignore Friends", "aimIgnoreFriends" },
                    { "toggle", "Only Fire At Low Speeds", "onlyFireAtLowSpeeds" },
                    { "slider", "Max Firing Speed", "maxFiringSpeed", 10, 80, 5, "s/s" },
                    { "slider", "Min Hit Chance", "minHitChance", 0, 95, 5, "%" },
                }
            },
            {
                title = "Motion Predictor Engine",
                items = {
                    { "toggle", "Human Predictor Engine", "humanPredictor" },
                    { "toggle", "Smart EV Hitbox", "smartHitboxEV" },
                    { "toggle", "Peak Confidence Auto-Fire", "peakConfidenceFire" },
                    { "slider", "Peak Fire Threshold", "peakFireThreshold", 50, 95, 5, "%" },
                }
            },
            {
                title = "Target Stalking",
                items = {
                    { "toggle", "I Hate You (Pursuit)", "iHateYou", function(v) if v then COMBAT.ensureHook(); COMBAT.startIHateYou() else COMBAT.stopIHateYou() end end },
                    { "slider", "Pursuit Distance", "iHateYouDistance", 20, 210, 5, "studs" },
                    { "toggle", "Martini Sniper Vantage", "martiniVantage" },
                }
            }
        }
    },
    {
        name = "Movement",
        sections = {
            {
                title = "Horsefly & Flight Controls",
                items = {
                    { "toggle", "Ghost Horsefly", "fakeHorseFly", function(v) if v then startFakeHorseFly() else stopFakeHorseFly(true) end end },
                    { "keybind", "Horsefly Keybind", "horseFlyKey" },
                    { "slider", "Flight Speed", "fakeFlySpeed", 20, 250, 5, "studs/s" },
                }
            },
            {
                title = "Horse Actions",
                items = {
                    { "dualBtn", "Summon Horse", summonHorse, "Mount Horse", mountHorse },
                    { "btn", "Dismount Horse", dismount },
                }
            }
        }
    },
    {
        name = "Fishing",
        sections = {
            {
                title = "Auto-Fishing Engine",
                items = {
                    { "toggle", "Auto Fish Loop", "autoFish" },
                    { "toggle", "Legit Navigation Mode", "legitFishing" },
                    { "toggle", "Visualize Route & Beacon", "visualizeLegit" },
                    { "toggle", "Require Bait To Cast", "requireBait" },
                    { "toggle", "Auto Pass Minigames", "autoQTE" },
                }
            },
            {
                title = "Vendor & Restock",
                items = {
                    { "toggle", "Auto Restock Bait", "autoRestock" },
                    { "slider", "Restock Target", "baitKeep", 5, 50, 5, "bait" },
                    { "toggle", "Auto Sell Fish", "autoSell" },
                    { "slider", "Sell Every N Catches", "sellEvery", 1, 40, 1, "catches" },
                    { "toggle", "Auto Sell When Broke", "autoSellOutOfMoney" },
                }
            },
            {
                title = "Spot Management",
                items = {
                    { "dropdown", "Active Fishing Set", "activeFishingSet", { "Default" } },
                    { "dropdown", "Spot Slot", "selectedSpotSlot", { "1", "2", "3" } },
                    { "slider", "Cast Timeout", "castTimeout", 8, 40, 1, "s" },
                    { "slider", "Reel Delay", "reelDelay", 0.05, 0.5, 0.02, "s" },
                    { "slider", "Dead Casts To Swap", "deadCastsBeforeMove", 1, 10, 1, "casts" },
                }
            }
        }
    },
    {
        name = "Harvest",
        sections = {
            {
                title = "World Harvesting",
                items = {
                    { "toggle", "Auto Farm Chests", "autoChests" },
                    { "toggle", "Auto Farm Herbs", "autoHerbs" },
                    { "slider", "Interaction Range", "promptRange", 5, 80, 1, "studs" },
                }
            },
            {
                title = "Pad Auto-Buy",
                items = {
                    { "toggle", "Auto Buy Ammo", "autoBuy" },
                    { "slider", "Keep Moola Above", "buyReserve", 0, 1000, 25, "$" },
                }
            }
        }
    },
    {
        name = "Saint",
        sections = {
            {
                title = "Saint Corpse Tracking",
                items = {
                    { "toggle", "Watch For Corpse", "saintWatch" },
                    { "toggle", "Auto Grab Corpse", "saintGrab" },
                    { "toggle", "Auto Retreat After Grab", "saintRetreat" },
                    { "slider", "Active Window", "saintWindow", 60, 900, 30, "s" },
                    { "slider", "Pre-Hold Delay", "saintPreHoldWait", 0, 60, 5, "s" },
                }
            }
        }
    },
    {
        name = "Visuals",
        sections = {
            {
                title = "ESP Overlays",
                items = {
                    { "toggle", "Player ESP", "espPlayers", ensureESP },
                    { "toggle", "Horse ESP", "espHorse", ensureESP },
                    { "toggle", "Chest ESP", "espChest", ensureESP },
                    { "toggle", "Herb ESP", "espHerb", ensureESP },
                    { "slider", "ESP Max Range", "espRange", 200, 4000, 100, "studs" },
                }
            }
        }
    },
    {
        name = "Safety",
        sections = {
            {
                title = "Proximity Protections",
                items = {
                    { "toggle", "Server Hop Near Player", "autoHopNearPlayer" },
                    { "slider", "Hop Distance", "autoHopDistance", 30, 500, 10, "studs" },
                    { "toggle", "Swap Set Near Player", "autoSwapSetNearPlayer" },
                    { "slider", "Swap Distance", "autoSwapDistance", 30, 500, 10, "studs" },
                    { "toggle", "Ignore Friends", "autoHopIgnoreFriends" },
                }
            }
        }
    },
    {
        name = "Display",
        sections = {
            {
                title = "AFK & HUD Overlays",
                items = {
                    { "toggle", "Show Mini-HUD Pill", "showHud", function(v) if UI.updateStatus then UI.updateStatus() end end },
                    { "toggle", "Blackscreen AFK Mode", "blackscreen", function(v)
                        if UI.bsGui and UI.bsGui:FindFirstChild("Frame") then
                            UI.bsGui.Frame.Visible = v
                        end
                    end },
                    { "toggle", "Blackscreen Opaque", "blackscreenOpaque" },
                }
            }
        }
    },
    {
        name = "Config",
        sections = {
            {
                title = "Configuration & Persistence",
                items = {
                    { "dualBtn", "Save Config", saveConfig, "Load Config", loadConfig },
                }
            },
            {
                title = "Discord Webhooks",
                items = {
                    { "toggle", "Periodic Webhook", "webhookIntervalEnabled" },
                    { "slider", "Interval (Minutes)", "webhookInterval", 1, 60, 1, "min" },
                    { "toggle", "Instant Dogbane Alert", "webhookOnDogbane" },
                    { "btn", "Send Test Webhook", function() sendInventoryWebhook("🧪 Test Telemetry") end },
                }
            }
        }
    }
}

-- ── INITIALIZE MAIN WINDOW ─────────────────────────────────────────────────
local function initMainWindow()
    local gui = mk("ScreenGui", { Name = "Bridger_Hub_Unified", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(gui)
    UI.gui = gui

    local vp = WS.CurrentCamera and WS.CurrentCamera.ViewportSize or Vector2.new(1000, 700)
    local W, H = math.min(560, vp.X - 20), math.min(420, vp.Y - 40)

    local main = mk("Frame", {
        Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BackgroundColor3 = TH.bg,
        Active = true,
        Draggable = true,
    }, gui)
    corner(main, 8)
    stroke(main, TH.border)
    UI.main = main

    -- Header Bar
    local header = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = TH.header,
    }, main)
    corner(header, 8)
    mk("Frame", {
        Position = UDim2.new(0, 0, 1, -6),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = TH.header,
        BorderSizePixel = 0,
    }, header)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "BRIDGER WESTERN  •  v" .. VERSION,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local closeBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = "✕",
        TextColor3 = TH.dim,
        TextSize = 11,
        AutoButtonColor = false,
    }, header)
    corner(closeBtn, 4)
    closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

    -- Body: Left Sidebar Tabs & Right Content
    local sidebar = mk("Frame", {
        Position = UDim2.fromOffset(6, 42),
        Size = UDim2.new(0, 110, 1, -48),
        BackgroundColor3 = TH.header,
    }, main)
    corner(sidebar, 6)

    local tabList = mk("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sidebar)
    mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, sidebar)

    local content = mk("Frame", {
        Position = UDim2.fromOffset(122, 42),
        Size = UDim2.new(1, -128, 1, -48),
        BackgroundTransparency = 1,
    }, main)

    -- Build Tabs & Content Pages from Declarative Schema
    local tabButtons = {}
    local tabPages = {}

    for tabIdx, tabDef in ipairs(UI_SCHEMA) do
        local page = mk("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = TH.border,
            Visible = (tabIdx == 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, content)
        mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        mk("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, page)
        tabPages[tabDef.name] = page

        local tabBtn = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = (tabIdx == 1) and TH.card or Color3.fromRGB(0,0,0),
            BackgroundTransparency = (tabIdx == 1) and 0 or 1,
            Font = Enum.Font.GothamMedium,
            Text = tabDef.name,
            TextColor3 = (tabIdx == 1) and TH.accent or TH.dim,
            TextSize = 11,
            AutoButtonColor = false,
        }, sidebar)
        corner(tabBtn, 4)
        tabButtons[tabDef.name] = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            for name, p in pairs(tabPages) do p.Visible = (name == tabDef.name) end
            for name, b in pairs(tabButtons) do
                b.BackgroundTransparency = (name == tabDef.name) and 0 or 1
                b.TextColor3 = (name == tabDef.name) and TH.accent or TH.dim
            end
        end)

        -- Build Sections inside Page
        for _, sec in ipairs(tabDef.sections) do
            local secCard = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = TH.header,
            }, page)
            corner(secCard, 6)
            stroke(secCard, TH.border)
            mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, secCard)
            mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, secCard)

            mk("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.GothamBold,
                Text = sec.title,
                TextColor3 = TH.accent,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, secCard)

            for _, item in ipairs(sec.items) do
                local iType = item[1]
                if iType == "toggle" then
                    createToggle(secCard, item[2], item[3], item[4])
                elseif iType == "slider" then
                    createSlider(secCard, item[2], item[3], item[4], item[5], item[6], item[7], item[8])
                elseif iType == "dropdown" then
                    createDropdown(secCard, item[2], item[3], item[4], item[5])
                elseif iType == "keybind" then
                    createKeybind(secCard, item[2], item[3])
                elseif iType == "btn" then
                    createButton(secCard, item[2], item[3])
                elseif iType == "dualBtn" then
                    createDualButton(secCard, item[2], item[3], item[4], item[5])
                end
            end
        end
    end
end


-- ============================================================
-- 10. LIFECYCLE, MAIN EVENT DISPATCHER & INITIALIZATION
-- ============================================================

-- Keybind Listeners
track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if S.blackscreen then
            S.blackscreen = false
            if UI.bsGui and UI.bsGui:FindFirstChild("Frame") then UI.bsGui.Frame.Visible = false end
            if UI.main then UI.main.Visible = true end
            if UI.updateStatus then UI.updateStatus() end
        elseif UI.main then
            UI.main.Visible = not UI.main.Visible
        end
    elseif input.KeyCode.Name == (S.horseFlyKey or "H") then
        S.fakeHorseFly = not S.fakeHorseFly
        if S.fakeHorseFly then startFakeHorseFly() else stopFakeHorseFly(true) end
        if toggleVisuals["fakeHorseFly"] then
            for _, fn in ipairs(toggleVisuals["fakeHorseFly"]) do fn(S.fakeHorseFly) end
        end
    end
end))

-- Background Automation Dispatcher
loop("autoFish", 0.5, function()
    FISH.step()
end)

loop("running", 0.5, function()
    stepAutomation()
end)

-- Heartbeat Combat & Safety Dispatcher
track(RunService.Heartbeat:Connect(function()
    if not S.running then return end
    checkSaintCorpse()
    stepSafety()
end))

-- Webhook Telemetry Loop
task.spawn(function()
    while S.running do
        if S.webhookIntervalEnabled and (os.clock() - lastWebhookSend) >= ((S.webhookInterval or 10) * 60) then
            sendInventoryWebhook("⏰ Periodic Telemetry Update")
        end
        task.wait(30)
    end
end)

-- Startup Boot
pcall(loadConfig)
pcall(applyGenvConfig)
task.spawn(COMBAT.ensureHook)
initMiniHud()
initBlackscreen()
initMainWindow()

logAction("SYSTEM", "Bridger Western v" .. VERSION .. " Unified Engine Initialized", Color3.fromRGB(80, 220, 140))
print("[BW Engine] Initialized single-file edition v" .. VERSION .. " successfully.")
