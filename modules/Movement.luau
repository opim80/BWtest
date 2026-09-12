--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Movement
-- Horse travel, Mounting, Safe teleport & Ghost Fake Fly
-- ============================================================
local ctx = ...

-- ==========================================
-- EXECUTOR HARDWARE KEYBOARD DRIVER (Shared with Navigation)
-- ==========================================
local keypressFn = keypress or (syn and syn.keypress) or (fluxus and fluxus.keypress)
local keyreleaseFn = keyrelease or (syn and syn.keyrelease) or (fluxus and fluxus.keyrelease)
local keyclickFn = keyclick

local function tapSpace()
    local navTap = (ctx and ctx.Navigation and ctx.Navigation.tapSpace)
        or (ctx and ctx.tapSpace)
        or (SHARED.NAV and SHARED.NAV.tapSpace)
        or SHARED.tapSpace
    if navTap then
        navTap()
        return
    end
    if keyclickFn then
        pcall(keyclickFn, 0x20)
    elseif keypressFn and keyreleaseFn then
        pcall(keypressFn, 0x20)
        task.wait(0.035)
        pcall(keyreleaseFn, 0x20)
    end
    if keyreleaseFn then
        pcall(keyreleaseFn, 0x20)
    end
    local h = hum()
    if h then
        pcall(function() h.Jump = false end)
    end
end

local function releaseAllKeys()
    if keyreleaseFn then
        pcall(keyreleaseFn, 0x20) -- Space
        pcall(keyreleaseFn, 0x45) -- E
        pcall(keyreleaseFn, 0x10) -- Shift
    end
    local h = hum()
    if h then
        pcall(function() h.Jump = false end)
    end
end

-- ── horse travel ───────────────────────────────────────────────────────────
local HORSE = { status = "idle" }
local function myHorse()
    local f = WS:FindFirstChild("Entities")
    if not f then return nil end
    for _, e in ipairs(f:GetChildren()) do
        local o = e:FindFirstChild("Owner")
        if o then
            if o:IsA("ObjectValue") and o.Value == LP then return e end
            if o.Value == LP or o.Value == LP.Name or tostring(o.Value) == tostring(LP.UserId) then return e end
        end
        local attrOwner = e:GetAttribute("Owner") or e:GetAttribute("OwnerUserId") or e:GetAttribute("OwnerName")
        if attrOwner then
            if attrOwner == LP.Name or attrOwner == LP.UserId or tostring(attrOwner) == tostring(LP.UserId) then return e end
        end
    end
    return nil
end

local function horseRoot()
    local h = myHorse()
    return h and h:FindFirstChild("HumanoidRootPart"), h
end


