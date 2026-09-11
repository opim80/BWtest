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
    centerRay = nil,
    leftRay = nil,
    rightRay = nil,
    steerTarget = nil,
    drawLines = {},
    drawCircles = {},
    drawTexts = {},
    statusLabel = nil,
    rayLabels = {},
}

function FISH.getVizLine(idx)
    local l = FISH.viz.drawLines[idx]
    if l then return l end
    local ok, obj = pcall(function() return Drawing.new("Line") end)
    if ok and obj then
        obj.Visible = false
        obj.Thickness = 2
        FISH.viz.drawLines[idx] = obj
        return obj
    end
    return nil
end

function FISH.getVizCircle(idx)
    local c = FISH.viz.drawCircles[idx]
    if c then return c end
    local ok, obj = pcall(function() return Drawing.new("Circle") end)
    if ok and obj then
        obj.Visible = false
        obj.Radius = 4
        obj.Filled = true
        FISH.viz.drawCircles[idx] = obj
        return obj
    end
    return nil
end

function FISH.getVizText(idx)
    local t = FISH.viz.drawTexts[idx]
    if t then return t end
    local ok, obj = pcall(function() return Drawing.new("Text") end)
    if ok and obj then
        obj.Visible = false
        obj.Size = 13
        obj.Center = true
        obj.Outline = true
        obj.Font = 2
        FISH.viz.drawTexts[idx] = obj
        return obj
    end
    return nil
end

function FISH.hideViz()
    if not FISH.viz then return end
    for _, l in pairs(FISH.viz.drawLines or {}) do pcall(function() l.Visible = false end) end
    for _, c in pairs(FISH.viz.drawCircles or {}) do pcall(function() c.Visible = false end) end
    for _, t in pairs(FISH.viz.drawTexts or {}) do pcall(function() t.Visible = false end) end
    if FISH.viz.statusLabel then pcall(function() FISH.viz.statusLabel.Visible = false end) end
end

function FISH.renderViz()
    if not S.visualizeLegit then
        FISH.hideViz()
        return
    end

    local cam = WS.CurrentCamera
    local r = root()
    if not cam or not r then
        FISH.hideViz()
        return
    end

    local lineIdx = 0
    local circleIdx = 0
    local textIdx = 0
    local myPos = r.Position

    -- 1. Staging Point Marker
    local activeSetName = FISH.getActiveSetName()
    local stagingPos = (FISH.getStagingPoint and FISH.getStagingPoint(activeSetName)) or (S.stagingPoints and S.stagingPoints[activeSetName])
    if stagingPos then
        local sp, onScreen = cam:WorldToViewportPoint(stagingPos)
        if onScreen then
            circleIdx = circleIdx + 1
            local c = FISH.getVizCircle(circleIdx)
            if c then
                c.Position = Vector2.new(sp.X, sp.Y)
                c.Radius = 6
                c.Color = Color3.fromRGB(80, 180, 255)
                c.Visible = true
            end
            textIdx = textIdx + 1
            local t = FISH.getVizText(textIdx)
            if t then
                t.Position = Vector2.new(sp.X, sp.Y - 14)
                t.Color = Color3.fromRGB(120, 210, 255)
                t.Text = "[STAGING POINT]"
                t.Visible = true
            end
        end
    end

    -- 2. Target Fishing Spot Marker & Direct Path Line
    local destSpot = FISH.viz.targetSpot or (FISH_SPOTS and FISH_SPOTS[spotIndex])
    if destSpot then
        local sp, onScreen = cam:WorldToViewportPoint(destSpot)
        if onScreen then
            circleIdx = circleIdx + 1
            local c = FISH.getVizCircle(circleIdx)
            if c then
                c.Position = Vector2.new(sp.X, sp.Y)
                c.Radius = 8
                c.Color = Color3.fromRGB(255, 215, 80)
                c.Visible = true
            end
            textIdx = textIdx + 1
            local t = FISH.getVizText(textIdx)
            if t then
                t.Position = Vector2.new(sp.X, sp.Y - 16)
                t.Color = Color3.fromRGB(255, 230, 120)
                local d = math.floor((destSpot - myPos).Magnitude)
                t.Text = string.format("[FISHING SPOT #%d] (%dm)", spotIndex, d)
                t.Visible = true
            end
        end

        -- Line from player to destination spot
        local sp0, on0 = cam:WorldToViewportPoint(myPos)
        local sp1, on1 = cam:WorldToViewportPoint(destSpot)
        if on0 or on1 then
            lineIdx = lineIdx + 1
            local l = FISH.getVizLine(lineIdx)
            if l then
                l.From = Vector2.new(sp0.X, sp0.Y)
                l.To = Vector2.new(sp1.X, sp1.Y)
                l.Color = Color3.fromRGB(0, 200, 255)
                l.Thickness = 2
                l.Visible = true
            end
        end
    end

    -- 3. Deflection Steer Vector Line
    if FISH.viz.steerTarget then
        local sp0, on0 = cam:WorldToViewportPoint(myPos)
        local sp1, on1 = cam:WorldToViewportPoint(FISH.viz.steerTarget)
        if on0 or on1 then
            lineIdx = lineIdx + 1
            local l = FISH.getVizLine(lineIdx)
            if l then
                l.From = Vector2.new(sp0.X, sp0.Y)
                l.To = Vector2.new(sp1.X, sp1.Y)
                l.Color = Color3.fromRGB(255, 170, 40)
                l.Thickness = 3
                l.Visible = true
            end
            if on1 then
                textIdx = textIdx + 1
                local t = FISH.getVizText(textIdx)
                if t then
                    t.Position = Vector2.new(sp1.X, sp1.Y - 12)
                    t.Color = Color3.fromRGB(255, 190, 60)
                    t.Text = "[STEER AROUND WALL]"
                    t.Visible = true
                end
            end
        end
    end

    -- 4. Whisker Rays (Center, Left, Right)
    local rays = {
        { data = FISH.viz.centerRay, label = "CENTER" },
        { data = FISH.viz.leftRay, label = "LEFT" },
        { data = FISH.viz.rightRay, label = "RIGHT" },
    }
    for _, rInfo in ipairs(rays) do
        local rData = rInfo.data
        if rData and rData.origin and rData.target then
            local sp0, on0 = cam:WorldToViewportPoint(rData.origin)
            local sp1, on1 = cam:WorldToViewportPoint(rData.target)
            if on0 or on1 then
                lineIdx = lineIdx + 1
                local l = FISH.getVizLine(lineIdx)
                if l then
                    l.From = Vector2.new(sp0.X, sp0.Y)
                    l.To = Vector2.new(sp1.X, sp1.Y)
                    l.Color = rData.hit and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(80, 255, 120)
                    l.Thickness = rData.hit and 2.5 or 1.5
                    l.Visible = true
                end
            end
        end
    end

    -- 5. 3D Status Label above player head
    local action = FISH.viz.currentAction or ""
    if action ~= "" and action ~= "Idle" then
        local sp, onScreen = cam:WorldToViewportPoint(myPos + Vector3.new(0, 3.5, 0))
        if onScreen then
            if not FISH.viz.statusLabel then
                local ok, t = pcall(function() return Drawing.new("Text") end)
                if ok then
                    t.Size = 14; t.Center = true; t.Outline = true; t.Font = 2
                    FISH.viz.statusLabel = t
                end
            end
            if FISH.viz.statusLabel then
                FISH.viz.statusLabel.Position = Vector2.new(sp.X, sp.Y)
                FISH.viz.statusLabel.Text = "[LEGIT] " .. action
                FISH.viz.statusLabel.Color = Color3.fromRGB(80, 255, 200)
                FISH.viz.statusLabel.Visible = true
            end
        else
            if FISH.viz.statusLabel then FISH.viz.statusLabel.Visible = false end
        end
    else
        if FISH.viz.statusLabel then FISH.viz.statusLabel.Visible = false end
    end

    for i = lineIdx + 1, #FISH.viz.drawLines do
        pcall(function() FISH.viz.drawLines[i].Visible = false end)
    end
    for i = circleIdx + 1, #FISH.viz.drawCircles do
        pcall(function() FISH.viz.drawCircles[i].Visible = false end)
    end
    for i = textIdx + 1, #FISH.viz.drawTexts do
        pcall(function() FISH.viz.drawTexts[i].Visible = false end)
    end
