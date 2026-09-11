--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Combat
-- Prediction Silent Aim, Target Highlighting & 'I Hate You'
-- Clean Reverted Edition (pre-arc fixes)
-- ============================================================
local ctx = ...

-- COMBAT: Prediction Silent Aim, Target Highlighting & 'I Hate You'
-- ============================================================
local COMBAT = {
    highlight = nil,
    hooked = false,
    conn = nil,
    currentTarget = nil,
    targetStatus = "None",
    u62Table = nil,
    iHateYouRunning = false,
    iHateYouTarget = nil,
    iHateYouConn = nil,
    iHateYouThread = nil,
    iHateYouSpawnTask = nil,
    currentVantagePos = nil,
    vantageTargetAnchorPos = nil,
    targetStillSince = 0,
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
    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    local state = hum and hum:GetState() or Enum.HumanoidStateType.Running

    table.insert(hist.samples, {
        t = now,
        pos = targetPart.Position,
        vel = vel,
        state = state,
    })

    if #hist.samples > 10 then
        table.remove(hist.samples, 1)
    end
end

function COMBAT.analyzeMotionProfile(targetChar, targetPart)
    local prof = {
        mode = "Stationary",
        isSteady = false,
        isAirborne = false,
        isAirborneApex = false,
        isRadial = false,
        isReversal = false,
        filteredVel = Vector3.zero,
        accel = Vector3.zero,
        radialSpeed = 0,
        transverseSpeed = 0,
        erraticScore = 0,
        turnRate = 0,
    }

    if not targetChar or not targetPart then return prof end

    local currentVel = COMBAT.getEffectiveVelocity(targetChar, targetPart)
    local currentSpd = currentVel.Magnitude
    local muzzlePos = COMBAT.getMuzzlePosition()
    local targetPos = targetPart.Position
    local toTarget = (targetPos - muzzlePos)
    local losDir = toTarget.Magnitude > 0 and toTarget.Unit or Vector3.new(0, 0, 1)

    local radialSpeed = currentVel:Dot(losDir)
    local radialVec = losDir * radialSpeed
    local transverseVec = currentVel - radialVec
    local transverseSpeed = transverseVec.Magnitude

    prof.radialSpeed = radialSpeed
    prof.transverseSpeed = transverseSpeed
    prof.filteredVel = currentVel

    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    local state = hum and hum:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        prof.isAirborne = true
        if math.abs(currentVel.Y) < 4 then
            prof.isAirborneApex = true
            prof.mode = "Jump Apex (Peak)"
        else
            prof.mode = currentVel.Y > 0 and "Jumping Up" or "Falling Down"
        end
        return prof
    end

    if currentSpd < 1.5 then
        prof.mode = "Stationary"
        prof.isSteady = true
        return prof
    end

    local transverseRatio = transverseSpeed / math.max(currentSpd, 0.1)
    if transverseRatio < 0.25 or transverseSpeed < 3.5 then
        prof.isRadial = true
        prof.isSteady = true
        prof.mode = radialSpeed > 0 and "Fleeing Straight (Radial)" or "Charging Straight (Radial)"
        return prof
    end

    local hist = COMBAT.targetHistory[targetChar]
    local samples = hist and hist.samples
    if samples and #samples >= 3 then
        local count = #samples
        local oldest = samples[1]
        local newest = samples[count]
        local dt = newest.t - oldest.t

        if dt > 0.05 then
            local sumVel = Vector3.zero
            for _, s in ipairs(samples) do
                sumVel = sumVel + s.vel
            end
            prof.filteredVel = sumVel / count
            prof.accel = (newest.vel - oldest.vel) / dt

            local dirVariance = 0
            local prevDir = oldest.vel.Magnitude > 1 and oldest.vel.Unit or nil
            for i = 2, count do
                local s = samples[i]
                if s.vel.Magnitude > 1 and prevDir then
                    local dot = math.clamp(s.vel.Unit:Dot(prevDir), -1, 1)
                    local ang = math.acos(dot)
                    dirVariance = dirVariance + ang
                    prevDir = s.vel.Unit
                end
            end
            local avgAngleChange = dirVariance / (count - 1)
            prof.turnRate = avgAngleChange / (dt / count)

            local dotOldNew = newest.vel:Dot(oldest.vel)
            if dotOldNew < -0.1 and currentSpd < 8 then
                prof.isReversal = true
                prof.mode = "Strafe Turn (Inflection)"
                return prof
            end

            if avgAngleChange < math.rad(15) then
                prof.isSteady = true
                prof.mode = currentSpd > 35 and "Horse Sprint (Steady)" or "Sprint (Straight Line)"
            elseif prof.turnRate > 1.2 then
                prof.mode = "Curving / Turning"
            else
                prof.erraticScore = math.clamp(avgAngleChange / math.rad(45), 0, 1)
                prof.mode = "Zig-Zagging (Dodging)"
            end
        end
    else
        prof.mode = currentSpd > 35 and "Horse Gallop" or "Running"
        prof.isSteady = true
    end

    return prof
end

function COMBAT.getShooterSpeed()
    local mySpd = 0
    local r = root()
    local myH = myHorse()
    local hp = myH and myH:FindFirstChild("HumanoidRootPart")
    if hp and isMounted(myH) then
        mySpd = hp.AssemblyLinearVelocity.Magnitude
    elseif r then
        mySpd = r.AssemblyLinearVelocity.Magnitude
    end
    return mySpd
end

function COMBAT.getHighlight()
    if not COMBAT.highlight or not COMBAT.highlight.Parent then
        local h = Instance.new("Highlight")
        h.Name = "CombatAimHighlight"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.35
        h.OutlineTransparency = 0.05
        h.Enabled = false
        h.Parent = WS.CurrentCamera or WS
        COMBAT.highlight = h
    end
    return COMBAT.highlight
end

function COMBAT.isTargetDown(tc)
    if not tc or not tc.Parent then return true end
    local hum = tc:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    if tc:GetAttribute("IsKnockedDown") == true or tc:GetAttribute("IsRagdolled") == true then return true end
    return false
end

function COMBAT.getGunMaxRange()
    if S.martiniBallistics then
        return 5000
    end
    local c = char()
    local tool = c and c:FindFirstChildWhichIsA("Tool")
    if not tool then
        local bp = LP:FindFirstChild("Backpack")
        tool = bp and bp:FindFirstChildWhichIsA("Tool")
    end
    if tool then
        local sc = tool:FindFirstChild("ServerConfig")
        if sc and sc:IsA("ModuleScript") then
            local ok, cfg = pcall(require, sc)
            if ok and typeof(cfg) == "table" and cfg.Range then
                local r = tonumber(cfg.Range) or 215
                if r <= 250 then return r end
            end
        end
    end
    return 215
end

function COMBAT.getMuzzlePosition()
    local c = char()
    if c then
        local vis = c:FindFirstChild("Visual_Martini Henry") or c:FindFirstChildWhichIsA("Model")
        if vis then
            local b = vis:FindFirstChild("Barrel", true)
            if b and b:IsA("Attachment") then
                return b.WorldPosition
            elseif b and b:IsA("BasePart") then
                return b.Position
            end
        end
        local head = c:FindFirstChild("Head")
        if head then return head.Position end
        local r = root()
        if r then return r.Position end
    end
    return (WS.CurrentCamera and WS.CurrentCamera.CFrame.Position) or Vector3.zero
end

function COMBAT.calculateTrajectory(targetChar, targetPart)
    if not targetChar or not targetPart then return nil end

    local muzzlePos = COMBAT.getMuzzlePosition()
    local targetPos = targetPart.Position
    local vel = COMBAT.getEffectiveVelocity(targetChar, targetPart)
    local targetSpd = vel.Magnitude

    local c = char()
    local tool = c and c:FindFirstChildWhichIsA("Tool")
    if not tool then
        local bp = LP:FindFirstChild("Backpack")
        tool = bp and bp:FindFirstChildWhichIsA("Tool")
    end

    local isMartiniOrProjectile = false
    local projSpeed = 1150
    local projGrav = 0.08

    if tool then
        if tool.Name:find("Martini") then
            isMartiniOrProjectile = true
        end
        local sc = tool:FindFirstChild("ServerConfig")
        if sc and sc:IsA("ModuleScript") then
            local ok, cfg = pcall(require, sc)
            if ok and typeof(cfg) == "table" then
                if cfg.FireType == "Projectile" or (cfg.Range and tonumber(cfg.Range) >= 5000) then
                    isMartiniOrProjectile = true
                end
                if cfg.ProjectileSpeed then
                    projSpeed = tonumber(cfg.ProjectileSpeed) or projSpeed
                end
                if cfg.ProjectileGravity then
                    projGrav = tonumber(cfg.ProjectileGravity) or projGrav
                end
            end
        end
    end

    local useBallistics = S.martiniBallistics and (isMartiniOrProjectile or not tool or tool.Name:find("Martini"))

    local ping = 0.06
    pcall(function()
        local stat = game:GetService("Stats"):FindFirstChild("Network")
        local item = stat and stat:FindFirstChild("ServerStatsItem")
        local pItem = item and item:FindFirstChild("Data Ping")
        if pItem then ping = pItem:GetValue() / 1000 end
    end)
    ping = math.clamp(ping, 0.02, 0.35)

    if not useBallistics then
        return targetPos + (vel * ping), 0, 0, ping
    end

    local shooterVel = Vector3.zero
    local myH = myHorse()
    local hp = myH and myH:FindFirstChild("HumanoidRootPart")
    local r = root()
    if hp and hp.AssemblyLinearVelocity.Magnitude > 1 then
        shooterVel = hp.AssemblyLinearVelocity
    elseif r and r.AssemblyLinearVelocity.Magnitude > 1 then
        shooterVel = r.AssemblyLinearVelocity
    end
    local effectiveMuzzlePos = muzzlePos + (shooterVel * ping)

    local dist0 = (targetPos - effectiveMuzzlePos).Magnitude
    local tFlight0 = dist0 / projSpeed
    local tTotal0 = tFlight0 + ping

    local gravAcc = (WS.Gravity or 196.2) * projGrav
    local dropY0 = 0.5 * gravAcc * (tFlight0 ^ 2)
    local predPos0 = targetPos + (vel * tTotal0) + Vector3.new(0, dropY0, 0)

    local dist1 = (predPos0 - effectiveMuzzlePos).Magnitude
    local tFlight1 = dist1 / projSpeed
    local tTotal1 = tFlight1 + ping
    local dropY1 = 0.5 * gravAcc * (tFlight1 ^ 2)

    local finalPredPos
    if S.humanPredictor then
        local prof = COMBAT.analyzeMotionProfile(targetChar, targetPart)
        if prof.isAirborne then
            local charGrav = WS.Gravity or 196.2
            local targetDrop = 0.5 * charGrav * (tTotal1 ^ 2)
            local predX = targetPos.X + (vel.X * tTotal1)
            local predY = targetPos.Y + (vel.Y * tTotal1) - targetDrop + dropY1
            local predZ = targetPos.Z + (vel.Z * tTotal1)
            finalPredPos = Vector3.new(predX, predY, predZ)
        elseif prof.isReversal then
            finalPredPos = targetPos + (vel * (tTotal1 * 0.3)) + Vector3.new(0, dropY1, 0)
        elseif prof.isRadial then
            finalPredPos = targetPos + (vel * tTotal1) + Vector3.new(0, dropY1, 0)
        elseif prof.isSteady and prof.accel.Magnitude > 2 and prof.accel.Magnitude < 40 then
            local accelDamped = prof.accel * math.clamp(1 - (tTotal1 * 0.4), 0, 1)
            finalPredPos = targetPos + (vel * tTotal1) + (0.5 * accelDamped * (tTotal1 ^ 2)) + Vector3.new(0, dropY1, 0)
        else
            finalPredPos = targetPos + (vel * tTotal1) + Vector3.new(0, dropY1, 0)
        end
    else
        finalPredPos = targetPos + (vel * tTotal1) + Vector3.new(0, dropY1, 0)
    end

    return finalPredPos, tFlight1, dropY1, ping
end

function COMBAT.calculateHitChance(targetChar, targetPart)
    if not targetChar or not targetPart then return 0, nil end

    local muzzlePos = COMBAT.getMuzzlePosition()
    local targetPos = targetPart.Position
    local dist = (targetPos - muzzlePos).Magnitude

    local vel = COMBAT.getEffectiveVelocity(targetChar, targetPart)
    local targetSpd = vel.Magnitude
    local shooterSpd = COMBAT.getShooterSpeed()

    -- Extract bullet speed and ballistics config from equipped weapon
    local c = char()
    local tool = c and c:FindFirstChildWhichIsA("Tool")
    if not tool then
        local bp = LP:FindFirstChild("Backpack")
        tool = bp and bp:FindFirstChildWhichIsA("Tool")
    end

    local projSpeed = 1150
    local isMartiniOrProjectile = false
    if tool then
        if tool.Name:find("Martini") then
            isMartiniOrProjectile = true
        end
        local sc = tool:FindFirstChild("ServerConfig")
        if sc and sc:IsA("ModuleScript") then
            local ok, cfg = pcall(require, sc)
            if ok and typeof(cfg) == "table" then
                if cfg.FireType == "Projectile" or (cfg.Range and tonumber(cfg.Range) >= 5000) then
                    isMartiniOrProjectile = true
                end
                if cfg.ProjectileSpeed then
                    projSpeed = tonumber(cfg.ProjectileSpeed) or projSpeed
                end
            end
        end
    end

    local useBallistics = S.martiniBallistics and (isMartiniOrProjectile or not tool or tool.Name:find("Martini"))

    -- Ping latency
    local ping = 0.06
    pcall(function()
        local stat = game:GetService("Stats"):FindFirstChild("Network")
        local item = stat and stat:FindFirstChild("ServerStatsItem")
        local pItem = item and item:FindFirstChild("Data Ping")
        if pItem then ping = pItem:GetValue() / 1000 end
    end)
    ping = math.clamp(ping, 0.02, 0.35)

    -- Bullet travel time & total lead latency
    local tFlight = useBallistics and (dist / projSpeed) or 0.015
    local tTotal = tFlight + ping

    -- Hitbox dimensions
    local isHead = (targetPart.Name == "Head")
    local hitboxRadius = isHead and 0.85 or 1.8

    local baseChance = 99
    local prof = COMBAT.analyzeMotionProfile(targetChar, targetPart)

    local effectiveEvasion = 0
    local predictabilityMultiplier = 1.0

    if S.humanPredictor then
        local transverseLead = prof.transverseSpeed * tTotal
        local radialLead = math.abs(prof.radialSpeed) * tTotal

        effectiveEvasion = transverseLead + (0.10 * radialLead)

        if prof.isAirborne then
            predictabilityMultiplier = 0.25
            if prof.isAirborneApex then
                predictabilityMultiplier = 0.15
            end
        elseif prof.isRadial then
            predictabilityMultiplier = 0.30
        elseif prof.isReversal then
            predictabilityMultiplier = 0.35
        elseif prof.isSteady then
            predictabilityMultiplier = 0.50
        else
            predictabilityMultiplier = 1.0 + (prof.erraticScore * 0.4)
        end
    else
        effectiveEvasion = targetSpd * tTotal
    end

    local motionRatio = (effectiveEvasion * predictabilityMultiplier) / hitboxRadius
    local motionPenalty = math.min(65, motionRatio * 7.5)

    local pingPenalty = math.min(12, (ping / 0.1) * 5)
    local shooterPenalty = math.min(15, (shooterSpd / 25) * 8)
    local distPenalty = math.min(18, (dist / 450) * 8)

    local finalChance = math.clamp(math.floor(baseChance - motionPenalty - pingPenalty - shooterPenalty - distPenalty), 5, 99)

    if S.humanPredictor then
        if prof.isAirborneApex then
            finalChance = math.clamp(finalChance + 15, 5, 99)
        elseif prof.isRadial and dist < 700 then
            finalChance = math.clamp(finalChance + 12, 5, 99)
        end
    end

    local details = {
        chance = finalChance,
        dist = math.floor(dist),
        leadDist = targetSpd * tTotal,
        transverseLead = prof.transverseSpeed * tTotal,
        radialLead = math.abs(prof.radialSpeed) * tTotal,
        tFlight = tFlight,
        tTotal = tTotal,
        ping = math.floor(ping * 1000),
        projSpeed = projSpeed,
        targetSpd = math.floor(targetSpd),
        shooterSpd = math.floor(shooterSpd),
        motionMode = prof.mode,
        isSteady = prof.isSteady,
        isAirborne = prof.isAirborne,
        isRadial = prof.isRadial,
        hitbox = targetPart.Name,
    }

    return finalChance, details
end

function COMBAT.getOptimalHitbox(targetChar)
    if not targetChar then return nil, "None", 0, nil end

    local headPart = targetChar:FindFirstChild("Head")
    local torsoPart = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("HumanoidRootPart")

    if not headPart and not torsoPart then return nil, "None", 0, nil end
    if not headPart then
        local chance, det = COMBAT.calculateHitChance(targetChar, torsoPart)
        return torsoPart, "Torso", chance, det
    end
    if not torsoPart then
        local chance, det = COMBAT.calculateHitChance(targetChar, headPart)
        return headPart, "Head", chance, det
    end

    if not S.smartHitboxEV then
        local choice = S.aimHitbox or "Head"
        local part = (choice == "Head" and headPart) or torsoPart
        local chance, det = COMBAT.calculateHitChance(targetChar, part)
        return part, choice, chance, det
    end

    local chanceHead, detHead = COMBAT.calculateHitChance(targetChar, headPart)
    local chanceTorso, detTorso = COMBAT.calculateHitChance(targetChar, torsoPart)

    local evHead = (chanceHead / 100) * 1.4
    local evTorso = (chanceTorso / 100) * 1.1

    if evTorso > evHead or (chanceHead < 50 and chanceTorso >= 70) then
        return torsoPart, "Torso (Smart EV)", chanceTorso, detTorso
    else
        return headPart, "Head (Smart EV)", chanceHead, detHead
    end
end

local lastAutoFireTime = 0
function COMBAT.checkPeakFire(targetChar, targetPart, chance, details)
    if not S.peakConfidenceFire then return end
    if not S.silentAim then return end
    if tick() - lastAutoFireTime < 0.28 then return end

    local thresh = S.peakFireThreshold or 75
    if chance < thresh then return end

    local isPeak = false
    if details then
        if details.isAirborne and details.motionMode and details.motionMode:find("Apex") then
            isPeak = true
        elseif details.isRadial and chance >= thresh then
            isPeak = true
        elseif details.motionMode and (details.motionMode:find("Inflection") or details.motionMode:find("Reversal")) then
            isPeak = true
        elseif details.targetSpd < 4 and chance >= thresh then
            isPeak = true
        elseif chance >= 90 then
            isPeak = true
        end
    end

    if isPeak then
        lastAutoFireTime = tick()
        COMBAT.triggerFire()
    end
end

function COMBAT.triggerFire()
    local c = char()
    local gun = c and c:FindFirstChildWhichIsA("Tool")
    if not gun then return end

    local ammoVal = gun:FindFirstChild("AmmoInClip")
    local ammo = ammoVal and ammoVal.Value or 1
    if ammo <= 0 then return end
    if c:GetAttribute("IsReloading") == true then return end

    pcall(function()
        if mouse1click then
            mouse1click()
        elseif IH then
            local isSniper = gun.Name:lower():find("martini")
            if isSniper then
                IH:FireVirtualInput("SecondaryInput", true)
                task.delay(0.08, function()
                    IH:FireVirtualInput("PrimaryInput", true)
                    task.delay(0.04, function()
                        IH:FireVirtualInput("PrimaryInput", false)
                        IH:FireVirtualInput("SecondaryInput", false)
                    end)
                end)
            else
                IH:FireVirtualInput("PrimaryInput", true)
                task.delay(0.04, function() IH:FireVirtualInput("PrimaryInput", false) end)
            end
        end
    end)
end

function COMBAT.findSniperVantage(targetChar)
    if not targetChar or not targetChar.Parent then return nil end
    local tTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("HumanoidRootPart")
    if not tTorso then return nil end
    local tHead = targetChar:FindFirstChild("Head") or tTorso
    local targetPos = tTorso.Position

    local myH = myHorse()
    local bestPos = nil
    local bestScore = -math.huge

    local testDistances = { 450, 400, 350, 300, 250, 200, 150 }
    local anglesCount = 16

    for _, dist in ipairs(testDistances) do
        for i = 0, anglesCount - 1 do
            local angle = (i / anglesCount) * math.pi * 2
            local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local samplePos = targetPos + (dir * dist)
            local gy = groundY(samplePos, myH)
            if gy then
                local candPos = Vector3.new(samplePos.X, gy + 3.5, samplePos.Z)
                local clear, _ = COMBAT.hasLineOfSight(candPos, tHead.Position, targetChar)
                if clear then
                    local elevationAdvantage = candPos.Y - targetPos.Y
                    local score = (dist * 2) + (elevationAdvantage * 4)
                    if score > bestScore then
                        bestScore = score
                        bestPos = candPos
                    end
                end
            end
        end
        if bestPos and bestScore > (dist * 2) then
            break
        end
    end

    return bestPos
end

function COMBAT.checkTargetStillForSniper(tgt)
    if not tgt or not tgt.Parent then return false end
    local r = tgt:FindFirstChild("HumanoidRootPart") or tgt:FindFirstChild("Torso")
    local tSpd = COMBAT.getEffectiveVelocity(tgt, r).Magnitude
    if tSpd >= 10 then
        COMBAT.targetStillSince = 0
        if UI.iHateYouStatusLabel then
            UI.iHateYouStatusLabel:Set(string.format("Target Moving (%.0f s/s) - Waiting", tSpd))
        end
        return false
    end
    if not COMBAT.targetStillSince or COMBAT.targetStillSince == 0 then
        COMBAT.targetStillSince = tick()
    end
    local stillDur = tick() - COMBAT.targetStillSince
    if stillDur < 1.0 then
        if UI.iHateYouStatusLabel then
            UI.iHateYouStatusLabel:Set(string.format("Waiting for Still (%.1fs / 1.0s)", stillDur))
        end
        return false
    end
    return true
end

function COMBAT.hasLineOfSight(origin, targetPos, targetChar)
    local myChar = char()
    local myHorseInst = myHorse()
    local dir = targetPos - origin
    local dist = dir.Magnitude
    local maxRange = COMBAT.getGunMaxRange()
    if dist > maxRange then return false, "Out of Range (" .. math.floor(dist) .. " studs)" end
    if dist < 0.5 then return true, "Clear" end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { myChar, WS.CurrentCamera }
    if myHorseInst then table.insert(ex, myHorseInst) end
    pcall(function()
        for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("BulletPassThrough")) do
            table.insert(ex, inst)
        end
    end)
    rp.FilterDescendantsInstances = ex
    rp.CollisionGroup = "RaycastCollisionGroup"

    local curOrigin = origin
    local remDist = math.min(dist, 5000)
    local rayDir = dir.Unit

    for _ = 1, 5 do
        local checkDist = math.min(remDist, 5000)
        local hit = WS:Raycast(curOrigin, rayDir * checkDist, rp)
        if not hit then
            return true, "Clear"
        end
        if targetChar and (hit.Instance:IsDescendantOf(targetChar) or (targetChar:FindFirstChildOfClass("Humanoid") and targetChar:FindFirstChildOfClass("Humanoid").SeatPart and hit.Instance:IsDescendantOf(targetChar:FindFirstChildOfClass("Humanoid").SeatPart.Parent))) then
            return true, "Clear"
        end
        if hit.Instance:IsDescendantOf(myChar) or (myHorseInst and hit.Instance:IsDescendantOf(myHorseInst)) then
            table.insert(ex, hit.Instance)
            rp.FilterDescendantsInstances = ex
        elseif not hit.Instance.CanCollide or hit.Instance.Transparency >= 0.75 then
            table.insert(ex, hit.Instance)
            rp.FilterDescendantsInstances = ex
            local traveled = (hit.Position - curOrigin).Magnitude + 0.1
            remDist = remDist - traveled
            curOrigin = hit.Position + rayDir * 0.1
            if remDist <= 0 then break end
        else
            return false, "Blocked by " .. hit.Instance.Name
        end
    end
    return true, "Clear"
