--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: Tabs
-- Tab Population: Fish, Travel, Combat, Farm, Saint, Visual, Logs, Info, Config
-- ============================================================
local ctx = ...


local function initTabs()
    local function buttonRow2(parentCard, txt1, fn1, txt2, fn2)
        local row = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
        }, parentCard)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, row)

        local function makeSubBtn(txt, fn, order)
            local b = mk("TextButton", {
                Size = UDim2.new(0.5, -3, 1, 0),
                BackgroundColor3 = TH.header,
                Font = Enum.Font.GothamMedium,
                Text = txt,
                TextColor3 = TH.text,
                TextSize = 11,
                AutoButtonColor = false,
                LayoutOrder = order,
            }, row)
            corner(b, 5)
            stroke(b, TH.border)
            track(b.MouseEnter:Connect(function() b.BackgroundColor3 = TH.cardHover; b.TextColor3 = TH.accent end))
            track(b.MouseLeave:Connect(function() b.BackgroundColor3 = TH.header; b.TextColor3 = TH.text end))
            if fn then
                track(b.MouseButton1Click:Connect(function() task.spawn(function() pcall(fn) end) end))
            end
            return b
        end

        local b1 = makeSubBtn(txt1, fn1, 1)
        local b2 = makeSubBtn(txt2, fn2, 2)
        return b1, b2
    end
    local TFish = UI.addTab("Fish")
local TTravel = UI.addTab("Travel")
local TCombat = UI.addTab("Combat")
local TFarm = UI.addTab("Farm")
local TSaint = UI.addTab("Saint")
local TVisual = UI.addTab("Visual")
local TLogs = UI.addTab("Logs")
local TInfo = UI.addTab("Info")
local TConfig = UI.addTab("Config")

track(UI.logsJumpBtn.MouseButton1Click:Connect(function() UI.selectTab(TLogs) end))
track(UI.hudToggleBtn.MouseButton1Click:Connect(function()
    S.showHud = not S.showHud
    UI.hudToggleBtn.TextColor3 = S.showHud and TH.accent or TH.dim
    if UI.updateHud then UI.updateHud() end
end))

