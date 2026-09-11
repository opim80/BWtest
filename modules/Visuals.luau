--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Visuals
-- 2D/3D ESP, Tracers, Boxes, Player Highlights & Drawing pool
-- ============================================================
local ctx = ...


-- ── ESP ────────────────────────────────────────────────────────────────────
local function getDraw(i)
    local d = draws[i]
    if d then return d end
    local ok, o = pcall(function() return Drawing.new("Text") end)
    if not ok or not o then return nil end
    o.Size = 14; o.Center = true; o.Outline = true; o.Font = 2; o.Visible = false
    draws[i] = o
    return o
end
local function hideDraws(from) for i = from, #draws do if draws[i] then pcall(function() draws[i].Visible = false end) end end end
local function clearDraws()
    for i = 1, #draws do
        if draws[i] then pcall(function() draws[i]:Remove() end) end
        draws[i] = nil
    end
end

local espOn = false
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
                if d <= S.espRange then put(part.Position, tag .. " " .. math.floor(d), col) end
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
                if p and p.ActionText == "Mount" then
                    local part = e:FindFirstChild("HumanoidRootPart")
                    if part then
                        local d = (part.Position - r.Position).Magnitude
                        local o = e:FindFirstChild("Owner")
                        local mine = o and o.Value == LP
                        if d <= S.espRange then
                            put(part.Position, (mine and "MY HORSE " or "HORSE ") .. math.floor(d),
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
                    if d <= S.espRange then
                        local isF = isPlayerFriend(o)
                        local oStand, oTier, oAlign = getStandInfo(o)
                        local standTag = oStand ~= "None" and (" | " .. oStand .. " [" .. oAlign .. "]") or ""
                        local nameTag = isF and ("[FRIEND] " .. o.Name) or o.Name
                        local espCol = isF and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(140, 190, 255)
                        put(hd.Position + Vector3.new(0, 2.5, 0),
                            ("%s (%d HP) [%dm]%s"):format(nameTag, math.floor(hh.Health), math.floor(d), standTag),
                            espCol)
                    end
                end
            end
        end
    end
    hideDraws(idx + 1)
end
local function ensureESP()
    local want = S.espChest or S.espHerb or S.espHorse or S.espPlayers or S.chamsWhite
    if want and not espOn then
        espOn = true
        task.spawn(function()
            while S.running and (S.espChest or S.espHerb or S.espHorse or S.espPlayers or S.chamsWhite) do
                pcall(espTick)
                if COMBAT and COMBAT.updateChams then
                    pcall(COMBAT.updateChams)
                end
                RunService.RenderStepped:Wait()
            end
            espOn = false
            pcall(hideDraws, 1)
            if COMBAT and COMBAT.updateChams then
                pcall(COMBAT.updateChams)
            end
        end)
    end
end


return {
    getDraw = getDraw,
    hideDraws = hideDraws,
    clearDraws = clearDraws,
    espTick = espTick,
    ensureESP = ensureESP,
}
