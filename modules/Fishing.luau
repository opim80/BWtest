--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Fishing
-- Ground-Up Clean Architecture: Baritone Navigation,
-- Permanent Default Sets, Zero-Lag Bite Watch, QTE & Vendor FSM
-- ============================================================
local ctx = ...
local SHARED = ctx and ctx.SHARED or getfenv(0)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer or Players:GetPlayers()[1]

-- ── CONTEXT & SHARED ACCESSORS ──────────────────────────────
local function S()
    return (ctx and ctx.S) or SHARED.S or {}
end

local function char()
    return (ctx and ctx.Utils and ctx.Utils.char and ctx.Utils.char())
        or (SHARED.char and SHARED.char())
        or LP.Character
end

local function root()
    return (ctx and ctx.Utils and ctx.Utils.root and ctx.Utils.root())
        or (SHARED.root and SHARED.root())
        or (char() and char():FindFirstChild("HumanoidRootPart"))
end

local function hum()
    return (ctx and ctx.Utils and ctx.Utils.hum and ctx.Utils.hum())
        or (SHARED.hum and SHARED.hum())
        or (char() and char():FindFirstChildOfClass("Humanoid"))
end

local function logAction(category, msg, color, tag, detail)
    if ctx and ctx.Logging and ctx.Logging.logAction then
        ctx.Logging.logAction(category, msg, color, tag, detail)
    elseif SHARED.logAction then
        SHARED.logAction(category, msg, color, tag, detail)
    end
end

local function spotPos(s)
    if not s then return nil end
    if typeof(s) == "Vector3" then return s end
    if typeof(s) == "CFrame" then return s.Position end
    if type(s) == "table" then
        if s.pos then return spotPos(s.pos) end
        if #s >= 3 then return Vector3.new(s[1], s[2], s[3]) end
    end
    return nil
end

local function spotLook(s)
    if not s then return nil end
    if typeof(s) == "CFrame" then return s.LookVector end
    if type(s) == "table" then
        if s.look then return spotLook(s.look) end
        if #s >= 6 then return Vector3.new(s[4], s[5], s[6]) end
    end
    return nil
end

local function findTool(name)
    return (ctx and ctx.Utils and ctx.Utils.findTool and ctx.Utils.findTool(name))
        or (SHARED.findTool and SHARED.findTool(name))
end

local function equipTool(name)
    return (ctx and ctx.Utils and ctx.Utils.equipTool and ctx.Utils.equipTool(name))
        or (SHARED.equipTool and SHARED.equipTool(name))
end

local function countTool(name)
    return (ctx and ctx.Utils and ctx.Utils.countTool and ctx.Utils.countTool(name))
        or (SHARED.countTool and SHARED.countTool(name))
        or 0
end

local function moola()
    return (ctx and ctx.Utils and ctx.Utils.moola and ctx.Utils.moola())
        or (SHARED.moola and SHARED.moola())
        or 0
end

local function myHorse()
    return (ctx and ctx.Movement and ctx.Movement.myHorse and ctx.Movement.myHorse())
        or (SHARED.myHorse and SHARED.myHorse())
end

local function isMounted(horse)
    return (ctx and ctx.Movement and ctx.Movement.isMounted and ctx.Movement.isMounted(horse))
        or (SHARED.isMounted and SHARED.isMounted(horse))
        or false
end

local function dismount()
    if ctx and ctx.Movement and ctx.Movement.dismount then
        return ctx.Movement.dismount()
    elseif SHARED.dismount then
        return SHARED.dismount()
    end
    local h = hum()
    if h then pcall(function() h.Sit = false end) end
end

local function horseTeleport(target)
    if ctx and ctx.Movement and ctx.Movement.horseTeleport then
        return ctx.Movement.horseTeleport(target)
    elseif SHARED.horseTeleport then
        return SHARED.horseTeleport(target)
    end
    return false
end

local function landBeside(target, offset)
    if ctx and ctx.Movement and ctx.Movement.landBeside then
        return ctx.Movement.landBeside(target, offset)
    elseif SHARED.landBeside then
        return SHARED.landBeside(target, offset)
    end
end

local function tap(alias, hold)
    if ctx and ctx.Utils and ctx.Utils.tap then
        return ctx.Utils.tap(alias, hold)
    elseif SHARED.tap then
        return SHARED.tap(alias, hold)
    end
    return false
end

local function getFishCounts()
    if ctx and ctx.Utils and ctx.Utils.getFishCounts then
        return ctx.Utils.getFishCounts()
    elseif SHARED.getFishCounts then
        return SHARED.getFishCounts()
    end
    return {}, 0
end

local function recordCatch(method, count)
    if ctx and ctx.Logging and ctx.Logging.recordCatch then
        return ctx.Logging.recordCatch(method, count)
    elseif SHARED.recordCatch then
        return SHARED.recordCatch(method, count)
    end
end

-- ============================================================
-- 1. HARDCODED CONSTANTS & IMMUTABLE DEFAULT SPOTS
-- ============================================================
local DEFAULT_SPOTS = {
    { pos = Vector3.new(-3131.6, 47.12, -3717.2), look = Vector3.new(0.35, 0, -0.93) },
    { pos = Vector3.new(-3139.6, 47.12, -3717.2), look = Vector3.new(0.35, 0, -0.93) },
    { pos = Vector3.new(-3147.6, 47.12, -3709.2), look = Vector3.new(0.35, 0, -0.93) },
}
local DEFAULT_STAGING = Vector3.new(-3125.0, 47.0, -3685.0)
local DANIEL_POS = Vector3.new(-3121.05, 46.34, -3618.09)

