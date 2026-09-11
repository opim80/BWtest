--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Fishing
-- Spots manager, A* pathfinding, Water raycasting, QTE & Loop
-- ============================================================
local ctx = ...


-- ── fishing ────────────────────────────────────────────────────────────────
local ANIM = {
    ["99374973462906"] = "SwingRod", ["85381268135994"] = "ReelLoop",
    ["98675703339517"] = "BringBack", ["99032819855540"] = "RodIdle",
    ["124675900911926"] = "Success",
}
local function anims()
    local h = hum()
    local an = h and h:FindFirstChildOfClass("Animator")
    if not an then return {} end
    local out = {}
    for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
        local id = tostring(tr.Animation and tr.Animation.AnimationId):match("(%d+)")
        if id and ANIM[id] then out[ANIM[id]] = true end
    end
    return out
end

local FISH_SPOTS = (S.fishingSets and S.fishingSets[FISH.getActiveSetIdx()]) or {
    Vector3.new(-3131.6, 47.12, -3717.2),
    Vector3.new(-3139.6, 47.12, -3717.2),
    Vector3.new(-3147.6, 47.12, -3709.2),
}
local spotIndex = 1
FISH = (FISH or { status = "idle", casts = 0, catches = 0, dead = 0 }) :: any

FISH.viz = {
    targetSpot = nil,
    currentSpeed = 16,
    currentAction = "Idle",
    drawLines = {},
    drawCircles = {},
    drawTexts = {},
    statusLabel = nil,
}

function FISH.getVizLine(idx) return nil end
function FISH.getVizCircle(idx) return nil end
function FISH.getVizText(idx) return nil end
function FISH.hideViz() end
function FISH.renderViz() end
function FISH.ensureViz() end

function FISH.setActiveSet(name)
    name = tostring(name or "Default")
    if not S.fishingSets or not S.fishingSets[name] then
        local names = FISH.getSetNames()
        name = names[1] or "Default"
    end
    S.activeFishingSet = name
    if S.fishingSets and S.fishingSets[name] then
        FISH_SPOTS = S.fishingSets[name]
    end
    spotIndex = 1
    logAction("FISH", string.format("Switched to Fishing Set '%s'", name), Color3.fromRGB(80, 220, 140), "FISHING")
    if UI and UI.activeSetDropdown then
        pcall(function() UI.activeSetDropdown:Refresh() end)
    end
    if UI and UI.refreshSpotsUI then
        pcall(function() UI.refreshSpotsUI() end)
    end
    if S.autoFish then
        task.spawn(function()
            local spot = FISH_SPOTS[spotIndex]
            if not spot then return end
            if S.legitFishing then
                FISH.walkToSpotLegit(spot)
            else
                if horseTeleport(spot) then
                    landBeside(spot, 3)
                    local l = spotLook(spot)
                    local rr = root()
                    if l and rr then
                        pcall(function()
                            rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                        end)
                    end
                end
            end
        end)
    end
end

function FISH.validateLegitPath(targetPos)
    local p = spotPos(targetPos)
    if p then
        return true, { p }
    end
    return false, nil
end

function FISH.validateAllSpots()
    local spots = FISH_SPOTS
    if not spots or #spots == 0 then return false, "No fishing spots in active set" end
    for i = 1, #spots do
        if not spotPos(spots[i]) then
            return false, string.format("Spot #%d is invalid", i)
        end
    end
    return true
end

function FISH.getStagingPoint(setName)
    setName = setName or FISH.getActiveSetName()
    local userStaging = S.stagingPoints and S.stagingPoints[setName]
    if userStaging then
        local p = spotPos(userStaging)
        if p then return p end
    end
    if setName == "Default" or not setName or setName == "" then
        return Vector3.new(-3125.0, 47.0, -3685.0)
    end
    return nil
end

function FISH.walkToSpotLegit(targetPos, maxHorseThreshold)
    local p = spotPos(targetPos)
    if not p then return false end
    local r, h = root(), hum()
    if not r or not h or h.Health <= 0 then return false end
    h:MoveTo(p)
    return true
end
local function cursorPos()
    local ok, ml = pcall(function() return UIS:GetMouseLocation() end)
    if ok and ml then return ml end
    local c = WS.CurrentCamera
    return Vector2.new(c.ViewportSize.X / 2, c.ViewportSize.Y / 2)
end

local function rayThroughCursor(maxDist)
    local camv = WS.CurrentCamera
    if not camv then return nil end
    local ml = cursorPos()
    local ray = camv:ViewportPointToRay(ml.X, ml.Y)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = false
    local ex = { char() }
    for _, n in ipairs({ "Effects", "MouseIgnore", "ProjectileContainer", "Entities" }) do
        local f = WS:FindFirstChild(n)
        if f then ex[#ex + 1] = f end
    end
    rp.FilterDescendantsInstances = ex
    return WS:Raycast(ray.Origin, ray.Direction * (maxDist or 400), rp)
end

local function rayDirFor(camCF, px, py)
    local camv = WS.CurrentCamera
    local vpX, vpY = camv.ViewportSize.X, camv.ViewportSize.Y
    local tanHalf = math.tan(math.rad(camv.FieldOfView) / 2)
    local aspect = vpX / vpY
    local ndcX = (px - vpX / 2) / (vpX / 2)
    local ndcY = (py - vpY / 2) / (vpY / 2)
    local dirCam = Vector3.new(ndcX * tanHalf * aspect, -ndcY * tanHalf, -1).Unit
    return camCF:VectorToWorldSpace(dirCam)
end

local function aimAtWater(customLook)
    local r = root()
    local camv = WS.CurrentCamera
    if not r or not camv then return false end
    local eye = r.Position + Vector3.new(0, 5, 0)
    local ml = cursorPos()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = false
    local ex = { char() }
    for _, n in ipairs({ "Effects", "MouseIgnore", "ProjectileContainer", "Entities" }) do
        local f = WS:FindFirstChild(n)
        if f then ex[#ex + 1] = f end
    end
    rp.FilterDescendantsInstances = ex

    local bestCF, bestD
    for yawDeg = 0, 350, 6 do
        for pitchDeg = -50, 25, 5 do
            local cf = CFrame.new(eye) * CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(math.rad(pitchDeg), 0, 0)
            local dir = rayDirFor(cf, ml.X, ml.Y)
            local hit = WS:Raycast(eye, dir * 200, rp)
            if hit and hit.Material == Enum.Material.Water then
                local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(eye.X, 0, eye.Z)).Magnitude
                if d > 40 and d < 120 then
                    local score = math.abs(d - 75)
                    if not bestD or score < bestD then bestCF, bestD = cf, score end
                end
            end
        end
    end
    if not bestCF then
        if customLook then
            local cf = CFrame.new(eye, eye + Vector3.new(customLook.X, -0.25, customLook.Z))
            camv.CFrame = cf
            pcall(function() r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(customLook.X, 0, customLook.Z)) end)
            FISH.status = "aimed at custom spot facing"
            return true
        end
        FISH.status = "no castable water in view"
        logAction("FISH", "No castable water in view", Color3.fromRGB(245, 160, 60), "FISHING")
        return false
    end
    camv.CFrame = bestCF
    local look = bestCF.LookVector
    pcall(function() r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(look.X, 0, look.Z)) end)
    RunService.Heartbeat:Wait()
    FISH.status = "aimed at water"
    logAction("FISH", "Locked onto water", Color3.fromRGB(80, 220, 140), "FISHING")
    return true
