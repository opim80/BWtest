--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Logging
-- Action logger, Catch recorder, Telemetry status & Auto-Play
-- ============================================================
local ctx = ...

-- ── central status & telemetry engine ──────────────────────────────────────
local Status = {
    state = "IDLE",
    action = "Ready to start",
    detail = "All systems operational",
    color = Color3.fromRGB(150, 160, 175),
    stateTime = os.clock(),
    logs = {},
}

local UI: any = {
    tabs = {},
}

local function logAction(category, message, color, stateKey, customDetail)
    local col = color or Color3.fromRGB(160, 170, 185)
    if stateKey then
        Status.state = stateKey
        Status.color = col
        Status.stateTime = os.clock()
    end
    if message then Status.action = message end
    if customDetail then Status.detail = customDetail end

    local entry = {
        time = os.date("%X"),
        category = category or "SYSTEM",
        text = message or "",
        color = col,
    }
    table.insert(Status.logs, 1, entry)
    if #Status.logs > 60 then
        table.remove(Status.logs)
    end

    if UI.updateBanner then pcall(UI.updateBanner) end
    if UI.updateHud then pcall(UI.updateHud) end
    if UI.updateLogs then pcall(UI.updateLogs) end
    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
end

local function recordCatch(source, count)
    count = count or 1
    FISH.catches = FISH.catches + count
    FISH.dead = 0
    castPhase = "idle"
    lastCast = 0
    lastCatchTime = os.clock()
    FISH.status = "CAUGHT ONE (" .. FISH.catches .. ")"
    logAction("FISH", ("Caught fish #%d! (+%d catch)"):format(FISH.catches, count), Color3.fromRGB(60, 240, 140), "SUCCESS",
        ("Catches: %d | Bait: %d"):format(FISH.catches, countTool("Bait")))
    if UI.updateBanner then pcall(UI.updateBanner) end
    if UI.updateHud then pcall(UI.updateHud) end
    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
end

local function initFishWatcher()
    pcall(function()
        local _, tot = getFishCounts()
        lastKnownFishTotal = tot
        if FISH.catches < tot then FISH.catches = tot end
    end)
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        track(bp.ChildAdded:Connect(function(c)
            if c:IsA("Tool") and isFish(c) then
                if os.clock() - lastCatchTime > 0.8 then
                    recordCatch("Backpack: " .. c.Name, 1)
                end
            end
        end))
    end
    local ch = char()
    if ch then
        track(ch.ChildAdded:Connect(function(c)
            if c:IsA("Tool") and isFish(c) then
                if os.clock() - lastCatchTime > 0.8 then
                    recordCatch("Character: " .. c.Name, 1)
                end
            end
        end))
    end
end
task.spawn(initFishWatcher)
track(LP.CharacterAdded:Connect(function()
    task.wait(1)
    initFishWatcher()
end))

local function autoHitPlay()
    local pg = LP:WaitForChild("PlayerGui", 10)
    if not pg then return end
    for _ = 1, 35 do
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and (not pg:FindFirstChild("MainMenu")) then
            break
        end
        local mm = pg:FindFirstChild("MainMenu")
        if mm and mm.Enabled then
            local bc = mm:FindFirstChild("ButtonContainer")
            local btn = bc and bc:FindFirstChild("PlayButton")
            if btn and btn.Visible then
                logAction("SYSTEM", "Main Menu detected. Automatically clicking PLAY...", Color3.fromRGB(80, 220, 140))
                local clicked = false
                local gc = rawget(getfenv(), "get_connections")
                local cons = (getconnections and getconnections(btn.MouseButton1Click)) or (gc and gc(btn.MouseButton1Click))
                if cons and #cons > 0 then
                    for _, c in ipairs(cons) do
                        if c.Function then
                            pcall(c.Function)
                            clicked = true
                        end
                    end
                end
                if not clicked then
                    pcall(function()
                        local rem = RS:FindFirstChild("WesternFramework")
                            and RS.WesternFramework:FindFirstChild("Shared")
                            and RS.WesternFramework.Shared:FindFirstChild("Remotes")
                            and RS.WesternFramework.Shared.Remotes:FindFirstChild("SpawnPlayerEvent")
                        if rem and rem:IsA("RemoteEvent") then
                            rem:FireServer()
                        end
                    end)
                end
                task.wait(2)
                break
            end
        end
        task.wait(0.5)
    end
    local c = LP.Character or LP.CharacterAdded:Wait()
    pcall(function() c:WaitForChild("HumanoidRootPart", 12) end)
end
task.spawn(autoHitPlay)

-- isSellingFish and isRestockingBait declared at top

local function setSellingStatus(action, detail)
    Status.state = "SELLING"
    Status.color = Color3.fromRGB(245, 175, 60)
    if action then Status.action = action end
    if detail then
        Status.detail = detail
    else
        local _, totalFish = getFishCounts()
        Status.detail = ("Fish: %d | Moola: $%d | Vendor: Daniel"):format(totalFish, moola())
    end
    Status.stateTime = os.clock()

    if UI.updateBanner then pcall(UI.updateBanner) end
    if UI.updateHud then pcall(UI.updateHud) end
    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
end


return {
    Status = Status,
    logAction = logAction,
    recordCatch = recordCatch,
    initFishWatcher = initFishWatcher,
    autoHitPlay = autoHitPlay,
    setSellingStatus = setSellingStatus,
}