-- Ensure S.fishingSets has the Default set initialized
local sTable = S()
if not sTable.fishingSets then sTable.fishingSets = {} end
if not sTable.fishingSets["Default"] then
    sTable.fishingSets["Default"] = {
        { pos = DEFAULT_SPOTS[1].pos, look = DEFAULT_SPOTS[1].look },
        { pos = DEFAULT_SPOTS[2].pos, look = DEFAULT_SPOTS[2].look },
        { pos = DEFAULT_SPOTS[3].pos, look = DEFAULT_SPOTS[3].look },
    }
end

-- ── FISHING STATE TABLE ─────────────────────────────────────
local FISH = (SHARED.FISH or { status = "idle", casts = 0, catches = 0, dead = 0 }) :: any
SHARED.FISH = FISH

local spotIndex = 1
local FISH_SPOTS = DEFAULT_SPOTS

local castPhase = "idle" -- "idle" | "casted" | "reeling"
local lastCast = 0
local tappedThisCast = false
local biteWatchRunning = false
local lastKnownFishTotal = 0
local lastCatchTime = 0
local isSellingFish = false
local isRestockingBait = false
local isBuyingRod = false

-- Visual proxy table (used by Tabs UI & Navigation)
FISH.viz = {
    targetSpot = nil,
    steerTarget = nil,
    currentSpeed = 16,
    currentAction = "Idle",
}

-- ============================================================
-- 2. ANIMATION HELPER
-- ============================================================
local ANIM_IDS = {
    ["99374973462906"] = "SwingRod",
    ["85381268135994"] = "ReelLoop",
    ["98675703339517"] = "BringBack",
    ["99032819855540"] = "RodIdle",
    ["124675900911926"] = "Success",
}

local function anims()
    local h = hum()
    local an = h and h:FindFirstChildOfClass("Animator")
    if not an then return {} end
    local out = {}
    for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
        local id = tostring(tr.Animation and tr.Animation.AnimationId):match("(%d+)")
        if id and ANIM_IDS[id] then
            out[ANIM_IDS[id]] = true
        end
    end
    return out
end

-- ============================================================
-- 3. SPOTS & SETS MANAGEMENT
-- ============================================================
function FISH.getSetNames()
    local names = { "Default" }
    local seen = { ["Default"] = true }
    local sets = S().fishingSets
    if sets and type(sets) == "table" then
        for k, _ in pairs(sets) do
            local str = tostring(k)
            if not seen[str] then
                seen[str] = true
                table.insert(names, str)
            end
        end
    end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)
    return names
end

function FISH.getActiveSetName()
    local act = S().activeFishingSet
    if act and type(act) == "string" and act ~= "" then
        if act == "Default" then return "Default" end
        local sets = S().fishingSets
        if sets and sets[act] then return act end
    end
    return "Default"
end

function FISH.getActiveSpots()
    local name = FISH.getActiveSetName()
    local sets = S().fishingSets
    if sets and sets[name] and #sets[name] > 0 then
        return sets[name]
    end
    return DEFAULT_SPOTS
end

function FISH.getSelectedSlotIdx()
    local n = tonumber(S().selectedSpotSlot) or 1
    return math.clamp(math.floor(n), 1, 3)
end

function FISH.getStagingPoint(setName)
    setName = setName or FISH.getActiveSetName()
    local staging = S().stagingPoints
    if staging and staging[setName] then
        local p = spotPos(staging[setName])
        if p then return p end
    end
    return DEFAULT_STAGING
end

function FISH.validateAllSpots()
    local spots = FISH.getActiveSpots()
    if not spots or #spots == 0 then
        return false, "No fishing spots configured in active set"
    end
    for i = 1, #spots do
        if not spotPos(spots[i]) then
            return false, string.format("Spot #%d is missing coordinates", i)
        end
    end
    return true
end

function FISH.setActiveSet(name)
    name = tostring(name or "Default")
    local sets = S().fishingSets
    if not sets or not sets[name] then
        name = "Default"
    end
    S().activeFishingSet = name
    FISH_SPOTS = FISH.getActiveSpots()
    spotIndex = 1

    logAction("FISH", string.format("Switched to Fishing Set '%s'", name), Color3.fromRGB(80, 220, 140), "FISHING")

    local UI = (ctx and ctx.UI) or SHARED.UI
    if UI then
        if UI.activeSetDropdown then pcall(function() UI.activeSetDropdown:Refresh() end) end
        if UI.refreshSpotsUI then pcall(UI.refreshSpotsUI) end
    end

    if S().autoFish then
        task.spawn(function()
            local spot = FISH_SPOTS[spotIndex]
            if not spot then return end
            if S().legitFishing then
                FISH.walkToSpotLegit(spot)
            else
                if horseTeleport(spot) then
                    landBeside(spot, 3)
                    local l = spotLook(spot)
                    local r = root()
                    if l and r then
                        pcall(function()
                            r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(l.X, 0, l.Z))
                        end)
                    end
                end
            end
        end)
    end
end

-- ============================================================
-- 4. BARITONE NAVIGATION & VISUALIZATION INTEGRATION
-- ============================================================
local function getNav()
    return (ctx and ctx.Navigation) or SHARED.NAV or {}
