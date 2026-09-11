--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Navigation
-- Baritone Weighted A*, Dynamic Ray Splicing & Hardware Jump Motor
-- ============================================================
local ctx = ...
local SHARED = ctx and ctx.SHARED or getfenv(0)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer or Players:GetPlayers()[1]

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

local function log(msg, color, tag)
    if ctx and ctx.Logging and ctx.Logging.logAction then
        ctx.Logging.logAction("NAV", msg, color or Color3.fromRGB(80, 200, 255), tag or "TRAVEL")
    elseif SHARED.logAction then
        SHARED.logAction("NAV", msg, color or Color3.fromRGB(80, 200, 255), tag or "TRAVEL")
    end
end

-- ==========================================
-- EXECUTOR HARDWARE KEYBOARD DRIVER
-- ==========================================
local keypressFn = keypress or (syn and syn.keypress) or (fluxus and fluxus.keypress)
local keyreleaseFn = keyrelease or (syn and syn.keyrelease) or (fluxus and fluxus.keyrelease)
local keyclickFn = keyclick

local function tapSpace()
    if keyclickFn then
        pcall(keyclickFn, 0x20)
    elseif keypressFn and keyreleaseFn then
        pcall(keypressFn, 0x20)
        task.wait(0.035)
        pcall(keyreleaseFn, 0x20)
    end
end

-- ==========================================
-- CONFIGURATION & RAYCAST FILTERS
-- ==========================================
local GRID_SIZE = 3.5
local MAX_STEP_UP = 2.4
local MAX_SINGLE_JUMP = 5.2
local MAX_DOUBLE_JUMP = 8.5
local MAX_DROP_DOWN = 18.0

local EXCLUDE_FILTER = (pcall(function() return Enum.RaycastFilterType.Exclude end) and Enum.RaycastFilterType.Exclude)
    or (pcall(function() return Enum.RaycastFilterType.Blacklist end) and Enum.RaycastFilterType.Blacklist)
    or 0

local VIZ_FOLDER_NAME = "_BaritoneNavVisuals"
local existingFolder = Workspace:FindFirstChild(VIZ_FOLDER_NAME)
if existingFolder then existingFolder:Destroy() end

local vizFolder = Instance.new("Folder")
vizFolder.Name = VIZ_FOLDER_NAME
vizFolder.Parent = Workspace

local rpGround = RaycastParams.new()
rpGround.FilterType = EXCLUDE_FILTER
rpGround.IgnoreWater = false

local rpBody = RaycastParams.new()
rpBody.FilterType = EXCLUDE_FILTER

local function updateFilters()
    local c = char()
    local ex = { vizFolder }
    if c then table.insert(ex, c) end
    if SHARED.myHorse then
        local mh = SHARED.myHorse()
        if mh then table.insert(ex, mh) end
    end
    rpGround.FilterDescendantsInstances = ex
    rpBody.FilterDescendantsInstances = ex
end

-- ==========================================
-- POLISHED VISUAL ENGINE
-- ==========================================
local routeFolder = Instance.new("Folder")
routeFolder.Name = "ActiveRoute"
routeFolder.Parent = vizFolder

local targetFolder = Instance.new("Folder")
targetFolder.Name = "ActiveTarget"
targetFolder.Parent = vizFolder

local function clearRouteVisuals()
    routeFolder:ClearAllChildren()
end

local function clearAllVisuals()
    routeFolder:ClearAllChildren()
    targetFolder:ClearAllChildren()
end

