--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Saint
-- Saint's Corpse radar, Auto-pickup & Safe retreat loop
-- ============================================================
local ctx = ...


-- ── Saint's Corpse ─────────────────────────────────────────────────────────
local SAINT: any = { status = "idle", detects = 0, grabs = 0, lastPart = "none", retreating = false, busy = false, wasHoldingPart = false }

function SAINT.defendCorpse()
    local gunName = S.saintGunSelect
    if not gunName or gunName == "None" then return end
    local gun = findTool(gunName)
    if not gun then return end
    equipTool(gunName)

    local myR = root()
    if not myR then return end
    local bestDist = 2500
    local bestChar, bestPart = nil, nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not isPlayerFriend(p) then
            local tc = p.Character
            if tc and tc.Parent and not COMBAT.isTargetDown(tc) then
                local head = tc:FindFirstChild("Head") or tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("HumanoidRootPart")
                if head then
                    local d = (head.Position - myR.Position).Magnitude
                    if d < bestDist then
                        local clear = COMBAT.hasLineOfSight(myR.Position, head.Position, tc)
                        if clear then
                            bestDist = d
                            bestChar = tc
                            bestPart = head
                        end
                    end
                end
            end
        end
    end

    if not bestChar or not bestPart then return end

    COMBAT.ensureHook()

    local ammoVal = gun:FindFirstChild("AmmoInClip")
    local ammo = ammoVal and ammoVal.Value or 6
    local isReloading = char() and char():GetAttribute("IsReloading") == true

    if isReloading then return end

    if ammo > 0 then
        myR.CFrame = CFrame.new(myR.Position, Vector3.new(bestPart.Position.X, myR.Position.Y, bestPart.Position.Z))
        local isSniper = gun.Name:lower():find("martini") or (gun:FindFirstChild("ClientConfig") and require(gun.ClientConfig).RequiresAimToFire)
        if isSniper then
            if IH then
                IH:FireVirtualInput("SecondaryInput", true)
                task.wait(0.1)
                IH:FireVirtualInput("PrimaryInput", true)
                task.wait(0.04)
                IH:FireVirtualInput("PrimaryInput", false)
                task.wait(0.06)
                IH:FireVirtualInput("SecondaryInput", false)
            else
                tap("SecondaryInput", 0.1)
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
        local delay = 0.25
        pcall(function()
            local cfg = require(gun:FindFirstChild("ServerConfig"))
            if cfg and cfg.FireRate then delay = cfg.FireRate + 0.05 end
        end)
        task.wait(delay)
    else
        if IH then
            IH:FireVirtualInput("ActionInput2", true)
            task.wait(0.05)
            IH:FireVirtualInput("ActionInput2", false)
        else
            tap("ActionInput2", 0.05)
        end
        task.wait(0.3)
    end
end