end

function FISH.ensureViz()
    local nav = getNav()
    if FISH.viz and FISH.viz.targetSpot and nav.drawBeacon then
        pcall(nav.drawBeacon, FISH.viz.targetSpot)
    end
end

function FISH.hideViz()
    local nav = getNav()
    if nav.clearVisuals then
        pcall(nav.clearVisuals)
    end
end

function FISH.walkToSpotLegit(targetPos, maxHorseThreshold)
    local p = spotPos(targetPos)
    if not p then return false end
    local r, h = root(), hum()
    if not r or not h or h.Health <= 0 then return false end

    local dist = (r.Position - p).Magnitude
    local maxDist = maxHorseThreshold or 80

    -- If far away, ride horse to the set's staging point first
    if dist > maxDist then
        local staging = FISH.getStagingPoint()
        if staging and (r.Position - staging).Magnitude > 25 then
            logAction("TRAVEL", string.format("Legit Fishing: Spot is %.0f studs away. Riding horse to staging point...", dist), Color3.fromRGB(90, 180, 255), "TRAVEL")
            if horseTeleport(staging) then
                landBeside(staging, 4)
            end
        end
        if isMounted(myHorse()) or (h and h.Sit) then
            dismount()
            task.wait(0.4)
        end
    end

    -- Guarantee player is standing on foot
    if isMounted(myHorse()) or (h and h.Sit) then
        dismount()
        task.wait(0.3)
    end

    -- Execute Baritone Weighted A* pathfinding via Navigation module
    local nav = getNav()
    local walkFn = nav.walkTo or (ctx and ctx.Navigation and ctx.Navigation.walkTo) or SHARED.walkTo
    if walkFn then
        return walkFn(p, {
            timeout = 180,
            stopDist = 3.5,
            sprint = true,
            visualize = S().visualizeLegit ~= false,
        })
    else
        h:MoveTo(p)
        return true
    end
end

-- ============================================================
-- 5. WATER AIMING & CHARGED CASTING
-- ============================================================
local function cursorPos()
    local ok, ml = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and ml then return ml end
    local c = Workspace.CurrentCamera
    return Vector2.new(c.ViewportSize.X / 2, c.ViewportSize.Y / 2)
end

local function rayDirFor(camCF, px, py)
    local cam = Workspace.CurrentCamera
    if not cam then return Vector3.new(0, 0, -1) end
    local vpX, vpY = cam.ViewportSize.X, cam.ViewportSize.Y
    local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
    local aspect = vpX / vpY
    local ndcX = (px - vpX / 2) / (vpX / 2)
    local ndcY = (py - vpY / 2) / (vpY / 2)
    local dirCam = Vector3.new(ndcX * tanHalf * aspect, -ndcY * tanHalf, -1).Unit
    return camCF:VectorToWorldSpace(dirCam)
end

local function aimAtWater(customLook)
    local r = root()
    local cam = Workspace.CurrentCamera
    if not r or not cam then return false end

    local eye = r.Position + Vector3.new(0, 5, 0)
    local ml = cursorPos()

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = false
    local ex = { char() }
    for _, n in ipairs({ "Effects", "MouseIgnore", "ProjectileContainer", "Entities" }) do
        local f = Workspace:FindFirstChild(n)
        if f then table.insert(ex, f) end
    end
    rp.FilterDescendantsInstances = ex

    local bestCF, bestScore
    for yawDeg = 0, 350, 8 do
        for pitchDeg = -45, 20, 6 do
            local cf = CFrame.new(eye) * CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(math.rad(pitchDeg), 0, 0)
            local dir = rayDirFor(cf, ml.X, ml.Y)
            local hit = Workspace:Raycast(eye, dir * 140, rp)
            if hit then
                local isWaterMat = hit.Material == Enum.Material.Water
                local isWaterInstance = hit.Instance and (hit.Instance.Name:lower():find("water") or hit.Instance.Name:lower():find("river"))
                if isWaterMat or isWaterInstance then
                    local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(eye.X, 0, eye.Z)).Magnitude
                    if d >= 10 and d <= 120 then
                        local score = math.abs(d - 65)
                        if not bestScore or score < bestScore then
                            bestCF, bestScore = cf, score
                        end
                    end
                end
            end
        end
    end

    if not bestCF then
        if customLook then
            local cf = CFrame.new(eye, eye + Vector3.new(customLook.X, -0.2, customLook.Z))
            cam.CFrame = cf
            pcall(function()
                r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(customLook.X, 0, customLook.Z))
            end)
            FISH.status = "aimed at custom spot facing"
            return true
        end
        FISH.status = "no castable water in view"
        logAction("FISH", "No castable water in view", Color3.fromRGB(245, 160, 60), "FISHING")
        return false
    end

    cam.CFrame = bestCF
    local look = bestCF.LookVector
    pcall(function()
        r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(look.X, 0, look.Z))
    end)
    RunService.Heartbeat:Wait()
    FISH.status = "aimed at water"
    return true
end

