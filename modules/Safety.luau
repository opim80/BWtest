--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Safety
-- Friends list cache, Player proximity check & Server Hopper
-- ============================================================
local ctx = ...


-- ── safety & server hopping ────────────────────────────────────────────────
local hoppingServer = false
local function serverHop()
    if hoppingServer then return end
    hoppingServer = true

    logAction("SAFETY", "Initiating Server Hop...", Color3.fromRGB(255, 120, 60), "HOP")
    Status.state = "HOP"
    Status.action = "Finding new server..."
    Status.detail = "Querying Roblox public servers"
    Status.color = Color3.fromRGB(255, 120, 60)
    if UI.updateBanner then pcall(UI.updateBanner) end
    if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end

    primeTeleportLoader()

    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local placeId = game.PlaceId
    local currentJob = game.JobId

    local req = (syn and syn.request) or (http and http.request) or http_request or request
    local candidateServers = {}
    local cursor = ""

    for _ = 1, 3 do
        local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
        local raw
        pcall(function()
            if req then
                local res = req({ Url = url, Method = "GET" })
                raw = res and res.Body
            elseif game.HttpGet then
                raw = game:HttpGet(url)
            end
        end)

        if raw then
            local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and parsed and parsed.data then
                for _, s in ipairs(parsed.data) do
                    local playing = s.playing or 0
                    local maxP = s.maxPlayers or 20
                    if s.id ~= currentJob and playing > 0 and playing < maxP then
                        candidateServers[#candidateServers + 1] = s
                    end
                end
                if #candidateServers > 0 then break end
                if parsed.nextPageCursor then
                    cursor = parsed.nextPageCursor
                else
                    break
                end
            end
        end
        task.wait(0.4)
    end

    if #candidateServers > 0 then
        local chosen = candidateServers[math.random(1, #candidateServers)]
        local shortId = tostring(chosen.id):sub(1, 8)
        logAction("SAFETY", ("Hopping to server %s (%d/%d players)..."):format(shortId, chosen.playing or 0, chosen.maxPlayers or 20), Color3.fromRGB(80, 220, 140), "HOP")
        Status.detail = ("Joining %s (%d/%d)"):format(shortId, chosen.playing or 0, chosen.maxPlayers or 20)
        if UI.updateBanner then pcall(UI.updateBanner) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end

        primeTeleportLoader()
        pcall(saveConfig)
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, chosen.id, LP)
        end)
        if not ok then
            logAction("SAFETY", "Instance teleport failed, using fallback Teleport: " .. tostring(err), Color3.fromRGB(255, 100, 100), "HOP")
            primeTeleportLoader()
            pcall(saveConfig)
            TeleportService:Teleport(placeId, LP)
        end
    else
        logAction("SAFETY", "No candidate server found in list, using fallback Teleport...", Color3.fromRGB(245, 160, 60), "HOP")
        primeTeleportLoader()
        pcall(saveConfig)
        TeleportService:Teleport(placeId, LP)
    end
end

-- Robust friends management: Official Roblox friends + custom whitelist
local myFriends = {}
local friendsLoaded = false

local function loadFriendsList()
    task.spawn(function()
        local lp = LP or Players.LocalPlayer
        if not lp or not lp.UserId or lp.UserId <= 0 then
            task.wait(1)
            lp = LP or Players.LocalPlayer
        end
        if not lp or not lp.UserId or lp.UserId <= 0 then return end

        local loadedCount = 0
        -- Method 1: Official engine API (fast, reliable, returns usernames)
        local ok, pages = pcall(function() return Players:GetFriendsAsync(lp.UserId) end)
        if ok and pages then
            while true do
                for _, item in ipairs(pages:GetCurrentPage()) do
                    if item.Id then myFriends[item.Id] = true end
                    if item.Username and item.Username ~= "" then
                        myFriends[item.Username:lower()] = true
                        loadedCount = loadedCount + 1
                    end
                end
                if pages.IsFinished then break end
                local aOk = pcall(function() pages:AdvanceToNextPageAsync() end)
                if not aOk then break end
            end
        end

        -- Method 2: Fallback to web API if method 1 returned 0
        if loadedCount == 0 then
            local req = (syn and syn.request) or (http and http.request) or http_request or request
            if req then
                local url = "https://friends.roblox.com/v1/users/" .. tostring(lp.UserId) .. "/friends"
                local rOk, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
                if rOk and res and res.Body then
                    local pOk, data = pcall(function() return game:GetService("HttpService"):JSONDecode(res.Body) end)
                    if pOk and data and data.data then
                        for _, f in ipairs(data.data) do
                            if f.id then myFriends[f.id] = true end
                            if f.name and f.name ~= "" then
                                myFriends[f.name:lower()] = true
                                loadedCount = loadedCount + 1
                            end
                        end
                    end
                end
            end
        end

        friendsLoaded = true
        if UI and UI.friendsCountLabel then
            UI.friendsCountLabel:Set(string.format("%d friends loaded", loadedCount))
        end
        logAction("FRIENDS", string.format("Friends list cached (%d friends loaded)", loadedCount), Color3.fromRGB(80, 220, 140), "FRIENDS")
    end)
end
loadFriendsList()

local function isPlayerFriend(p)
    if not p then return false end

    local name, uid
    if typeof(p) == "string" then
        name = p
        local pl = Players:FindFirstChild(p)
        if pl then uid = pl.UserId end
    elseif typeof(p) == "Instance" then
        if p:IsA("Player") then
            name = p.Name
            uid = p.UserId
        else
            local pl = Players:GetPlayerFromCharacter(p)
            if pl then
                name = pl.Name
                uid = pl.UserId
            else
                name = p.Name
            end
        end
    end

    local lowerName = name and name:lower()

    -- 1. Check custom whitelist from settings
    if S.customFriends and S.customFriends ~= "" and lowerName then
        for rawName in string.gmatch(S.customFriends, "[^,%s]+") do
            if rawName:lower() == lowerName then
                return true
            end
        end
    end

    -- 2. Check cached friends table
    if uid and myFriends[uid] ~= nil then
        return myFriends[uid]
    end
    if lowerName and myFriends[lowerName] ~= nil then
        return myFriends[lowerName]
    end

    -- 3. If not cached, initiate non-blocking background check
    if uid and uid > 0 and LP and LP.UserId and LP.UserId > 0 then
        myFriends[uid] = false
        if lowerName then myFriends[lowerName] = false end

        task.spawn(function()
            local ok, isF = pcall(function() return LP:IsFriendsWith(uid) end)
            if ok and isF == true then
                myFriends[uid] = true
                if lowerName then myFriends[lowerName] = true end
            end
        end)
    end

    return false
end

local function playerProximityTick()
    if (not S.autoHopNearPlayer and not S.autoSwapSetNearPlayer) or hoppingServer then return end
    local myRoot = root()
    local myPos = myRoot and myRoot.Position
    if not myPos then
        local hr = select(1, horseRoot())
        myPos = hr and hr.Position
    end
    if not myPos then return end
    local hopThreshold = S.autoHopDistance or 200
    local swapThreshold = S.autoSwapDistance or 150

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local skip = false
            if S.autoHopIgnoreFriends and isPlayerFriend(p) then
                skip = true
            end

            if not skip then
                local c = p.Character
                local pRoot = c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Head"))
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local isAlive = not h or h.Health > 0

                if pRoot and isAlive then
                    local dist = (pRoot.Position - myPos).Magnitude
                    local name = p.DisplayName and p.DisplayName ~= "" and p.DisplayName or p.Name

                    -- Proximity set swapping (alternative to server hop)
                    -- Explicit requirement: disabled when legit is on!
                    if S.autoSwapSetNearPlayer and not S.legitFishing and dist <= swapThreshold then
                        if not S._lastSwapNearPlayer or os.clock() - S._lastSwapNearPlayer > 12 then
                            S._lastSwapNearPlayer = os.clock()
                            local setList = FISH.getSetNames()
                            if #setList > 1 then
                                local curName = FISH.getActiveSetName()
                                local curIdx = table.find(setList, curName) or 1
                                local nextIdx = (curIdx % #setList) + 1
                                local nextName = setList[nextIdx]
                                logAction("SAFETY", string.format("Player '%s' (@%s) entered proximity (%.0f / %d studs)! Swapping to Fishing Set '%s' instead of hopping.",
                                    name, p.Name, dist, swapThreshold, nextName), Color3.fromRGB(255, 140, 60), "SAFETY")
                                FISH.setActiveSet(nextName)
                                return
                            end
                        end
                    end

                    -- Auto server hop
                    if S.autoHopNearPlayer and dist <= hopThreshold then
                        local pStand, pTier, pAlign = getStandInfo(p)
                        logAction("SAFETY", ("Player '%s' (@%s, Stand: %s [%s]) entered proximity (%.0f / %d studs)! Hopping server immediately!"):format(
                            name, p.Name, pStand, pAlign, dist, hopThreshold), Color3.fromRGB(255, 70, 70), "HOP")
                        task.spawn(serverHop)
                        return
                    end
                end
            end
        end
    end
end


return {
    serverHop = serverHop,
    loadFriendsList = loadFriendsList,
    isPlayerFriend = isPlayerFriend,
    playerProximityTick = playerProximityTick,
}