local function holdingCorpse()
    local c = char()
    if c and c:GetAttribute("HasCorpsePart") == true then return true end
    for _, src in ipairs({ LP:FindFirstChild("Backpack"), c }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and tostring(t.Name):lower():find("saint", 1, true) then return true end
            end
        end
    end
    return false
end

local SEEN_AT = {}
local function announcementLive()
    local g = LP:FindFirstChildOfClass("PlayerGui")
    if not g then return false end
    for _, d in ipairs(g:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
            local tx = tostring(d.Text):lower()
            if tx:find("it appears", 1, true) then return true end
        end
    end
    return false
end

local function corpseCandidates()
    local live, parked = {}, 0
    local now = os.clock()
    local function consider(part, wrapped)
        if not part:IsA("BasePart") then return end
        if tostring(part.Name):sub(1, 6) ~= "Saints" then return end
        if SEEN_AT[part] == nil then SEEN_AT[part] = now end
        local prompt
        for _, x in ipairs(part:GetDescendants()) do
            if x:IsA("ProximityPrompt") then prompt = x; break end
        end
        if not prompt or not prompt.Enabled then parked = parked + 1; return end
        if part:GetAttribute("BeingPickedUp") == true then parked = parked + 1; return end
        if not wrapped and part.Position.Y < 15 then parked = parked + 1; return end
        local announcedAt = SAINT.announcedAt or -math.huge
        if SEEN_AT[part] < announcedAt - 5 then parked = parked + 1; return end
        live[#live + 1] = { part = part, prompt = prompt, wrapped = wrapped }
    end
    for _, d in ipairs(WS:GetChildren()) do
        if d:IsA("BasePart") then
            consider(d, false)
        elseif d:IsA("Model") and tostring(d.Name):lower():find("_corpse", 1, true) then
            for _, c in ipairs(d:GetChildren()) do consider(c, true) end
        end
    end
    return live, parked
end

local function holdE(seconds)
    local vk = 0x45
    if keypressFn and keyreleaseFn then
        pcall(keypressFn, vk)
        local t0 = os.clock()
        while os.clock() - t0 < seconds do
            if holdingCorpse() then break end
            task.wait(0.05)
        end
        pcall(keyreleaseFn, vk)
        return true
    end
    return false
end

local function retreatSafe()
    if SAINT.retreating then return end
    SAINT.retreating = true
    SAINT.status = "RETREATING with the part"
    logAction("SAINT", "Secured corpse part! Retreating to safe location...", Color3.fromRGB(90, 180, 255), "TRAVEL")
    task.spawn(function()
        pcall(function()
            local dest = PC.saintRetreat
            if not dest then
                local best, bestScore
                local f = WS:FindFirstChild("NPC")
                if f then
                    for _, npc in ipairs(f:GetChildren()) do
                        local p = npc:FindFirstChild("HumanoidRootPart")
                            or npc:FindFirstChildWhichIsA("BasePart", true)
                        if p then
                            local nearest = math.huge
                            for _, o in ipairs(Players:GetPlayers()) do
                                if o ~= LP and o.Character then
                                    local orp = o.Character:FindFirstChild("HumanoidRootPart")
                                    if orp then
                                        local dd = (orp.Position - p.Position).Magnitude
                                        if dd < nearest then nearest = dd end
                                    end
                                end
                            end
                            if not bestScore or nearest > bestScore then best, bestScore = p.Position, nearest end
                        end
                    end
                end
                dest = best
            end
            if dest then
                horseTeleport(dest)
                landBeside(dest, 6)
                SAINT.status = "hidden - stay alive until it merges"
                logAction("SAINT", "Safely hidden at retreat point. Awaiting stand merge.", Color3.fromRGB(80, 220, 140), "SAINT")
            else
                SAINT.status = "no retreat point found"
                logAction("SAINT", "No safe retreat point found", Color3.fromRGB(245, 90, 90), "ERROR")
            end
        end)
        task.wait(2)
        SAINT.retreating = false
    end)
end

local function grabCorpse(entry)
    if SAINT.busy then return end
    SAINT.busy = true
    SAINT.grabs = SAINT.grabs + 1
    SAINT.lastPart = entry.part.Name
    task.spawn(function()
        pcall(function()
            local part, prompt = entry.part, entry.prompt
            local r = root()
            local dist = r and (part.Position - r.Position).Magnitude or 9999
            SAINT.status = ("going for %s (%d studs)"):format(part.Name, math.floor(dist))
            logAction("SAINT", ("Going for corpse: %s (%d studs away)..."):format(part.Name, math.floor(dist)), Color3.fromRGB(255, 110, 110), "SAINT")
            if dist > 70 then
                horseTeleport(part.Position)
                landBeside(part.Position, 5)
            end
            if not part.Parent then
                SAINT.status = "part vanished"
                logAction("SAINT", "Corpse part disappeared before arrival", Color3.fromRGB(245, 90, 90), "ERROR")
                return
            end
            local preWait = math.clamp(tonumber(S.saintPreHoldWait) or 0, 0, 120)
            if preWait > 0 then
                local tWaitStart = os.clock()
                logAction("SAINT", string.format("Arrived at corpse (%s). Waiting %ds before grabbing...", part.Name, preWait), Color3.fromRGB(255, 180, 80), "SAINT")
                while os.clock() - tWaitStart < preWait and S.running and part.Parent do
                    local rem = math.ceil(preWait - (os.clock() - tWaitStart))
                    SAINT.status = string.format("waiting %ds to grab %s", rem, part.Name)
                    local rr = root()
                    if rr and (rr.Position - part.Position).Magnitude > 20 then
                        rr.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        rr.AssemblyLinearVelocity = Vector3.zero
                    end
                    if S.saintDefendGun and S.saintGunSelect and S.saintGunSelect ~= "None" then
                        pcall(SAINT.defendCorpse)
                    end
                    task.wait(0.1)
                end
                if not part.Parent then
                    SAINT.status = "part vanished during wait"
                    logAction("SAINT", "Corpse part disappeared during pre-grab wait", Color3.fromRGB(245, 90, 90), "ERROR")
                    return
                end
            end
            local hold = math.max((prompt.HoldDuration or 3) + 2, 5)
            local stop = false
            task.spawn(function()
                local t0 = os.clock()
                while os.clock() - t0 < hold + 2 and not stop do
                    local rr = root()
                    if rr and part.Parent then
                        rr.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        rr.AssemblyLinearVelocity = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
            task.wait(0.4)
            local h0 = hum()
            SAINT.status = "holding E on " .. part.Name
            logAction("SAINT", ("Holding interaction [E] on %s..."):format(part.Name), Color3.fromRGB(255, 130, 90), "SAINT")
            if h0 then pcall(function() h0.Sit = false end) end
            holdE(hold)
            if not holdingCorpse() then
                SAINT.status = "E hold failed, trying fireproximityprompt"
                logAction("SAINT", "Key hold failed, attempting direct prompt fire...", Color3.fromRGB(245, 160, 60), "SAINT")
                if firepp and prompt and prompt.Parent then
                    for _ = 1, 3 do
                        pcall(firepp, prompt, prompt.HoldDuration or 0)
                        task.wait(0.4)
                        if holdingCorpse() then break end
                    end
                end
            end
            stop = true
            task.wait(0.3)
            if holdingCorpse() then
                SAINT.status = "GOT IT - retreating"
                logAction("SAINT", ("Secured corpse part: %s!"):format(part.Name), Color3.fromRGB(60, 240, 140), "SUCCESS")
                if S.saintRetreat then retreatSafe() end
            else
                SAINT.status = "grab failed on " .. part.Name
                logAction("SAINT", ("Failed to secure corpse part: %s"):format(part.Name), Color3.fromRGB(245, 90, 90), "ERROR")
            end
        end)
        task.wait(1)
        SAINT.busy = false
    end)
end

local function saintTick()
    if not S.saintWatch then return end
    local isHolding = holdingCorpse()
    if SAINT.wasHoldingPart and not isHolding then
        local h = hum()
        if h and h.Health > 0 then
            SAINT.status = "stand merged!"
            logAction("SAINT", "Stand merge completed successfully!", Color3.fromRGB(60, 240, 140), "SUCCESS")
            if S.saintMergeTpPlayer and S.saintMergeTpPlayer ~= "None" then
                local targetPlr = Players:FindFirstChild(S.saintMergeTpPlayer)
                local tc = targetPlr and targetPlr.Character
                local tr = tc and (tc:FindFirstChild("HumanoidRootPart") or tc.PrimaryPart or tc:FindFirstChild("Torso"))
                if tr then
                    logAction("SAINT", ("Auto-teleporting to %s after merge..."):format(targetPlr.Name), Color3.fromRGB(80, 255, 140), "TRAVEL")
                    horseTeleport(tr.Position)
                    landBeside(tr.Position, 3)
                else
                    logAction("SAINT", ("Merge complete, but target player %s has no character"):format(S.saintMergeTpPlayer), Color3.fromRGB(245, 160, 60), "SAINT")
                end
            end
        end
    end
    SAINT.wasHoldingPart = isHolding

    if isHolding then
        if S.saintRetreat and not SAINT.retreating then
            SAINT.status = "holding a part"
            retreatSafe()
        end
        return
    end
    if SAINT.busy then return end
    if announcementLive() then
        if not SAINT.announcedAt or os.clock() - SAINT.announcedAt > 30 then
            SAINT.announcedAt = os.clock()
            logAction("SAINT", "Announcement detected: 'IT APPEARS ONCE AGAIN'", Color3.fromRGB(255, 110, 110), "SAINT")
        end
        SAINT.lastAnnounce = os.clock()
    end
    if not SAINT.announcedAt or os.clock() - SAINT.announcedAt > (S.saintWindow or 300) then
        SAINT.status = "waiting for \"IT APPEARS ONCE AGAIN\""
        return
    end
    local live, parked = corpseCandidates()
    if #live == 0 then
        SAINT.status = parked > 0
            and ("waiting - %d part(s) claimed or underground"):format(parked)
            or "waiting for a spawn"
        return
    end
    SAINT.detects = SAINT.detects + 1
    local r = root()
    table.sort(live, function(a, b)
        if not r then return false end
        return (a.part.Position - r.Position).Magnitude < (b.part.Position - r.Position).Magnitude
    end)
    if S.saintGrab then
        grabCorpse(live[1])
    else
        SAINT.status = ("%s available (%d studs)"):format(live[1].part.Name,
            r and math.floor((live[1].part.Position - r.Position).Magnitude) or -1)
    end
end

getgenv().BW3_SaintTick = function() return saintTick() end
getgenv().BW3_SaintRetreat = function() return retreatSafe() end


return {
    SAINT = SAINT,
    holdingCorpse = holdingCorpse,
    announcementLive = announcementLive,
    grabCorpse = grabCorpse,
    retreatSafe = retreatSafe,
    saintTick = saintTick,
}