-- ============================================================
-- 6. ZERO-LAG CHARACTER-SCOPED BITE WATCHER
-- ============================================================
local function strikeAndReel()
    tappedThisCast = true
    task.wait(S().reelDelay or 0.15)

    -- Strike the line
    local IH = getgenv().IH or SHARED.IH
    if IH then
        pcall(function() IH:FireVirtualInput("PrimaryInput", true) end)
        task.wait(0.04)
        pcall(function() IH:FireVirtualInput("PrimaryInput", false) end)
    else
        tap("PrimaryInput", 0.05)
    end

    FISH.status = "BITE - reeling"
    logAction("BITE", "Fish bite sound detected! Striking & reeling...", Color3.fromRGB(255, 175, 50), "BITE")

    -- Sustain reeling until catch animation triggers or minigame begins
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < 9 and S().running and S().autoFish do
            if LP:GetAttribute("IsMashing") == true or LP:GetAttribute("IsShaking") == true then
                break
            end
            local a = anims()
            if a.Success or a.BringBack then break end
            if not a.ReelLoop and (os.clock() - t0 > 1.2) then break end

            if IH then
                pcall(function() IH:FireVirtualInput("PrimaryInput", true) end)
                task.wait(0.03)
                pcall(function() IH:FireVirtualInput("PrimaryInput", false) end)
            else
                tap("PrimaryInput", 0.03)
            end
            task.wait(0.18 + math.random() * 0.05)
        end
    end)
end

local function startBiteWatch()
    if biteWatchRunning then return end
    biteWatchRunning = true

    task.spawn(function()
        local op = OverlapParams.new()
        op.MaxParts = 25
        op.FilterType = Enum.RaycastFilterType.Include

        while S().running and S().autoFish and castPhase == "casted" and not tappedThisCast do
            -- Allow line 1.2s to land in the water before listening
            if os.clock() - lastCast > 1.2 then
                local c = char()
                local r = root()
                local detected = false

                -- 1. Check Character descendants (~50 instances) - completely lag-free
                if c then
                    for _, sfx in ipairs(c:GetDescendants()) do
                        if sfx:IsA("Sound") and sfx.IsPlaying then
                            local sn = sfx.Name:lower()
                            if sn:find("bite") or sn:find("splash") or sn:find("reel") or sn == "fishbite" or sn == "bitecrunch" then
                                detected = true
                                break
                            end
                        end
                    end
                end

                -- 2. Bounded spatial query fallback (75 studs radius around character)
                if not detected and r then
                    local nearby = Workspace:GetPartBoundsInRadius(r.Position, 75, op)
                    for _, part in ipairs(nearby) do
                        for _, sfx in ipairs(part:GetChildren()) do
                            if sfx:IsA("Sound") and sfx.IsPlaying then
                                local sn = sfx.Name:lower()
                                if sn:find("bite") or sn:find("splash") or sn:find("reel") or sn == "fishbite" or sn == "bitecrunch" then
                                    detected = true
                                    break
                                end
                            end
                        end
                        if detected then break end
                    end
                end

                if detected then
                    strikeAndReel()
                    break
                end
            end
            task.wait(0.08)
        end
        biteWatchRunning = false
    end)
end

-- ============================================================
-- 7. MINIGAME QTE AUTOMATION
-- ============================================================
local QTE_VK = { R = 0x52, T = 0x54, G = 0x47, F = 0x46, Z = 0x5A, Y = 0x59, H = 0x48, B = 0x42 }
local keypressFn = keypress or (syn and syn.keypress) or (fluxus and fluxus.keypress)
local keyreleaseFn = keyrelease or (syn and syn.keyrelease) or (fluxus and fluxus.keyrelease)
local keyclickFn = keyclick
local lastQTEKey = 0

local function qteTap(k)
    local vk = QTE_VK[tostring(k):upper()]
    if not vk then return end
    if keyclickFn then
        pcall(keyclickFn, vk)
    elseif keypressFn and keyreleaseFn then
        pcall(keypressFn, vk)
        task.wait(0.03)
        pcall(keyreleaseFn, vk)
    end
end

local function guiObj(n)
    local g = LP:FindFirstChildOfClass("PlayerGui")
    return g and g:FindFirstChild(n)
end

local function handleQTE()
    if not S().autoQTE then return false end

    local ms = guiObj("MashingSystem")
    local mashing = LP:GetAttribute("IsMashing") == true
    local reacting = LP:GetAttribute("IsReacting") == true
    local shaking = LP:GetAttribute("IsShaking") == true

    -- Mashing / Shaking Minigame
    if mashing or shaking then
        tappedThisCast = true
        local key = "G"
        local ct = ms and ms:FindFirstChild("Container")
        local circle = ct and ct:FindFirstChild("Circle")
        local lab = circle and circle:FindFirstChild("KeyLabel")
        if lab and lab.Text ~= "" then key = lab.Text end

        if os.clock() - lastQTEKey > 0.045 then
            lastQTEKey = os.clock()
            qteTap(key)
        end
        FISH.status = "mashing [" .. tostring(key) .. "]"
        return true
    end

    -- Reaction Circle Minigame
    if reacting then
        tappedThisCast = true
        local rc = ms and ms:FindFirstChild("ReactionCircle")
        if rc and rc.Visible then
            local lab = rc:FindFirstChild("KeyLabel")
            local key = (lab and lab.Text ~= "" and lab.Text) or "Z"
            if os.clock() - lastQTEKey > 0.20 then
                lastQTEKey = os.clock()
                task.wait(0.22)
                qteTap(key)
            end
            FISH.status = "reaction [" .. tostring(key) .. "]"
            return true
        end
    end

    -- Dot Minigame (tracking cursor to goal zone)
    local dot = guiObj("DotMinigameGui")
    if dot and dot.Enabled then
        tappedThisCast = true
        local d, gz = dot:FindFirstChild("Dot"), dot:FindFirstChild("GoalZone")
        local mr = mousemoverel
        if d and gz and mr then
            local dc = d.AbsolutePosition + d.AbsoluteSize / 2
            local gc = gz.AbsolutePosition + gz.AbsoluteSize / 2
            local delta = gc - dc
            pcall(mr, math.clamp(delta.X / 6, -40, 40), math.clamp(delta.Y / 6, -40, 40))
        end
        FISH.status = "tracking dot minigame"
        return true
    end

    return false