end

function FISH.ensureViz()
    if FISH.vizConn then return end
    FISH.vizConn = RunService.RenderStepped:Connect(function()
        if S.visualizeLegit and (S.legitFishing or (FISH.viz and FISH.viz.currentAction ~= "Idle")) then
            pcall(FISH.renderViz)
        else
            FISH.hideViz()
        end
    end)
end

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
                if horseTeleport(spot) then landBeside(spot, 3) end
            end
        end)
    end
end

function FISH.validateLegitPath(targetPos)
    if typeof(targetPos) == "Vector3" then
        return true, { targetPos }
    end
    return false, nil
end

function FISH.validateAllSpots()
    local spots = FISH_SPOTS
    if not spots or #spots == 0 then return false, "No fishing spots in active set" end
    for i = 1, #spots do
        if typeof(spots[i]) ~= "Vector3" then
            return false, string.format("Spot #%d is invalid", i)
        end
    end
    return true
end

function FISH.getStagingPoint(setName)
    setName = setName or FISH.getActiveSetName()
    local userStaging = S.stagingPoints and S.stagingPoints[setName]
    if userStaging and typeof(userStaging) == "Vector3" then
        return userStaging
    end
    if setName == "Default" or not setName or setName == "" then
        return Vector3.new(-3125.0, 47.0, -3685.0)
    end
    return nil
end