-- FISH TAB
do
    local cAuto = card(TFish, "Automation")
    toggle(cAuto, "Auto Fish", "Automatic horse travel, casting, reeling, & QTEs", "autoFish", function(v)
        if v then startFishing() else stopFishing() end
    end)
    toggle(cAuto, "Legit Fishing Mode", "Horse TPs to staging coords, then walks/sprints to spots", "legitFishing", function(v)
        if v then
            local ok, err = FISH.validateAllSpots()
            if not ok then
                S.legitFishing = false
                if togglesByKey["legitFishing"] then
                    for _, fn in ipairs(togglesByKey["legitFishing"]) do fn(false) end
                end
                logAction("FISH", "Legit Fishing rejected: " .. tostring(err), Color3.fromRGB(245, 90, 90), "ERROR")
                return
            end
            FISH.ensureViz()
            logAction("FISH", "Legit Fishing enabled (all spots reachable via pathfinding)", Color3.fromRGB(80, 220, 140), "FISHING")
        else
            FISH.hideViz()
            logAction("FISH", "Legit Fishing disabled", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    toggle(cAuto, "Visualize Legit Path", "Draws 3D waypoints, lines, obstacle rays, & actions on screen", "visualizeLegit", function(v)
        if v then
            FISH.ensureViz()
            logAction("FISH", "Legit visualization enabled", Color3.fromRGB(80, 220, 140), "FISHING")
        else
            FISH.hideViz()
            logAction("FISH", "Legit visualization disabled", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    toggle(cAuto, "Require Bait To Fish", "When off, you can fish freely with zero bait", "requireBait")
    toggle(cAuto, "Auto Sell When Out Of Money", "Visits Daniel to sell fish whenever moola runs low", "autoSellOutOfMoney")
    slider(cAuto, "Low Money Threshold", "lowMoneyThreshold", 0, 100, 5, "moola")
    toggle(cAuto, "Auto Pass Minigames", "Solves Mash, Reaction circle, and Dot minigames", "autoQTE")
    toggle(cAuto, "Auto Restock Bait", "Visits Daniel when bait runs out (if bait required)", "autoRestock")
    slider(cAuto, "Restock Target Bait", "baitKeep", 5, 50, 5, "bait")
    toggle(cAuto, "Auto Sell Fish", "Visits Daniel periodically to sell catches", "autoSell")
    slider(cAuto, "Sell Every N Catches", "sellEvery", 1, 40, 1, "catches")
    button(cAuto, "Reset Catches Counter", function()
        FISH.catches = 0
        logAction("FISH", "Catches counter reset to 0", Color3.fromRGB(160, 165, 180), "IDLE")
        if UI.updateHud then pcall(UI.updateHud) end
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
    end)

    local cTiming = card(TFish, "Timing & Casts")
    slider(cTiming, "Recast Timeout", "castTimeout", 8, 40, 1, "s")
    slider(cTiming, "Reel Delay After Bite", "reelDelay", 0.02, 0.5, 0.02, "s")
    slider(cTiming, "Dead Casts Before Moving Spot", "deadCastsBeforeMove", 1, 10, 1, "casts")
    button(cTiming, "Cast Rod Once (Manual)", function()
        if ensureRod() and aimAtWater() then
            tap("PrimaryInput")
            logAction("FISH", "Manual cast triggered", Color3.fromRGB(80, 220, 140), "FISHING")
        end
    end)

    local cSpots = card(TFish, "Fishing Sets & Spot Manager")

    -- 1. Active Fishing Set Dropdown (Unlimited Saved Sets)
    UI.activeSetDropdown = dropdown(cSpots, "Active Fishing Set", "Select from your saved sets (unlimited)", "activeFishingSet", function()
        return FISH.getSetNames()
    end, function(val)
        FISH.setActiveSet(val)
        if UI.refreshSpotsUI then pcall(UI.refreshSpotsUI) end
    end)

    -- 2. Create / Save New Set Row (Type name + click Save)
    local saveSetRow = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = TH.header,
    }, cSpots)
    corner(saveSetRow, 6)
    stroke(saveSetRow, TH.border)

    local newSetInput = mk("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -125, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = "",
        PlaceholderText = "Type new set name...",
        PlaceholderColor3 = TH.dim,
        TextColor3 = TH.accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, saveSetRow)

    local saveSetBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(110, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = "+ Save Set",
        TextColor3 = TH.accent,
        TextSize = 11,
        AutoButtonColor = false,
    }, saveSetRow)
    corner(saveSetBtn, 4)
    stroke(saveSetBtn, TH.border)

    -- 3. Set Management Bar: Delete Set & Save Staging Point
    local deleteSetBtn, saveStagingBtn = buttonRow2(cSpots, "Delete Active Set", nil, "Save Staging Point", nil)

    -- 4. Target Slot Dropdown (Explicit user request: dropdown to select 1, 2, or 3)
    UI.targetSlotDropdown = dropdown(cSpots, "Target Spot Slot", "Select which slot (1, 2, or 3) to record", "selectedSpotSlot", {
        "Spot #1", "Spot #2", "Spot #3"
    }, function(opt)
        local n = tonumber(tostring(opt):match("(%d+)")) or 1
        S.selectedSpotSlot = n
        spotIndex = n
        if UI.refreshSpotsUI then pcall(UI.refreshSpotsUI) end
    end)

    -- 5. Quick 3-Slot Segment Bar (One-click instant switcher)
    local slotBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, cSpots)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, slotBar)

    local slotBtns = {}
    for slotNum = 1, 3 do
        local btn = mk("TextButton", {
            Size = UDim2.new(0.333, -4, 1, 0),
            BackgroundColor3 = TH.header,
            Font = Enum.Font.GothamMedium,
            Text = "Spot #" .. slotNum,
            TextColor3 = TH.dim,
            TextSize = 11,
            AutoButtonColor = false,
            LayoutOrder = slotNum,
        }, slotBar)
        corner(btn, 5)
        stroke(btn, TH.border)
        slotBtns[slotNum] = btn
    end

    -- 6. Live Spot Inspector Dashboard Frame
    local spotDash = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = TH.header,
    }, cSpots)
    corner(spotDash, 6)
    stroke(spotDash, TH.border)

    mk("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, spotDash)

    mk("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, spotDash)

    local dashHeader = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "SET: SAVED SPOTS",
        TextColor3 = TH.accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    }, spotDash)

    local slotRows = {}
    for slotNum = 1, 3 do
        local row = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = TH.card,
            Font = Enum.Font.Gotham,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = slotNum + 1,
        }, spotDash)
        corner(row, 4)
        local rStroke = stroke(row, TH.border)

        local rowTag = mk("TextLabel", {
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(0, 65, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = "Spot #" .. slotNum,
            TextColor3 = TH.accent,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)

        local rowCoords = mk("TextLabel", {
            Position = UDim2.new(0, 75, 0, 0),
            Size = UDim2.new(1, -165, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "(0, 0, 0)",
            TextColor3 = TH.text,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        local rowDist = mk("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 0),
            Size = UDim2.new(0, 85, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = "-- m",
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)

        slotRows[slotNum] = { frame = row, tag = rowTag, coords = rowCoords, dist = rowDist, stroke = rStroke }
    end

    -- 7. Prominent Save Button with Visual Feedback
    local saveBtn = button(cSpots, "Save Current Position To Selected Slot", function() end)

    -- 8. Paired Navigation & Preview Button Bars
    local goToBtn, rotateBtn = buttonRow2(cSpots, "Travel To Spot", nil, "Rotate Next Spot", nil)
    local previewBtn, clearPreviewBtn = buttonRow2(cSpots, "Preview Route (3D)", nil, "Clear Preview", nil)

    -- 9. Live Feedback Banner
    local feedbackLabel = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = "Ready • Choose a slot and click Save to record your spot",
        TextColor3 = TH.dim,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, cSpots)

    local isSaveFlashing = false
    local function refreshSpotsUI()
        local activeName = FISH.getActiveSetName()
        dashHeader.Text = string.format("SET: '%s' - SAVED SPOTS", activeName:upper())

        local r = root()
        local myPos = r and r.Position

        local spotsList = (S.fishingSets and S.fishingSets[activeName]) or FISH_SPOTS or {}
        local slotIdx = FISH.getSelectedSlotIdx()

        for i = 1, 3 do
            local isSelected = (i == slotIdx)
            local btn = slotBtns[i]
            if btn then
                if isSelected then
                    btn.BackgroundColor3 = TH.accent
                    btn.TextColor3 = TH.darkText
                    btn.Font = Enum.Font.GothamBold
                    btn.Text = "● Slot " .. i .. " (Active)"
                else
                    btn.BackgroundColor3 = TH.header
                    btn.TextColor3 = TH.dim
                    btn.Font = Enum.Font.GothamMedium
                    btn.Text = "Slot " .. i
                end
            end

            local row = slotRows[i]
            if row then
                local pt = spotsList[i]
                local p = spotPos(pt)
                if p then
                    row.coords.Text = string.format("X: %.0f, Y: %.0f, Z: %.0f", p.X, p.Y, p.Z)
                    if myPos then
                        local d = math.floor((p - myPos).Magnitude)
                        if d <= 4 then
                            row.dist.Text = "● Standing Here"
                            row.dist.TextColor3 = TH.green
                        else
                            row.dist.Text = d .. "m away"
                            row.dist.TextColor3 = isSelected and TH.accent or TH.dim
                        end
                    else
                        row.dist.Text = "-- m"
                        row.dist.TextColor3 = TH.dim
                    end
                else
                    row.coords.Text = "(Not configured)"
                    row.dist.Text = "--"
                    row.dist.TextColor3 = TH.dim
                end

                if isSelected then
                    row.frame.BackgroundColor3 = TH.cardHover
                    row.tag.TextColor3 = TH.accent
                    row.tag.Text = string.format("▶ Slot #%d", i)
                    row.coords.TextColor3 = TH.accent
                    row.stroke.Color = TH.accent
                else
                    row.frame.BackgroundColor3 = TH.card
                    row.tag.TextColor3 = TH.text
                    row.tag.Text = string.format("  Slot #%d", i)
                    row.coords.TextColor3 = TH.text
                    row.stroke.Color = TH.border
                end
            end
        end

        if not isSaveFlashing then
            saveBtn.Text = string.format("Save Position To Slot #%d ('%s')", slotIdx, activeName)
            saveBtn.BackgroundColor3 = TH.header
            saveBtn.TextColor3 = TH.text
        end

        deleteSetBtn.Text = string.format("Delete Set ('%s')", activeName)
        saveStagingBtn.Text = string.format("Save Staging ('%s')", activeName)

        local curSpot = spotsList[slotIdx]
        local curPos = spotPos(curSpot)
        local spotDist = (curPos and myPos) and math.floor((curPos - myPos).Magnitude) or nil
        if spotDist then
            goToBtn.Text = string.format("Travel Slot #%d (%dm)", slotIdx, spotDist)
        else
            goToBtn.Text = string.format("Travel Slot #%d", slotIdx)
        end

        local nextIdx = (spotIndex % math.max(1, #spotsList)) + 1
        rotateBtn.Text = string.format("Rotate (-> #%d)", nextIdx)
        previewBtn.Text = string.format("Preview #%d (3D)", slotIdx)
        clearPreviewBtn.Text = "Clear Preview"

        if UI.targetSlotDropdown then
            pcall(function() UI.targetSlotDropdown:Set("Spot #" .. slotIdx) end)
        end
    end
    UI.refreshSpotsUI = refreshSpotsUI

    local function selectSlot(slotNum)
        S.selectedSpotSlot = slotNum
        spotIndex = slotNum
        refreshSpotsUI()
        feedbackLabel.Text = string.format("Selected Slot #%d • Click 'Save' to record position", slotNum)
        feedbackLabel.TextColor3 = TH.text
    end

    for slotNum = 1, 3 do
        track(slotBtns[slotNum].MouseButton1Click:Connect(function() selectSlot(slotNum) end))
        track(slotRows[slotNum].frame.MouseButton1Click:Connect(function() selectSlot(slotNum) end))
    end

    local function doCreateOrSaveSet()
        local raw = newSetInput.Text
        local sName = tostring(raw or ""):match("^%s*(.-)%s*$")
        if not sName or sName == "" then
            feedbackLabel.Text = "⚠ Please enter a set name first!"
            feedbackLabel.TextColor3 = TH.red
            return
        end

        if not S.fishingSets then S.fishingSets = {} :: any end
        local copy = {}
        local curList = FISH_SPOTS or {}
        local r = root()
        for s = 1, 3 do
            copy[s] = curList[s] or (r and r.Position) or Vector3.new(-3131.6, 47.12, -3717.2)
        end
        S.fishingSets[sName] = copy
        S.activeFishingSet = sName
        FISH_SPOTS = S.fishingSets[sName]
        pcall(saveConfig)

        newSetInput.Text = ""
        if UI.activeSetDropdown then UI.activeSetDropdown:Refresh() end
        refreshSpotsUI()

        local msg = string.format("✓ Saved set '%s' with 3 spots!", sName)
        feedbackLabel.Text = msg
        feedbackLabel.TextColor3 = TH.green
        logAction("FISH", msg, TH.green, "FISHING")
    end

    track(saveSetBtn.MouseButton1Click:Connect(doCreateOrSaveSet))
    track(newSetInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then doCreateOrSaveSet() end
    end))

    track(deleteSetBtn.MouseButton1Click:Connect(function()
        local names = FISH.getSetNames()
        if #names <= 1 then
            feedbackLabel.Text = "⚠ Cannot delete: Must keep at least one fishing set!"
            feedbackLabel.TextColor3 = TH.red
            return
        end
        local cur = FISH.getActiveSetName()
        if cur == "Default" then
            feedbackLabel.Text = "⚠ Cannot delete: The 'Default' set is permanent!"
            feedbackLabel.TextColor3 = TH.red
            return
        end
        S.fishingSets[cur] = nil
        if S.stagingPoints then S.stagingPoints[cur] = nil end
        local remaining = FISH.getSetNames()
        FISH.setActiveSet(remaining[1] or "Default")
        pcall(saveConfig)
        if UI.activeSetDropdown then UI.activeSetDropdown:Refresh() end
        refreshSpotsUI()
        local msg = string.format("✓ Deleted set '%s'. Active set is now '%s'.", cur, S.activeFishingSet)
        feedbackLabel.Text = msg
        feedbackLabel.TextColor3 = TH.amber
        logAction("FISH", msg, TH.amber, "FISHING")
    end))

    track(saveBtn.MouseButton1Click:Connect(function()
        local r = root()
        if not r then
            feedbackLabel.Text = "⚠ Cannot save: Character HumanoidRootPart not found!"
            feedbackLabel.TextColor3 = TH.red
            return
        end

        local slot = FISH.getSelectedSlotIdx()
        local activeName = FISH.getActiveSetName()

        if not S.fishingSets then S.fishingSets = {} :: any end
        if not S.fishingSets[activeName] then S.fishingSets[activeName] = {} end
        S.fishingSets[activeName][slot] = {
            pos = r.Position,
            look = r.CFrame.LookVector,
        }
        FISH_SPOTS = S.fishingSets[activeName]
        spotIndex = slot

        pcall(saveConfig)

        isSaveFlashing = true
        saveBtn.Text = string.format("✓ SAVED SLOT #%d! (%.0f, %.0f, %.0f)", slot, r.Position.X, r.Position.Y, r.Position.Z)
        saveBtn.BackgroundColor3 = Color3.fromRGB(40, 165, 80)
        saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

        local confirmMsg = string.format("✓ Saved position & facing to '%s' - Slot #%d: (%.1f, %.1f, %.1f)!",
            activeName, slot, r.Position.X, r.Position.Y, r.Position.Z)
        feedbackLabel.Text = confirmMsg
        feedbackLabel.TextColor3 = TH.green
        logAction("FISH", confirmMsg, TH.green, "FISHING")

        refreshSpotsUI()

        if S.visualizeLegit or (FISH.viz and FISH.viz.targetSpot) then
            FISH.ensureViz()
            FISH.viz.targetSpot = r.Position
        end

        task.delay(2.5, function()
            isSaveFlashing = false
            refreshSpotsUI()
        end)
    end))

    track(saveStagingBtn.MouseButton1Click:Connect(function()
        local r = root()
        if not r then return end
        local activeName = FISH.getActiveSetName()
        if not S.stagingPoints then S.stagingPoints = {} end
        S.stagingPoints[activeName] = r.Position
        pcall(saveConfig)
        local msg = string.format("✓ Saved staging arrival point for '%s': (%.0f, %.0f, %.0f)!", activeName, r.Position.X, r.Position.Y, r.Position.Z)
        feedbackLabel.Text = msg
        feedbackLabel.TextColor3 = TH.green
        logAction("FISH", msg, TH.green, "FISHING")
    end))

    track(goToBtn.MouseButton1Click:Connect(function()
        local slot = FISH.getSelectedSlotIdx()
        local activeName = FISH.getActiveSetName()
        local spotsList = (S.fishingSets and S.fishingSets[activeName]) or FISH_SPOTS or {}
        local spot = spotsList[slot]
        if not spot then
            feedbackLabel.Text = "⚠ Selected spot has no coordinates configured!"
            feedbackLabel.TextColor3 = TH.red
            return
        end
        local p = spotPos(spot)
        local l = spotLook(spot)
        if not p then return end
        spotIndex = slot
        feedbackLabel.Text = string.format("▶ Traveling to Set '%s' Slot #%d...", activeName, slot)
        feedbackLabel.TextColor3 = TH.blue
        logAction("TRAVEL", string.format("Traveling to fishing spot #%d in '%s'...", slot, activeName), TH.blue, "TRAVEL")
        if S.legitFishing then
            FISH.walkToSpotLegit(p)
        else
            if horseTeleport(p) then
                landBeside(p, 3)
                if l and root() then
                    pcall(function()
                        root().CFrame = CFrame.new(root().Position, root().Position + Vector3.new(l.X, 0, l.Z))
                    end)
                end
            end
        end
        refreshSpotsUI()
    end))

    track(rotateBtn.MouseButton1Click:Connect(function()
        local activeName = FISH.getActiveSetName()
        local spotsList = (S.fishingSets and S.fishingSets[activeName]) or FISH_SPOTS or {}
        spotIndex = (spotIndex % math.max(1, #spotsList)) + 1
        S.selectedSpotSlot = spotIndex
        local spot = spotsList[spotIndex]
        feedbackLabel.Text = string.format("▶ Rotating to Spot #%d...", spotIndex)
        feedbackLabel.TextColor3 = TH.blue
        logAction("TRAVEL", string.format("Rotating to fishing spot #%d...", spotIndex), TH.blue, "TRAVEL")
        if spot then
            local p = spotPos(spot)
            local l = spotLook(spot)
            if p then
                if S.legitFishing then
                    FISH.walkToSpotLegit(p)
                else
                    if horseTeleport(p) then
                        landBeside(p, 3)
                        if l and root() then
                            pcall(function()
                                root().CFrame = CFrame.new(root().Position, root().Position + Vector3.new(l.X, 0, l.Z))
                            end)
                        end
                    end
                end
            end
        end
        refreshSpotsUI()
    end))

    track(previewBtn.MouseButton1Click:Connect(function()
        local slot = FISH.getSelectedSlotIdx()
        local activeName = FISH.getActiveSetName()
        local spotsList = (S.fishingSets and S.fishingSets[activeName]) or FISH_SPOTS or {}
        local spot = spotsList[slot]
        if not spot then return end
        local p = spotPos(spot)
        if not p then return end
        FISH.ensureViz()
        FISH.viz.targetSpot = p
        local r = root()
        local myPos = r and r.Position or p
        local d = math.floor((p - myPos).Magnitude)
        FISH.viz.currentAction = string.format("Previewing Legit Route to Spot #%d (%dm away)", slot, d)
        feedbackLabel.Text = string.format("👁 Previewing route to Spot #%d (%dm away)", slot, d)
        feedbackLabel.TextColor3 = TH.accent
        logAction("FISH", string.format("Previewing legit route to Spot #%d (%dm away)", slot, d), TH.green, "FISHING")
    end))

    track(clearPreviewBtn.MouseButton1Click:Connect(function()
        FISH.viz.targetSpot = nil
        FISH.viz.steerTarget = nil
        FISH.viz.currentAction = "Idle"
        FISH.hideViz()
        feedbackLabel.Text = "Cleared route preview from screen"
        feedbackLabel.TextColor3 = TH.dim
        logAction("FISH", "Cleared path preview", TH.dim, "IDLE")
    end))

    refreshSpotsUI()
    local cVendor = card(TFish, "Daniel / Vendor Actions")
    button(cVendor, "Travel To Daniel", function()
        local npc = findNPC("Daniel")
        local p = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true))
        local tgt = p and p.Position + Vector3.new(0, 0, 6) or DANIEL_POS
        local r = root()
        local d = r and (r.Position - tgt).Magnitude or 999
        if S.legitFishing and d <= 300 then
            logAction("TRAVEL", ("Legit Fishing: Traveling to Daniel on foot (%.0f studs away)..."):format(d), Color3.fromRGB(90, 180, 255), "TRAVEL")
            FISH.walkToSpotLegit(tgt, 300)
        else
            if horseTeleport(tgt) then landBeside(tgt, 5) end
        end
    end)
    buttonRow2(cVendor, "Buy Bait Now", function() buyBait() end, "Buy Rod ($150)", function() buyRod() end)
    buttonRow2(cVendor, "Sell All Fish Now", function() sellAllFish() end, "Inspect Dialogue", function()
        local choices = dialogueOpen() and table.concat(listChoices(), " | ") or "No dialogue open"
        logAction("VENDOR", "Dialogue choices: " .. choices, Color3.fromRGB(160, 165, 180), "VENDOR")
    end)
end

-- TRAVEL TAB
do
    local cSafety = card(TTravel, "Safety & Server Hop")
    toggle(cSafety, "Auto Server Hop When Player Near", "Automatically hops to a new server if another player approaches", "autoHopNearPlayer", function(v)
        if v then
            logAction("SAFETY", ("Auto Server Hop active (Distance threshold: %d studs)"):format(S.autoHopDistance), Color3.fromRGB(255, 120, 60), "HOP")
            loop("autoHopNearPlayer", 0.5, playerProximityTick)
        else
            logAction("SAFETY", "Auto Server Hop disabled", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    slider(cSafety, "Proximity Distance", "autoHopDistance", 30, 600, 10, "studs")
    toggle(cSafety, "Swap Set When Player Near", "Alternative to hop: swaps set when player approaches (Disabled in legit mode)", "autoSwapSetNearPlayer", function(v)
        if v then
            logAction("SAFETY", ("Proximity Set Swap active (Distance threshold: %d studs)"):format(S.autoSwapDistance or 150), Color3.fromRGB(255, 140, 60), "SAFETY")
            loop("autoHopNearPlayer", 0.5, playerProximityTick)
        else
            logAction("SAFETY", "Proximity Set Swap disabled", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    slider(cSafety, "Swap Set Distance", "autoSwapDistance", 30, 600, 10, "studs")
    toggle(cSafety, "Ignore Friends", "Do not trigger hop/swap if approaching player is on your friends list", "autoHopIgnoreFriends")
    button(cSafety, "Server Hop Now (Manual)", function()
        serverHop()
    end)

    local cTravel = card(TTravel, "Horse Navigation")
    toggle(cTravel, "Horsefly", "Fly around client-side with your horse; toggling off lands you back", "fakeHorseFly", function(val)
        if val then
            startFakeHorseFly()
        else
            stopFakeHorseFly(true)
        end
    end)
    keybind(cTravel, "Horsefly Keybind", "Key to toggle Horsefly on / off", "horseFlyKey", "H")
    slider(cTravel, "Horsefly Speed", "fakeFlySpeed", 20, 250, 5, "studs/s")
    local horseBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, cTravel)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, horseBar)

    local function miniBtn(txt, fn, order)
        local b = mk("TextButton", {
            Size = UDim2.new(0.333, -4, 1, 0),
            BackgroundColor3 = TH.header,
            Font = Enum.Font.GothamMedium,
            Text = txt,
            TextColor3 = TH.text,
            TextSize = 11,
            AutoButtonColor = false,
            LayoutOrder = order,
        }, horseBar)
        corner(b, 5)
        stroke(b, TH.border)
        track(b.MouseEnter:Connect(function() b.BackgroundColor3 = TH.cardHover; b.TextColor3 = TH.accent end))
        track(b.MouseLeave:Connect(function() b.BackgroundColor3 = TH.header; b.TextColor3 = TH.text end))
        track(b.MouseButton1Click:Connect(function() task.spawn(function() pcall(fn) end) end))
        return b
    end
    miniBtn("Summon Horse", summonHorse, 1)
    miniBtn("Mount Horse", mountHorse, 2)
    miniBtn("Dismount", dismount, 3)
    buttonRow2(cTravel, "Teleport Saved Waypoint", function()
        if PC.savedPoint then
            logAction("TRAVEL", "Teleporting to saved waypoint...", Color3.fromRGB(90, 180, 255), "TRAVEL")
            horseTeleport(PC.savedPoint)
        else
            logAction("TRAVEL", "No saved waypoint recorded", Color3.fromRGB(245, 160, 60), "IDLE")
        end
    end, "Save Current Waypoint", function()
        local r = root()
        if r then
            PC.savedPoint = r.Position
            logAction("TRAVEL", "Waypoint saved at current position", Color3.fromRGB(80, 220, 140), "TRAVEL")
        end
    end)

    buttonRow2(cTravel, "TP Mud Witch Hut", function()
        logAction("TRAVEL", "Teleporting to Mud Witch Hut...", Color3.fromRGB(90, 180, 255), "TRAVEL")
        local p = TONIC_STATION_POS
        logAction("TRAVEL", ("Mud Witch Hut located at (%.0f, %.0f, %.0f) - horse teleporting..."):format(p.X, p.Y, p.Z), Color3.fromRGB(80, 220, 140), "TRAVEL")
        if horseTeleport(p) then
            landBeside(p, 5)
            logAction("TRAVEL", "Arrived at Mud Witch Hut!", Color3.fromRGB(80, 220, 140), "IDLE")
        else
            logAction("TRAVEL", "Horse teleport to Mud Witch Hut failed", Color3.fromRGB(245, 90, 90), "ERROR")
        end
    end, "TP Tonic Station", function()
        logAction("TRAVEL", "Locating Tonic Station / Brewing Station...", Color3.fromRGB(90, 180, 255), "TRAVEL")
        local p = findTonicStation()
        if not p then
            logAction("TRAVEL", "Tonic Station not found in workspace", Color3.fromRGB(245, 90, 90), "ERROR")
            return
        end
        logAction("TRAVEL", ("Tonic Station located at (%.0f, %.0f, %.0f) - horse teleporting..."):format(p.X, p.Y, p.Z), Color3.fromRGB(80, 220, 140), "TRAVEL")
        if horseTeleport(p) then
            landBeside(p, 5)
            logAction("TRAVEL", "Arrived at Tonic Station!", Color3.fromRGB(80, 220, 140), "IDLE")
        else
            logAction("TRAVEL", "Horse teleport to Tonic Station failed", Color3.fromRGB(245, 90, 90), "ERROR")
        end
    end)

    local cWitch = card(TTravel, "Mud Witch Interactions")
    button(cWitch, "Read Fortune (Open Tarot Card UI)", function()
        readMudWitchFortune()
    end)
    buttonRow2(cWitch, "Talk: Anything I Can Do?", function()
        talkMudWitchQuest()
    end, "Close Dialogue", function()
        closeDialogue()
    end)
    local cTravelInfo = card(TTravel, "Navigation Mechanics")
    statLabel(cTravelInfo, "Mounted Teleport:", "Infinite distance (no speed cap)")
    statLabel(cTravelInfo, "On-Foot Teleport:", "Capped at ~70 studs by game anticheat")
end

-- COMBAT TAB
do
    local cCombat = card(TCombat, "Gun Prediction & Silent Aim")
    toggle(cCombat, "Prediction Silent Aim", "Redirects shots to predicted target hitbox on fire", "silentAim", function(v)
        if v then
            COMBAT.start()
        else
            COMBAT.stop()
        end
    end)
    toggle(cCombat, "Martini Ballistics (5000 Range)", "Expands range to 5000 studs & compensates for bullet travel & drop", "martiniBallistics")

    local targetDropdown
    targetDropdown = dropdown(cCombat, "Target Mode", "Auto-target cursor/closest or select specific player", "aimTargetMode", function()
        local opts = { "Closest to Cursor", "Closest" }
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(opts, p.Name) end
        end
        return opts
    end, function(val)
        if COMBAT.highlight then
            COMBAT.highlight.Adornee = nil
            COMBAT.highlight.Enabled = false
        end
    end)

    toggle(cCombat, "Blacklist Friends", "Prevents friends from being auto-targeted in Closest mode", "aimIgnoreFriends")
    textInput(cCombat, "Friend Whitelist", "Comma-separated usernames to treat as friends", "customFriends", "username1, username2")
    dropdown(cCombat, "Target Hitbox", "Head deals 1.4x (26.6 dmg), Torso deals 1.1x", "aimHitbox", { "Head", "Torso" })

    buttonRow2(cCombat, "Refresh Friends List", function()
        loadFriendsList()
        logAction("FRIENDS", "Refreshing friends list cache...", Color3.fromRGB(90, 180, 255), "FRIENDS")
    end, "Refresh Player List", function()
        if targetDropdown then targetDropdown:Refresh() end
        logAction("COMBAT", "Player list refreshed", Color3.fromRGB(90, 180, 255), "COMBAT")
    end)

    toggle(cCombat, "Only Fire At Low Speeds", "Pauses firing when target or shooter is moving rapidly", "onlyFireAtLowSpeeds")
    slider(cCombat, "Max Firing Speed", "maxFiringSpeed", 10, 80, 5, "s/s")
    slider(cCombat, "Min Hit Chance To Fire", "minHitChance", 0, 95, 5, "%")
    UI.combatTargetLabel = statLabel(cCombat, "Current Target", "-")
    UI.combatStatusLabel = statLabel(cCombat, "Target Status", "-")
    UI.combatHitChanceLabel = statLabel(cCombat, "Hit Probability", "-")

    local cPredictor = card(TCombat, "Human Behavior Prediction Engine (WIP)")
    toggle(cPredictor, "Human Predictor Engine", "Exploits jump gravity, radial sightline, turning arcs & inertia", "humanPredictor")
    toggle(cPredictor, "Smart EV Hitbox (Head/Torso)", "Dynamically picks Head vs Torso to maximize hit rate & DPS", "smartHitboxEV")
    toggle(cPredictor, "Peak Confidence Auto-Fire", "Auto-fires at local probability peaks (jump apex, turn nodes)", "peakConfidenceFire")
    slider(cPredictor, "Peak Fire Threshold", "peakFireThreshold", 50, 95, 5, "%")
    UI.combatMotionProfileLabel = statLabel(cPredictor, "Motion Profile", "-")

    local cIHateYou = card(TCombat, "I Hate You (Torso Pursuit & Silent Spam)")
    toggle(cIHateYou, "I Hate You", "Auto-pursues behind target & spams silent aim until ragdoll", "iHateYou", function(v)
        if v then
            COMBAT.startIHateYou()
        else
            COMBAT.stopIHateYou()
        end
    end)
    slider(cIHateYou, "Target Distance", "iHateYouDistance", 20, 210, 5, "studs")
    toggle(cIHateYou, "Martini Sniper Vantage", "Positions at farthest ground vantage & waits for target to be still (>1s)", "martiniVantage")
    UI.iHateYouStatusLabel = statLabel(cIHateYou, "Pursuit Status", "Idle")
end

-- FARM TAB
do
    local cFarm = card(TFarm, "World Harvesting")
    toggle(cFarm, "Auto Farm Chests", "Horse teleports to chests and opens prompts", "autoChests", function(v)
        if v then
            logAction("FARM", "Chest farming enabled", Color3.fromRGB(180, 140, 255), "FARMING")
            loop("autoChests", 0.8, function() farmTick("Chests", "chest", false) end)
        else
            FARM.busy = false
            logAction("FARM", "Chest farming stopped", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    toggle(cFarm, "Auto Farm Herbs", "Horse teleports to wild herbs and collects", "autoHerbs", function(v)
        if v then
            logAction("FARM", "Herb farming enabled", Color3.fromRGB(180, 140, 255), "FARMING")
            loop("autoHerbs", 0.8, function() farmTick("SpawnedHerbs", "herb", false) end)
        else
            FARM.busy = false
            logAction("FARM", "Herb farming stopped", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    slider(cFarm, "Interaction Range", "promptRange", 5, 80, 1, "studs")
    button(cFarm, "Sweep Nearby Prompts Now", function()
        logAction("FARM", "Sweeping nearby prompts...", Color3.fromRGB(180, 140, 255), "FARMING")
        promptSweep("Chests", S.promptRange)
        promptSweep("SpawnedHerbs", S.promptRange, false)
    end)

    local cShop = card(TFarm, "Pad Auto-Buy")
    toggle(cShop, "Auto Buy From Pad", "Repeatedly purchases target tool from pad", "autoBuy", function(v)
        if v then
            logAction("SHOP", "Pad auto-buy started for " .. S.buyTarget, Color3.fromRGB(80, 220, 140), "SHOP")
            loop("autoBuy", 1.2, autoBuyTick)
        else
            _buyStatus = "off"
            logAction("SHOP", "Pad auto-buy stopped", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    slider(cShop, "Reserve Moola Above", "buyReserve", 0, 1000, 10, "moola")
    button(cShop, "Buy Once From Pad", autoBuyTick)
    button(cShop, "Cycle Target Pad Item", function()
        local list = padCatalog()
        if #list == 0 then
            logAction("SHOP", "No purchase pads found in workspace", Color3.fromRGB(245, 160, 60), "SHOP")
            return
        end
        local i = 1
        for k, v in ipairs(list) do if v == S.buyTarget then i = k end end
        S.buyTarget = list[(i % #list) + 1]
        logAction("SHOP", "Selected buy target: " .. S.buyTarget, Color3.fromRGB(80, 220, 140), "SHOP")
    end)
end

-- SAINT'S CORPSE TAB
do
    local cSaint = card(TSaint, "Corpse Automation")
    toggle(cSaint, "Watch For Corpse Spawns", "Listens for announcement and tracks parts", "saintWatch", function(v)
        if v then
            logAction("SAINT", "Started watching for corpse announcements", Color3.fromRGB(255, 110, 110), "SAINT")
            loop("saintWatch", 2, saintTick)
        else
            SAINT.status = "idle"
            logAction("SAINT", "Corpse watcher stopped", Color3.fromRGB(160, 165, 180), "IDLE")
        end
    end)
    toggle(cSaint, "Auto Grab (Horse TP + Hold E)", "Teleports to part and activates prompt", "saintGrab")
    toggle(cSaint, "Auto Retreat After Grab", "Teleports to safe hiding haven", "saintRetreat")
    slider(cSaint, "Active Window After Announcement", "saintWindow", 60, 900, 30, "s")
    slider(cSaint, "Pre-Hold Delay", "saintPreHoldWait", 0, 120, 5, "s")
    toggle(cSaint, "Defend Corpse With Gun", "Auto shoots nearest enemy while waiting for corpse part", "saintDefendGun")
    dropdown(cSaint, "Defend Weapon", "Weapon from inventory used for corpse defense", "saintGunSelect", function()
        local list = { "None" }
        local seen = {}
        for _, src in ipairs({ LP:FindFirstChild("Backpack"), char() }) do
            if src then
                for _, t in ipairs(src:GetChildren()) do
                    if t:IsA("Tool") then
                        local bn = baseName(t.Name)
                        if not seen[bn] then
                            seen[bn] = true
                            table.insert(list, bn)
                        end
                    end
                end
            end
        end
        return list
    end)
    dropdown(cSaint, "Post-Merge TP Player", "Auto teleports to selected player after stand merges", "saintMergeTpPlayer", function()
        local list = { "None" }
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                table.insert(list, p.Name)
            end
        end
        return list
    end)
    buttonRow2(cSaint, "Grab Nearest Corpse", function()
        SAINT.announcedAt = os.clock()
        local live = corpseCandidates()
        if #live == 0 then
            logAction("SAINT", "No grabbable corpse parts in world", Color3.fromRGB(245, 160, 60), "SAINT")
            return
        end
        grabCorpse(live[1])
    end, "Retreat Safe Now", function() retreatSafe() end)

    buttonRow2(cSaint, "Save Retreat Point", function()
        local r = root()
        if r then
            PC.saintRetreat = r.Position
            logAction("SAINT", "Custom retreat point saved at current position", Color3.fromRGB(80, 220, 140), "SAINT")
        end
    end, "Clear Retreat Point", function()
        PC.saintRetreat = nil
        logAction("SAINT", "Cleared retreat point (now dynamic safe NPC)", Color3.fromRGB(160, 165, 180), "SAINT")
    end)

    local cSaintInfo = card(TSaint, "Requirements")
    statLabel(cSaintInfo, "Stand Status:", "Standless required to merge corpse parts")
    statLabel(cSaintInfo, "Corpse Models:", "Parts spawn under <Name>_Corpse models")
end

-- VISUAL TAB
do
    local cVisual = card(TVisual, "ESP Overlays")
    toggle(cVisual, "Chest ESP", "Highlights world chests", "espChest", ensureESP)
    toggle(cVisual, "Herb ESP", "Highlights wild spawned herbs", "espHerb", ensureESP)
    toggle(cVisual, "Horse ESP", "Highlights personal & world horses", "espHorse", ensureESP)
    toggle(cVisual, "Legit Path & Obstacles", "Draws active pathfinding waypoints, lines, & jump rays", "visualizeLegit", function(v)
        if v then FISH.ensureViz() else FISH.hideViz() end
    end)
    toggle(cVisual, "Player ESP", "Displays names, health, & distance", "espPlayers", ensureESP)
    toggle(cVisual, "White Player Chams", "Highlights all players in solid white (visible through walls & rocks)", "chamsWhite", function(v)
        ensureESP()
        if COMBAT and COMBAT.updateChams then COMBAT.updateChams() end
    end)
    slider(cVisual, "ESP Max Range", "espRange", 200, 5000, 100, "studs")

    local cHudSettings = card(TVisual, "Heads-Up & AFK Display")
    toggle(cHudSettings, "Blackscreen AFK Mode", "OLED-black status screen with fish & dogbane counts", "blackscreen", function(v)
        UI.setBlackscreen(v)
    end)
    toggle(cHudSettings, "Blackscreen Opaque Background", "Solid black background vs transparent overlay", "blackscreenOpaque", function(v)
        if UI.updateBlackscreen then pcall(UI.updateBlackscreen) end
    end)
    toggle(cHudSettings, "Show Floating Mini-HUD (Bubble)", "Draggable status pill on-screen", "showHud", function(v)
        UI.hudToggleBtn.TextColor3 = v and TH.accent or TH.dim
        if UI.updateHud then UI.updateHud() end
    end)
end

-- LOGS TAB
do
    local cLogsHeader = card(TLogs, "Live Activity Feed")
    UI.logCountLabel = statLabel(cLogsHeader, "Recorded Events:", "0")
    button(cLogsHeader, "Clear Activity Log", function()
        table.clear(Status.logs)
        if UI.updateLogs then UI.updateLogs() end
    end)

    local logFeedCard = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 220),
        BackgroundColor3 = TH.card,
    }, TLogs.page)
    corner(logFeedCard, 8)
    stroke(logFeedCard, TH.border)

    local logScroll = mk("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = TH.accent,
        BorderSizePixel = 0,
    }, logFeedCard)
    mk("UIListLayout", { Padding = UDim.new(0, 4) }, logScroll)
    UI.logScroll = logScroll

    UI.updateLogs = function()
        if not UI.gui or not UI.gui.Parent then return end
        if UI.logCountLabel then
            UI.logCountLabel:Set(tostring(#Status.logs) .. " entries")
        end
        for _, ch in ipairs(logScroll:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        for _, item in ipairs(Status.logs) do
            local row = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = TH.header,
            }, logScroll)
            corner(row, 4)

            mk("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(6, 0),
                Size = UDim2.fromOffset(55, 20),
                Font = Enum.Font.Code,
                Text = item.time,
                TextColor3 = TH.dim,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            mk("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(65, 0),
                Size = UDim2.fromOffset(60, 20),
                Font = Enum.Font.GothamBold,
                Text = "[" .. item.category .. "]",
                TextColor3 = item.color or TH.accent,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            mk("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(130, 0),
                Size = UDim2.new(1, -136, 1, 0),
                Font = Enum.Font.Gotham,
                Text = item.text,
                TextColor3 = TH.text,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)
        end
    end
end

-- INFO TAB
do
    local cStandInfo = card(TInfo, "Stand & Character Progression")
    UI.infoStandPath = statLabel(cStandInfo, "Stand Path:", "Loading...")
    UI.infoStandTier = statLabel(cStandInfo, "Stand Tier:", "Loading...")
    UI.infoStandAlign = statLabel(cStandInfo, "Alignment:", "Loading...")
    UI.infoStandExp = statLabel(cStandInfo, "Stand EXP:", "Loading...")
    UI.infoCatches = statLabel(cStandInfo, "Total Catches:", "0")

    local cInfoDiag = card(TInfo, "System Diagnostics")
    statLabel(cInfoDiag, "Executor:", (identifyexecutor and select(1, identifyexecutor()) or "Unknown"))
    statLabel(cInfoDiag, "Input Handler:", IH and "Loaded OK" or "MISSING (inputs disabled)")
    statLabel(cInfoDiag, "Missing Capabilities:", #MISSING == 0 and "None (All Present)" or table.concat(MISSING, ", "))

    local cInfoUsage = card(TInfo, "Hotkeys & Controls")
    statLabel(cInfoUsage, "RightShift:", "Toggle Main Window / Exit Blackscreen")
    statLabel(cInfoUsage, "AFK Button:", "Toggle Blackscreen Monitor")
    statLabel(cInfoUsage, "Floating 'B' Button:", "Draggable UI toggle button")
    statLabel(cInfoUsage, "Floating Mini-HUD:", "Draggable live telemetry pill (Bubble)")
end

-- CONFIG TAB
do
    local cWebhook = card(TConfig, "Discord Webhook Integration")
    textInput(cWebhook, "Webhook URL", "Discord channel webhook endpoint for alerts & telemetry", "webhookUrl", "https://discord.com/api/webhooks/...")
    toggle(cWebhook, "Periodic Webhook Telemetry", "Dispatch status & inventory summary on interval", "webhookIntervalEnabled")
    slider(cWebhook, "Telemetry Interval", "webhookInterval", 1, 60, 1, "min")
    toggle(cWebhook, "Instant Dogbane Alert", "Send high-priority alert immediately when Dogbane is picked", "webhookOnDogbane")
    button(cWebhook, "Send Test Webhook Now", function()
        sendInventoryWebhook("🧪 Test Webhook Triggered")
    end)

    local cCfg = card(TConfig, "Config Persistence (Native File)")
    statLabel(cCfg, "Config File:", CONFIG_FILE)
    statLabel(cCfg, "Engine:", "Native Luau readfile/writefile (No MCP)")
    button(cCfg, "📋 Copy Current Config As getgenv()", function()
        copyConfigAsGenv()
    end)
    buttonRow2(cCfg, "💾 Save Config Now", function()
        if saveConfig() then
            logAction("CONFIG", "Configuration saved manually to " .. CONFIG_FILE, Color3.fromRGB(80, 220, 140))
        end
    end, "🔄 Reload Config", function()
        if loadConfig() then
            logAction("CONFIG", "Configuration reloaded from " .. CONFIG_FILE, Color3.fromRGB(80, 220, 140))
        end
    end)

    local cHop = card(TConfig, "Server Hop & Teleport Auto-Loader")
    local hasQueue = ((syn and syn.queue_on_teleport) or queue_on_teleport) ~= nil
    statLabel(cHop, "Queue On Teleport:", hasQueue and "Supported & Active" or "Not Supported by Executor")
    buttonRow2(cHop, "🔁 Re-Arm Auto-Loader", function()
        if primeTeleportLoader() then
            logAction("SYSTEM", "Re-armed teleport queue successfully", Color3.fromRGB(150, 160, 255))
        end
    end, "🌐 Server Hop Now", function()
        task.spawn(serverHop)
    end)
end

end

return {
    initTabs = initTabs,
}