end

-- ============================================================
-- 8. DANIEL VENDOR AUTOMATION (SELLING & BAIT RESTOCK)
-- ============================================================
local function dialogueGui()
    local g = LP:FindFirstChildOfClass("PlayerGui")
    return g and g:FindFirstChild("DialogueGui")
end

local function dialogueOpen()
    local dg = dialogueGui()
    return dg ~= nil and dg.Enabled
end

local function choiceButtons()
    local dg = dialogueGui()
    if not dg or not dg.Enabled then return {} end
    local mf = dg:FindFirstChild("MainFrame")
    local cl = mf and mf:FindFirstChild("ChoiceList")
    local out = {}
    if cl then
        for _, b in ipairs(cl:GetChildren()) do
            if b:IsA("TextButton") and b.Visible and b.Name ~= "TemplateButton" and tostring(b.Text) ~= "" then
                table.insert(out, b)
            end
        end
    end
    return out
end

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
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(b.AbsolutePosition.X + b.AbsoluteSize.X / 2, b.AbsolutePosition.Y + b.AbsoluteSize.Y / 2, 0, true, game, 0)
        task.wait(0.04)
        VirtualInputManager:SendMouseButtonEvent(b.AbsolutePosition.X + b.AbsoluteSize.X / 2, b.AbsolutePosition.Y + b.AbsoluteSize.Y / 2, 0, false, game, 0)
    end)
    return true
end

local function pickChoice(pattern, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 5) do
        for _, b in ipairs(choiceButtons()) do
            if tostring(b.Text):lower():find(pattern:lower(), 1, true) then
                pressChoice(b)
                return true, b.Text
            end
        end
        task.wait(0.25)
    end
    return false
end

local function listChoices()
    local t = {}
    for _, b in ipairs(choiceButtons()) do table.insert(t, tostring(b.Text)) end
    return t
end

local function closeDialogue()
    for _ = 1, 5 do
        if not dialogueOpen() then return true end
        for _, b in ipairs(choiceButtons()) do
            local tx = tostring(b.Text):lower()
            if tx:find("thanks") or tx:find("bye") or tx:find("nevermind") or tx:find("later") or tx:find("passing") then
                pressChoice(b)
                break
            end
        end
        task.wait(0.5)
    end
    return not dialogueOpen()
end

local function findNPC(name)
    local f = Workspace:FindFirstChild("NPC")
    local n = f and f:FindFirstChild(name)
    if n then return n end
    local ent = Workspace:FindFirstChild("Entities")
    local ne = ent and ent:FindFirstChild(name)
    if ne then return ne end
    return nil
end

local function openNPC(name)
    local npc = findNPC(name)
    if not npc then return false, "NPC not found" end
    local cd = npc:FindFirstChildOfClass("ClickDetector") or npc:FindFirstChildWhichIsA("ClickDetector", true)
    if not cd then return false, "No ClickDetector" end
    local fireclick = fireclickdetector or (getgenv and getgenv().fire_click_detector)

    closeDialogue()
    task.wait(0.3)
    for _ = 1, 5 do
        if dialogueOpen() and #choiceButtons() > 0 then return true end
        if fireclick then pcall(fireclick, cd) end
        local t0 = os.clock()
        while os.clock() - t0 < 2.0 do
            if dialogueOpen() and #choiceButtons() > 0 then return true end
            task.wait(0.15)
        end
    end
    return dialogueOpen()
end