end

function COMBAT.getTarget()
    local myChar = char()
    local myHrp = root()
    if not myChar or not myHrp then return nil, nil, "No Character" end

    local origin = (myChar:FindFirstChild("Head") or myHrp).Position
    local targetMode = S.aimTargetMode or "Closest to Cursor"
    local hitboxName = S.aimHitbox or "Head"

    if targetMode ~= "Closest" and targetMode ~= "Closest to Cursor" then
        local tp = Players:FindFirstChild(targetMode)
        if not tp then return nil, nil, "Player Not in Server" end
        local tc = tp.Character
        if not tc then return nil, nil, "Player Has No Character" end
        local th = tc:FindFirstChildOfClass("Humanoid")
        local tr = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso") or tc:FindFirstChild("UpperTorso")
        if not th or th.Health <= 0 or not tr then return nil, nil, "Target is Dead" end

        local targetPart = (hitboxName == "Head" and tc:FindFirstChild("Head")) or tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso") or tr
        if not targetPart then return nil, nil, "No Part" end
        local dist = (targetPart.Position - origin).Magnitude
        local maxRange = COMBAT.getGunMaxRange()
        if dist > maxRange then
            return tc, targetPart, "Out of Range (" .. math.floor(dist) .. " studs)"
        end

        local clear, reason = COMBAT.hasLineOfSight(origin, targetPart.Position, tc)
        if not clear then
            return tc, targetPart, reason or "Obstructed"
        end
        return tc, targetPart, "Valid"
    else
        local candidates = {}
        local maxRange = COMBAT.getGunMaxRange()
        local cam = WS.CurrentCamera
        local mousePos = Vector2.zero

        if targetMode == "Closest to Cursor" then
            local uis = game:GetService("UserInputService")
            local ok, m = pcall(function() return uis:GetMouseLocation() end)
            if ok and m then
                mousePos = m
            elseif cam and cam.ViewportSize then
                mousePos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if not (S.aimIgnoreFriends and isPlayerFriend(p)) then
                    local tc = p.Character
                    if tc and tc.Parent then
                        local th = tc:FindFirstChildOfClass("Humanoid")
                        local tr = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso") or tc:FindFirstChild("UpperTorso")
                        if th and th.Health > 0 and tr then
                            local tp = (hitboxName == "Head" and tc:FindFirstChild("Head")) or tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso") or tr
                            if tp then
                                local d3D = (tp.Position - origin).Magnitude
                                if d3D <= maxRange then
                                    if targetMode == "Closest to Cursor" then
                                        if cam then
                                            local sPos, onScreen = cam:WorldToViewportPoint(tp.Position)
                                            if sPos.Z > 0 then
                                                local sVec = Vector2.new(sPos.X, sPos.Y)
                                                local cursorDist = (sVec - mousePos).Magnitude
                                                table.insert(candidates, {
                                                    char = tc,
                                                    part = tp,
                                                    dist = cursorDist,
                                                    d3D = d3D,
                                                    onScreen = onScreen
                                                })
                                            end
                                        end
                                    else
                                        table.insert(candidates, {
                                            char = tc,
                                            part = tp,
                                            dist = d3D,
                                            d3D = d3D,
                                            onScreen = true
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            if targetMode == "Closest to Cursor" then
                return nil, nil, "None in View"
            else
                return nil, nil, "No Players Found"
            end
        end

        table.sort(candidates, function(a, b)
            return a.dist < b.dist
        end)

        local firstBlockedChar, firstBlockedPart, firstBlockedReason = nil, nil, nil
        for _, cand in ipairs(candidates) do
            local clear, reason = COMBAT.hasLineOfSight(origin, cand.part.Position, cand.char)
            if clear then
                return cand.char, cand.part, "Valid"
            elseif not firstBlockedChar then
                firstBlockedChar = cand.char
                firstBlockedPart = cand.part
                firstBlockedReason = reason or "Obstructed"
            end
        end

        return firstBlockedChar, firstBlockedPart, firstBlockedReason or "Obstructed"
    end
end

function COMBAT.getIHateYouTarget()
    local myChar = char()
    local myHrp = root()
    if not myChar or not myHrp then return nil, "No Character" end

    local targetMode = S.aimTargetMode or "Closest to Cursor"
    if targetMode ~= "Closest" and targetMode ~= "Closest to Cursor" then
        local tp = Players:FindFirstChild(targetMode)
        if not tp then
            return nil, "Target player not in server"
        end
        local tc = tp.Character
        if not tc or not tc.Parent then
            return nil, "Target player not loaded in memory"
        end
        local tr = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso") or tc:FindFirstChild("UpperTorso")
        if not tr then
            return nil, "Target character not loaded"
        end
        if COMBAT.isTargetDown(tc) then
            return nil, "Target is already dead or ragdolled"
        end
        return tc, "Loaded"
    else
        local origin = myHrp.Position
        local bestChar = nil
        local bestDist = math.huge

        local cam = WS.CurrentCamera
        local mousePos = Vector2.zero
        if targetMode == "Closest to Cursor" then
            local uis = game:GetService("UserInputService")
            local ok, m = pcall(function() return uis:GetMouseLocation() end)
            if ok and m then
                mousePos = m
            elseif cam and cam.ViewportSize then
                mousePos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if not (S.aimIgnoreFriends and isPlayerFriend(p)) then
                    local tc = p.Character
                    if tc and tc.Parent and not COMBAT.isTargetDown(tc) then
                        local tr = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso") or tc:FindFirstChild("UpperTorso")
                        if tr then
                            local d = (tr.Position - origin).Magnitude
                            if targetMode == "Closest to Cursor" and cam then
                                local sPos, onScreen = cam:WorldToViewportPoint(tr.Position)
                                if sPos.Z > 0 then
                                    local cursorDist = (Vector2.new(sPos.X, sPos.Y) - mousePos).Magnitude
                                    if cursorDist < bestDist then
                                        bestDist = cursorDist
                                        bestChar = tc
                                    end
                                end
                            else
                                if d < bestDist then
                                    bestDist = d
                                    bestChar = tc
                                end
                            end
                        end
                    end
                end
            end
        end

        if not bestChar and targetMode == "Closest to Cursor" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and not (S.aimIgnoreFriends and isPlayerFriend(p)) then
                    local tc = p.Character
                    if tc and tc.Parent and not COMBAT.isTargetDown(tc) then
                        local tr = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso") or tc:FindFirstChild("UpperTorso")
                        if tr then
                            local d = (tr.Position - origin).Magnitude
                            if d < bestDist then
                                bestDist = d
                                bestChar = tc
                            end
                        end
                    end
                end
            end
        end

        if not bestChar then
            return nil, "No valid targets loaded in memory"
        end
        return bestChar, "Loaded"
    end
end

function COMBAT.ensureGunEquipped()
    local c = char()
    if not c then return nil end
    local cur = c:FindFirstChildWhichIsA("Tool")
    if cur and (cur:HasTag("Gun") or cur:FindFirstChild("AmmoInClip") or cur:FindFirstChild("ClientConfig")) then
        return cur
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and (t:HasTag("Gun") or t:FindFirstChild("AmmoInClip") or t:FindFirstChild("ClientConfig")) then
                local h = hum()
                if h then pcall(function() h:EquipTool(t) end) end
                task.wait(0.3)
                return c:FindFirstChildWhichIsA("Tool") or t
            end
        end
    end
    return nil
end

function COMBAT.calculateBehindPosition(targetChar)
    if not targetChar or not targetChar.Parent then return nil, nil end
    local tTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("HumanoidRootPart")
    if not tTorso then return nil, nil end

    local tHum = targetChar:FindFirstChildOfClass("Humanoid")
    local tHorseRoot = tHum and tHum.SeatPart and tHum.SeatPart.Parent and tHum.SeatPart.Parent:FindFirstChild("HumanoidRootPart")
    local effectiveRoot = tHorseRoot or tTorso

    local ping = 0.06
    pcall(function()
        local stat = game:GetService("Stats"):FindFirstChild("Network")
        local item = stat and stat:FindFirstChild("ServerStatsItem")
        local pItem = item and item:FindFirstChild("Data Ping")
        if pItem then ping = pItem:GetValue() / 1000 end
    end)
    ping = math.clamp(ping, 0.02, 0.35)

    local vel = COMBAT.getEffectiveVelocity(targetChar, tTorso)
    local predTargetPos = tTorso.Position + (vel * ping)

    local lookVec = tTorso.CFrame.LookVector
    local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
    if flatLook.Magnitude > 0.01 then
        flatLook = flatLook.Unit
    else
        flatLook = lookVec
    end
    local behindDir = -flatLook

    local desiredDist = S.iHateYouDistance or 190
    local rayOrigin = predTargetPos + Vector3.new(0, 1.5, 0)
    local wallParams = RaycastParams.new()
    wallParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = { char(), targetChar, WS.CurrentCamera }
    local myH = myHorse()
    if myH then table.insert(filterList, myH) end
    if tHorseRoot and tHorseRoot.Parent then table.insert(filterList, tHorseRoot.Parent) end
    pcall(function()
        for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("BulletPassThrough")) do
            table.insert(filterList, inst)
        end
    end)
    wallParams.FilterDescendantsInstances = filterList

    local wallHit = WS:Raycast(rayOrigin, behindDir * desiredDist, wallParams)
    local actualDist = desiredDist
    if wallHit then
        local hitDist = (wallHit.Position - rayOrigin).Magnitude
        actualDist = math.max(15, hitDist - 4)
    end

    local candidatePos = predTargetPos + (behindDir * actualDist)

    local gy = groundY(candidatePos, myH)
    if gy then
        candidatePos = Vector3.new(candidatePos.X, gy + 3.5, candidatePos.Z)
    else
        candidatePos = Vector3.new(candidatePos.X, predTargetPos.Y, candidatePos.Z)
    end

    local faceTargetCF = CFrame.new(candidatePos, Vector3.new(predTargetPos.X, candidatePos.Y, predTargetPos.Z))
    return candidatePos, faceTargetCF
end

function COMBAT.ensureHook()
    if COMBAT.hooked and COMBAT.u62Table then return true end

    local getgcFn = getgc
    local getupvaluesFn = getupvalues or (debug and debug.getupvalues)
    if not getgcFn or not getupvaluesFn then return false end

    local equipFn
    local okMod, gunMod = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules", 3):WaitForChild("CoreGunClientModule", 3))
    end)
    if okMod and typeof(gunMod) == "table" and typeof(gunMod.Equip) == "function" then
        equipFn = gunMod.Equip
    end

    if not equipFn and getgc then
        pcall(function()
            for _, v in ipairs(getgc(false) or getgc()) do
                if typeof(v) == "function" and islclosure(v) and not isexecutorclosure(v) then
                    local src = debug.info(v, "s")
                    local name = debug.info(v, "n")
                    if src and src:find("CoreGunClientModule") and name == "Equip" then
                        equipFn = v
                        break
                    end
                end
            end
        end)
    end

    if not equipFn then return false end

    local uvs = getupvaluesFn(equipFn)
    for _, uv in pairs(uvs) do
        if typeof(uv) == "table" and typeof(rawget(uv, "FireServer")) == "function" then
            COMBAT.u62Table = uv
            local oldFire = uv.FireServer
            local hookFunc = function(self, action, targetPos, isAiming, ...)
                            if action == "Fire" and (S.silentAim or S.iHateYou) then
                                local tChar, tPart, status, hitboxMode
                                if S.iHateYou and COMBAT.iHateYouTarget and COMBAT.iHateYouTarget.Parent then
                                    tChar = COMBAT.iHateYouTarget
                                    local hitboxName = S.aimHitbox or "Head"
                                    tPart = (hitboxName == "Head" and tChar:FindFirstChild("Head")) or tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso") or tChar:FindFirstChild("HumanoidRootPart")
                                    status = tPart and "Valid" or "NoPart"
                                    hitboxMode = hitboxName
                                else
                                    tChar, tPart, status = COMBAT.getTarget()
                                    if S.smartHitboxEV and tChar and status == "Valid" then
                                        local optPart, optName = COMBAT.getOptimalHitbox(tChar)
                                        if optPart then
                                            tPart = optPart
                                            hitboxMode = optName
                                        end
                                    else
                                        hitboxMode = S.aimHitbox or "Head"
                                    end
                                end

                                if status == "Valid" and tPart then
                                    local vel = COMBAT.getEffectiveVelocity(tChar, tPart)
                                    local shooterSpd = COMBAT.getShooterSpeed()
                                    local targetSpd = vel.Magnitude

                                    if S.onlyFireAtLowSpeeds then
                                        local maxSpd = S.maxFiringSpeed or 25
                                        if shooterSpd > maxSpd or targetSpd > maxSpd then
                                            logAction("COMBAT", string.format("Silent Aim: Hold fire (Speed high: shooter %.0f, target %.0f > %.0f)", shooterSpd, targetSpd, maxSpd), Color3.fromRGB(245, 175, 60), "COMBAT")
                                            return
                                        end
                                    end

                                    local hitChance, hitDetails = COMBAT.calculateHitChance(tChar, tPart)
                                    if S.minHitChance and S.minHitChance > 0 and hitChance < S.minHitChance then
                                        logAction("COMBAT", string.format("Silent Aim: Hold fire (Hit chance low: %d%% < %d%%)", hitChance, S.minHitChance), Color3.fromRGB(245, 175, 60), "COMBAT")
                                        return
                                    end

                                    local predPos, tFlight, dropY, ping = COMBAT.calculateTrajectory(tChar, tPart)
                                    if predPos then
                                        targetPos = predPos
                                        local modeTag = hitDetails and hitDetails.motionMode or "Normal"
                                        if tFlight and tFlight > 0 then
                                            logAction("COMBAT", string.format("Silent Aim (Martini): Ballistic -> %s [%s] (%d%% hit | %s | flight %.2fs, drop +%.1f, ping %.0fms, spd %.0f)", tChar.Name, hitboxMode or S.aimHitbox or "Head", hitChance, modeTag, tFlight, dropY, ping * 1000, targetSpd), Color3.fromRGB(80, 255, 140), "COMBAT")
                                        else
                                            logAction("COMBAT", string.format("Silent Aim: Lead shot -> %s [%s] (%d%% hit | %s | ping %.0fms, spd %.0f)", tChar.Name, hitboxMode or S.aimHitbox or "Head", hitChance, modeTag, ping * 1000, targetSpd), Color3.fromRGB(80, 255, 140), "COMBAT")
                                        end
                                    end
                                    if S.martiniBallistics then
                                        isAiming = true
                                    end
                                end
                            end
                            return oldFire(self, action, targetPos, isAiming, ...)
                        end
                        rawset(uv, "FireServer", hookFunc)
                        COMBAT.hooked = true
                        logAction("COMBAT", "Gun hook initialized successfully", Color3.fromRGB(80, 220, 140), "COMBAT")
                        return true
                    end
                end
    return false