local function drawTargetBeacon(targetPos: Vector3)
    targetFolder:ClearAllChildren()

    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 5.5, 5.5)
    ring.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(0, 255, 180)
    ring.Transparency = 0.2
    ring.Parent = targetFolder

    local pillar = Instance.new("Part")
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Size = Vector3.new(120, 0.8, 0.8)
    pillar.CFrame = CFrame.new(targetPos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.CanQuery = false
    pillar.Material = Enum.Material.Neon
    pillar.Color = Color3.fromRGB(0, 255, 180)
    pillar.Transparency = 0.6
    pillar.Parent = targetFolder
end

local function createBeam(p1: Vector3, p2: Vector3, color: Color3, parent: Instance)
    local part1 = Instance.new("Part")
    part1.Size = Vector3.new(0.05, 0.05, 0.05)
    part1.Position = p1
    part1.Anchored = true
    part1.CanCollide = false
    part1.CanQuery = false
    part1.Transparency = 1
    part1.Parent = parent

    local part2 = Instance.new("Part")
    part2.Size = Vector3.new(0.05, 0.05, 0.05)
    part2.Position = p2
    part2.Anchored = true
    part2.CanCollide = false
    part2.CanQuery = false
    part2.Transparency = 1
    part2.Parent = parent

    local a1 = Instance.new("Attachment", part1)
    local a2 = Instance.new("Attachment", part2)

    local beam = Instance.new("Beam")
    beam.Attachment0 = a1
    beam.Attachment1 = a2
    beam.Color = ColorSequence.new(color)
    beam.Width0 = 0.25
    beam.Width1 = 0.25
    beam.FaceCamera = true
    beam.Segments = 1
    beam.Parent = parent
    return beam
end

local function createWaypointMarker(pos: Vector3, labelText: string, color: Color3, parent: Instance)
    local marker = Instance.new("Part")
    marker.Shape = Enum.PartType.Ball
    marker.Size = Vector3.new(0.85, 0.85, 0.85)
    marker.Position = pos
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.Material = Enum.Material.Neon
    marker.Color = color
    marker.Transparency = 0.15
    marker.Parent = parent

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 90, 0, 22)
    bb.StudsOffset = Vector3.new(0, 1.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = marker
    bb.Parent = marker

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = labelText
    label.Parent = bb

    return marker
end

-- ==========================================
-- GEOMETRY & OBSTACLE EVALUATION
-- ==========================================
local function findWalkableFloor(origin: Vector3, searchDepth: number)
    local currentOrigin = origin
    local depthLeft = searchDepth

    for _ = 1, 5 do
        local hit = Workspace:Raycast(currentOrigin, Vector3.new(0, -depthLeft, 0), rpGround)
        if not hit then return nil end

        if hit.Material == Enum.Material.Water then return nil end
        local name = hit.Instance and hit.Instance.Name:lower() or ""
        if name:find("water") or name:find("ocean") or name:find("river") then return nil end

        if hit.Instance and (hit.Instance.CanCollide or hit.Instance:IsA("Terrain")) then
            return hit
        end

        local dropped = (currentOrigin.Y - hit.Position.Y) + 0.1
        depthLeft = depthLeft - dropped
        if depthLeft <= 0 then break end
        currentOrigin = hit.Position - Vector3.new(0, 0.1, 0)
    end
    return nil
end

local function isSolidWall(hitResult: RaycastResult): boolean
    if not hitResult or not hitResult.Instance then return false end
    if not hitResult.Instance.CanCollide and not hitResult.Instance:IsA("Terrain") then return false end
    if hitResult.Instance:IsA("Terrain") then
        return hitResult.Normal.Y < 0.55
    end
    return true
end

local function getObstacleTop(hitPos: Vector3, baseFloorY: number): (number, boolean, number)
    local probeY = baseFloorY + MAX_DOUBLE_JUMP + 2.0
    local probeOrigin = Vector3.new(hitPos.X, probeY, hitPos.Z)
    local topHit = findWalkableFloor(probeOrigin, MAX_DOUBLE_JUMP + 4.0)

    if topHit then
        local topY = topHit.Position.Y
        local obstacleHeight = topY - baseFloorY
        local ceiling = Workspace:Raycast(Vector3.new(hitPos.X, topY + 0.5, hitPos.Z), Vector3.new(0, 4.8, 0), rpBody)
        local hasHeadroom = not isSolidWall(ceiling)
        return obstacleHeight, hasHeadroom, topY
    end
    return math.huge, false, baseFloorY
end

local function evaluateCell(worldX: number, worldZ: number, refFloorY: number)
    local probeOrigin = Vector3.new(worldX, refFloorY + MAX_DOUBLE_JUMP + 1.5, worldZ)
    local totalDepth = MAX_DROP_DOWN + MAX_DOUBLE_JUMP + 2.5

    local floorHit = nil
    for _ = 1, 4 do
        floorHit = findWalkableFloor(probeOrigin, totalDepth)
        if not floorHit then return nil end

        local floorY = floorHit.Position.Y
        if floorY > (refFloorY + MAX_DOUBLE_JUMP + 0.5) then
            local dropAmount = (probeOrigin.Y - floorY) + 0.2
            totalDepth = totalDepth - dropAmount
            if totalDepth <= 0 then return nil end
            probeOrigin = Vector3.new(worldX, floorY - 0.2, worldZ)
        else
            break
        end
    end

    if not floorHit then return nil end
    local floorY = floorHit.Position.Y

    local ceiling = Workspace:Raycast(Vector3.new(worldX, floorY + 0.5, worldZ), Vector3.new(0, 5.0, 0), rpBody)
    if ceiling and isSolidWall(ceiling) then
        return nil
    end

    local nearEdge = false
    local EDGE_OFFSETS = {
        Vector3.new(2.0, 0, 0), Vector3.new(-2.0, 0, 0),
        Vector3.new(0, 0, 2.0), Vector3.new(0, 0, -2.0)
    }
    for _, off in ipairs(EDGE_OFFSETS) do
        local edgeHit = findWalkableFloor(Vector3.new(worldX + off.X, floorY + 2.0, worldZ + off.Z), 8.0)
        if not edgeHit or (floorY - edgeHit.Position.Y) > 5.0 then
            nearEdge = true
            break
        end
    end

    return {
        pos = Vector3.new(worldX, floorY + 1.5, worldZ),
        floorY = floorY,
        nearEdge = nearEdge
    }
end

local function isTraversableBetween(posA: Vector3, posB: Vector3, floorYA: number, floorYB: number): (boolean, string)
    local heightDiff = floorYB - floorYA
    if heightDiff > MAX_DOUBLE_JUMP or heightDiff < -MAX_DROP_DOWN then
        return false, "none"
    end

    local jumpType = "none"
    if heightDiff > MAX_STEP_UP and heightDiff <= MAX_SINGLE_JUMP then
        jumpType = "single"
    elseif heightDiff > MAX_SINGLE_JUMP and heightDiff <= MAX_DOUBLE_JUMP then
        jumpType = "double"
    end

    local baseFloor = math.min(floorYA, floorYB)
    local maxFloor = math.max(floorYA, floorYB)

    local waistA = Vector3.new(posA.X, maxFloor + 1.8, posA.Z)
    local waistB = Vector3.new(posB.X, maxFloor + 1.8, posB.Z)
    local dir = waistB - waistA
    local waistHit = Workspace:Raycast(waistA, dir, rpBody)

    if waistHit and isSolidWall(waistHit) then
        local obsHeight, hasHeadroom = getObstacleTop(waistHit.Position, baseFloor)
        if hasHeadroom then
            if obsHeight <= MAX_STEP_UP then
                jumpType = "none"
            elseif obsHeight <= MAX_SINGLE_JUMP then
                jumpType = "single"
            elseif obsHeight <= MAX_DOUBLE_JUMP then
                jumpType = "double"
            else
                return false, "none"
            end
        else
            return false, "none"
        end
    end

    local chestA = Vector3.new(posA.X, maxFloor + 3.2, posA.Z)
    local chestB = Vector3.new(posB.X, maxFloor + 3.2, posB.Z)
    local chestHit = Workspace:Raycast(chestA, chestB - chestA, rpBody)

    if chestHit and isSolidWall(chestHit) then
        local obsHeight, hasHeadroom = getObstacleTop(chestHit.Position, baseFloor)
        if hasHeadroom and obsHeight <= MAX_DOUBLE_JUMP then
            if obsHeight <= MAX_SINGLE_JUMP then
                jumpType = "single"
            else
                jumpType = "double"
            end
        else
            return false, "none"
        end
    end

    return true, jumpType
end

local function canTraverseDirect(posA: Vector3, posB: Vector3, floorYA: number, floorYB: number): boolean
    local horizDiff = Vector3.new(posB.X - posA.X, 0, posB.Z - posA.Z)
    local dist = horizDiff.Magnitude
    if dist < 1.0 then return true end

    local fwd = horizDiff.Unit
    local side = Vector3.new(-fwd.Z, 0, fwd.X)
    local shoulderOffset = 1.3
    local maxFloor = math.max(floorYA, floorYB)

    local wCenterA = Vector3.new(posA.X, maxFloor + 1.8, posA.Z)
    local targetDir = fwd * dist
    if isSolidWall(Workspace:Raycast(wCenterA, targetDir, rpBody)) then return false end
    if isSolidWall(Workspace:Raycast(wCenterA + (side * shoulderOffset), targetDir, rpBody)) then return false end
    if isSolidWall(Workspace:Raycast(wCenterA - (side * shoulderOffset), targetDir, rpBody)) then return false end

    local cCenterA = Vector3.new(posA.X, maxFloor + 3.2, posA.Z)
    if isSolidWall(Workspace:Raycast(cCenterA, targetDir, rpBody)) then return false end

    local steps = math.clamp(math.ceil(dist / 3.0), 1, 35)
    for i = 1, steps do
        local alpha = i / (steps + 1)
        local sampleHoriz = posA:Lerp(posB, alpha)
        local expectedY = floorYA + (floorYB - floorYA) * alpha

        local floorHit = findWalkableFloor(Vector3.new(sampleHoriz.X, expectedY + 3.5, sampleHoriz.Z), 10.0)
        if not floorHit or math.abs(floorHit.Position.Y - expectedY) > (MAX_STEP_UP + 1.5) then
            return false
        end
    end

    return true
end

-- ==========================================
-- BINARY HEAP WEIGHTED A*
-- ==========================================
local function heapPush(heap, item)
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

local function heapPop(heap)
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

local DIRS = {
    Vector3.new(GRID_SIZE, 0, 0), Vector3.new(-GRID_SIZE, 0, 0),
    Vector3.new(0, 0, GRID_SIZE), Vector3.new(0, 0, -GRID_SIZE),
    Vector3.new(GRID_SIZE, 0, GRID_SIZE), Vector3.new(-GRID_SIZE, 0, GRID_SIZE),
    Vector3.new(GRID_SIZE, 0, -GRID_SIZE), Vector3.new(-GRID_SIZE, 0, -GRID_SIZE),
}

local function solvePath(startPos: Vector3, goalPos: Vector3)
    updateFilters()

    local startFloorHit = findWalkableFloor(startPos + Vector3.new(0, 3.0, 0), 8.0)
    local startFloorY = startFloorHit and startFloorHit.Position.Y or (startPos.Y - 2.5)

    local goalFloorHit = findWalkableFloor(goalPos + Vector3.new(0, 3.0, 0), 14.0)
    local goalFloorY = goalFloorHit and goalFloorHit.Position.Y or goalPos.Y

    local startFloor = Vector3.new(startPos.X, startFloorY, startPos.Z)
    local goalFloor = Vector3.new(goalPos.X, goalFloorY, goalPos.Z)
    local resolvedGoal = goalFloor + Vector3.new(0, 1.5, 0)

    if canTraverseDirect(startFloor, goalFloor, startFloorY, goalFloorY) then
        local hDiff = goalFloorY - startFloorY
        local jType = "none"
        if hDiff > MAX_STEP_UP and hDiff <= MAX_SINGLE_JUMP then jType = "single" end
        if hDiff > MAX_SINGLE_JUMP and hDiff <= MAX_DOUBLE_JUMP then jType = "double" end
        return { { pos = resolvedGoal, floorY = goalFloorY, jumpType = jType } }, true
    end

    local originX = startFloor.X
    local originZ = startFloor.Z

    local openHeap = {}
    local cameFrom = {}
    local gScore = {}
    local closedSet = {}
    local jumpReq = {}

    local function key(gx: number, gz: number) return gx .. ":" .. gz end

    local startKey = key(0, 0)
    gScore[startKey] = 0

    local H_WEIGHT = 1.4
    local initialDist = (startFloor - goalFloor).Magnitude
    heapPush(openHeap, {
        gx = 0, gz = 0,
        pos = startFloor + Vector3.new(0, 1.5, 0),
        floorY = startFloorY,
        f = initialDist * H_WEIGHT
    })

    local bestNode = openHeap[1]
    local bestDist = initialDist
    local reachedGoal = false
    local iterations = 0

    while #openHeap > 0 and iterations < 6000 do
        iterations = iterations + 1
        local current = heapPop(openHeap)
        if not current then break end

        local currentFloor = Vector3.new(current.pos.X, current.floorY, current.pos.Z)
        local distToGoal = (currentFloor - goalFloor).Magnitude

        if distToGoal < bestDist then
            bestDist = distToGoal
            bestNode = current
        end

        if distToGoal <= GRID_SIZE * 1.4 or canTraverseDirect(currentFloor, goalFloor, current.floorY, goalFloorY) then
            bestNode = current
            reachedGoal = true
            break
        end

        local curKey = key(current.gx, current.gz)
        closedSet[curKey] = true
        local curG = gScore[curKey] or 0

        for _, offset in ipairs(DIRS) do
            local nGX = current.gx + math.round(offset.X / GRID_SIZE)
            local nGZ = current.gz + math.round(offset.Z / GRID_SIZE)
            local nKey = key(nGX, nGZ)

            if not closedSet[nKey] then
                local wx = originX + (nGX * GRID_SIZE)
                local wz = originZ + (nGZ * GRID_SIZE)
                local neighbor = evaluateCell(wx, wz, current.floorY)

                if neighbor then
                    local canTraverse, jType = isTraversableBetween(current.pos, neighbor.pos, current.floorY, neighbor.floorY)

                    if canTraverse then
                        local stepDist = (current.pos - neighbor.pos).Magnitude
                        local jumpPenalty = (jType == "double" and 4.0) or (jType == "single" and 1.5) or 0
                        local penalty = jumpPenalty + (neighbor.nearEdge and 14.0 or 0)
                        local tentativeG = curG + stepDist + penalty

                        if tentativeG < (gScore[nKey] or math.huge) then
                            cameFrom[nKey] = current
                            jumpReq[nKey] = jType
                            gScore[nKey] = tentativeG

                            local hDist = (Vector3.new(wx, neighbor.floorY, wz) - goalFloor).Magnitude
                            heapPush(openHeap, {
                                gx = nGX, gz = nGZ,
                                pos = neighbor.pos,
                                floorY = neighbor.floorY,
                                f = tentativeG + (hDist * H_WEIGHT)
                            })
                        end
                    end
                end
            end
        end
    end

    local rawPath = {}
    local curr = bestNode
    while curr do
        local cKey = key(curr.gx, curr.gz)
        table.insert(rawPath, 1, { pos = curr.pos, floorY = curr.floorY, jumpType = jumpReq[cKey] or "none" })
        curr = cameFrom[cKey]
    end

    if #rawPath <= 1 and not reachedGoal then
        return nil, false
    end

    if reachedGoal and (rawPath[#rawPath].pos - resolvedGoal).Magnitude > 1.5 then
        local hDiff = goalFloorY - rawPath[#rawPath].floorY
        local jType = "none"
        if hDiff > MAX_STEP_UP and hDiff <= MAX_SINGLE_JUMP then jType = "single" end
        if hDiff > MAX_SINGLE_JUMP and hDiff <= MAX_DOUBLE_JUMP then jType = "double" end
        table.insert(rawPath, { pos = resolvedGoal, floorY = goalFloorY, jumpType = jType })
    end

    local smoothed = { rawPath[1] }
    local cIdx = 1
    while cIdx < #rawPath do
        local nextIdx = #rawPath
        while nextIdx > cIdx + 1 do
            local pA = rawPath[cIdx].pos
            local pB = rawPath[nextIdx].pos
            if canTraverseDirect(pA, pB, rawPath[cIdx].floorY, rawPath[nextIdx].floorY) then
                break
            end
            nextIdx = nextIdx - 1
        end
        table.insert(smoothed, rawPath[nextIdx])
        cIdx = nextIdx
    end

    return smoothed, reachedGoal
end

-- ==========================================
-- JUMP CLIMB CONTROLLER
-- ==========================================
local function executeJumpClimb(targetWpPos: Vector3, requiredClearY: number, isDoubleJump: boolean, myToken: number, NAV: any)
    local r = root()
    local h = hum()
    if not r or not h or h.Health <= 0 then return false end

    h:Move(Vector3.zero, false)

    local climbStart = os.clock()
    local cleared = false

    while (os.clock() - climbStart < 3.2) and (NAV.walkToken == myToken) do
        r = root()
        h = hum()
        if not r or not h or h.Health <= 0 then break end

        local currentFeetY = r.Position.Y - 2.2
        if currentFeetY >= requiredClearY - 0.3 then
            cleared = true
            break
        end

        h:Move(Vector3.zero, false)

        tapSpace()
        if isDoubleJump then
            task.wait(0.20)
            tapSpace()
            task.wait(0.45)
        else
            task.wait(0.65)
        end
    end

    if cleared and NAV.walkToken == myToken then
        local pushStart = os.clock()
        while (os.clock() - pushStart < 0.40) and (NAV.walkToken == myToken) do
            r = root()
            h = hum()
            if not r or not h or h.Health <= 0 then break end
            h:MoveTo(targetWpPos)
            task.wait(0.05)
        end
    end

    return cleared
end

-- ==========================================
-- PUBLIC NAVIGATION CONTROLLER
-- ==========================================
local NAV = {
    walkToken = 0,
    isWalking = false,
    activeTarget = nil,
}

function NAV.cancel()
    NAV.walkToken = NAV.walkToken + 1
    NAV.isWalking = false
    clearAllVisuals()
    local h = hum()
    if h then
        pcall(function()
            h:Move(Vector3.zero, false)
            h.WalkSpeed = 16
        end)
    end
    if keyreleaseFn then pcall(keyreleaseFn, 0x10) end
end

function NAV.walkTo(targetPos: Vector3, options: any?): boolean
    if not targetPos then return false end
    local opt = options or {}
    local maxTimeout = opt.timeout or 120
    local stopDist = opt.stopDist or 3.8
    local allowSprint = opt.sprint ~= false
    local showViz = opt.visualize ~= false

    local r = root()
    local h = hum()
    if not r or not h or h.Health <= 0 then return false end

    NAV.walkToken = NAV.walkToken + 1
    local myToken = NAV.walkToken
    NAV.isWalking = true
    NAV.activeTarget = targetPos

    if showViz then
        drawTargetBeacon(targetPos)
    else
        clearAllVisuals()
    end

    local totalTimeout = os.clock()
    local success = false

    while NAV.walkToken == myToken and (os.clock() - totalTimeout < maxTimeout) do
        r = root()
        h = hum()
        if not r or not h or h.Health <= 0 then break end

        local distToBeacon = (targetPos - r.Position).Magnitude
        if distToBeacon <= stopDist then
            success = true
            break
        end

        local waypoints, isComplete = solvePath(r.Position, targetPos)

        if not waypoints or #waypoints == 0 then
            local escapeOffsets = {
                -r.CFrame.LookVector * 4.0,
                r.CFrame.RightVector * 4.0,
                -r.CFrame.RightVector * 4.0,
                -r.CFrame.LookVector * 4.0 + r.CFrame.RightVector * 4.0,
                -r.CFrame.LookVector * 4.0 - r.CFrame.RightVector * 4.0
            }
            for _, esc in ipairs(escapeOffsets) do
                local testPos = r.Position + esc
                waypoints, isComplete = solvePath(testPos, targetPos)
                if waypoints and #waypoints > 1 then
                    table.insert(waypoints, 1, { pos = testPos, floorY = testPos.Y - 1.5, jumpType = "none" })
                    break
                end
            end
        end

        if not waypoints or #waypoints == 0 then
            log("Navigation stalled: No clear trajectory found", Color3.fromRGB(245, 140, 60), "NAV")
            break
        end

        if showViz then
            clearRouteVisuals()
            for i = 1, #waypoints do
                local wp = waypoints[i]
                local markerColor = Color3.fromRGB(0, 200, 255)
                local markerLabel = `#{i}`

                if wp.jumpType == "double" then
                    markerColor = Color3.fromRGB(255, 80, 220)
                    markerLabel = `[DBL] #{i}`
                elseif wp.jumpType == "single" then
                    markerColor = Color3.fromRGB(255, 160, 40)
                    markerLabel = `[JUMP] #{i}`
                end

                createWaypointMarker(wp.pos, markerLabel, markerColor, routeFolder)

                if i < #waypoints then
                    createBeam(wp.pos, waypoints[i + 1].pos, markerColor, routeFolder)
                end
            end
        end

        local wpIndex = 1
        local lastRecalcCheck = os.clock()
        local wasFalling = false

        local stuckAnchorPos = r.Position
        local stuckCheckTime = os.clock()
        local stuckAttempts = 0

        while wpIndex <= #waypoints and NAV.walkToken == myToken do
            r = root()
            h = hum()
            if not r or not h or h.Health <= 0 then break end

            local hState = h:GetState()

            if hState == Enum.HumanoidStateType.Ragdoll or hState == Enum.HumanoidStateType.FallingDown or hState == Enum.HumanoidStateType.Physics then
                pcall(function()
                    h:ChangeState(Enum.HumanoidStateType.GettingUp)
                    h.PlatformStand = false
                end)
                task.wait(0.2)
            end

            if h.Sit then
                h.Sit = false
                tapSpace()
            end
            if h.PlatformStand then h.PlatformStand = false end

            if hState == Enum.HumanoidStateType.Freefall then
                wasFalling = true
            elseif wasFalling and (h.FloorMaterial ~= Enum.Material.Air) then
                wasFalling = false
                break
            end

            if hState == Enum.HumanoidStateType.Swimming then
                tapSpace()
                task.wait(0.2)
                break
            end

            local currentWp = waypoints[wpIndex]

            local vertDiffToWp = currentWp.pos.Y - r.Position.Y
            if vertDiffToWp > (MAX_DOUBLE_JUMP + 1.0) then
                break
            end

            local toWp = currentWp.pos - r.Position
            local flatDistToWp = Vector3.new(toWp.X, 0, toWp.Z).Magnitude
            distToBeacon = (targetPos - r.Position).Magnitude

            if distToBeacon <= stopDist then
                success = true
                break
            end

            local isHighStep = (currentWp.pos.Y - r.Position.Y) > MAX_STEP_UP
            local fwdDir = flatDistToWp > 0.2 and toWp.Unit or r.CFrame.LookVector
            local fwdHit = Workspace:Raycast(r.Position + Vector3.new(0, 1.0, 0), fwdDir * 3.0, rpBody)
            local obsHeight = 0
            local hasHeadroom = false
            local obsAbsoluteTopY = 0

            if fwdHit and isSolidWall(fwdHit) then
                obsHeight, hasHeadroom, obsAbsoluteTopY = getObstacleTop(fwdHit.Position, r.Position.Y - 2.2)
            end

            local requiresPlannedJump = (currentWp.jumpType ~= "none" and flatDistToWp <= 3.2)
            local requiresDynamicClimb = (hasHeadroom and obsHeight > MAX_STEP_UP and obsHeight <= MAX_DOUBLE_JUMP and flatDistToWp <= 2.8)
            local requiresElevationStep = (isHighStep and flatDistToWp <= 2.8)

            if requiresPlannedJump or requiresDynamicClimb or requiresElevationStep then
                local isDouble = (currentWp.jumpType == "double") or (obsHeight > MAX_SINGLE_JUMP)
                local targetClearY = math.max(currentWp.pos.Y - 1.5, obsAbsoluteTopY)
                executeJumpClimb(currentWp.pos, targetClearY, isDouble, myToken, NAV)
            end

            if flatDistToWp <= 3.2 then
                wpIndex = wpIndex + 1
                if wpIndex <= #waypoints then
                    currentWp = waypoints[wpIndex]
                end
            end

            if allowSprint and distToBeacon > 20 then
                pcall(function()
                    h.WalkSpeed = 22
                    if keypressFn then pcall(keypressFn, 0x10) end
                end)
            else
                pcall(function()
                    h.WalkSpeed = 16
                    if keyreleaseFn then pcall(keyreleaseFn, 0x10) end
                end)
            end

            h:MoveTo(currentWp.pos)

            -- Dynamic shortcut check
            if os.clock() - lastRecalcCheck > 0.40 then
                lastRecalcCheck = os.clock()

                local rFloor = r.Position.Y - 1.5
                local gFloor = targetPos.Y
                if canTraverseDirect(r.Position, targetPos, rFloor, gFloor) then
                    local hDiff = gFloor - rFloor
                    local jType = "none"
                    if hDiff > MAX_STEP_UP and hDiff <= MAX_SINGLE_JUMP then jType = "single" end
                    if hDiff > MAX_SINGLE_JUMP and hDiff <= MAX_DOUBLE_JUMP then jType = "double" end
                    waypoints = { { pos = targetPos + Vector3.new(0, 1.5, 0), floorY = gFloor, jumpType = jType } }
                    wpIndex = 1
                    break
                end
            end

            -- Sustained Stuck Watchdog: 1.4s window, 1.2 stud progress check
            if os.clock() - stuckCheckTime >= 1.4 then
                local distanceTraveled = (r.Position - stuckAnchorPos).Magnitude

                if distanceTraveled < 1.2 and flatDistToWp > 3.0 then
                    stuckAttempts = stuckAttempts + 1
                    local isDouble = (obsHeight > MAX_SINGLE_JUMP) or (currentWp.jumpType == "double")
                    local targetClearY = math.max(currentWp.pos.Y - 1.5, obsAbsoluteTopY)
                    executeJumpClimb(currentWp.pos, targetClearY, isDouble, myToken, NAV)

                    if stuckAttempts >= 3 then
                        break
                    end
                else
                    stuckAttempts = 0
                end

                stuckAnchorPos = r.Position
                stuckCheckTime = os.clock()
            end

            task.wait(0.05)
        end

        if success then break end
        task.wait(0.05)
    end

    pcall(function()
        local hFinal = hum()
        if hFinal then
            hFinal:Move(Vector3.zero, false)
            hFinal.WalkSpeed = 16
        end
        if keyreleaseFn then pcall(keyreleaseFn, 0x10) end
    end)

    if NAV.walkToken == myToken then
        NAV.isWalking = false
        clearAllVisuals()
    end

    return success
end

return {
    NAV = NAV,
    walkTo = NAV.walkTo,
    cancel = NAV.cancel,
    clearVisuals = clearAllVisuals,
}