local function pinTo(getPos)
    local c, h = char(), hum()
    local restore = {}
    if c then
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") then
                restore[d] = d.CanCollide
                pcall(function() d.CanCollide = false end)
            end
        end
    end
    if h then pcall(function() h.Sit = true end) end
    local conn = RunService.Heartbeat:Connect(function()
        local r = root()
        local tp = getPos()
        if r and tp then
            r.CFrame = CFrame.new(tp)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    return function()
        pcall(function() conn:Disconnect() end)
        local h2 = hum()
        if h2 then pcall(function() h2.Sit = false end) end
        task.wait(0.1)
        for part, v in pairs(restore) do
            if part.Parent then pcall(function() part.CanCollide = v end) end
        end
    end
end

local function travelToVendor(target)
    local r = root()
    local d = r and (r.Position - target).Magnitude or 999
    if d <= 12 then return true end

    if S().legitFishing and d <= 300 then
        logAction("TRAVEL", string.format("Legit Fishing: Traveling to Daniel on foot (%.0f studs away)...", d), Color3.fromRGB(90, 180, 255), "TRAVEL")
        return FISH.walkToSpotLegit(target, 300)
    else
        logAction("TRAVEL", string.format("Traveling to Daniel via horse (%.0f studs away)...", d), Color3.fromRGB(90, 180, 255), "TRAVEL")
        if horseTeleport(target) then
            landBeside(target, 5)
            return true
        end
        return false
    end
end

local function sellAllFish()
    if isSellingFish then return false end
    isSellingFish = true
    local lotsSold = 0
    local totalMoola = 0

    local ok, res = pcall(function()
        local _, fCount = getFishCounts()
        if fCount == 0 then
            logAction("SELLING", "No fish in inventory to sell", Color3.fromRGB(160, 165, 180), "SELLING")
            return false
        end

        local npc = findNPC("Daniel")
        local target = DANIEL_POS
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then target = p.Position + Vector3.new(0, 0, 6) end
        end

        if not travelToVendor(target) then
            logAction("SELLING", "Failed to travel to Daniel", Color3.fromRGB(245, 90, 90), "ERROR")
            return false
        end

        pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
        task.wait(0.3)

        local unpin
        npc = findNPC("Daniel")
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then
                unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
                task.wait(0.8)
            end
        end

        if not openNPC("Daniel") then
            logAction("SELLING", "Failed to open dialogue with Daniel", Color3.fromRGB(245, 90, 90), "ERROR")
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.5)

        if not pickChoice("fish to sell", 5) then
            logAction("SELLING", "No 'Fish to sell' option found", Color3.fromRGB(245, 90, 90), "ERROR")
            closeDialogue()
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.8)

        local before = moola()
        for _ = 1, 20 do
            local targetBtn = nil
            for _, b in ipairs(choiceButtons()) do
                local tx = tostring(b.Text):lower()
                if tx:find("sell all", 1, true) then
                    targetBtn = b
                    break
                elseif tx:match("^%s*sell%s+%d") or tx:match("^%s*sell%s+%a") then
                    targetBtn = b
                end
            end

            if not targetBtn then break end
            local m0 = moola()
            pressChoice(targetBtn)
            task.wait(1.0)
            if moola() > m0 then
                lotsSold = lotsSold + 1
            else
                break
            end
        end

        closeDialogue()
        if unpin then pcall(unpin) end
        totalMoola = moola() - before

        if lotsSold > 0 then
            logAction("SELLING", string.format("Sold %d fish lot(s) for +$%d Moola!", lotsSold, totalMoola), Color3.fromRGB(60, 240, 140), "SUCCESS")
        end
        return lotsSold > 0
    end)

    isSellingFish = false
    return ok and res or false
end

local function buyBait()
    if isRestockingBait then return false end
    isRestockingBait = true

    local ok, res = pcall(function()
        local npc = findNPC("Daniel")
        local target = DANIEL_POS
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then target = p.Position + Vector3.new(0, 0, 6) end
        end

        if not travelToVendor(target) then return false end
        pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
        task.wait(0.3)

        local unpin
        npc = findNPC("Daniel")
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then
                unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
                task.wait(0.8)
            end
        end

        if not openNPC("Daniel") then
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.5)

        local beforeBait = countTool("Bait")
        if not pickChoice("gear", 5) then
            closeDialogue()
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.8)

        if not pickChoice("bait", 5) then
            closeDialogue()
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.8)

        local m = moola()
        local tiers = {
            { label = "50 ($500)", cost = 500 },
            { label = "10 ($100)", cost = 100 },
            { label = "5 ($10)",   cost = 10 },
            { label = "1 ($10)",   cost = 10 },
        }
        for _, t in ipairs(tiers) do
            if m >= t.cost then
                if pickChoice(t.label, 3) then break end
            end
        end

        task.wait(1.2)
        closeDialogue()
        if unpin then pcall(unpin) end

        local afterBait = countTool("Bait")
        local gained = afterBait - beforeBait
        if gained > 0 then
            logAction("RESTOCK", string.format("Purchased %d bait! (Total now: %d)", gained, afterBait), Color3.fromRGB(60, 240, 140), "SUCCESS")
        end
        return gained > 0
    end)

    isRestockingBait = false
    return ok and res or false
end

local function buyRod()
    if isBuyingRod then return false end
    isBuyingRod = true

    local ok, res = pcall(function()
        if findTool("FishingRod") then
            logAction("RESTOCK", "You already have a FishingRod!", Color3.fromRGB(80, 220, 140), "RESTOCK")
            return true
        end

        local m = moola()
        if m < 150 then
            logAction("RESTOCK", string.format("Insufficient Moola for rod ($150 required, you have $%d)", m), Color3.fromRGB(245, 90, 90), "ERROR")
            return false
        end

        local npc = findNPC("Daniel")
        local target = DANIEL_POS
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then target = p.Position + Vector3.new(0, 0, 6) end
        end

        if not travelToVendor(target) then return false end
        pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
        task.wait(0.3)

        local unpin
        npc = findNPC("Daniel")
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then
                unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
                task.wait(0.8)
            end
        end

        if not openNPC("Daniel") then
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.5)

        if not pickChoice("gear", 5) then
            closeDialogue()
            if unpin then pcall(unpin) end
            return false
        end
        task.wait(0.8)

        if not pickChoice("fishing rod", 5) then
            closeDialogue()
            if unpin then pcall(unpin) end
            return false
        end

        task.wait(1.2)
        closeDialogue()
        if unpin then pcall(unpin) end

        if findTool("FishingRod") then
            logAction("RESTOCK", "Successfully purchased FishingRod ($150)!", Color3.fromRGB(60, 240, 140), "SUCCESS")
            return true
        end
        return false
    end)

    isBuyingRod = false
    return ok and res or false