end

function COMBAT.update()
    if not S.silentAim then
        if not S.iHateYou and COMBAT.highlight then
            COMBAT.highlight.Enabled = false
            COMBAT.highlight.Adornee = nil
        end
        return
    end

    COMBAT.ensureHook()

    local tChar, _, status = COMBAT.getTarget()
    COMBAT.currentTarget = tChar
    COMBAT.targetStatus = status or "None"

    local tPart, hitboxMode, hitChance, hitDetails
    if status == "Valid" and tChar then
        if S.smartHitboxEV then
            tPart, hitboxMode, hitChance, hitDetails = COMBAT.getOptimalHitbox(tChar)
        else
            local hitboxName = S.aimHitbox or "Head"
            tPart = (hitboxName == "Head" and tChar:FindFirstChild("Head")) or tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso") or tChar:FindFirstChild("HumanoidRootPart")
            if tPart then
                hitChance, hitDetails = COMBAT.calculateHitChance(tChar, tPart)
                hitboxMode = hitboxName
            end
        end

        if tPart then
            COMBAT.recordTargetState(tChar, tPart)
        end

        if S.peakConfidenceFire and tPart and hitChance and hitDetails then
            COMBAT.checkPeakFire(tChar, tPart, hitChance, hitDetails)
        end
    end

    if not S.iHateYou then
        local hl = COMBAT.getHighlight()
        if tChar then
            hl.Adornee = tChar
            hl.Enabled = true
            if status == "Valid" then
                hl.FillColor = Color3.fromRGB(50, 255, 100)
                hl.OutlineColor = Color3.fromRGB(80, 255, 140)
            else
                hl.FillColor = Color3.fromRGB(255, 50, 50)
                hl.OutlineColor = Color3.fromRGB(255, 80, 80)
            end
        else
            hl.Enabled = false
            hl.Adornee = nil
        end
    end

    if UI.combatTargetLabel then
        UI.combatTargetLabel:Set(tChar and tChar.Name or "None")
    end
    if UI.combatStatusLabel then
        local dispStatus = status or "None"
        if status == "Valid" and tChar and root() then
            local tRoot = tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso") or tChar:FindFirstChild("UpperTorso")
            if tRoot then
                local d = math.floor((tRoot.Position - root().Position).Magnitude)
                dispStatus = string.format("Valid (%d studs)", d)
            end
        end
        UI.combatStatusLabel:Set(dispStatus)
    end
    if UI.combatHitChanceLabel then
        if status == "Valid" and tChar and hitChance and hitDetails then
            UI.combatHitChanceLabel:Set(string.format("%d%% [%s] (Lead: %.1fst | Ping: %dms | Flight: %.2fs)", hitChance, hitboxMode or "Target", hitDetails.leadDist, hitDetails.ping, hitDetails.tFlight))
        else
            UI.combatHitChanceLabel:Set("-")
        end
    end
    if UI.combatMotionProfileLabel then
        if status == "Valid" and tChar and hitDetails and hitDetails.motionMode then
            UI.combatMotionProfileLabel:Set(hitDetails.motionMode)
        else
            UI.combatMotionProfileLabel:Set("-")
        end
    end