end

local QTE_VK = { R = 0x52, T = 0x54, G = 0x47, F = 0x46, Z = 0x5A, Y = 0x59, H = 0x48, B = 0x42 }
local lastQTEKey = 0
local function qteTap(k)
    local vk = QTE_VK[tostring(k):upper()]
    if not vk then return end
    if rbxActive then
        local ok, on = pcall(rbxActive)
        if ok and not on then return end
    end
    if keyclickFn then
        pcall(keyclickFn, vk)
    elseif keypressFn and keyreleaseFn then
        pcall(keypressFn, vk)
        task.wait(0.035)
        pcall(keyreleaseFn, vk)
    end
end
local function guiObj(n)
    local g = LP:FindFirstChildOfClass("PlayerGui")
    return g and g:FindFirstChild(n)
end
local function handleQTE()
    if not S.autoQTE then return false end
    tappedThisCast = true
    local ms = guiObj("MashingSystem")
    local mashing = LP:GetAttribute("IsMashing") == true
    local reacting = LP:GetAttribute("IsReacting") == true
    local shaking = LP:GetAttribute("IsShaking") == true
    if mashing or shaking then
        local key = "G"
        local ct = ms and ms:FindFirstChild("Container")
        local circle = ct and ct:FindFirstChild("Circle")
        local lab = circle and circle:FindFirstChild("KeyLabel")
        if lab and lab.Text ~= "" then key = lab.Text end
        if os.clock() - lastQTEKey > 0.045 then
            lastQTEKey = os.clock()
            qteTap(key)
        end
        FISH.status = "mashing " .. tostring(key)
        logAction("QTE", ("Minigame: Mashing key [%s]"):format(tostring(key)), Color3.fromRGB(255, 110, 130), "MINIGAME")
        return true
    end
    if reacting then
        local rc = ms and ms:FindFirstChild("ReactionCircle")
        if rc and rc.Visible then
            local lab = rc:FindFirstChild("KeyLabel")
            local key = (lab and lab.Text ~= "" and lab.Text) or "Z"
            if os.clock() - lastQTEKey > 0.18 then
                lastQTEKey = os.clock()
                task.wait(0.22)
                qteTap(key)
            end
            FISH.status = "reaction " .. tostring(key)
            logAction("QTE", ("Reaction QTE: Tapping [%s]"):format(tostring(key)), Color3.fromRGB(255, 110, 130), "MINIGAME")
            return true
        end
    end
    local dot = guiObj("DotMinigameGui")
    if dot and dot.Enabled then
        local d, gz = dot:FindFirstChild("Dot"), dot:FindFirstChild("GoalZone")
        local mr = cap("mousemoverel")
        if d and gz and mr then
            local dc = d.AbsolutePosition + d.AbsoluteSize / 2
            local gc = gz.AbsolutePosition + gz.AbsoluteSize / 2
            local delta = gc - dc
            pcall(mr, math.clamp(delta.X / 6, -45, 45), math.clamp(delta.Y / 6, -45, 45))
        end
        FISH.status = "minigame: dot"
        logAction("QTE", "Tracking cursor in Dot Minigame", Color3.fromRGB(255, 110, 130), "MINIGAME")
        return true
    end
    return false
end