end

local function ensureRod()
    if findTool("FishingRod") then
        return equipTool("FishingRod")
    end
    if moola() >= 150 then
        logAction("FISH", "Fishing rod missing! Auto-purchasing from Daniel ($150)...", Color3.fromRGB(245, 175, 60), "RESTOCK")
        if buyRod() then
            task.wait(0.8)
            if findTool("FishingRod") then return equipTool("FishingRod") end
        end
    end
    FISH.status = "no rod - buy from Daniel ($150)"
    return false
end

-- ============================================================
-- 9. MAIN FISHING FSM (TICK LOOP)
-- ============================================================
local function fishTick()
    if not S().running or not S().autoFish then return end
    local r, h = root(), hum()
    if not r or not h or h.Health <= 0 then return end
    if isSellingFish or isRestockingBait or isBuyingRod then return end

    -- Check if Navigation is actively walking to avoid interrupting pathfinding
    local nav = getNav()
    if nav.isWalking then return end

    -- 1. Handle Minigames
    if handleQTE() then
        local t0 = os.clock()
        while os.clock() - t0 < 10 and S().running and S().autoFish do
            if not handleQTE() then break end
            task.wait(0.03)
        end
        return
    end

    -- 2. Check Catch Detection (Inventory Count or Success/BringBack Animation)
    local _, curTotalFish = getFishCounts()
    if curTotalFish > lastKnownFishTotal and not isSellingFish then
        local delta = curTotalFish - lastKnownFishTotal
        lastKnownFishTotal = curTotalFish
        recordCatch("Inventory", delta)
        lastCatchTime = os.clock()
    elseif curTotalFish < lastKnownFishTotal then
        lastKnownFishTotal = curTotalFish
    end

    if curTotalFish > FISH.catches then
        FISH.catches = curTotalFish
        local UI = (ctx and ctx.UI) or SHARED.UI
        if UI and UI.updateHud then pcall(UI.updateHud) end
    end

    local a = anims()
    if (a.Success or (a.BringBack and (tappedThisCast or (lastCast > 0 and os.clock() - lastCast > 1.5)))) and castPhase == "casted" then
        if os.clock() - lastCatchTime > 1.0 then
            recordCatch(a.Success and "Success Animation" or "BringBack Animation", 1)
            lastCatchTime = os.clock()
        end
        tappedThisCast = false
        castPhase = "idle"
        lastCast = 0

        -- Auto-Sell fish periodically
        if S().autoSell and FISH.catches > 0 and (FISH.catches % math.max(1, S().sellEvery or 10) == 0) then
            task.spawn(function()
                if sellAllFish() then
                    logAction("TRAVEL", "Returning to fishing spot...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    local spots = FISH.getActiveSpots()
                    local spot = spots[spotIndex]
                    if S().legitFishing then
                        FISH.walkToSpotLegit(spot, 300)
                    else
                        if horseTeleport(spot) then landBeside(spot, 3) end
                    end
                end
            end)
            return
        end
        task.wait(0.8)
        return
    end

    if a.ReelLoop then
        FISH.status = "reeling it in"
        return
    end

    -- 3. Check Out-of-Money Auto Sell
    if S().autoSellOutOfMoney and moola() <= (S().lowMoneyThreshold or 10) then
        local _, fCount = getFishCounts()
        if fCount > 0 then
            task.spawn(function()
                if sellAllFish() then
                    local spots = FISH.getActiveSpots()
                    local spot = spots[spotIndex]
                    if S().legitFishing then
                        FISH.walkToSpotLegit(spot, 300)
                    else
                        if horseTeleport(spot) then landBeside(spot, 3) end
                    end
                end
            end)
            return
        end
    end

    -- 4. Check Bait Restock
    local bait = countTool("Bait")
    if bait < 1 and S().requireBait then
        if S().autoRestock and not isRestockingBait and not isSellingFish then
            task.spawn(function()
                local m = moola()
                local _, fCount = getFishCounts()
                if m < 10 and fCount > 0 then
                    logAction("RESTOCK", string.format("Low funds ($%d) for bait! Selling %d fish first...", m, fCount), Color3.fromRGB(245, 175, 60), "SELLING")
                    sellAllFish()
                end
                if buyBait() then
                    logAction("TRAVEL", "Returning to fishing spot with fresh bait...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    local spots = FISH.getActiveSpots()
                    local spot = spots[spotIndex]
                    if S().legitFishing then
                        FISH.walkToSpotLegit(spot, 300)
                    else
                        if horseTeleport(spot) then landBeside(spot, 3) end
                    end
                end
            end)
        else
            FISH.status = "out of bait (waiting for restock)"
        end
        return
    end

    -- 5. Monitor Casted Phase & Dead Cast Timeout
    if castPhase == "casted" then
        if os.clock() - lastCast > (S().castTimeout or 22) then
            castPhase = "idle"
            lastCast = 0
            FISH.dead = (FISH.dead or 0) + 1
            FISH.status = string.format("no bite within %ds — recasting (%d dead)", S().castTimeout or 22, FISH.dead)
            logAction("FISH", FISH.status, Color3.fromRGB(245, 160, 60), "FISHING")

            local spots = FISH.getActiveSpots()
            if FISH.dead >= (S().deadCastsBeforeMove or 3) then
                FISH.dead = 0
                spotIndex = (spotIndex % #spots) + 1
                local nextSpot = spots[spotIndex]
                FISH.status = "rotating to spot #" .. spotIndex
                logAction("FISH", string.format("Dead casts reached %d — rotating to Spot #%d", S().deadCastsBeforeMove or 3, spotIndex), Color3.fromRGB(180, 140, 255), "TRAVEL")
                if S().legitFishing then
                    FISH.walkToSpotLegit(nextSpot)
                else
                    if horseTeleport(nextSpot) then
                        landBeside(nextSpot, 3)
                        local l = spotLook(nextSpot)
                        local rr = root()
                        if l and rr then
                            pcall(function() rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z)) end)
                        end
                    end
                end
            end
            return
        end

        local waitElapsed = math.floor(os.clock() - lastCast)
        FISH.status = string.format("waiting for bite (%ds) | casts %d catches %d", waitElapsed, FISH.casts, FISH.catches)
        return
    end

    -- 6. Guarantee Player is on Foot and Close to Target Spot
    if isMounted(myHorse()) or (h and h.Sit) then
        FISH.status = "dismounting horse..."
        dismount()
        task.wait(0.3)
        return
    end

    local spots = FISH.getActiveSpots()
    local curSpot = spots[spotIndex]
    local p = spotPos(curSpot)
    if not p then return end

    if (r.Position - p).Magnitude > 35 then
        FISH.status = "traveling to fishing spot"
        logAction("TRAVEL", string.format("Traveling to fishing spot #%d (%.0f studs away)...", spotIndex, (r.Position - p).Magnitude), Color3.fromRGB(90, 180, 255), "TRAVEL")
        if S().legitFishing then
            FISH.walkToSpotLegit(curSpot)
        else
            if horseTeleport(curSpot) then
                landBeside(curSpot, 3)
                local l = spotLook(curSpot)
                local rr = root()
                if l and rr then
                    pcall(function() rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z)) end)
                end
            end
        end
        return
    end

    -- 7. Equip Rod and Cast Line
    if not ensureRod() then return end

    local sLook = spotLook(curSpot)
    if not aimAtWater(sLook) then return end

    -- Charged cast throw: hold PrimaryInput for 0.35s
    local IH = getgenv().IH or SHARED.IH
    if IH then
        pcall(function() IH:FireVirtualInput("PrimaryInput", true) end)
        task.wait(0.35)
        pcall(function() IH:FireVirtualInput("PrimaryInput", false) end)
    else
        tap("PrimaryInput", 0.35)
    end

    lastCast = os.clock()
    castPhase = "casted"
    tappedThisCast = false
    startBiteWatch()

    FISH.casts = (FISH.casts or 0) + 1
    local baitStr = bait > 0 and (" (bait " .. bait .. ")") or " (no bait)"
    FISH.status = "cast #" .. FISH.casts .. baitStr
    logAction("FISH", string.format("Cast #%d launched towards water%s", FISH.casts, baitStr), Color3.fromRGB(80, 220, 140), "FISHING",
        string.format("Spot #%d | Catches: %d", spotIndex, FISH.catches))
