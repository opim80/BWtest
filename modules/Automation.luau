--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Automation
-- Pickups sweep, Ore/Crop auto-farming, Auto-buy bait & sell
-- ============================================================
local ctx = ...


-- ── pickups / shop / farm ──────────────────────────────────────────────────
local function promptSweep(folder, range, skipHeld)
    if not firepp then return end
    local r = root()
    local f = WS:FindFirstChild(folder)
    if not r or not f then return end
    local held
    if skipHeld then
        held = {}
        for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
            if src then for _, t in ipairs(src:GetChildren()) do if t:IsA("Tool") then held[t.Name] = true end end end
        end
    end
    for _, item in ipairs(f:GetChildren()) do
        if not (held and held[item.Name]) then
            local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
            if part and (part.Position - r.Position).Magnitude <= range then
                for _, d in ipairs(item:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then pcall(firepp, d, d.HoldDuration or 0) end
                end
            end
        end
    end
end

local FARM = { status = "idle", busy = false, opened = 0 }
local SPAWNED_AT, DONE_UNTIL = {}, {}

for _, fname in ipairs({ "Chests", "SpawnedHerbs" }) do
    local f = WS:FindFirstChild(fname)
    if f then
        for _, item in ipairs(f:GetChildren()) do SPAWNED_AT[item] = 0 end
        conns[#conns + 1] = f.ChildAdded:Connect(function(item)
            SPAWNED_AT[item] = os.clock()
        end)
        conns[#conns + 1] = f.ChildRemoved:Connect(function(item)
            SPAWNED_AT[item] = nil
            DONE_UNTIL[item] = nil
        end)
    end
end

local function nearestPrompted(folderName, skipHeld)
    local r = root()
    local f = WS:FindFirstChild(folderName)
    if not r or not f then return nil end
    local held
    if skipHeld then
        held = {}
        for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
            if src then for _, t in ipairs(src:GetChildren()) do if t:IsA("Tool") then held[t.Name] = true end end end
        end
    end
    local best, bestD, bestPrompt, bestScore, bestItem
    local now = os.clock()
    for _, item in ipairs(f:GetChildren()) do
        local onCooldown = DONE_UNTIL[item] and now < DONE_UNTIL[item]
        if not (held and held[item.Name]) and not onCooldown then
            local prompt
            for _, d in ipairs(item:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then prompt = d; break end
            end
            if prompt then
                local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local dist = (part.Position - r.Position).Magnitude
                    local age = SPAWNED_AT[item] and (now - SPAWNED_AT[item]) or math.huge
                    local score = dist
                    if age < 90 then score = dist * 0.25 end
                    if not bestScore or score < bestScore then
                        best, bestD, bestPrompt, bestScore, bestItem = part, dist, prompt, score, item
                    end
                end
            end
        end
    end
    return best, bestD, bestPrompt, bestItem
end

local function sitBeside(pos, seconds)
    local h = hum()
    local oldSit = h and h.Sit
    if h then
        pcall(function()
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            h:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            h.Sit = true
        end)
    end
    task.wait(0.12)
    local t0 = os.clock()
    while os.clock() - t0 < (seconds or 1.2) do
        local rr = root()
        if rr then
            rr.CFrame = CFrame.new(pos)
            rr.AssemblyLinearVelocity = Vector3.zero
        end
        RunService.Heartbeat:Wait()
    end
    local h2 = hum()
    if h2 then
        pcall(function()
            h2.Sit = oldSit or false
            h2:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            h2:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            h2:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end)
    end
end

local function farmTick(folderName, label, skipHeld)
    if FARM.busy then return end
    local part, dist, prompt, item = nearestPrompted(folderName, skipHeld)
    if not part then
        FARM.status = label .. ": none available"
        return
    end
    if dist <= S.promptRange then
        FARM.status = ("%s: opening (%d studs)"):format(label, math.floor(dist))
        logAction("FARM", ("Interacting with %s (%d studs)..."):format(label, math.floor(dist)), Color3.fromRGB(180, 140, 255), "FARMING")
        promptSweep(folderName, S.promptRange, skipHeld)
        if item then DONE_UNTIL[item] = os.clock() + 45 end
        FARM.opened = FARM.opened + 1
        logAction("FARM", ("Opened %s! (Total: %d)"):format(label, FARM.opened), Color3.fromRGB(60, 240, 140), "SUCCESS")
        return
    end
    FARM.busy = true
    FARM.status = ("%s: %d studs away - travelling"):format(label, math.floor(dist))
    logAction("FARM", ("Travelling to %s (%d studs away)..."):format(label, math.floor(dist)), Color3.fromRGB(180, 140, 255), "FARMING")
    task.spawn(function()
        pcall(function()
            local dest = part.Position
            if dist > 70 then
                horseTeleport(dest)
                landBeside(dest, 4)
            end
            local approach = dest + Vector3.new(0, 3, 0)
            sitBeside(approach, 0.8)
            FARM.status = label .. ": opening"
            for _ = 1, 6 do
                if firepp and prompt and prompt.Parent and prompt.Enabled then
                    pcall(firepp, prompt, prompt.HoldDuration or 0)
                end
                promptSweep(folderName, S.promptRange, skipHeld)
                task.wait(0.25)
            end
            if item then DONE_UNTIL[item] = os.clock() + 45 end
            FARM.opened = FARM.opened + 1
            logAction("FARM", ("Opened %s! (Total: %d)"):format(label, FARM.opened), Color3.fromRGB(60, 240, 140), "SUCCESS")
        end)
        task.wait(0.4)
        FARM.busy = false
    end)
end

getgenv().BW3_FarmTick = function(a, b, c) return farmTick(a, b, c) end

-- (Kaitun mode stripped: dedicated kaitun.luau should be used instead)


local function padCatalog()
    local names, seen = {}, {}
    local f = WS:FindFirstChild("PurchasePads")
    if not f then return names end
    for _, v in ipairs(f:GetChildren()) do
        local tn = v:GetAttribute("ToolName")
        if tn and not seen[tn] then seen[tn] = true; names[#names + 1] = tn end
    end
    table.sort(names)
    return names
end

local _buyStatus = "off"
local function autoBuyTick()
    if not fireclick then _buyStatus = "no fireclickdetector"; return end
    local r, f = root(), WS:FindFirstChild("PurchasePads")
    if not r or not f then return end
    local m = moola()
    local pad, bd
    for _, v in ipairs(f:GetChildren()) do
        if v:IsA("BasePart") and v:GetAttribute("ToolName") == S.buyTarget then
            local d = (v.Position - r.Position).Magnitude
            if not bd or d < bd then pad, bd = v, d end
        end
    end
    if not pad then _buyStatus = "no pad sells " .. S.buyTarget; return end
    local price = pad:GetAttribute("Price") or 0
    local maxOwn = pad:GetAttribute("MaxOwn")
    if maxOwn and countTool(S.buyTarget) >= maxOwn then _buyStatus = S.buyTarget .. " at max"; return end
    if m - price < S.buyReserve then
        _buyStatus = ("hold: %s=%d have %d keep %d"):format(S.buyTarget, price, m, S.buyReserve); return
    end
    if bd > 20 then _buyStatus = ("pad %d studs away"):format(math.floor(bd)); return end
    local cd = pad:FindFirstChildOfClass("ClickDetector")
    if not cd then _buyStatus = "pad has no ClickDetector"; return end
    pcall(fireclick, cd)
    _buyStatus = ("bought %s (%d)"):format(S.buyTarget, price)
    logAction("SHOP", ("Purchased %s ($%d) from pad"):format(S.buyTarget, price), Color3.fromRGB(60, 240, 140), "SUCCESS")
end


return {
    FARM = FARM,
    promptSweep = promptSweep,
    nearestPrompted = nearestPrompted,
    sitBeside = sitBeside,
    farmTick = farmTick,
    padCatalog = padCatalog,
    autoBuyTick = autoBuyTick,
}