local buyBait
local DANIEL_POS = Vector3.new(-3121.05, 46.34, -3618.09)

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
                out[#out + 1] = b
            end
        end
    end
    return out
end
local function pressChoice(b)
    if not b or not getcons then return false end
    local function fireCons()
        if not b or not b.Parent then return false end
        local ok, cons = pcall(getcons, b.MouseButton1Click)
        if not ok or not cons then return false end
        local fired = false
        for _, c in ipairs(cons) do
            if c.Function then pcall(c.Function); fired = true end
        end
        return fired
    end
    local ok = fireCons()
    task.wait(0.28)
    if b and b.Parent and b.Visible then fireCons() end
    return ok
end
local function pickChoice(pattern, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 6) do
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
    for _, b in ipairs(choiceButtons()) do t[#t + 1] = tostring(b.Text) end
    return t
end
local function closeDialogue()
    for _ = 1, 6 do
        if not dialogueOpen() then return true end
        local done = false
        for _, b in ipairs(choiceButtons()) do
            local tx = tostring(b.Text):lower()
            if tx:find("thanks") or tx:find("bye") or tx:find("nevermind") or tx:find("passing")
               or tx:find("changed") or tx:find("later") or tx:find("fear") then
                pressChoice(b); done = true; break
            end
        end
        if not done then return false end
        task.wait(0.7)
    end
    return not dialogueOpen()
end
local function findNPC(name)
    local f = WS:FindFirstChild("NPC")
    local n = f and f:FindFirstChild(name)
    if n then return n end
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("Model") and d.Name == name then return d end
    end
    return nil
end
local function openNPC(name)
    local npc = findNPC(name)
    if not npc then return false, "npc not found" end
    local cd = npc:FindFirstChildOfClass("ClickDetector")
    if not cd or not fireclick then return false, "no clickdetector" end
    closeDialogue()
    task.wait(0.3)
    for _ = 1, 6 do
        if dialogueOpen() and #choiceButtons() > 0 then return true end
        pcall(fireclick, cd)
        local t0 = os.clock()
        while os.clock() - t0 < 2.5 do
            if dialogueOpen() and #choiceButtons() > 0 then return true end
            local dg = dialogueGui()
            local mf = dg and dg:FindFirstChild("MainFrame")
            local nt = mf and mf:FindFirstChild("NPCText")
            if nt and tostring(nt.Text):find("Howdiddly", 1, true) then return true end
            task.wait(0.15)
        end
    end
    return dialogueOpen()
end

local VENDOR = { status = "idle", lastChoices = "" }

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
    if h then
        for _, st in ipairs({ Enum.HumanoidStateType.FallingDown,
                              Enum.HumanoidStateType.Freefall,
                              Enum.HumanoidStateType.Ragdoll }) do
            pcall(function() h:SetStateEnabled(st, false) end)
        end
        pcall(function() h.Sit = true end)
    end
    local conn = RunService.Heartbeat:Connect(function()
        local rr = root()
        local tp = getPos()
        if rr and tp then
            rr.CFrame = CFrame.new(tp)
            rr.AssemblyLinearVelocity = Vector3.zero
            rr.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    return function()
        pcall(function() conn:Disconnect() end)
        local h2 = hum()
        if h2 then
            pcall(function() h2.Sit = false end)
            for _, st in ipairs({ Enum.HumanoidStateType.FallingDown,
                                  Enum.HumanoidStateType.Freefall,
                                  Enum.HumanoidStateType.Ragdoll }) do
                pcall(function() h2:SetStateEnabled(st, true) end)
            end
        end
        task.wait(0.1)
        for part, v in pairs(restore) do
            if part.Parent then pcall(function() part.CanCollide = v end) end
        end
    end
end

local sellAllFish
local sellOnce
sellOnce = function()
    local _, initialFish = getFishCounts()
    setSellingStatus("Traveling to Daniel to sell fish...", ("Holding %d fish • Riding to vendor"):format(initialFish))
    logAction("SELLING", "Heading to Daniel to sell fish...", Color3.fromRGB(245, 175, 60), "SELLING", ("Fish count: %d"):format(initialFish))

    local npc = findNPC("Daniel")
    local target = DANIEL_POS
    if npc then
        local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
        if p then target = p.Position + Vector3.new(0, 0, 6) end
    end
    local r = root()
    local distToDaniel = r and (r.Position - target).Magnitude or 999
    if distToDaniel > 12 then
        if S.legitFishing and distToDaniel <= 300 then
            setSellingStatus("Walking to Daniel...", ("Target: Daniel • %d studs away (Legit Walk)"):format(math.floor(distToDaniel)))
            logAction("SELLING", ("Legit Fishing: Daniel is within 300 studs (%.0f studs). Walking on foot..."):format(distToDaniel), Color3.fromRGB(90, 180, 255), "SELLING")
            if not FISH.walkToSpotLegit(target, 300) then
                setSellingStatus("Failed to reach Daniel", "Walk to Daniel interrupted")
                logAction("SELLING", "Walk to Daniel interrupted", Color3.fromRGB(245, 90, 90), "ERROR")
                return false
            end
        else
            local distInitial = math.floor(distToDaniel)
            setSellingStatus("Riding horse to Daniel...", ("Target: Daniel • %d studs away"):format(distInitial))
            if not horseTeleport(target) then
                setSellingStatus("Failed to reach Daniel", "Horse travel failed")
                logAction("SELLING", "Could not reach Daniel", Color3.fromRGB(245, 90, 90), "ERROR")
                return false
            end
            landBeside(target, 5)
        end
    end
    pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
    task.wait(0.3)
    npc = findNPC("Daniel")
    local unpin
    if npc then
        local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
        if p then
            unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
            task.wait(1.2)
        end
    end

    setSellingStatus("Interacting with Daniel...", "Opening vendor dialogue...")
    logAction("SELLING", "Interacting with Daniel (Fish Buyer)...", Color3.fromRGB(245, 175, 60), "SELLING")

    if not openNPC("Daniel") then
        setSellingStatus("Failed to open dialogue", "NPC interaction timed out")
        logAction("SELLING", "Dialogue with Daniel failed to open", Color3.fromRGB(245, 90, 90), "ERROR")
        if unpin then pcall(unpin) end
        return false
    end
    task.wait(0.6)

    setSellingStatus("Selecting 'Fish to sell'...", "Navigating dialogue choices")
    logAction("SELLING", "Selecting 'Fish to sell' dialogue option...", Color3.fromRGB(245, 175, 60), "SELLING")

    if not pickChoice("fish to sell", 5) then
        setSellingStatus("No sell option found", table.concat(listChoices(), " | "))
        logAction("SELLING", "No fish sell dialogue option found", Color3.fromRGB(245, 90, 90), "ERROR")
        closeDialogue()
        if unpin then pcall(unpin) end
        return false
    end
    task.wait(0.9)

    local sold, before = 0, moola()
    for _ = 1, 25 do
        local bulk, single
        for _, b in ipairs(choiceButtons()) do
            local tx = tostring(b.Text):lower()
            if tx:find("sell all", 1, true) then
                if not bulk then bulk = b end
            elseif tx:match("^%s*sell%s+%d") or tx:match("^%s*sell%s+%a") then
                if not single then single = b end
            end
        end
        local target2 = bulk or single
        if not target2 then
            if not dialogueOpen() then
                if not openNPC("Daniel") then break end
                task.wait(0.5)
            end
            if not pickChoice("fish to sell", 3) then break end
            task.wait(0.9)
            bulk, single = nil, nil
            for _, b in ipairs(choiceButtons()) do
                local tx = tostring(b.Text):lower()
                if tx:find("sell all", 1, true) then
                    if not bulk then bulk = b end
                elseif tx:match("^%s*sell%s+%d") or tx:match("^%s*sell%s+%a") then
                    if not single then single = b end
                end
            end
            target2 = bulk or single
            if not target2 then break end
        end

        local m0 = moola()
        local itemText = tostring(target2.Text)
        setSellingStatus(("Selling: %s..."):format(itemText), ("Sold %d lot(s) • Balance: $%d"):format(sold, m0))
        logAction("SELLING", ("Selling lot: %s"):format(itemText), Color3.fromRGB(245, 175, 60), "SELLING", ("Current balance: $%d"):format(m0))

        pressChoice(target2)
        task.wait(1.1)
        if moola() > m0 then
            sold = sold + 1
            local diff = moola() - m0
            setSellingStatus(("Sold %s (+%d Moola)"):format(itemText, diff), ("Total Lots: %d • New Balance: $%d"):format(sold, moola()))
            logAction("SELLING", ("Sold %s for +$%d Moola!"):format(itemText, diff), Color3.fromRGB(60, 240, 140), "SELLING")
        else
            break
        end
    end

    closeDialogue()
    if unpin then pcall(unpin) end
    local gained = moola() - before
    if sold > 0 then
        setSellingStatus(("Sale Complete! (+%d Moola)"):format(gained), ("Sold %d lot(s) • Balance: $%d"):format(sold, moola()))
        logAction("SELLING", ("Sold %d lot(s) for +$%d moola"):format(sold, gained), Color3.fromRGB(60, 240, 140), "SELLING")
    end
    return sold > 0
end

sellAllFish = function()
    if isSellingFish then return false end
    isSellingFish = true
    local lots, total = 0, 0
    local ok, res = pcall(function()
        local _, fCount = getFishCounts()
        if fCount == 0 then
            setSellingStatus("No fish in inventory to sell", ("Current Moola: $%d"):format(moola()))
            logAction("SELLING", "No fish in inventory to sell", Color3.fromRGB(160, 165, 180), "SELLING")
            task.wait(1.2)
            return false
        end

        for i = 1, 8 do
            local before = moola()
            local okOne = sellOnce()
            local gained = moola() - before
            if gained > 0 then
                total = total + gained
                lots = lots + 1
            end
            if not okOne or gained <= 0 then break end
            task.wait(0.6)
        end

        if lots > 0 then
            setSellingStatus(("Sales Complete! (+%d Moola)"):format(total), ("Sold %d lot(s) • Balance: $%d"):format(lots, moola()))
            logAction("SELLING", ("Sales completed: %d lot(s) for +$%d total moola!"):format(lots, total), Color3.fromRGB(60, 240, 140), "SELLING")
            task.wait(1.5)
        else
            setSellingStatus("Finished checking vendor", ("Balance: $%d"):format(moola()))
            logAction("SELLING", "Fish sales completed or no further lots", Color3.fromRGB(160, 165, 180), "SELLING")
            task.wait(1)
        end
        return lots > 0
    end)
    isSellingFish = false
    return ok and res or false
end

buyBait = function()
    if isRestockingBait then return false end
    isRestockingBait = true
    local ok, res = pcall(function()
        Status.state = "RESTOCK"
        Status.color = Color3.fromRGB(245, 175, 60)
        Status.action = "Traveling to Daniel for bait..."
        Status.detail = "Riding horse to bait vendor"
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
        logAction("RESTOCK", "Travelling to Daniel for bait restock...", Color3.fromRGB(245, 175, 60), "RESTOCK")

        local npc = findNPC("Daniel")
        local target = DANIEL_POS
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then target = p.Position + Vector3.new(0, 0, 6) end
        end
        local r = root()
        local distToDaniel = r and (r.Position - target).Magnitude or 999
        if distToDaniel > 12 then
            if S.legitFishing and distToDaniel <= 300 then
                Status.action = ("Walking to Daniel (%d studs away)..."):format(math.floor(distToDaniel))
                Status.detail = "Walking to bait vendor on foot"
                if UI.updateBanner then pcall(UI.updateBanner) end
                if UI.updateHud then pcall(UI.updateHud) end
                if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
                logAction("RESTOCK", ("Legit Fishing: Daniel is within 300 studs (%.0f studs). Walking on foot..."):format(distToDaniel), Color3.fromRGB(90, 180, 255), "RESTOCK")
                if not FISH.walkToSpotLegit(target, 300) then
                    logAction("RESTOCK", "Walk to Daniel interrupted", Color3.fromRGB(245, 90, 90), "ERROR")
                    return false
                end
            else
                if not horseTeleport(target) then
                    logAction("RESTOCK", "Could not reach Daniel", Color3.fromRGB(245, 90, 90), "ERROR")
                    return false
                end
                landBeside(target, 5)
            end
        end
        pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
        task.wait(0.3)
        npc = findNPC("Daniel")
        local unpin
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then
                unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
                task.wait(1.2)
            end
        end
        VENDOR.unpin = unpin

        Status.action = "Opening shop dialogue with Daniel..."
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
        logAction("RESTOCK", "Opening shop dialogue with Daniel...", Color3.fromRGB(245, 175, 60), "RESTOCK")

        if not openNPC("Daniel") then
            logAction("RESTOCK", "Failed to open Daniel dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end
            return false
        end
        task.wait(0.6)

        Status.action = "Purchasing bait from Daniel..."
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end

        local before = countTool("Bait")
        if not pickChoice("gear", 5) then
            logAction("RESTOCK", "No Gear option found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            closeDialogue(); if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end; return false
        end
        task.wait(0.9)
        if not pickChoice("bait", 5) then
            logAction("RESTOCK", "No Bait option found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            closeDialogue(); if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end; return false
        end
        task.wait(0.9)
        local m = moola()
        local picked = false
        local tiers = {
            { label = "50 ($500)", qty = 50, cost = 500 },
            { label = "10 ($100)", qty = 10, cost = 100 },
            { label = "5 ($10)",   qty = 5,  cost = 10 },
            { label = "1 ($10)",   qty = 1,  cost = 10 },
        }
        for _, t in ipairs(tiers) do
            if m >= t.cost and S.baitKeep >= t.qty then
                if pickChoice(t.label, 3) then
                    picked = true
                    logAction("RESTOCK", ("Purchasing %d bait for $%d"):format(t.qty, t.cost), Color3.fromRGB(245, 175, 60), "RESTOCK")
                    break
                end
            end
        end
        if not picked then
            for _, t in ipairs(tiers) do
                if m >= t.cost and pickChoice(t.label, 2) then picked = true; break end
            end
        end
        task.wait(1.4)
        closeDialogue()
        if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end
        local after = countTool("Bait")
        local gained = after - before
        if gained > 0 then
            Status.action = ("Purchased %d bait! (Total: %d)"):format(gained, after)
            if UI.updateBanner then pcall(UI.updateBanner) end
            if UI.updateHud then pcall(UI.updateHud) end
            if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
            logAction("RESTOCK", ("Purchased %d bait! (Total now: %d)"):format(gained, after), Color3.fromRGB(60, 240, 140), "SUCCESS")
        else
            logAction("RESTOCK", "Bait purchase did not increase inventory count", Color3.fromRGB(245, 90, 90), "ERROR")
        end
        return after > before
    end)
    isRestockingBait = false
    return ok and res or false
end

local isBuyingRod = false
local buyRod
buyRod = function()
    if isBuyingRod then return false end
    isBuyingRod = true
    local ok, res = pcall(function()
        if findTool("FishingRod") then
            logAction("RESTOCK", "You already have a FishingRod in inventory!", Color3.fromRGB(80, 220, 140), "RESTOCK")
            return true
        end

        local m = moola()
        if m < 150 then
            logAction("RESTOCK", ("Insufficient Moola for FishingRod ($150 required, you have $%d)"):format(m), Color3.fromRGB(245, 90, 90), "ERROR")
            return false
        end

        Status.state = "RESTOCK"
        Status.color = Color3.fromRGB(245, 175, 60)
        Status.action = "Traveling to Daniel for Fishing Rod..."
        Status.detail = ("Riding to Daniel • Cost: $150 (Have: $%d)"):format(m)
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
        logAction("RESTOCK", "Heading to Daniel to purchase FishingRod ($150)...", Color3.fromRGB(245, 175, 60), "RESTOCK")

        local npc = findNPC("Daniel")
        local target = DANIEL_POS
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then target = p.Position + Vector3.new(0, 0, 6) end
        end

        local r = root()
        local distToDaniel = r and (r.Position - target).Magnitude or 999
        if distToDaniel > 12 then
            if S.legitFishing and distToDaniel <= 300 then
                Status.action = ("Walking to Daniel (%d studs away)..."):format(math.floor(distToDaniel))
                Status.detail = "Walking to bait vendor on foot"
                if UI.updateBanner then pcall(UI.updateBanner) end
                if UI.updateHud then pcall(UI.updateHud) end
                if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
                logAction("RESTOCK", ("Legit Fishing: Daniel is within 300 studs (%.0f studs). Walking on foot..."):format(distToDaniel), Color3.fromRGB(90, 180, 255), "RESTOCK")
                if not FISH.walkToSpotLegit(target, 300) then
                    logAction("RESTOCK", "Walk to Daniel interrupted", Color3.fromRGB(245, 90, 90), "ERROR")
                    return false
                end
            else
                if not horseTeleport(target) then
                    logAction("RESTOCK", "Could not reach Daniel", Color3.fromRGB(245, 90, 90), "ERROR")
                    return false
                end
                landBeside(target, 5)
            end
        end
        pcall(function() LP:RequestStreamAroundAsync(target, 8) end)
        task.wait(0.3)
        npc = findNPC("Daniel")
        local unpin
        if npc then
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if p then
                unpin = pinTo(function() return p.Position + Vector3.new(0, 3, 5) end)
                task.wait(1.0)
            end
        end
        VENDOR.unpin = unpin

        Status.action = "Opening shop dialogue with Daniel..."
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
        logAction("RESTOCK", "Opening shop dialogue with Daniel...", Color3.fromRGB(245, 175, 60), "RESTOCK")

        if not openNPC("Daniel") then
            logAction("RESTOCK", "Failed to open Daniel dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end
            return false
        end
        task.wait(0.6)

        Status.action = "Selecting gear options..."
        if not pickChoice("gear", 5) then
            logAction("RESTOCK", "No Gear option found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            closeDialogue()
            if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end
            return false
        end
        task.wait(0.9)

        Status.action = "Purchasing FishingRod ($150)..."
        if not (pickChoice("fishingrod", 5) or pickChoice("rod", 3)) then
            logAction("RESTOCK", "Buy FishingRod option not found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
            closeDialogue()
            if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end
            return false
        end
        task.wait(1.2)
        closeDialogue()
        if VENDOR.unpin then pcall(VENDOR.unpin); VENDOR.unpin = nil end

        if findTool("FishingRod") then
            logAction("RESTOCK", "FishingRod successfully purchased from Daniel!", Color3.fromRGB(60, 240, 140), "SUCCESS")
            return true
        else
            logAction("RESTOCK", "FishingRod purchase completed", Color3.fromRGB(245, 175, 60), "RESTOCK")
            return true
        end
    end)
    isBuyingRod = false
    return ok and res or false
end

local function findMudWitch()
    local f = WS:FindFirstChild("NPC")
    local w = f and f:FindFirstChild("Mud Witch")
    if w then return w end
    return findNPC("Mud Witch")
end

local function openMudWitch()
    local witch = findMudWitch()
    if not witch then return false, "Mud Witch not found" end
    local cd = witch:FindFirstChildOfClass("ClickDetector")
    if not cd or not fireclick then return false, "No ClickDetector on Mud Witch" end
    closeDialogue()
    task.wait(0.3)
    for _ = 1, 5 do
        if dialogueOpen() and #choiceButtons() > 0 then return true end
        pcall(fireclick, cd)
        local t0 = os.clock()
        while os.clock() - t0 < 2.5 do
            if dialogueOpen() and #choiceButtons() > 0 then return true end
            task.wait(0.15)
        end
    end
    return dialogueOpen()
end

local function readMudWitchFortune()
    logAction("WITCH", "Opening dialogue with Mud Witch...", Color3.fromRGB(180, 140, 255), "WITCH")
    local ok, err = openMudWitch()
    if not ok then
        logAction("WITCH", "Failed to interact with Mud Witch: " .. tostring(err), Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
    task.wait(0.4)
    local picked = pickChoice("fortune", 3)
    if picked then
        logAction("WITCH", "Requested card reading ('Read my fortune.')", Color3.fromRGB(80, 220, 140), "WITCH")
        return true
    else
        logAction("WITCH", "Fortune option not found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
end

local function talkMudWitchQuest()
    logAction("WITCH", "Opening dialogue with Mud Witch...", Color3.fromRGB(180, 140, 255), "WITCH")
    local ok, err = openMudWitch()
    if not ok then
        logAction("WITCH", "Failed to interact with Mud Witch: " .. tostring(err), Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
    task.wait(0.4)
    local picked = pickChoice("anything", 3)
    if picked then
        logAction("WITCH", "Asked Mud Witch: 'Anything I can do for you?'", Color3.fromRGB(80, 220, 140), "WITCH")
        return true
    else
        logAction("WITCH", "Quest option not found in dialogue", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end
end

local function ensureRod()
    if findTool("FishingRod") then return equipTool("FishingRod") end
    if moola() >= 150 then
        logAction("FISH", "Fishing rod missing! Auto-purchasing from Daniel ($150)...", Color3.fromRGB(245, 175, 60), "RESTOCK")
        if buyRod() then
            task.wait(1)
            if findTool("FishingRod") then return equipTool("FishingRod") end
        end
    end
    FISH.status = "no rod - buy one from Daniel ($150)"
    logAction("FISH", "Fishing rod missing! Purchase from Daniel ($150 required)", Color3.fromRGB(245, 90, 90), "ERROR")
    return false
end

-- lastCast, castPhase, tappedThisCast forward declared at top
tappedThisCast = false
local biteFlag = false

-- biteWatchStarted declared at top
local function startBiteWatch()
    if biteWatchStarted then return end
    biteWatchStarted = true
    task.spawn(function()
        while S.running do
            if S.autoFish and castPhase == "casted" and not tappedThisCast
               and os.clock() - lastCast > 1.5 then
                local r = root()
                if r then
                    for _, d in ipairs(WS:GetChildren()) do
                        if d:IsA("BasePart") and (d.Position - r.Position).Magnitude < 200 then
                            for _, sfx in ipairs(d:GetChildren()) do
                                if sfx:IsA("Sound") and sfx.IsPlaying then
                                    local sn = sfx.Name:lower()
                                    if sn:find("bite") or sn:find("splash") or sn:find("reel") or sn == "fishbite" or sn == "bitecrunch" then
                                    tappedThisCast = true
                                    _lastReelTap = os.clock()
                                    task.wait(S.reelDelay or 0.25)
                                    if IH then
                                        pcall(function() IH:FireVirtualInput("PrimaryInput", true) end)
                                        pcall(function() IH:FireVirtualInput("PrimaryInput", false) end)
                                    end
                                    FISH.status = "BITE - reeling"
                                    logAction("BITE", "Fish bite sound detected! Striking & reeling...", Color3.fromRGB(255, 175, 50), "BITE")
                                    task.spawn(function()
                                        local t1 = os.clock()
                                        while os.clock() - t1 < 8 and S.running do
                                            if LP:GetAttribute("IsMashing") == true
                                               or LP:GetAttribute("IsShaking") == true then break end
                                            local playing = false
                                            local hh = hum()
                                            local an = hh and hh:FindFirstChildOfClass("Animator")
                                            if an then
                                                for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
                                                    local id = tostring(tr.Animation and tr.Animation.AnimationId):match("(%d+)")
                                                    if id == "85381268135994" then playing = true; break end
                                                end
                                            end
                                            if not playing then break end
                                            if IH then
                                                pcall(function() IH:FireVirtualInput("PrimaryInput", true) end)
                                                task.wait(0.03)
                                                pcall(function() IH:FireVirtualInput("PrimaryInput", false) end)
                                            end
                                            task.wait(0.16 + math.random() * 0.06)
                                        end
                                    end)
                                    break
                                end
                            end
                        end
                        if tappedThisCast then break end
                    end
                end
            end
            task.wait(0.04)
        end
        biteWatchStarted = false
    end)
end


local function fishTick()
    if not S.running or not S.autoFish then return end
    local r = root()
    if not r or not r.Parent then return end
    if isSellingFish or isRestockingBait then return end

    if handleQTE() then
        local t0 = os.clock()
        while os.clock() - t0 < 12 and S.running and S.autoFish do
            if not handleQTE() then break end
            task.wait(0.03)
        end
        return
    end
    if biteFlag then
        biteFlag = false
        if castPhase == "casted" and not tappedThisCast then
            tappedThisCast = true
            _lastReelTap = os.clock()
            tap("PrimaryInput")
            FISH.status = "BITE - reeling"
            logAction("BITE", "Bite detected! Auto-reeling...", Color3.fromRGB(255, 175, 50), "BITE")
            return
        end
    end
    local _, curTotalFish = getFishCounts()
    if curTotalFish > lastKnownFishTotal and not isSellingFish then
        local delta = curTotalFish - lastKnownFishTotal
        lastKnownFishTotal = curTotalFish
        recordCatch("Inventory", delta)
    elseif curTotalFish < lastKnownFishTotal then
        lastKnownFishTotal = curTotalFish
    end

    if curTotalFish > FISH.catches then
        FISH.catches = curTotalFish
        if UI.updateHud then pcall(UI.updateHud) end
    end

    local a = anims()
    if (a.Success or (a.BringBack and (tappedThisCast or (lastCast > 0 and os.clock() - lastCast > 1.5)))) and castPhase == "casted" then
        if os.clock() - lastCatchTime > 1.0 then
            recordCatch(a.Success and "Success Animation" or "BringBack Animation", 1)
        end
        tappedThisCast = false
        castPhase = "idle"
        lastCast = 0
        if S.autoSell and FISH.catches > 0 and FISH.catches % math.max(1, S.sellEvery) == 0 then
            task.spawn(function()
                if sellAllFish() then
                    logAction("TRAVEL", "Returning to fishing spot...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    Status.state = "TRAVEL"
                    Status.color = Color3.fromRGB(90, 180, 255)
                    Status.action = "Returning to fishing spot..."
                    Status.detail = ("Returning to Spot #%d"):format(spotIndex)
                    if UI.updateBanner then pcall(UI.updateBanner) end
                    if UI.updateHud then pcall(UI.updateHud) end
                    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
                    if S.legitFishing then
                        FISH.walkToSpotLegit(FISH_SPOTS[spotIndex], 300)
                    else
                        horseTeleport(FISH_SPOTS[spotIndex])
                        landBeside(FISH_SPOTS[spotIndex], 3)
                    end
                end
            end)
            return
        end
        task.wait(1.0)
        return
    end
    if a.ReelLoop then
        FISH.status = "reeling it in"
        logAction("FISH", "Reeling in the line...", Color3.fromRGB(255, 175, 50), "FISHING")
        return
    end
    if a.BringBack and not tappedThisCast and castPhase == "casted" and os.clock() - lastCast < 1.5 then
        castPhase = "idle"; lastCast = 0
        FISH.dead = FISH.dead + 1
        FISH.status = "cast failed (yanked back early)"
        logAction("FISH", "Cast yanked back early - resetting", Color3.fromRGB(245, 160, 60), "FISHING")
        task.wait(0.5)
        return
    end
    if not ensureRod() then return end

    -- Check auto-sell when out of money
    if S.autoSellOutOfMoney and moola() <= (S.lowMoneyThreshold or 10) then
        local _, fCount = getFishCounts()
        if fCount > 0 then
            task.spawn(function()
                if sellAllFish() then
                    logAction("TRAVEL", "Returning to fishing spot after selling...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    Status.state = "TRAVEL"
                    Status.color = Color3.fromRGB(90, 180, 255)
                    Status.action = "Returning to fishing spot..."
                    Status.detail = ("Returning to Spot #%d"):format(spotIndex)
                    if UI.updateBanner then pcall(UI.updateBanner) end
                    if UI.updateHud then pcall(UI.updateHud) end
                    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
                    if S.legitFishing then
                        FISH.walkToSpotLegit(FISH_SPOTS[spotIndex], 300)
                    else
                        if horseTeleport(FISH_SPOTS[spotIndex]) then
                            landBeside(FISH_SPOTS[spotIndex], 3)
                            local l = spotLook(FISH_SPOTS[spotIndex])
                            local rr = root()
                            if l and rr then
                                pcall(function()
                                    rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                                end)
                            end
                        end
                    end
                end
            end)
            return
        end
    end

    local bait = countTool("Bait")
    if bait < 1 and S.requireBait then
        if S.autoRestock and not isRestockingBait and not isSellingFish then
            task.spawn(function()
                local m = moola()
                local _, fCount = getFishCounts()
                if m < 10 and fCount > 0 then
                    logAction("RESTOCK", ("Low funds ($%d) for bait! Selling %d fish first..."):format(m, fCount), Color3.fromRGB(245, 175, 60), "SELLING")
                    if sellAllFish() then
                        if S.legitFishing then
                            FISH.walkToSpotLegit(FISH_SPOTS[spotIndex])
                        else
                            if horseTeleport(FISH_SPOTS[spotIndex]) then
                                landBeside(FISH_SPOTS[spotIndex], 3)
                                local l = spotLook(FISH_SPOTS[spotIndex])
                                local rr = root()
                                if l and rr then
                                    pcall(function()
                                        rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                                    end)
                                end
                            end
                        end
                    end
                end
                if buyBait() then
                    logAction("TRAVEL", "Returning to fishing spot with fresh bait...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    if S.legitFishing then
                        FISH.walkToSpotLegit(FISH_SPOTS[spotIndex], 300)
                    else
                        if horseTeleport(FISH_SPOTS[spotIndex]) then
                            landBeside(FISH_SPOTS[spotIndex], 3)
                            local l = spotLook(FISH_SPOTS[spotIndex])
                            local rr = root()
                            if l and rr then
                                pcall(function()
                                    rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                                end)
                            end
                        end
                    end
                else
                    logAction("RESTOCK", "Bait restock attempt deferred - will retry next cycle", Color3.fromRGB(245, 160, 60), "RESTOCK")
                end
            end)
        else
            FISH.status = "out of bait (waiting for restock)"
            logAction("FISH", "Out of bait - awaiting restock", Color3.fromRGB(245, 160, 60), "IDLE")
        end
        return
    end

    if castPhase == "casted" then
        if a.BringBack and os.clock() - lastCast < 4 then
            castPhase = "idle"; lastCast = 0
            FISH.dead = FISH.dead + 1
            FISH.status = "cast failed (yanked back)"
            logAction("FISH", "Cast yanked back early - resetting", Color3.fromRGB(245, 160, 60), "FISHING")
            return
        end
        if os.clock() - lastCast > S.castTimeout then
            castPhase = "idle"; lastCast = 0
            FISH.dead = FISH.dead + 1
            FISH.status = "no bite - recasting (" .. FISH.dead .. " dead)"
            logAction("FISH", ("No bite within %ds — recasting (%d dead)"):format(S.castTimeout, FISH.dead), Color3.fromRGB(245, 160, 60), "FISHING")
            if FISH.dead >= S.deadCastsBeforeMove then
                FISH.dead = 0
                spotIndex = (spotIndex % #FISH_SPOTS) + 1
                FISH.status = "rotating to spot " .. spotIndex
                logAction("FISH", ("Dead casts reached %d — rotating to spot #%d"):format(S.deadCastsBeforeMove, spotIndex), Color3.fromRGB(180, 140, 255), "TRAVEL")
                if S.legitFishing then
                    FISH.walkToSpotLegit(FISH_SPOTS[spotIndex])
                else
                    if horseTeleport(FISH_SPOTS[spotIndex]) then
                        landBeside(FISH_SPOTS[spotIndex], 3)
                        local l = spotLook(FISH_SPOTS[spotIndex])
                        local rr = root()
                        if l and rr then
                            pcall(function()
                                rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                            end)
                        end
                    end
                end
            end
            return
        end
        local waitElapsed = math.floor(os.clock() - lastCast)
        FISH.status = ("waiting for bite %ds | casts %d catches %d"):format(waitElapsed, FISH.casts, FISH.catches)
        Status.state = "FISHING"
        Status.color = Color3.fromRGB(70, 200, 140)
        Status.action = ("Waiting for bite (%ds)"):format(waitElapsed)
        Status.detail = ("Cast #%d | Catches: %d | Bait: %d | Spot #%d"):format(FISH.casts, FISH.catches, bait, spotIndex)
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
        return
    end
    local r = root()
    local h = hum()
    if h and h:GetState() == Enum.HumanoidStateType.Swimming then
        FISH.status = "recovering from water"
        if S.legitFishing then
            FISH.walkToSpotLegit(FISH_SPOTS[spotIndex])
        else
            horseTeleport(FISH_SPOTS[spotIndex])
            landBeside(FISH_SPOTS[spotIndex], 3)
        end
        return
    end

    local hObj = myHorse()
    if isMounted(hObj) or (h and h.Sit) then
        FISH.status = "dismounting horse..."
        dismount()
        task.wait(0.3)
        return
    end

    local spot = FISH_SPOTS[spotIndex]
    local p = spotPos(spot)
    if not p then return end
    if r and (r.Position - p).Magnitude > 35 then
        if FISH.isWalking then
            -- Legit walk already actively navigating: do not spawn overlapping walk
            return
        end
        FISH.status = "travelling to fishing spot"
        logAction("TRAVEL", ("Travelling to fishing spot #%d (%.0f studs away)..."):format(spotIndex, (r.Position - p).Magnitude), Color3.fromRGB(90, 180, 255), "TRAVEL")
        if S.legitFishing then
            FISH.walkToSpotLegit(spot)
        else
            if horseTeleport(spot) then
                landBeside(spot, 3)
                local l = spotLook(spot)
                local rr = root()
                if l and rr then
                    pcall(function()
                        rr.CFrame = CFrame.new(rr.Position, rr.Position + Vector3.new(l.X, 0, l.Z))
                    end)
                end
            end
        end
        return
    end

    local camv = WS.CurrentCamera
    local camBefore = camv and camv.CFrame
    local r0 = root()
    local faceBefore = r0 and r0.CFrame
    local sLook = spotLook(spot)
    if not aimAtWater(sLook) then
        if camv and camBefore then camv.CFrame = camBefore end
        return
    end
    tap("PrimaryInput")
    task.delay(0.35, function()
        local c2 = WS.CurrentCamera
        if c2 and camBefore then pcall(function() c2.CFrame = camBefore end) end
        local rr = root()
        if rr and faceBefore then pcall(function() rr.CFrame = CFrame.new(rr.Position, rr.Position + faceBefore.LookVector) end) end
    end)
    lastCast = os.clock()
    castPhase = "casted"
    tappedThisCast = false
    startBiteWatch()
    FISH.casts = FISH.casts + 1
    local baitStr = bait > 0 and (" (bait " .. bait .. ")") or " (no bait)"
    FISH.status = "cast #" .. FISH.casts .. baitStr
    logAction("FISH", ("Cast #%d launched towards water%s"):format(FISH.casts, baitStr), Color3.fromRGB(80, 220, 140), "FISHING",
        ("Spot #%d | Catches: %d"):format(spotIndex, FISH.catches))
end

local function startFishing()
    S.autoFish = true
    FISH.casts, FISH.dead = 0, 0
    castPhase, lastCast = "idle", 0
    FISH.status = "starting"
    logAction("FISH", "Starting Auto-Fish routine...", Color3.fromRGB(80, 220, 140), "FISHING")
    loop("autoFish", 0.25, fishTick)
end
getgenv().BW3_BuyBait = function() return buyBait() end
getgenv().BW3_SellFish = function() return sellAllFish() end
getgenv().BW3_StartFish = function() startFishing() end
local function stopFishing()
    S.autoFish = false
    loops["autoFish"] = false
    castPhase, lastCast = "idle", 0
    FISH.status = "stopped"
    logAction("FISH", "Stopped Auto-Fish", Color3.fromRGB(160, 165, 180), "IDLE")
end
getgenv().BW3_StopFish = function() stopFishing() end


return {
    FISH = FISH,
    FISH_SPOTS = FISH_SPOTS,
    spotIndex = spotIndex,
    VENDOR = VENDOR,
    startFishing = startFishing,
    stopFishing = stopFishing,
    fishTick = fishTick,
    aimAtWater = aimAtWater,
    handleQTE = handleQTE,
    ensureRod = ensureRod,
    startBiteWatch = startBiteWatch,
}