function FISH.walkToSpotLegit(targetPos, maxHorseThreshold)
    if not targetPos then return false end
    local r = root()
    local h = hum()
    if not r or not h or h.Health <= 0 then return false end

    -- Cancel any previous running walkTo loop immediately
    FISH.walkCancelToken = (FISH.walkCancelToken or 0) + 1
    local myToken = FISH.walkCancelToken
    FISH.isWalking = true

    FISH.ensureViz()
    FISH.viz.targetSpot = targetPos

    -- Raycast Filter Setup
    local rpGround = RaycastParams.new()
    rpGround.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { char(), WS.CurrentCamera }
    local mh = myHorse()
    if mh then table.insert(ex, mh) end
    rpGround.FilterDescendantsInstances = ex
    rpGround.IgnoreWater = false

    local rpBody = RaycastParams.new()
    rpBody.FilterType = Enum.RaycastFilterType.Exclude
    rpBody.FilterDescendantsInstances = ex

    local function isWaterOrDrop(hit, oY)
        if not hit then return true end
        if hit.Material == Enum.Material.Water then return true end
        local nm = hit.Instance and hit.Instance.Name:lower() or ""
        if nm:find("water") or nm:find("ocean") or nm:find("river") or nm:find("lake") or nm:find("sea") then
            return true
        end
        if hit.Instance and not hit.Instance.CanCollide and not hit.Instance:IsA("Terrain") then
            return true
        end
        local curFeetY = (root() and root().Position.Y - 2.5) or (oY - 6.0)
        if hit.Position.Y < (curFeetY - 4.5) then
            return true
        end
        return false
    end

    local function isBridgePart(inst)
        if not inst then return false end
        local nm = inst.Name:lower()
        local pnm = inst.Parent and inst.Parent.Name:lower() or ""
        return nm:find("bridge") or nm:find("plank") or nm:find("deck") or nm:find("pier") or nm:find("dock") or nm:find("walkway")
            or pnm:find("bridge") or pnm:find("pier") or pnm:find("dock")
    end

    local function isNearWater(wx, wz, groundY, bufferDist)
        local radius = bufferDist or 5.0
        local PROBE_DIRS = {
            Vector3.new(radius, 0, 0),
            Vector3.new(-radius, 0, 0),
            Vector3.new(0, 0, radius),
            Vector3.new(0, 0, -radius),
            Vector3.new(radius * 0.7, 0, radius * 0.7),
            Vector3.new(-radius * 0.7, 0, radius * 0.7),
            Vector3.new(radius * 0.7, 0, -radius * 0.7),
            Vector3.new(-radius * 0.7, 0, -radius * 0.7)
        }
        for _, off in ipairs(PROBE_DIRS) do
            local pCheck = WS:Raycast(Vector3.new(wx + off.X, groundY + 4.0, wz + off.Z), Vector3.new(0, -12.0, 0), rpGround)
            if isWaterOrDrop(pCheck, groundY + 4.0) then
                return true
            end
        end
        return false
    end

    local function findSafeStagingLand(goalPos)
        if not goalPos then return nil end
        local tHit = WS:Raycast(goalPos + Vector3.new(0, 5, 0), Vector3.new(0, -15, 0), rpGround)
        if tHit and not isWaterOrDrop(tHit, goalPos.Y + 5) then
            if not isNearWater(goalPos.X, goalPos.Z, tHit.Position.Y, 7.0) then
                return goalPos
            end
        end
        local bestCand = nil
        local bestDist = 1e9
        local dPos = Vector3.new(-3121.05, 46.34, -3618.09)
        for dist = 25, 45, 10 do
            for ang = 0, 337.5, 22.5 do
                local rad = math.rad(ang)
                local cand = goalPos + Vector3.new(math.cos(rad) * dist, 0, math.sin(rad) * dist)
                local gRay = WS:Raycast(cand + Vector3.new(0, 6, 0), Vector3.new(0, -18, 0), rpGround)
                if gRay and not isWaterOrDrop(gRay, cand.Y + 6) then
                    local gY = gRay.Position.Y
                    if not isNearWater(cand.X, cand.Z, gY, 6.0) then
                        local dVal = (cand - dPos).Magnitude
                        if dVal < bestDist then
                            bestDist = dVal
                            bestCand = Vector3.new(cand.X, gY + 1.5, cand.Z)
                        end
                    end
                end
            end
            if bestCand then break end
        end
        return bestCand
    end

    -- 1. Distance check: ONLY use horse travel if genuinely far away (> horseThreshold studs)!
    local horseThreshold = maxHorseThreshold or 100
    local distToTarget = (r.Position - targetPos).Magnitude
    if distToTarget > horseThreshold then
        local isTargetDaniel = (targetPos - Vector3.new(-3121.05, 46.34, -3618.09)).Magnitude < 20
        local stagingPos
        if isTargetDaniel then
            stagingPos = targetPos
        else
            local activeName = FISH.getActiveSetName()
            stagingPos = FISH.getStagingPoint(activeName)
            if not stagingPos then
                stagingPos = findSafeStagingLand(targetPos)
            end
        end

        if stagingPos then
            FISH.viz.currentAction = string.format("Horse Travel to Staging Point (%.0fm away)...", distToTarget)
            logAction("TRAVEL", string.format("Legit Fishing: Far from target (%.0f studs). Riding horse to staging point...", distToTarget), Color3.fromRGB(90, 180, 255), "TRAVEL")
            horseTeleport(stagingPos)
            landBeside(stagingPos, 2)
            dismount()
            task.wait(0.3)
        else
            logAction("TRAVEL", "No safe staging point set; navigating on foot to prevent water hazard.", Color3.fromRGB(245, 175, 60), "TRAVEL")
            if isMounted(myHorse()) then
                dismount()
            end
        end

        r = root(); h = hum()
        if not r or not h or h.Health <= 0 or FISH.walkCancelToken ~= myToken then
            FISH.isWalking = false
            return false
        end
    else
        if isMounted(myHorse()) then
            FISH.viz.currentAction = "Dismounting Horse..."
            dismount()
            task.wait(0.3)
            r = root(); h = hum()
            if not r or not h or h.Health <= 0 or FISH.walkCancelToken ~= myToken then
                FISH.isWalking = false
                return false
            end
        end
    end

    local initialDist = (targetPos - r.Position).Magnitude
    logAction("TRAVEL", string.format("Legit walking towards spot (%.0f studs away)...", initialDist), Color3.fromRGB(90, 180, 255), "TRAVEL")

    -- Strict Landed Check: Required before any jump to prevent anti-cheat detection from infinite mid-air jumps
    local lastJumpTime = 0
    local function isLanded()
        local curH = hum()
        local curR = root()
        if not curH or not curR or curH.Health <= 0 then return false end

        if curH.FloorMaterial == Enum.Material.Air then
            return false
        end

        local state = curH:GetState()
        if state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Swimming then
            return false
        end

        local feetPos = curR.Position + Vector3.new(0, -1.5, 0)
        local groundHit = WS:Raycast(feetPos, Vector3.new(0, -2.5, 0), rpGround)
        if not groundHit or isWaterOrDrop(groundHit, feetPos.Y) then
            return false
        end

        return true
    end

    local function safeJump()
        if not isLanded() then
            return false
        end
        if os.clock() - lastJumpTime < 0.65 then
            return false
        end
        lastJumpTime = os.clock()
        local curH = hum()
        if curH then curH.Jump = true end
        return true
    end

    local function isDoorInst(inst)
        if not inst then return false end
        local nm = inst.Name:lower()
        local pnm = inst.Parent and inst.Parent.Name:lower() or ""
        return nm:find("door") or nm:find("gate") or nm:find("entrance") or nm:find("portal")
            or pnm:find("door") or pnm:find("gate") or pnm:find("entrance")
    end

    local function tryOpenNearbyDoor(centerPart)
        if not centerPart then return false end
        local model = centerPart:FindFirstAncestorOfClass("Model") or centerPart
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = desc.ActionText:lower()
                local obj = desc.ObjectText:lower()
                local name = desc.Name:lower()
                if act:find("open") or act:find("enter") or act:find("door") or act:find("use") or
                   obj:find("door") or obj:find("gate") or name:find("door") or name:find("gate") or act == "" then
                    if firepp then
                        pcall(firepp, desc, desc.HoldDuration or 0)
                        task.wait(0.08)
                        return true
                    end
                end
            end
        end
        return false
    end

    -- Full Body Clearance + Lateral Water Buffer (Center, Left 2.5m, Right 2.5m)
    -- Guarantees a wide 5-stud dry land corridor; rejects any segment that skirts near water edges
    local function canBodyTraverse(posA, posB)
        local diff = posB - posA
        local dist = diff.Magnitude
        if dist < 0.5 then return true end

        local fwd = diff.Unit
        local side = Vector3.new(-fwd.Z, 0, fwd.X)
        local shoulderOffset = 1.15

        -- 1. Three parallel waist rays: Center, Left, Right
        local wCenter = posA + Vector3.new(0, 1.8, 0)
        local wLeft = wCenter - (side * shoulderOffset)
        local wRight = wCenter + (side * shoulderOffset)
        local targetOffset = fwd * dist

        local hitCenter = WS:Raycast(wCenter, targetOffset, rpBody)
        if hitCenter and hitCenter.Instance and hitCenter.Instance.CanCollide and not hitCenter.Instance:IsA("Terrain") and not isDoorInst(hitCenter.Instance) then
            return false
        end

        local hitLeft = WS:Raycast(wLeft, targetOffset, rpBody)
        if hitLeft and hitLeft.Instance and hitLeft.Instance.CanCollide and not hitLeft.Instance:IsA("Terrain") and not isDoorInst(hitLeft.Instance) then
            return false
        end

        local hitRight = WS:Raycast(wRight, targetOffset, rpBody)
        if hitRight and hitRight.Instance and hitRight.Instance.CanCollide and not hitRight.Instance:IsA("Terrain") and not isDoorInst(hitRight.Instance) then
            return false
        end

        -- 2. Chest center ray
        local cCenter = posA + Vector3.new(0, 3.2, 0)
        local hitChest = WS:Raycast(cCenter, targetOffset, rpBody)
        if hitChest and hitChest.Instance and hitChest.Instance.CanCollide and not hitChest.Instance:IsA("Terrain") and not isDoorInst(hitChest.Instance) then
            return false
        end

        -- 3. Low feet ray: detects thin sticks, curbs, and low fences that trip the character
        local fCenter = posA + Vector3.new(0, 0.6, 0)
        local hitFeet = WS:Raycast(fCenter, targetOffset, rpBody)
        if hitFeet and hitFeet.Instance and hitFeet.Instance.CanCollide and not hitFeet.Instance:IsA("Terrain") and not isDoorInst(hitFeet.Instance) then
            if hitCenter ~= nil or hitChest ~= nil then
                return false
            end
        end

        -- 4. Ground and WATER clearance sampled along the line every 1.5 studs (Triple Lateral Ground Check)
        local numSamples = math.clamp(math.ceil(dist / 1.5), 1, 55)
        for i = 1, numSamples do
            local alpha = i / (numSamples + 1)
            local p = posA:Lerp(posB, alpha)

            -- Center Ground Check
            local gRay = WS:Raycast(p + Vector3.new(0, 4.0, 0), Vector3.new(0, -12.0, 0), rpGround)
            if not gRay or isWaterOrDrop(gRay, p.Y + 4.0) then
                return false
            end
            if math.abs(gRay.Position.Y - p.Y) > 3.5 then
                return false
            end

            -- If not confirmed bridge deck, verify lateral dry land margin (2.5 studs left & right)
            local isBridge = isBridgePart(gRay.Instance)
            if not isBridge then
                local pLeft = p - (side * 2.5)
                local gLeft = WS:Raycast(pLeft + Vector3.new(0, 4.0, 0), Vector3.new(0, -12.0, 0), rpGround)
                if not gLeft or isWaterOrDrop(gLeft, p.Y + 4.0) then
                    return false
                end

                local pRight = p + (side * 2.5)
                local gRight = WS:Raycast(pRight + Vector3.new(0, 4.0, 0), Vector3.new(0, -12.0, 0), rpGround)
                if not gRight or isWaterOrDrop(gRight, p.Y + 4.0) then
                    return false
                end
            end
        end

        return true
    end

    -- 3. Baritone Multi-Route Candidate Generator with Maximum Water Margin
    local function generateCandidateRoute(startPos, goalPos, corridorBias, gridStep)
        local GRID_SIZE = gridStep or 4.0
        local startGX = math.floor(startPos.X / GRID_SIZE + 0.5)
        local startGZ = math.floor(startPos.Z / GRID_SIZE + 0.5)
        local goalGX = math.floor(goalPos.X / GRID_SIZE + 0.5)
        local goalGZ = math.floor(goalPos.Z / GRID_SIZE + 0.5)

        local mainFwd = (goalPos - startPos)
        local mainFlat = Vector3.new(mainFwd.X, 0, mainFwd.Z)
        local mainDir = mainFlat.Magnitude > 1 and mainFlat.Unit or Vector3.new(0, 0, 1)

        local cache = {}
        local function getNode(gx, gz, refY)
            local key = (gx + 10000) * 20000 + (gz + 10000)
            local c = cache[key]
            if c ~= nil then return c end

            local wx = gx * GRID_SIZE
            local wz = gz * GRID_SIZE
            local gRay = WS:Raycast(Vector3.new(wx, refY + 4.5, wz), Vector3.new(0, -22.0, 0), rpGround)

            if not gRay or isWaterOrDrop(gRay, refY + 4.5) then
                cache[key] = false
                return false
            end

            local gY = gRay.Position.Y
            local isBridge = isBridgePart(gRay.Instance)

            -- WATER AVOIDANCE AT ALL COSTS: If not on a bridge, check if water is within 5.0 studs
            local nearWater = false
            if not isBridge then
                nearWater = isNearWater(wx, wz, gY, 5.0)
            end

            -- Headroom check
            local hHit = WS:Raycast(Vector3.new(wx, gY + 1.2, wz), Vector3.new(0, 3.5, 0), rpBody)
            if hHit and hHit.Instance and hHit.Instance.CanCollide and not hHit.Instance:IsA("Terrain") and not isDoorInst(hHit.Instance) then
                cache[key] = false
                return false
            end

            -- Body width clearance check around node: ensure not right against a stick/post/wall
            local sideA = WS:Raycast(Vector3.new(wx - 1.2, gY + 1.8, wz), Vector3.new(2.4, 0, 0), rpBody)
            local sideB = WS:Raycast(Vector3.new(wx, gY + 1.8, wz - 1.2), Vector3.new(0, 0, 2.4), rpBody)
            local isTight = (sideA and sideA.Instance and sideA.Instance.CanCollide and not sideA.Instance:IsA("Terrain") and not isDoorInst(sideA.Instance))
                or (sideB and sideB.Instance and sideB.Instance.CanCollide and not sideB.Instance:IsA("Terrain") and not isDoorInst(sideB.Instance))

            local node = {
                gx = gx,
                gz = gz,
                pos = Vector3.new(wx, gY + 1.5, wz),
                gY = gY,
                isTight = isTight,
                nearWater = nearWater,
                isBridge = isBridge
            }
            cache[key] = node
            return node
        end

        local heap = {}
        local function heapPush(item)
            table.insert(heap, item)
            local idx = #heap
            while idx > 1 do
                local parent = math.floor(idx / 2)
                if heap[idx].f < heap[parent].f then
                    heap[idx], heap[parent] = heap[parent], heap[idx]
                    idx = parent
                else
                    break
                end
            end
        end

        local function heapPop()
            if #heap == 0 then return nil end
            local top = heap[1]
            local last = table.remove(heap)
            if #heap > 0 then
                heap[1] = last
                local idx = 1
                local n = #heap
                while true do
                    local left = idx * 2
                    local right = left + 1
                    local smallest = idx
                    if left <= n and heap[left].f < heap[smallest].f then smallest = left end
                    if right <= n and heap[right].f < heap[smallest].f then smallest = right end
                    if smallest ~= idx then
                        heap[idx], heap[smallest] = heap[smallest], heap[idx]
                        idx = smallest
                    else
                        break
                    end
                end
            end
            return top
        end

        local gScore = {}
        local cameFrom = {}
        local visited = {}

        local startKey = (startGX + 10000) * 20000 + (startGZ + 10000)
        gScore[startKey] = 0
        local startNode = getNode(startGX, startGZ, startPos.Y) or { gx = startGX, gz = startGZ, pos = startPos, gY = startPos.Y, isTight = false, nearWater = false, isBridge = false }

        heapPush({
            gx = startGX,
            gz = startGZ,
            pos = startNode.pos,
            gY = startNode.gY,
            f = (startNode.pos - goalPos).Magnitude
        })

        local DIRS = {
            {1, 0, 1.0}, {-1, 0, 1.0}, {0, 1, 1.0}, {0, -1, 1.0},
            {1, 1, 1.414}, {1, -1, 1.414}, {-1, 1, 1.414}, {-1, -1, 1.414}
        }

        local closestNode = startNode
        local closestDist = (startNode.pos - goalPos).Magnitude
        local nodesExplored = 0

        while #heap > 0 and nodesExplored < 650 do
            local current = heapPop()
            if not current then break end
            nodesExplored = nodesExplored + 1

            local curKey = (current.gx + 10000) * 20000 + (current.gz + 10000)
            visited[curKey] = true

            local distToGoal = (current.pos - goalPos).Magnitude
            if distToGoal < closestDist then
                closestDist = distToGoal
                closestNode = current
            end

            if math.abs(current.gx - goalGX) <= 1 and math.abs(current.gz - goalGZ) <= 1 then
                closestNode = current
                break
            end

            local curG = gScore[curKey] or 0

            for _, d in ipairs(DIRS) do
                local ngx = current.gx + d[1]
                local ngz = current.gz + d[2]
                local nKey = (ngx + 10000) * 20000 + (ngz + 10000)

                if not visited[nKey] then
                    local neighbor = getNode(ngx, ngz, current.gY)
                    if neighbor then
                        local yDiff = math.abs(neighbor.gY - current.gY)
                        if yDiff <= 3.8 then
                            local p1 = Vector3.new(current.pos.X, current.gY + 1.8, current.pos.Z)
                            local p2 = Vector3.new(neighbor.pos.X, neighbor.gY + 1.8, neighbor.pos.Z)
                            local wall = WS:Raycast(p1, p2 - p1, rpBody)
                            local isWall = wall and wall.Instance and wall.Instance.CanCollide and not wall.Instance:IsA("Terrain") and not isDoorInst(wall.Instance)

                            if not isWall then
                                local baseStepCost = d[3] * GRID_SIZE + (yDiff * 1.8)
                                if neighbor.isTight then
                                    baseStepCost = baseStepCost + 4.0
                                end

                                -- AVOID WATER AT ALL COSTS: Massive penalty if near water
                                if neighbor.nearWater then
                                    baseStepCost = baseStepCost + 75.0
                                end

                                -- Corridor bias: explore diverse flanks (Left, Right, Inland)
                                if corridorBias == "left" then
                                    local toN = neighbor.pos - startPos
                                    local cross = mainDir.X * toN.Z - mainDir.Z * toN.X
                                    if cross < 0 then baseStepCost = baseStepCost + (math.abs(cross) * 0.2) end
                                elseif corridorBias == "right" then
                                    local toN = neighbor.pos - startPos
                                    local cross = mainDir.X * toN.Z - mainDir.Z * toN.X
                                    if cross > 0 then baseStepCost = baseStepCost + (cross * 0.2) end
                                elseif corridorBias == "inland" then
                                    if neighbor.nearWater then baseStepCost = baseStepCost + 200.0 end
                                end

                                local tentativeG = curG + baseStepCost
                                if tentativeG < (gScore[nKey] or 1e9) then
                                    gScore[nKey] = tentativeG
                                    cameFrom[nKey] = current
                                    local hDist = (neighbor.pos - goalPos).Magnitude
                                    heapPush({
                                        gx = ngx,
                                        gz = ngz,
                                        pos = neighbor.pos,
                                        gY = neighbor.gY,
                                        f = tentativeG + hDist
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        local rawPath = {}
        local curr = closestNode
        while curr do
            table.insert(rawPath, 1, curr.pos)
            local cKey = (curr.gx + 10000) * 20000 + (curr.gz + 10000)
            curr = cameFrom[cKey]
        end

        if #rawPath == 0 then return { goalPos } end
        if (rawPath[#rawPath] - goalPos).Magnitude > 1.2 then
            table.insert(rawPath, goalPos)
        end

        -- Raytraced string-pulling using 5-stud multi-ray body and water clearance
        local pruned = { rawPath[1] }
        local currentIdx = 1
        while currentIdx < #rawPath do
            local nextIdx = #rawPath
            while nextIdx > currentIdx + 1 do
                if canBodyTraverse(rawPath[currentIdx], rawPath[nextIdx]) then
                    break
                end
                nextIdx = nextIdx - 1
            end
            table.insert(pruned, rawPath[nextIdx])
            currentIdx = nextIdx
        end

        return pruned
    end

    -- Upfront Candidate Route Evaluation: Heavily penalizes any proximity to water
    local function evaluateRouteQuality(waypoints, goalPos)
        if not waypoints or #waypoints == 0 then return 1e9 end
        local lastWP = waypoints[#waypoints]
        local endDist = (lastWP - goalPos).Magnitude
        if endDist > 4.5 then
            return 50000 + endDist * 100
        end

        local totalLen = 0
        local totalCurvature = 0
        local elevationSteps = 0
        local waterPenalty = 0

        for i = 1, #waypoints - 1 do
            local pA = waypoints[i]
            local pB = waypoints[i + 1]
            totalLen = totalLen + (pB - pA).Magnitude
            if math.abs(pB.Y - pA.Y) > 1.0 then
                elevationSteps = elevationSteps + 1
            end
            if i > 1 then
                local v1 = (pA - waypoints[i - 1]).Unit
                local v2 = (pB - pA).Unit
                totalCurvature = totalCurvature + (1 - math.clamp(v1:Dot(v2), -1, 1)) * 8
            end

            -- Strict water proximity penalty: checks if waypoint is near water
            local nearWaterCheck = WS:Raycast(pB + Vector3.new(0, 3.5, 0), Vector3.new(0, -10.0, 0), rpGround)
            if nearWaterCheck and not isBridgePart(nearWaterCheck.Instance) then
                if isNearWater(pB.X, pB.Z, pB.Y, 5.5) then
                    waterPenalty = waterPenalty + 80.0
                end
            end
        end

        return (totalLen * 1.0) + (totalCurvature * 2.0) + (elevationSteps * 6.0) + waterPenalty + (#waypoints * 2.5)
    end

    -- Fast Check: Can we walk directly to goalPos with full body clearance AND zero water risk?
    local waypoints
    if canBodyTraverse(r.Position, targetPos) then
        waypoints = { targetPos }
        logAction("TRAVEL", "Direct route confirmed with complete dry land clearance.", Color3.fromRGB(80, 220, 140), "TRAVEL")
    else
        -- Calculate multiple candidate routes prioritizing maximum water avoidance
        local candidates = {
            { name = "Inland Highway", bias = "inland", step = 4.0 },
            { name = "Direct Safe A*", bias = "none", step = 4.0 },
            { name = "Left Flank", bias = "left", step = 4.0 },
            { name = "Right Flank", bias = "right", step = 4.0 },
        }

        local bestScore = 1e9
        local bestRoute = nil
        local bestName = "Inland Highway"

        for _, cand in ipairs(candidates) do
            local route = generateCandidateRoute(r.Position, targetPos, cand.bias, cand.step)
            local score = evaluateRouteQuality(route, targetPos)
            if score < bestScore then
                bestScore = score
                bestRoute = route
                bestName = cand.name
            end
        end

        waypoints = bestRoute or { targetPos }
        logAction("TRAVEL", string.format("Selected safest route '%s' (water-shielded, score %.0f, %d waypoints)", bestName, bestScore, #waypoints), Color3.fromRGB(80, 220, 140), "TRAVEL")
    end

    local maxWalkTime = math.clamp(initialDist / 2.5 + 10, 10, 90)
    local tStart = os.clock()
    local lastPos = r.Position
    local lastStuckCheck = os.clock()
    local stuckCount = 0
    local success = false
    local lastDryPos = r.Position
    local wpIndex = 1
    local lastPathCalc = os.clock()

    while S.running and S.autoFish and os.clock() - tStart < maxWalkTime do
        if FISH.walkCancelToken ~= myToken then
            break
        end

        r = root(); h = hum()
        if not r or not r.Parent or not h or not h.Parent or h.Health <= 0 then
            logAction("TRAVEL", "Legit walk interrupted: Character dead or despawned", Color3.fromRGB(245, 90, 90), "ERROR")
            break
        end

        local hState = h:GetState()
        if hState == Enum.HumanoidStateType.Ragdoll or hState == Enum.HumanoidStateType.FallingDown or hState == Enum.HumanoidStateType.Physics then
            FISH.viz.currentAction = "Recovering from knockdown/ragdoll..."
            pcall(function()
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
                h.PlatformStand = false
            end)
            task.wait(0.2)
        elseif hState == Enum.HumanoidStateType.Swimming then
            -- WATER RESCUE: Swim to verified safe land without mid-air jumps
            FISH.viz.currentAction = "IN WATER: Swimming to dry land..."
            local rescueTarget = lastDryPos
            if not rescueTarget or (rescueTarget - r.Position).Magnitude < 1 then
                for ang = 0, 315, 45 do
                    local pDir = (CFrame.Angles(0, math.rad(ang), 0) * Vector3.new(0, 0, 1)).Unit
                    local gProbe = WS:Raycast(r.Position + (pDir * 10) + Vector3.new(0, 3.5, 0), Vector3.new(0, -12.0, 0), rpGround)
                    if gProbe and not isWaterOrDrop(gProbe, r.Position.Y + 3.5) then
                        rescueTarget = gProbe.Position + Vector3.new(0, 2.0, 0)
                        break
                    end
                end
            end
            if not rescueTarget then
                rescueTarget = r.Position - Vector3.new(0, 0, 12)
            end

            local rescueStart = os.clock()
            while os.clock() - rescueStart < 4.0 and S.running and S.autoFish do
                r = root(); h = hum()
                if not r or not h or h.Health <= 0 or FISH.walkCancelToken ~= myToken then break end

                local curState = h:GetState()
                if curState ~= Enum.HumanoidStateType.Swimming then
                    local footRay = WS:Raycast(r.Position + Vector3.new(0, 2.0, 0), Vector3.new(0, -5.0, 0), rpGround)
                    if footRay and not isWaterOrDrop(footRay, r.Position.Y + 2.0) then
                        logAction("TRAVEL", "Escaped water successfully onto dry land!", Color3.fromRGB(80, 220, 140), "TRAVEL")
                        break
                    end
                end

                if isLanded() then
                    safeJump()
                end

                h:MoveTo(rescueTarget)
                task.wait(0.08)
            end

            hState = h:GetState()
            waypoints = generateCandidateRoute(r.Position, targetPos, "inland", 4.0)
            wpIndex = 1
        end

        if h.Sit then
            h.Sit = false
            safeJump()
        end
        if h.PlatformStand then
            h.PlatformStand = false
        end

        if hState ~= Enum.HumanoidStateType.Swimming then
            local footCheck = WS:Raycast(r.Position + Vector3.new(0, 2.0, 0), Vector3.new(0, -5.0, 0), rpGround)
            if footCheck and not isWaterOrDrop(footCheck, r.Position.Y + 2.0) then
                if not isNearWater(r.Position.X, r.Position.Z, r.Position.Y, 4.0) then
                    lastDryPos = r.Position
                end
            end
        end

        local toTarget = targetPos - r.Position
        local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

        if flatDist <= 4.2 then
            success = true
            break
        end

        local fwdDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
        local sideVec = Vector3.new(-fwdDir.Z, 0, fwdDir.X)

        -- 4. ACTIVE REAL-TIME WATER SHIELD & EMERGENCY WATER BRAKE
        -- Casts feelers 4.5 studs forward, left, and right. If water is detected within 4.5 studs:
        local fwdFeeler = WS:Raycast(r.Position + (fwdDir * 4.5) + Vector3.new(0, 3.5, 0), Vector3.new(0, -12.0, 0), rpGround)
        local leftFeeler = WS:Raycast(r.Position + (fwdDir * 3.5 - sideVec * 2.0) + Vector3.new(0, 3.5, 0), Vector3.new(0, -12.0, 0), rpGround)
        local rightFeeler = WS:Raycast(r.Position + (fwdDir * 3.5 + sideVec * 2.0) + Vector3.new(0, 3.5, 0), Vector3.new(0, -12.0, 0), rpGround)

        local waterAhead = isWaterOrDrop(fwdFeeler, r.Position.Y + 3.5)
            or isWaterOrDrop(leftFeeler, r.Position.Y + 3.5)
            or isWaterOrDrop(rightFeeler, r.Position.Y + 3.5)

        if waterAhead and hState ~= Enum.HumanoidStateType.Swimming then
            -- If within 10 studs of fishing spot: HALT IMMEDIATELY ON DRY SHORE! (No need to step closer to water)
            if flatDist <= 10.0 then
                local underFeet = WS:Raycast(r.Position + Vector3.new(0, 2.0, 0), Vector3.new(0, -5.0, 0), rpGround)
                if underFeet and not isWaterOrDrop(underFeet, r.Position.Y + 2.0) then
                    success = true
                    FISH.viz.currentAction = "Safe on dry shore! Halting to avoid water."
                    logAction("TRAVEL", string.format("Arrived safely at fishing spot edge (%.1fm away). Halting on dry land.", flatDist), Color3.fromRGB(80, 220, 140), "FISHING")
                    break
                end
            else
                -- Not at destination: Emergency Brake & re-plan inland route
                h:MoveTo(r.Position)
                FISH.viz.currentAction = "Water Shield: Emergency brake active!"
                waypoints = generateCandidateRoute(r.Position, targetPos, "inland", 4.0)
                wpIndex = 1
            end
        end

        -- Manage active waypoint
        if wpIndex > #waypoints then
            wpIndex = #waypoints
        end

        local currentWp = waypoints[wpIndex]
        local wpFlatDist = Vector3.new(currentWp.X - r.Position.X, 0, currentWp.Z - r.Position.Z).Magnitude

        -- Advance waypoint when reached
        if wpFlatDist <= 3.0 and wpIndex < #waypoints then
            wpIndex = wpIndex + 1
            currentWp = waypoints[wpIndex]
        end

        -- Forward lookahead shortcut: skip intermediate waypoints if full 5-stud dry corridor is confirmed
        if os.clock() - lastPathCalc > 0.6 then
            for fIdx = #waypoints, wpIndex + 2, -1 do
                if canBodyTraverse(r.Position, waypoints[fIdx]) then
                    wpIndex = fIdx
                    currentWp = waypoints[wpIndex]
                    break
                end
            end
            lastPathCalc = os.clock()
        end

        -- Check for doors along current segment
        local wpDir = (currentWp - r.Position)
        if wpDir.Magnitude > 0.5 then
            local doorRay = WS:Raycast(r.Position + Vector3.new(0, 1.5, 0), wpDir.Unit * 4.5, rpBody)
            if doorRay and isDoorInst(doorRay.Instance) then
                tryOpenNearbyDoor(doorRay.Instance)
            end
        end

        -- Step elevation check: safe jump when approaching steps/stairs/curbs
        local isStepUp = (currentWp.Y - r.Position.Y) > 1.0
        local fwdFeet = WS:Raycast(r.Position + Vector3.new(0, -1.5, 0), (currentWp - r.Position).Unit * 3.2, rpBody)
        if isStepUp or (fwdFeet and fwdFeet.Instance and fwdFeet.Instance.CanCollide and not fwdFeet.Instance:IsA("Terrain")) then
            safeJump()
        end

        -- Full continuous walk / sprint towards current waypoint
        if flatDist > 15 then
            FISH.viz.currentSpeed = 22
            pcall(function()
                h.WalkSpeed = 22
                if keypressFn then pcall(keypressFn, 0x10) end
            end)
        else
            FISH.viz.currentSpeed = 16
            pcall(function()
                h.WalkSpeed = 16
                if keyreleaseFn then pcall(keyreleaseFn, 0x10) end
            end)
        end

        FISH.viz.currentAction = string.format("Water-Safe Route: Node %d/%d (%.0fm to Spot)", wpIndex, #waypoints, flatDist)
        FISH.viz.steerTarget = currentWp
        h:MoveTo(currentWp)

        -- Stuck detection: If stuck, re-plan route with wider inland clearance
        if os.clock() - lastStuckCheck > 0.70 then
            local moved = (r.Position - lastPos).Magnitude
            if moved < 0.6 and flatDist > 4.2 then
                stuckCount = stuckCount + 1
                safeJump()
                if stuckCount >= 2 then
                    local fallbackBias = (stuckCount % 2 == 0) and "inland" or "left"
                    waypoints = generateCandidateRoute(r.Position, targetPos, fallbackBias, 4.0)
                    wpIndex = 1
                    currentWp = waypoints[1] or targetPos
                    h:MoveTo(currentWp)
                end
                if stuckCount >= 6 then
                    logAction("TRAVEL", "Path blocked by obstruction after repeated attempts. Continuing cleanly.", Color3.fromRGB(245, 160, 60), "TRAVEL")
                    break
                end
            else
                stuckCount = 0
            end
            lastPos = r.Position
            lastStuckCheck = os.clock()
        end

        task.wait(0.05)
    end

    pcall(function()
        local hFinal = hum()
        if hFinal then hFinal.WalkSpeed = 16 end
        if keyreleaseFn then pcall(keyreleaseFn, 0x10) end
    end)

    FISH.viz.steerTarget = nil
    FISH.viz.centerRay = nil
    FISH.viz.leftRay = nil
    FISH.viz.rightRay = nil
    FISH.isWalking = false

    if success then
        logAction("TRAVEL", string.format("Successfully arrived safely on dry land (%.1fm to spot)! Ready to fish.", (r and (targetPos - r.Position).Magnitude) or 0), Color3.fromRGB(80, 220, 140), "FISHING")
    end
    return success
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

local function aimAtWater()
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
            if hit and (hit.Material == Enum.Material.Water or (hit.Instance and hit.Instance.Name:lower():find("water"))) then
                local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(eye.X, 0, eye.Z)).Magnitude
                if d > 12 and d < 120 then
                    local score = math.abs(d - 65)
                    if not bestD or score < bestD then bestCF, bestD = cf, score end
                end
            end
        end
    end
    if not bestCF then
        FISH.status = "no castable water in view"
        logAction("FISH", "No castable water in view", Color3.fromRGB(245, 160, 60), "FISHING")
        return false
    end
    camv.CFrame = bestCF
    local look = bestCF.LookVector
    pcall(function() r.CFrame = CFrame.new(r.Position, r.Position + Vector3.new(look.X, 0, look.Z)) end)
    RunService.Heartbeat:Wait()
    local hit = rayThroughCursor(300)
    if hit and (hit.Material == Enum.Material.Water or (hit.Instance and hit.Instance.Name:lower():find("water"))) then
        local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude
        FISH.status = ("aimed at water %d studs"):format(math.floor(d))
        logAction("FISH", ("Locked onto water (%d studs out)"):format(math.floor(d)), Color3.fromRGB(80, 220, 140), "FISHING")
        return true
    end
    FISH.status = "aim verify failed"
    logAction("FISH", "Water aim verification failed", Color3.fromRGB(245, 160, 60), "FISHING")
    return false
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
                                if sfx:IsA("Sound") and sfx.IsPlaying
                                   and (sfx.Name == "FishBite" or sfx.Name == "BiteCrunch") then
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

local function isRodCast()
    local a = anims()
    if a.SwingRod or a.RodIdle or a.ReelLoop then return true end
    local c = char()
    local rod = c and c:FindFirstChildWhichIsA("Tool")
    if rod then
        for _, d in ipairs(rod:GetDescendants()) do
            if d:IsA("RopeConstraint") or d:IsA("RodConstraint") or d:IsA("Beam") then
                return true
            end
            if (d.Name:lower():find("bobber") or d.Name:lower():find("line")) and d:IsA("BasePart") then
                local r = root()
                if r and (d.Position - r.Position).Magnitude > 6 then
                    return true
                end
            end
        end
        if rod:GetAttribute("Cast") or rod:GetAttribute("Casted") then return true end
    end
    return false
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
                        horseTeleport(FISH_SPOTS[spotIndex])
                        landBeside(FISH_SPOTS[spotIndex], 3)
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
                            horseTeleport(FISH_SPOTS[spotIndex])
                            landBeside(FISH_SPOTS[spotIndex], 3)
                        end
                    end
                end
                if buyBait() then
                    logAction("TRAVEL", "Returning to fishing spot with fresh bait...", Color3.fromRGB(90, 180, 255), "TRAVEL")
                    if S.legitFishing then
                        FISH.walkToSpotLegit(FISH_SPOTS[spotIndex], 300)
                    else
                        horseTeleport(FISH_SPOTS[spotIndex])
                        landBeside(FISH_SPOTS[spotIndex], 3)
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
                    horseTeleport(FISH_SPOTS[spotIndex])
                    dismount()
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
    if r and (r.Position - spot).Magnitude > 35 then
        if FISH.isWalking then
            -- Legit walk already actively navigating: do not spawn overlapping walk
            return
        end
        FISH.status = "travelling to fishing spot"
        logAction("TRAVEL", ("Travelling to fishing spot #%d (%.0f studs away)..."):format(spotIndex, (r.Position - spot).Magnitude), Color3.fromRGB(90, 180, 255), "TRAVEL")
        if S.legitFishing then
            FISH.walkToSpotLegit(spot)
        else
            horseTeleport(spot)
            landBeside(spot, 3)
        end
        return
    end
    if not aimAtWater() then
        return
    end
    tap("PrimaryInput", 0.35)
    pcall(function()
        if mouse1press and mouse1release then
            mouse1press()
            task.wait(0.35)
            mouse1release()
        end
    end)
    task.wait(0.7)
    if not isRodCast() then
        FISH.status = "cast not detected - recasting"
        logAction("FISH", "Cast not detected on rod - recasting immediately", Color3.fromRGB(245, 160, 60), "FISHING")
        castPhase = "idle"
        lastCast = 0
        return
    end
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