end

-- ============================================================
-- 10. PUBLIC CONTROLLER FUNCTIONS
-- ============================================================
local function startFishing()
    S().autoFish = true
    FISH.casts, FISH.dead = 0, 0
    castPhase, lastCast = "idle", 0
    tappedThisCast = false
    FISH.status = "starting"
    logAction("FISH", "Starting Auto-Fish routine...", Color3.fromRGB(80, 220, 140), "FISHING")

    local loopFn = (ctx and ctx.loop) or SHARED.loop
    if loopFn then
        loopFn("autoFish", 0.25, fishTick)
    end
end

local function stopFishing()
    S().autoFish = false
    local loops = (ctx and ctx.loops) or SHARED.loops
    if loops then loops["autoFish"] = false end
    castPhase, lastCast = "idle", 0
    tappedThisCast = false
    FISH.status = "stopped"
    logAction("FISH", "Stopped Auto-Fish", Color3.fromRGB(160, 165, 180), "IDLE")

    local nav = getNav()
    if nav.cancel then pcall(nav.cancel) end
end

-- Global helper binds
getgenv().BW3_BuyBait = function() return buyBait() end
getgenv().BW3_SellFish = function() return sellAllFish() end
getgenv().BW3_StartFish = function() startFishing() end
getgenv().BW3_StopFish = function() stopFishing() end

return {
    FISH = FISH,
    FISH_SPOTS = DEFAULT_SPOTS,
    spotIndex = spotIndex,
    DANIEL_POS = DANIEL_POS,
    DEFAULT_SPOTS = DEFAULT_SPOTS,
    DEFAULT_STAGING = DEFAULT_STAGING,
    startFishing = startFishing,
    stopFishing = stopFishing,
    fishTick = fishTick,
    aimAtWater = aimAtWater,
    handleQTE = handleQTE,
    ensureRod = ensureRod,
    startBiteWatch = startBiteWatch,
    sellAllFish = sellAllFish,
    buyBait = buyBait,
    buyRod = buyRod,
    dialogueOpen = dialogueOpen,
    listChoices = listChoices,
    spotPos = spotPos,
    spotLook = spotLook,
}