end

function COMBAT.start()
    if COMBAT.conn then return end
    COMBAT.ensureHook()
    task.spawn(function()
        pcall(COMBAT.update)
    end)
    local lastT = 0
    COMBAT.conn = RunService.Heartbeat:Connect(function()
        if not S.silentAim then
            COMBAT.stop()
            return
        end
        local now = tick()
        if now - lastT >= 0.05 then
            lastT = now
            pcall(COMBAT.update)
        end
    end)
end

function COMBAT.stop()
    if COMBAT.conn then
        pcall(function() COMBAT.conn:Disconnect() end)
        COMBAT.conn = nil
    end
    if not S.iHateYou and COMBAT.highlight then
        COMBAT.highlight.Enabled = false
        COMBAT.highlight.Adornee = nil
    end
    if UI.combatTargetLabel then UI.combatTargetLabel:Set("-") end
    if UI.combatStatusLabel then UI.combatStatusLabel:Set("-") end
    if UI.combatHitChanceLabel then UI.combatHitChanceLabel:Set("-") end
    if UI.combatMotionProfileLabel then UI.combatMotionProfileLabel:Set("-") end
end

function COMBAT.startIHateYou()
    if not S.iHateYou then return end
    if COMBAT.iHateYouRunning then return end

    local tChar, reason = COMBAT.getIHateYouTarget()
    if not tChar then
        logAction("COMBAT", "I Hate You: " .. tostring(reason), Color3.fromRGB(245, 90, 90), "ERROR")
        COMBAT.stopIHateYou()
        if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Rejected (" .. tostring(reason) .. ")") end
        return
    end

    COMBAT.iHateYouTarget = tChar
    COMBAT.iHateYouRunning = true
    COMBAT.ensureHook()

    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Target: " .. tChar.Name) end
    logAction("COMBAT", "I Hate You: Engaged on target " .. tChar.Name, Color3.fromRGB(255, 80, 80), "COMBAT")

    local myR = root()
    local tR = tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso")
    local initDist = (myR and tR) and (tR.Position - myR.Position).Magnitude or 999

    COMBAT.iHateYouSpawnTask = task.spawn(function()
        if initDist > 70 and not isMounted(myHorse()) then
            if not S.iHateYou or not COMBAT.iHateYouRunning then return end
            if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Mounting Horse...") end
            logAction("COMBAT", "I Hate You: Target is " .. math.floor(initDist) .. " studs away. Mounting horse for uncapped teleport...", Color3.fromRGB(90, 180, 255), "TRAVEL")
            local mounted = mountHorse()
            if not S.iHateYou or not COMBAT.iHateYouRunning then return end
            if not mounted then
                logAction("COMBAT", "I Hate You: Failed to mount horse! Cannot gap-close over 70 studs.", Color3.fromRGB(245, 90, 90), "ERROR")
                COMBAT.stopIHateYou()
                if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Mount Failed") end
                return
            end
        end

        if not S.iHateYou or not COMBAT.iHateYouRunning then return end

        local lastPosUpdate = 0
        COMBAT.iHateYouConn = RunService.Heartbeat:Connect(function()
            if not S.iHateYou or not COMBAT.iHateYouRunning then
                COMBAT.stopIHateYou()
                return
            end

            local tgt = COMBAT.iHateYouTarget
            if not tgt or not tgt.Parent or COMBAT.isTargetDown(tgt) then
                local tgtName = tgt and tgt.Name or "Target"
                logAction("COMBAT", string.format("I Hate You: %s ragdolled/down! Mission accomplished.", tgtName), Color3.fromRGB(80, 255, 140), "COMBAT")
                COMBAT.stopIHateYou()
                if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Target Down!") end
                return
            end

            local hl = COMBAT.getHighlight()
            hl.Adornee = tgt
            hl.Enabled = true
            hl.FillColor = Color3.fromRGB(255, 45, 45)
            hl.OutlineColor = Color3.fromRGB(255, 100, 100)

            local candPos, faceCF
            if S.martiniVantage then
                local tHead = tgt:FindFirstChild("Head") or tgt:FindFirstChild("HumanoidRootPart")
                local tgtPos = (tgt:FindFirstChild("UpperTorso") or tgt:FindFirstChild("HumanoidRootPart")).Position

                local needRecalc = false
                if not COMBAT.currentVantagePos or not COMBAT.vantageTargetAnchorPos then
                    needRecalc = true
                else
                    local movedDist = (tgtPos - COMBAT.vantageTargetAnchorPos).Magnitude
                    if movedDist > 45 then
                        needRecalc = true
                    elseif tHead and not COMBAT.hasLineOfSight(COMBAT.currentVantagePos, tHead.Position, tgt) then
                        needRecalc = true
                    end
                end

                if needRecalc then
                    local newVantage = COMBAT.findSniperVantage(tgt)
                    if newVantage then
                        COMBAT.currentVantagePos = newVantage
                        COMBAT.vantageTargetAnchorPos = tgtPos
                    end
                end

                candPos = COMBAT.currentVantagePos or tgtPos
                faceCF = CFrame.new(candPos, Vector3.new(tgtPos.X, candPos.Y, tgtPos.Z))
            else
                candPos, faceCF = COMBAT.calculateBehindPosition(tgt)
            end

            if faceCF and candPos then
                local hObj = myHorse()
                local hp = hObj and hObj:FindFirstChild("HumanoidRootPart")
                local rr = root()

                if isMounted(hObj) and hp and hp.Parent then
                    hp.CFrame = faceCF
                    hp.AssemblyLinearVelocity = Vector3.zero
                    hp.AssemblyAngularVelocity = Vector3.zero
                    if rr then
                        rr.CFrame = faceCF + Vector3.new(0, 2.2, 0)
                        rr.AssemblyLinearVelocity = Vector3.zero
                        rr.AssemblyAngularVelocity = Vector3.zero
                    end
                elseif rr then
                    local hopDist = (candPos - rr.Position).Magnitude
                    if hopDist <= 65 then
                        rr.CFrame = faceCF
                        rr.AssemblyLinearVelocity = Vector3.zero
                        rr.AssemblyAngularVelocity = Vector3.zero
                    else
                        if tick() - lastPosUpdate > 1.5 then
                            lastPosUpdate = tick()
                            task.spawn(mountHorse)
                        end
                    end
                end
            end
        end)

        COMBAT.iHateYouThread = task.spawn(function()
            while S.iHateYou and COMBAT.iHateYouRunning do
                local tgt = COMBAT.iHateYouTarget
                if not tgt or not tgt.Parent or COMBAT.isTargetDown(tgt) then
                    local tgtName = tgt and tgt.Name or "Target"
                    logAction("COMBAT", string.format("I Hate You: %s ragdolled/down! Mission accomplished.", tgtName), Color3.fromRGB(80, 255, 140), "COMBAT")
                    COMBAT.stopIHateYou()
                    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Target Down!") end
                    break
                end

                local gun = COMBAT.ensureGunEquipped()
                if not gun then
                    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Equipping Gun...") end
                    task.wait(0.3)
                    continue
                end

                local ammoVal = gun:FindFirstChild("AmmoInClip")
                local storedVal = gun:FindFirstChild("StoredAmmo")
                local ammo = ammoVal and ammoVal.Value or 6
                local stored = storedVal and storedVal.Value or 99
                local isReloading = char() and char():GetAttribute("IsReloading") == true

                if isReloading then
                    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Reloading...") end
                    task.wait(0.1)
                elseif S.martiniVantage and not COMBAT.checkTargetStillForSniper(tgt) then
                    task.wait(0.08)
                elseif S.onlyFireAtLowSpeeds and (COMBAT.getShooterSpeed() > (S.maxFiringSpeed or 25) or COMBAT.getEffectiveVelocity(tgt, tgt:FindFirstChild("HumanoidRootPart") or tgt:FindFirstChild("Torso")).Magnitude > (S.maxFiringSpeed or 25)) then
                    local sSpd = COMBAT.getShooterSpeed()
                    local tSpd = COMBAT.getEffectiveVelocity(tgt, tgt:FindFirstChild("HumanoidRootPart") or tgt:FindFirstChild("Torso")).Magnitude
                    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set(string.format("Speed High (%.0f) - Holding Fire", math.max(sSpd, tSpd))) end
                    task.wait(0.08)
                elseif ammo > 0 then
                    if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set(string.format("Firing... (Ammo %d)", ammo)) end
                    local isSniper = (gun.Name:lower():find("martini")) or (gun:FindFirstChild("ClientConfig") and require(gun.ClientConfig).RequiresAimToFire)
                    if isSniper then
                        if IH then
                            IH:FireVirtualInput("SecondaryInput", true)
                            task.wait(0.12)
                            IH:FireVirtualInput("PrimaryInput", true)
                            task.wait(0.04)
                            IH:FireVirtualInput("PrimaryInput", false)
                            task.wait(0.06)
                            IH:FireVirtualInput("SecondaryInput", false)
                        else
                            tap("SecondaryInput", 0.12)
                            tap("PrimaryInput", 0.04)
                        end
                    else
                        if IH then
                            IH:FireVirtualInput("PrimaryInput", true)
                            task.wait(0.04)
                            IH:FireVirtualInput("PrimaryInput", false)
                        else
                            tap("PrimaryInput", 0.04)
                        end
                    end

                    local delay = 0.18
                    pcall(function()
                        local cfg = require(gun:FindFirstChild("ServerConfig"))
                        if cfg and cfg.FireRate then delay = cfg.FireRate + 0.05 end
                    end)
                    task.wait(delay)
                else
                    if stored > 0 then
                        if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Reloading...") end
                        logAction("COMBAT", "I Hate You: Cylinder empty, reloading...", Color3.fromRGB(245, 175, 60), "COMBAT")
                        if IH then
                            IH:FireVirtualInput("ActionInput2", true)
                            task.wait(0.05)
                            IH:FireVirtualInput("ActionInput2", false)
                        else
                            tap("ActionInput2", 0.05)
                        end
                        local t0 = tick()
                        task.wait(0.2)
                        while tick() - t0 < 1.6 do
                            if not S.iHateYou or not COMBAT.iHateYouRunning then break end
                            if char() and char():GetAttribute("IsReloading") == false and ammoVal and ammoVal.Value > 0 then
                                break
                            end
                            task.wait(0.1)
                        end
                    else
                        if UI.iHateYouStatusLabel then UI.iHateYouStatusLabel:Set("Out of Reserve Ammo!") end
                        logAction("COMBAT", "I Hate You: Out of reserve ammo!", Color3.fromRGB(245, 90, 90), "ERROR")
                        task.wait(1.0)
                    end
                end
            end
        end)
    end)
end

function COMBAT.stopIHateYou()
    COMBAT.iHateYouRunning = false
    COMBAT.iHateYouTarget = nil
    if COMBAT.iHateYouSpawnTask then
        pcall(task.cancel, COMBAT.iHateYouSpawnTask)
        COMBAT.iHateYouSpawnTask = nil
    end
    if COMBAT.iHateYouConn then
        pcall(function() COMBAT.iHateYouConn:Disconnect() end)
        COMBAT.iHateYouConn = nil
    end
    if COMBAT.iHateYouThread then
        pcall(task.cancel, COMBAT.iHateYouThread)
        COMBAT.iHateYouThread = nil
    end
    if COMBAT.highlight then
        COMBAT.highlight.Enabled = false
        COMBAT.highlight.Adornee = nil
    end
    COMBAT.currentVantagePos = nil
    COMBAT.vantageTargetAnchorPos = nil
    COMBAT.targetStillSince = 0
    if UI.setToggle then
        UI.setToggle("iHateYou", false)
    else
        S.iHateYou = false
    end
    if UI.iHateYouStatusLabel then
        UI.iHateYouStatusLabel:Set("Idle")
    end
end




return COMBAT