local function summonHorse(timeout)
    local r = root()
    local h = myHorse()
    local hp = h and h:FindFirstChild("HumanoidRootPart")
    if h and hp and r and (hp.Position - r.Position).Magnitude <= 25 then
        return h
    end

    HORSE.status = "summoning"
    logAction("HORSE", "Calling horse via whistle...", Color3.fromRGB(245, 175, 60), "TRAVEL", "Waiting for horse to appear")

    -- Call ToggleHorse remote directly to spawn horse adjacent to player
    pcall(function()
        local hc = require(game:GetService("ReplicatedStorage").Modules.HorseController)
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
        if h and hp and r and (hp.Position - r.Position).Magnitude <= 30 then
            logAction("HORSE", "Horse summoned: " .. h.Name, Color3.fromRGB(80, 220, 140), "TRAVEL")
            return h
        end
        task.wait(0.25)
    end
    logAction("HORSE", "Horse summon timed out", Color3.fromRGB(245, 90, 90), "ERROR")
    return myHorse()
end

local function groundY(p, ignore)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    local ex = { char() }
    if ignore then ex[#ex + 1] = ignore end
    rp.FilterDescendantsInstances = ex
    local hit = WS:Raycast(p + Vector3.new(0, 100, 0), Vector3.new(0, -3000, 0), rp)
    return hit and hit.Position.Y
end

local function isMounted(h)
    local hm = hum()
    local r = root()
    if not hm or not r then return false end

    -- 1. Standard seat
    if hm.SeatPart ~= nil then return true end

    -- 2. Character attributes (game uses IsRiding attribute)
    local c = char()
    if c and (c:GetAttribute("IsRiding") == true or c:GetAttribute("Mounted") == true or c:GetAttribute("Horse") ~= nil) then return true end
    if h and (h:GetAttribute("Rider") == LP.Name or h:GetAttribute("RiderUserId") == LP.UserId) then return true end

    -- 3. Weld / Motor6D connection between character and horse
    if c and h then
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                if (d.Part0 and d.Part0:IsDescendantOf(h)) or (d.Part1 and d.Part1:IsDescendantOf(h)) then
                    return true
                end
            end
        end
    end

    -- 4. Sitting directly on horse saddle
    local hp = h and h:FindFirstChild("HumanoidRootPart")
    if hp and hp.Parent then
        local dist = (hp.Position - r.Position).Magnitude
        if hm.Sit and dist < 8.0 then
            return true
        end
    end

    return false
end

local function mountHorse()
    local h = myHorse()
    local hp = h and h:FindFirstChild("HumanoidRootPart")
    local r = root()

    -- If no horse or horse is farther than 25 studs, summon/recall it
    if not h or not hp or not r or (hp.Position - r.Position).Magnitude > 25 then
        h = summonHorse(8)
    end

    if not h then
        HORSE.status = "no horse"
        logAction("HORSE", "Cannot mount: horse not found", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end

    -- Already mounted check
    if isMounted(h) then
        HORSE.status = "mounted"
        return true
    end

    hp = h:FindFirstChild("HumanoidRootPart")
    if not hp then
        HORSE.status = "horse has no root"
        logAction("HORSE", "Horse has no root part", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end

    HORSE.status = "approaching"
    for _ = 1, 15 do
        r = root()
        if not r or not hp.Parent then break end
        local d = (hp.Position - r.Position).Magnitude
        if d <= 6 then break end
        logAction("HORSE", ("Approaching horse (%d studs)..."):format(math.floor(d)), Color3.fromRGB(245, 175, 60), "TRAVEL")
        r.CFrame = CFrame.new(r.Position + (hp.Position - r.Position).Unit * math.min(10, d - 4))
        task.wait(0.15)
    end

    task.wait(0.2)

    local prompt
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            prompt = d
            break
        end
    end

    logAction("HORSE", "Activating Mount prompt...", Color3.fromRGB(245, 175, 60), "TRAVEL")
    if prompt and firepp then
        pcall(firepp, prompt, 0)
    end

    local tMount = os.clock()
    while os.clock() - tMount < 3.0 do
        task.wait(0.15)
        if isMounted(h) then
            HORSE.status = "mounted"
            logAction("HORSE", "Mounted horse successfully", Color3.fromRGB(80, 220, 140), "TRAVEL")
            return true
        end
        if prompt and firepp then
            pcall(firepp, prompt, 0)
        end
    end

    local ok = isMounted(h)
    HORSE.status = ok and "mounted" or "mount failed"
    if ok then
        logAction("HORSE", "Mounted horse successfully", Color3.fromRGB(80, 220, 140), "TRAVEL")
    else
        logAction("HORSE", "Horse mount failed", Color3.fromRGB(245, 90, 90), "ERROR")
    end
    return ok
end

-- DIRECT TELEPORT PROHIBITED: ALL TRAVEL REQUIRES GENUINELY MOUNTED HORSE
local function horseTeleport(dest)
    dest = spotPos(dest)
    if not dest then return false end
    if typeof(dest) == "CFrame" then dest = dest.Position end
    local r = root()
    if not r then return false end
    if (r.Position - dest).Magnitude < 15 then
        HORSE.status = "already there"
        return true
    end
    local distInitial = math.floor((r.Position - dest).Magnitude)
    local stKey = (isSellingFish and "SELLING") or (isRestockingBait and "RESTOCK") or "TRAVEL"
    local col = (stKey == "SELLING" or stKey == "RESTOCK") and Color3.fromRGB(245, 175, 60) or Color3.fromRGB(90, 180, 255)
    local actPrefix = isSellingFish and "Traveling to Daniel to sell fish..." or (isRestockingBait and "Traveling to Daniel for bait..." or ("Initiating travel (%d studs away)..."):format(distInitial))

    logAction(stKey, actPrefix, col, stKey, ("Distance: %d studs"):format(distInitial))

    local mounted = false
    local hp, hObj
    for attempt = 1, 3 do
        mounted = mountHorse()
        hp, hObj = horseRoot()
        if mounted and hp and hp.Parent and isMounted(hObj) then
            break
        end
        task.wait(0.5)
    end

    -- STRICT SAFETY: If not genuinely mounted on the horse, NEVER teleport!
    if not mounted or not hp or not hp.Parent or not isMounted(hObj) then
        logAction(stKey, "Cannot travel: horse not mounted (direct teleport disabled)", Color3.fromRGB(245, 90, 90), "ERROR")
        return false
    end

    HORSE.status = "travelling"
    local t = dest
    local rpTele = RaycastParams.new()
    rpTele.FilterType = Enum.RaycastFilterType.Exclude
    rpTele.IgnoreWater = false
    local ex = { char() }
    if hObj then table.insert(ex, hObj) end
    rpTele.FilterDescendantsInstances = ex
    local hit = WS:Raycast(dest + Vector3.new(0, 8, 0), Vector3.new(0, -25, 0), rpTele)
    if hit and hit.Material ~= Enum.Material.Water then
        t = Vector3.new(dest.X, hit.Position.Y + 3.0, dest.Z)
    else
        local g = groundY(dest, hObj)
        if g and math.abs(g - dest.Y) < 20 then
            t = Vector3.new(dest.X, g + 3.0, dest.Z)
        end
    end

    for _ = 1, 15 do
        local rr = root()
        if hp and hp.Parent then hp.CFrame = CFrame.new(t); hp.AssemblyLinearVelocity = Vector3.zero end
        if rr then rr.CFrame = CFrame.new(t + Vector3.new(0, 2.0, 0)); rr.AssemblyLinearVelocity = Vector3.zero end
        RunService.Heartbeat:Wait()
    end
    task.wait(0.5)
    local rr = root()
    local offset = rr and math.floor((rr.Position - dest).Magnitude) or 999
    if rr and offset < 45 then
        local arrMsg = isSellingFish and "Arrived at Daniel (Fish Buyer)" or (isRestockingBait and "Arrived at Daniel (Bait Vendor)" or ("Arrived at destination (%d studs off)"):format(offset))
        logAction(stKey, arrMsg, Color3.fromRGB(80, 220, 140), stKey)
        return true
    end

    logAction(stKey, "Horse travel failed to reach destination", Color3.fromRGB(245, 90, 90), "ERROR")
    return false
end

local function dismount()
    local stKey = (isSellingFish and "SELLING") or (isRestockingBait and "RESTOCK") or "HORSE"
    logAction(stKey, "Dismounting horse...", Color3.fromRGB(160, 165, 180), stKey)
    local hm = hum()
    local hObj = myHorse()
    local c = char()
    local r = root()

    for _ = 1, 6 do
        if not isMounted(hObj) and not (hm and hm.Sit) then break end
        tap("HorseDismountInput", 0.15)
        tap("ActionInput2", 0.15)

        -- Clean hardware jump pulse from Navigation (Space VK 0x20 & clears Humanoid.Jump)
        tapSpace()

        -- Key E (VK 0x45) pulse
        pcall(function()
            if keyclickFn then
                keyclickFn(0x45)
            elseif keypressFn and keyreleaseFn then
                keypressFn(0x45)
                task.wait(0.035)
                keyreleaseFn(0x45)
            end
            if keyreleaseFn then
                keyreleaseFn(0x45)
            end
        end)

        if hObj and firepp then
            for _, d in ipairs(hObj:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    pcall(firepp, d, 0)
                end
            end
        end

        if c and hObj then
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                    if (d.Part0 and d.Part0:IsDescendantOf(hObj)) or (d.Part1 and d.Part1:IsDescendantOf(hObj)) then
                        pcall(function() d:Destroy() end)
                    end
                end
            end
            for _, d in ipairs(hObj:GetDescendants()) do
                if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                    if (d.Part0 and d.Part0:IsDescendantOf(c)) or (d.Part1 and d.Part1:IsDescendantOf(c)) then
                        pcall(function() d:Destroy() end)
                    end
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

    -- Thorough cleanup: release physical keys and force Humanoid to non-jumping Running state
    releaseAllKeys()
    local hCleanup = hum()
    if hCleanup then
        hCleanup.Sit = false
        hCleanup.Jump = false
        pcall(function() hCleanup:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    task.wait(0.15)
end

local function landBeside(pos, offset)
    dismount()
    task.wait(0.3)
    local r = root()
    if not r then return false end
    pos = spotPos(pos) or pos
    offset = offset or 5
    local best
    for _, dir in ipairs({ Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1),
                           Vector3.new(1,0,1).Unit, Vector3.new(-1,0,-1).Unit }) do
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
    task.wait(0.4)
    local stKey = (isSellingFish and "SELLING") or (isRestockingBait and "RESTOCK") or "TRAVEL"
    local landMsg = isSellingFish and "Arrived at Daniel for selling" or (isRestockingBait and "Arrived at Daniel for restock" or "Arrived at destination")
    logAction(stKey, landMsg, Color3.fromRGB(160, 165, 180), stKey)
    return true
end

-- ── Fake Horse Fly (Client-Side Desync / Ghost Flight) ─────────────────────
local fakeFly = {
    active = false,
    ghostModel = nil,
    landingCircle = nil,
    savedTransparency = {},
    conn = nil,
    inputConn = nil,
    inputBeganConn = nil,
    inputEndedConn = nil,
}

local function getPlayerControls()
    local ps = LP:FindFirstChild("PlayerScripts")
    local pm = ps and ps:FindFirstChild("PlayerModule")
    if pm then
        local ok, mod = pcall(require, pm)
        if ok and mod and mod.GetControls then
            return mod:GetControls()
        end
    end
    return nil
end

local function cleanupFakeFlyVisuals()
    if fakeFly.conn then
        pcall(function() fakeFly.conn:Disconnect() end)
        fakeFly.conn = nil
    end

    if fakeFly.inputConn then
        pcall(function() fakeFly.inputConn:Disconnect() end)
        fakeFly.inputConn = nil
    end

    if fakeFly.inputBeganConn then
        pcall(function() fakeFly.inputBeganConn:Disconnect() end)
        fakeFly.inputBeganConn = nil
    end

    if fakeFly.inputEndedConn then
        pcall(function() fakeFly.inputEndedConn:Disconnect() end)
        fakeFly.inputEndedConn = nil
    end

    pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)

    if fakeFly.landingCircle then
        pcall(function() fakeFly.landingCircle:Destroy() end)
        fakeFly.landingCircle = nil
    end

    if fakeFly.ghostModel then
        pcall(function() fakeFly.ghostModel:Destroy() end)
        fakeFly.ghostModel = nil
    end

    for part, trans in pairs(fakeFly.savedTransparency) do
        if part and part.Parent then
            pcall(function() part.Transparency = trans end)
        end
    end
    table.clear(fakeFly.savedTransparency)

    -- Re-enable player movement controls
    local ctrl = getPlayerControls()
    if ctrl then pcall(function() ctrl:Enable() end) end

    -- Reset camera back to player
    local hm = hum()
    local cam = WS.CurrentCamera
    if cam then
        pcall(function()
            cam.CameraType = Enum.CameraType.Custom
            if hm then cam.CameraSubject = hm end
        end)
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
            logAction("TRAVEL", ("Landing from Horsefly: Traveling horse & body to floor (%.0f, %.0f, %.0f)..."):format(dest.X, dest.Y, dest.Z), Color3.fromRGB(80, 220, 140), "TRAVEL")
            task.spawn(function()
                horseTeleport(dest)
            end)
        else
            logAction("TRAVEL", "Horsefly landing cancelled: No ground below to land on", Color3.fromRGB(245, 175, 60), "TRAVEL")
        end
    else
        logAction("TRAVEL", "Horsefly ended", Color3.fromRGB(160, 165, 180), "IDLE")
    end

    if UI.updateToggles then pcall(UI.updateToggles) end
end

local function startFakeHorseFly()
    if fakeFly.active then return end

    local c = char()
    local r = root()
    local hm = hum()
    local h = myHorse()
    if not c or not r or not hm then
        logAction("TRAVEL", "Character not ready for Fake Horse Fly", Color3.fromRGB(245, 90, 90), "ERROR")
        S.fakeHorseFly = false
        return
    end

    if not h or not isMounted(h) then
        logAction("TRAVEL", "Mounting horse before initiating Fake Horse Fly...", Color3.fromRGB(245, 175, 60), "TRAVEL")
        if not mountHorse() then
            logAction("TRAVEL", "Cannot Fake Fly: must be mounted on your horse", Color3.fromRGB(245, 90, 90), "ERROR")
            S.fakeHorseFly = false
            return
        end
        h = myHorse()
    end

    local hp = h and h:FindFirstChild("HumanoidRootPart")
    if not hp then
        logAction("TRAVEL", "Horse has no root part", Color3.fromRGB(245, 90, 90), "ERROR")
        S.fakeHorseFly = false
        return
    end

    fakeFly.active = true
    logAction("TRAVEL", "Horsefly ACTIVE! (RMB drag to look, WASD to fly, Space=Up, Shift=Down)", Color3.fromRGB(80, 220, 140), "TRAVEL")

    -- 1. Onion Skin on Real Body & Real Horse
    table.clear(fakeFly.savedTransparency)
    for _, inst in ipairs({ c, h }) do
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                fakeFly.savedTransparency[d] = d.Transparency
                d.Transparency = math.max(0.65, d.Transparency)
            end
        end
    end

    -- Disable standard WASD movement controls so real body/horse remain in natural stationary idle
    local ctrl = getPlayerControls()
    if ctrl then pcall(function() ctrl:Disable() end) end

    -- 2. Build Flying Visual Ghost Model
    local ghostModel = Instance.new("Model")
    ghostModel.Name = "GhostHorseFlight"

    local ghostRoot = Instance.new("Part")
    ghostRoot.Name = "GhostRoot"
    ghostRoot.Size = Vector3.new(2, 2, 2)
    ghostRoot.Transparency = 1
    ghostRoot.CanCollide = false
    ghostRoot.CanTouch = false
    ghostRoot.CanQuery = false
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
            d.CanTouch = false
            d.CanQuery = false
            d.Anchored = true
            d.CastShadow = false
            local nl = d.Name:lower()
            if d.Name == "HumanoidRootPart" or nl:find("root") or nl:find("collision") or nl:find("hitbox") then
                d.Transparency = 1
            else
                d.Transparency = 0
            end
        elseif d:IsA("Decal") then
            d.Transparency = 0
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
            d.CanTouch = false
            d.CanQuery = false
            d.Anchored = true
            d.CastShadow = false
            local nl = d.Name:lower()
            if d.Name == "HumanoidRootPart" or nl:find("root") or nl:find("collision") or nl:find("hitbox") then
                d.Transparency = 1
            else
                d.Transparency = 0
            end
        elseif d:IsA("Decal") then
            d.Transparency = 0
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
            d:Destroy()
        end
    end
    hClone.Parent = ghostModel

    local cam = WS.CurrentCamera
    ghostModel.Parent = cam or WS
    fakeFly.ghostModel = ghostModel

    -- Ground landing indicator (green circle on the ground directly below)
    local landingCircle = Instance.new("Part")
    landingCircle.Name = "HorseflyLandingCircle"
    landingCircle.Shape = Enum.PartType.Cylinder
    landingCircle.Size = Vector3.new(0.08, 6.5, 6.5)
    landingCircle.Color = Color3.fromRGB(50, 255, 120)
    landingCircle.Material = Enum.Material.Neon
    landingCircle.Transparency = 1
    landingCircle.CanCollide = false
    landingCircle.CanTouch = false
    landingCircle.CanQuery = false
    landingCircle.CastShadow = false
    landingCircle.Anchored = true
    landingCircle.Parent = cam or WS
    fakeFly.landingCircle = landingCircle

    local circleParams = RaycastParams.new()
    circleParams.FilterType = Enum.RaycastFilterType.Exclude
    circleParams.FilterDescendantsInstances = { c, h, ghostModel, landingCircle, cam or WS.CurrentCamera }
    circleParams.IgnoreWater = false

    -- Initialize camera angles from existing camera direction
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

    -- 3. Mouse Movement Listeners (Hold Right-Click to orbit / pan camera smoothly)
    fakeFly.inputBeganConn = UIS.InputBegan:Connect(function(input, gpe)
        if not fakeFly.active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end)

    fakeFly.inputEndedConn = UIS.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end)

    fakeFly.inputConn = UIS.InputChanged:Connect(function(input, gpe)
        if not fakeFly.active then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            camDist = math.clamp(camDist - input.Position.Z * 2.5, 4, 40)
        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
                local sens = 0.0035
                yaw = yaw - input.Delta.X * sens
                pitch = math.clamp(pitch - input.Delta.Y * sens, -1.35, 1.35)
            end
        end
    end)

    -- 4. Flight & Camera Update Loop
    fakeFly.conn = RunService.RenderStepped:Connect(function(dt)
        if not fakeFly.active or not S.fakeHorseFly then
            cleanupFakeFlyVisuals()
            return
        end

        local cNow = char()
        local hmNow = hum()
        if not cNow or not hmNow or hmNow.Health <= 0 then
            stopFakeHorseFly(false)
            return
        end

        local curCam = WS.CurrentCamera
        if not curCam then return end

        -- Orbit camera behind the ghost horse based on yaw and pitch
        local rotCF = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        local camOffset = rotCF:PointToWorldSpace(Vector3.new(0, 3, camDist))
        local camCF = CFrame.lookAt(curCF.Position + camOffset, curCF.Position + Vector3.new(0, 2, 0))
        curCam.CFrame = camCF

        -- Fly in the direction the camera is facing
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

            -- Turn ghost horse to face flight direction
            local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            if flatDir.Magnitude > 0.05 then
                curCF = CFrame.new(curCF.Position, curCF.Position + flatDir.Unit)
            end
        end

        if fakeFly.ghostModel and fakeFly.ghostModel.PrimaryPart then
            fakeFly.ghostModel:PivotTo(curCF)
        end

        -- Update ground landing indicator circle
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

-- Exact coordinates for Mud Witch / Tonic Brewing Hut
local TONIC_STATION_POS = Vector3.new(-2410.98, 42.79, -5214.38)
local function findTonicStation()
    for _, container in ipairs({ WS:FindFirstChild("Map"), WS:FindFirstChild("Entities"), WS }) do
        if container then
            for _, c in ipairs(container:GetChildren()) do
                local n = c.Name:lower()
                if n:find("tonic") or n:find("brew") or n:find("kettle") or n:find("witch") then
                    local p = c:IsA("BasePart") and c.Position or (c:FindFirstChildWhichIsA("BasePart") and c:FindFirstChildWhichIsA("BasePart").Position)
                    if p then return p, c end
                end
            end
        end
    end
    return TONIC_STATION_POS, nil
end


return {
    HORSE = HORSE,
    myHorse = myHorse,
    horseRoot = horseRoot,
    summonHorse = summonHorse,
    groundY = groundY,
    isMounted = isMounted,
    mountHorse = mountHorse,
    horseTeleport = horseTeleport,
    dismount = dismount,
    landBeside = landBeside,
    getPlayerControls = getPlayerControls,
    cleanupFakeFlyVisuals = cleanupFakeFlyVisuals,
    stopFakeHorseFly = stopFakeHorseFly,
    startFakeHorseFly = startFakeHorseFly,
    findTonicStation = findTonicStation,
    fakeFly = fakeFly,
    tapSpace = tapSpace,
    releaseAllKeys = releaseAllKeys,
}
