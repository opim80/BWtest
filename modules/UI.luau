--!nocheck
-- ============================================================
-- BRIDGER HUB (BW) - MODULE: UI
-- Design system, Component builders, Mini-HUD & Main Window
-- ============================================================
local ctx = ...
local SHARED = getfenv()
local UI = SHARED.UI or { tabs = {} }
SHARED.UI = UI


-- ── UI DESIGN SYSTEM & BUILDERS ────────────────────────────────────────────
local TH = {
    bg = Color3.fromRGB(15, 17, 23),
    header = Color3.fromRGB(19, 22, 30),
    card = Color3.fromRGB(22, 25, 34),
    cardHover = Color3.fromRGB(28, 32, 44),
    border = Color3.fromRGB(36, 41, 56),
    accent = Color3.fromRGB(230, 165, 55),
    accentHover = Color3.fromRGB(245, 180, 70),
    text = Color3.fromRGB(242, 244, 250),
    dim = Color3.fromRGB(140, 146, 165),
    darkText = Color3.fromRGB(15, 17, 23),

    green = Color3.fromRGB(68, 207, 138),
    amber = Color3.fromRGB(245, 170, 50),
    red = Color3.fromRGB(245, 90, 90),
    blue = Color3.fromRGB(80, 170, 255),
    purple = Color3.fromRGB(175, 130, 255),
}

local function mk(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function stroke(p, c, thickness)
    return mk("UIStroke", { Color = c or TH.border, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function parentGui(sg)
    pcall(function() sg.Parent = gethui and gethui() end)
    if not sg.Parent then pcall(function() sg.Parent = game:GetService("CoreGui") end) end
    if not sg.Parent then sg.Parent = LP:WaitForChild("PlayerGui") end
end

local function card(tab, title)
    local c = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = TH.card,
    }, tab.page)
    corner(c, 8)
    stroke(c, TH.border)

    mk("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, c)

    mk("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, c)

    if title then
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = title:upper(),
            TextColor3 = TH.accent,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 0,
        }, c)
    end
    return c
end

local togglesByKey = {}
local function updateAllTogglesUI()
    for key, fns in pairs(togglesByKey) do
        local val = S[key]
        for _, fn in ipairs(fns) do
            pcall(fn, val)
        end
    end
end
UI.updateAllTogglesUI = updateAllTogglesUI

function UI.setToggle(key, val)
    S[key] = val
    if togglesByKey[key] then
        for _, fn in ipairs(togglesByKey[key]) do
            pcall(fn, val)
        end
    end
end

local function toggle(parentCard, name, desc, key, onChange)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 40 or 32),
        BackgroundColor3 = TH.header,
    }, parentCard)
    corner(row, 6)
    stroke(row, TH.border)

    local textY = desc and 3 or 0
    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, textY),
        Size = UDim2.new(1, -65, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    if desc then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 20),
            Size = UDim2.new(1, -65, 0, 14),
            Font = Enum.Font.Gotham,
            Text = desc,
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
    end

    local pill = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(36, 18),
        BackgroundColor3 = S[key] and TH.accent or Color3.fromRGB(48, 52, 66),
    }, row)
    corner(pill, 9)

    local knob = mk("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = S[key] and UDim2.new(0, 19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = S[key] and TH.darkText or TH.text,
    }, pill)
    corner(knob, 7)

    local function setVisual(val)
        TS:Create(pill, TweenInfo.new(0.14), {
            BackgroundColor3 = val and TH.accent or Color3.fromRGB(48, 52, 66)
        }):Play()
        TS:Create(knob, TweenInfo.new(0.14), {
            Position = val and UDim2.new(0, 19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = val and TH.darkText or TH.text,
        }):Play()
    end
    togglesByKey[key] = togglesByKey[key] or {}
    table.insert(togglesByKey[key], setVisual)

    local b = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, row)
    track(b.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        setVisual(S[key])
        if onChange then task.spawn(onChange, S[key]) end
    end))
end

local function slider(parentCard, name, key, min, max, step, suffix)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = TH.header,
    }, parentCard)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(0.65, 0, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local valPill = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 4),
        Size = UDim2.fromOffset(50, 16),
        BackgroundColor3 = TH.card,
    }, row)
    corner(valPill, 4)
    stroke(valPill, TH.border)

    local valLabel = mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        Text = tostring(S[key]),
        TextColor3 = TH.accent,
        TextSize = 10,
    }, valPill)

    local bar = mk("Frame", {
        Position = UDim2.fromOffset(10, 28),
        Size = UDim2.new(1, -20, 0, 6),
        BackgroundColor3 = Color3.fromRGB(40, 45, 58),
    }, row)
    corner(bar, 3)

    local fill = mk("Frame", {
        Size = UDim2.fromScale(math.clamp((S[key] - min) / (max - min), 0, 1), 1),
        BackgroundColor3 = TH.accent,
    }, bar)
    corner(fill, 3)

    local function render()
        local pct = math.clamp((S[key] - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(pct, 1)
        valLabel.Text = tostring(S[key]) .. (suffix and (" " .. suffix) or "")
    end
    render()

    local dragging = false
    local function set(i)
        local a = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        S[key] = math.floor((min + (max - min) * a) / step + 0.5) * step
        render()
    end
    track(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; set(i)
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then set(i) end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

local function button(parentCard, name, fn)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = TH.header,
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        AutoButtonColor = false,
    }, parentCard)
    corner(b, 6)
    stroke(b, TH.border)

    track(b.MouseEnter:Connect(function()
        b.BackgroundColor3 = TH.cardHover
        b.TextColor3 = TH.accent
    end))
    track(b.MouseLeave:Connect(function()
        b.BackgroundColor3 = TH.header
        b.TextColor3 = TH.text
    end))
    track(b.MouseButton1Click:Connect(function() task.spawn(function() pcall(fn) end) end))
    return b
end

local function statLabel(parentCard, titleText, initialVal)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, parentCard)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.4, 0, 1, 0),
        Font = Enum.Font.Gotham,
        Text = titleText,
        TextColor3 = TH.dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local v = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.4, 0, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = initialVal or "-",
        TextColor3 = TH.text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local o = {}
    function o:Set(txt) v.Text = txt end
    function o:Get() return v.Text end
    return o
end

local function keybind(parentCard, name, desc, key, defaultKey)
    if not S[key] then S[key] = defaultKey or "H" end
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 44 or 34),
        BackgroundColor3 = TH.header,
    }, parentCard)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -110, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    if desc then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 20),
            Size = UDim2.new(1, -110, 0, 14),
            Font = Enum.Font.Gotham,
            Text = desc,
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local btn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(75, 22),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = "[" .. tostring(S[key] or "None") .. "]",
        TextColor3 = TH.accent,
        TextSize = 11,
    }, row)
    corner(btn, 4)
    stroke(btn, TH.border)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        S._rebinding = true
        btn.Text = "[...]"
        btn.TextColor3 = Color3.fromRGB(255, 200, 80)
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local kName = input.KeyCode.Name
                if kName ~= "Unknown" then
                    conn:Disconnect()
                    if kName == "Backspace" or kName == "Escape" then
                        S[key] = "None"
                    else
                        S[key] = kName
                    end
                    btn.Text = "[" .. tostring(S[key]) .. "]"
                    btn.TextColor3 = TH.accent
                    pcall(saveConfig)
                    listening = false
                    task.delay(0.2, function()
                        S._rebinding = false
                    end)
                end
            end
        end)
    end)
end

local function textInput(parentCard, name, desc, key, placeholder, onDone)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 56 or 44),
        BackgroundColor3 = TH.header,
    }, parentCard)
    corner(row, 6)
    stroke(row, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -20, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    if desc then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 19),
            Size = UDim2.new(1, -20, 0, 14),
            Font = Enum.Font.Gotham,
            Text = desc,
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local tbBox = mk("Frame", {
        Position = UDim2.new(0, 10, 0, desc and 34 or 22),
        Size = UDim2.new(1, -20, 0, 18),
        BackgroundColor3 = TH.card,
    }, row)
    corner(tbBox, 4)
    stroke(tbBox, TH.border)

    local tb = mk("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.new(1, -12, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = S[key] or "",
        PlaceholderText = placeholder or "Paste URL here...",
        PlaceholderColor3 = TH.dim,
        TextColor3 = TH.accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, tbBox)

    local function apply()
        S[key] = tb.Text
        if onDone then task.spawn(onDone, tb.Text) end
    end

    track(tb.FocusLost:Connect(function()
        apply()
    end))

    local o = {}
    function o:Set(txt)
        tb.Text = txt
        S[key] = txt
    end
    function o:Get()
        return tb.Text
    end
    return o
end

local function dropdown(parentCard, name, desc, key, getOptionsFn, onChange)
    if not S[key] then S[key] = "Closest" end
    local isOpen = false

    local function getDisplayLabel()
        if key == "activeFishingSet" then
            return tostring(S.activeFishingSet or "Default")
        elseif key == "selectedSpotSlot" then
            local cur = (FISH and FISH.getSelectedSlotIdx and FISH.getSelectedSlotIdx()) or tonumber(tostring(S.selectedSpotSlot):match("(%d+)")) or 1
            return string.format("Spot Slot %d", cur)
        end
        return tostring(S[key] or "Closest")
    end

    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 44 or 34),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = TH.header,
        ClipsDescendants = true,
    }, parentCard)
    corner(row, 6)
    stroke(row, TH.border)

    local header = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, desc and 44 or 34),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, desc and 4 or 8),
        Size = UDim2.new(0.55, -10, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)

    if desc then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 22),
            Size = UDim2.new(0.55, -10, 0, 14),
            Font = Enum.Font.Gotham,
            Text = desc,
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, header)
    end

    local selLabel = mk("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0.42, 0, 0, 22),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = getDisplayLabel() .. " v",
        TextColor3 = TH.accent,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)
    corner(selLabel, 4)
    stroke(selLabel, TH.border)

    local listFrame = mk("Frame", {
        Position = UDim2.new(0, 8, 0, (desc and 44 or 34) + 4),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, row)

    mk("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, listFrame)

    local function refreshList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local options = typeof(getOptionsFn) == "function" and getOptionsFn() or (getOptionsFn or {"Closest"})
        local currentDisplay = getDisplayLabel()
        for idx, opt in ipairs(options) do
            local isSelected = (opt == currentDisplay) or (S[key] == opt)
            local optBtn = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = isSelected and TH.cardHover or TH.card,
                Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham,
                Text = opt,
                TextColor3 = isSelected and TH.accent or TH.text,
                TextSize = 11,
                AutoButtonColor = false,
                LayoutOrder = idx,
            }, listFrame)
            corner(optBtn, 4)
            stroke(optBtn, TH.border)

            track(optBtn.MouseButton1Click:Connect(function()
                if key == "selectedSpotSlot" then
                    local n = tonumber(tostring(opt):match("(%d+)")) or 1
                    S.selectedSpotSlot = n
                else
                    S[key] = opt
                end
                selLabel.Text = getDisplayLabel() .. " v"
                pcall(saveConfig)
                isOpen = false
                listFrame.Visible = false
                if onChange then pcall(onChange, opt) end
            end))
        end
    end

    track(header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            refreshList()
            listFrame.Visible = true
            selLabel.Text = getDisplayLabel() .. " ^"
        else
            listFrame.Visible = false
            selLabel.Text = getDisplayLabel() .. " v"
        end
    end))

    local obj = {}
    function obj:Set(val)
        if key == "selectedSpotSlot" then
            local n = tonumber(tostring(val):match("(%d+)")) or 1
            S.selectedSpotSlot = n
        else
            S[key] = val
        end
        selLabel.Text = getDisplayLabel() .. " v"
    end
    function obj:Refresh()
        selLabel.Text = getDisplayLabel() .. (isOpen and " ^" or " v")
        if isOpen then refreshList() end
    end
    return obj
end


-- ── INITIALIZE MINI-HUD (The Bubble) ───────────────────────────────────────
local function initMiniHud()
    local hudGui = mk("ScreenGui", { Name = "Bridger_MiniHUD", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(hudGui)
    UI.hudGui = hudGui

    local hudPill = mk("Frame", {
        Position = UDim2.new(0.5, -240, 0, 10),
        Size = UDim2.fromOffset(480, 36),
        BackgroundColor3 = TH.bg,
        Active = true,
        Draggable = true,
        Visible = S.showHud and not S.blackscreen,
    }, hudGui)
    corner(hudPill, 18)
    stroke(hudPill, TH.border)
    UI.hudPill = hudPill

    local hudDot = mk("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = TH.accent,
    }, hudPill)
    corner(hudDot, 6)
    UI.hudDot = hudDot

    local hudStateBadge = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.fromOffset(72, 36),
        Font = Enum.Font.GothamBold,
        Text = "[IDLE]",
        TextColor3 = TH.accent,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, hudPill)
    UI.hudStateBadge = hudStateBadge

    local hudText = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(106, 0),
        Size = UDim2.new(1, -116, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = "Ready to start",
        TextColor3 = TH.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, hudPill)
    UI.hudText = hudText

    UI.updateHud = function()
        if not hudGui.Parent then return end
        hudPill.Visible = S.showHud and not S.blackscreen
        hudDot.BackgroundColor3 = Status.color
        hudStateBadge.Text = "[" .. Status.state .. "]"
        hudStateBadge.TextColor3 = Status.color

        local line = Status.action
        if Status.detail and Status.detail ~= "" then
            line = line .. "  •  " .. Status.detail
        end
        hudText.Text = line
    end
end
initMiniHud()

-- ── INITIALIZE BLACKSCREEN DASHBOARD ───────────────────────────────────────
local function initBlackscreenDashboard()
    local bsGui = mk("ScreenGui", { Name = "Bridger_Blackscreen", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(bsGui)
    UI.bsGui = bsGui

    local bsFrame = mk("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(10, 12, 16),
        BackgroundTransparency = (S.blackscreenOpaque == false) and 1 or 0,
        BorderSizePixel = 0,
        Visible = S.blackscreen,
        Active = (S.blackscreenOpaque ~= false),
    }, bsGui)
    UI.bsFrame = bsFrame

    local bsCenterCard = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(540, 420),
        BackgroundColor3 = TH.card,
    }, bsFrame)
    corner(bsCenterCard, 12)
    stroke(bsCenterCard, TH.border)

    local bsHeader = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsHeader, 12)
    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = TH.header,
        BorderSizePixel = 0,
    }, bsHeader)

    local bsLogoBadge = mk("Frame", {
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = TH.accent,
    }, bsHeader)
    corner(bsLogoBadge, 6)
    mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        Text = "B",
        TextColor3 = TH.darkText,
        TextSize = 14,
    }, bsLogoBadge)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(44, 0),
        Size = UDim2.fromOffset(180, 42),
        Font = Enum.Font.GothamBold,
        Text = "BRIDGER  •  AFK MONITOR",
        TextColor3 = TH.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsHeader)

    local bsOpaqueBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -125, 0.5, 0),
        Size = UDim2.fromOffset(80, 26),
        BackgroundColor3 = TH.cardHover,
        Font = Enum.Font.GothamMedium,
        Text = (S.blackscreenOpaque ~= false) and "Opaque: ON" or "Opaque: OFF",
        TextColor3 = (S.blackscreenOpaque ~= false) and TH.accent or TH.dim,
        TextSize = 11,
        AutoButtonColor = false,
    }, bsHeader)
    corner(bsOpaqueBtn, 6)
    stroke(bsOpaqueBtn, TH.border)
    bsOpaqueBtn.MouseButton1Click:Connect(function()
        S.blackscreenOpaque = not S.blackscreenOpaque
        bsOpaqueBtn.Text = S.blackscreenOpaque and "Opaque: ON" or "Opaque: OFF"
        bsOpaqueBtn.TextColor3 = S.blackscreenOpaque and TH.accent or TH.dim
        if UI.updateBlackscreen then UI.updateBlackscreen() end
    end)

    local bsExitBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(110, 26),
        BackgroundColor3 = TH.cardHover,
        Font = Enum.Font.GothamMedium,
        Text = "Exit Blackscreen",
        TextColor3 = TH.accent,
        TextSize = 11,
        AutoButtonColor = false,
    }, bsHeader)
    corner(bsExitBtn, 6)
    stroke(bsExitBtn, TH.border)

    -- Blackscreen Status Display
    local bsStatusBox = mk("Frame", {
        Position = UDim2.fromOffset(14, 50),
        Size = UDim2.new(1, -28, 0, 50),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsStatusBox, 8)
    stroke(bsStatusBox, TH.border)

    local bsDot = mk("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = TH.accent,
    }, bsStatusBox)
    corner(bsDot, 5)
    UI.bsDot = bsDot

    local bsStateBadge = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 6),
        Size = UDim2.fromOffset(70, 18),
        Font = Enum.Font.GothamBold,
        Text = "[IDLE]",
        TextColor3 = TH.accent,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsStatusBox)
    UI.bsStateBadge = bsStateBadge

    local bsActionText = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(102, 6),
        Size = UDim2.new(1, -112, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = "Ready to start",
        TextColor3 = TH.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, bsStatusBox)
    UI.bsActionText = bsActionText

    local bsDetailText = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 26),
        Size = UDim2.new(1, -38, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "All systems operational",
        TextColor3 = TH.dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, bsStatusBox)
    UI.bsDetailText = bsDetailText

    -- Row 1: Moola & Dogbane Herbs
    local bsMoolaCard = mk("Frame", {
        Position = UDim2.fromOffset(14, 108),
        Size = UDim2.new(0.5, -20, 0, 66),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsMoolaCard, 8)
    stroke(bsMoolaCard, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = "TOTAL MOOLA",
        TextColor3 = TH.dim,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsMoolaCard)

    local bsMoolaVal = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 36),
        Font = Enum.Font.GothamBold,
        Text = "$0",
        TextColor3 = TH.green,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsMoolaCard)
    UI.bsMoolaVal = bsMoolaVal

    local bsDogbaneCard = mk("Frame", {
        Position = UDim2.new(0.5, 6, 0, 108),
        Size = UDim2.new(0.5, -20, 0, 66),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsDogbaneCard, 8)
    stroke(bsDogbaneCard, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = "DOGBANE HERBS",
        TextColor3 = TH.dim,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsDogbaneCard)

    local bsDogbaneVal = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 36),
        Font = Enum.Font.GothamBold,
        Text = "0",
        TextColor3 = TH.purple,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsDogbaneCard)
    UI.bsDogbaneVal = bsDogbaneVal

    -- Row 2: Dedicated Stand & Progression Card (Prominent & High-Visibility)
    local bsStandCard = mk("Frame", {
        Position = UDim2.fromOffset(14, 182),
        Size = UDim2.new(1, -28, 0, 72),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsStandCard, 8)
    stroke(bsStandCard, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = "STAND & PROGRESSION",
        TextColor3 = TH.accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsStandCard)

    local bsStandPathVal = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 24),
        Size = UDim2.new(1, -24, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = "⚔️ Stand: Loading...",
        TextColor3 = TH.text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsStandCard)
    UI.bsStandPathVal = bsStandPathVal

    local bsStandMetaVal = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 47),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = "Alignment: -  •  EXP: -  •  Catches: 0",
        TextColor3 = TH.dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsStandCard)
    UI.bsStandMetaVal = bsStandMetaVal

    -- Row 3: Fish Breakdown Card
    local bsFishCard = mk("Frame", {
        Position = UDim2.fromOffset(14, 262),
        Size = UDim2.new(1, -28, 0, 96),
        BackgroundColor3 = TH.header,
    }, bsCenterCard)
    corner(bsFishCard, 8)
    stroke(bsFishCard, TH.border)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = "FISH INVENTORY BREAKDOWN",
        TextColor3 = TH.accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsFishCard)

    local bsFishRow = mk("Frame", {
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundTransparency = 1,
    }, bsFishCard)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, bsFishRow)

    local function makeFishPill(label, col)
        local p = mk("Frame", {
            Size = UDim2.fromOffset(95, 34),
            BackgroundColor3 = TH.card,
        }, bsFishRow)
        corner(p, 6)
        stroke(p, TH.border)

        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 2),
            Size = UDim2.new(1, -16, 0, 14),
            Font = Enum.Font.Gotham,
            Text = label,
            TextColor3 = TH.dim,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, p)

        local v = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 16),
            Size = UDim2.new(1, -16, 0, 16),
            Font = Enum.Font.GothamBold,
            Text = "0",
            TextColor3 = col or TH.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, p)
        return v
    end

    UI.bsBassVal = makeFishPill("Bass", TH.text)
    UI.bsSnapperVal = makeFishPill("Snapper", TH.text)
    UI.bsCodVal = makeFishPill("Cod", TH.text)
    UI.bsTotalFishVal = makeFishPill("Total Fish", TH.accent)

    local bsFishMeta = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 70),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = "Catches: 0  •  Bait: 0  •  Auto-Sell on Empty: Enabled",
        TextColor3 = TH.dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bsFishCard)
    UI.bsFishMeta = bsFishMeta

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 368),
        Size = UDim2.new(1, -28, 0, 24),
        Font = Enum.Font.Gotham,
        Text = "Press RightShift or click 'Exit Blackscreen' to return to normal game view",
        TextColor3 = TH.dim,
        TextSize = 11,
    }, bsCenterCard)

    UI.updateBlackscreen = function()
        if not bsGui.Parent then return end
        bsFrame.Visible = S.blackscreen
        bsFrame.BackgroundTransparency = (S.blackscreenOpaque == false) and 1 or 0
        bsFrame.Active = (S.blackscreenOpaque ~= false)
        if not S.blackscreen then return end

        bsDot.BackgroundColor3 = Status.color
        bsStateBadge.Text = "[" .. Status.state .. "]"
        bsStateBadge.TextColor3 = Status.color
        bsActionText.Text = Status.action
        bsDetailText.Text = Status.detail

        local curM = moola()
        local dogbane = countDogbane()
        local fCounts, fTotal = getFishCounts()
        local cBait = countTool("Bait")

        bsMoolaVal.Text = "$" .. tostring(curM)
        bsDogbaneVal.Text = tostring(dogbane)
        UI.bsBassVal.Text = tostring(fCounts.Bass or 0)
        UI.bsSnapperVal.Text = tostring(fCounts.Snapper or 0)
        UI.bsCodVal.Text = tostring(fCounts.Cod or 0)
        UI.bsTotalFishVal.Text = tostring(fTotal)

        local myStand, myTier, myAlign, myExp = getStandInfo()
        if UI.bsStandPathVal then
            UI.bsStandPathVal.Text = ("⚔️ %s   •   Tier %s"):format(myStand, myTier)
        end
        if UI.bsStandMetaVal then
            UI.bsStandMetaVal.Text = ("Alignment: %s   •   EXP: %s   •   Catches: %d"):format(
                myAlign, myExp, FISH.catches)
        end
        if UI.bsFishMeta then
            UI.bsFishMeta.Text = ("Bait Remaining: %d  •  Auto-Sell on Empty: Enabled"):format(cBait)
        end
    end

    UI.setBlackscreen = function(on)
        S.blackscreen = on
        bsFrame.Visible = on
        if UI.main then UI.main.Visible = not on end
        if UI.fab then UI.fab.Visible = not on end
        if UI.updateHud then UI.updateHud() end
        if UI.afkQuickBtn then
            UI.afkQuickBtn.TextColor3 = on and TH.accent or TH.dim
        end
        if on then
            UI.updateBlackscreen()
        end
    end

    track(bsExitBtn.MouseButton1Click:Connect(function()
        UI.setBlackscreen(false)
    end))
end
initBlackscreenDashboard()

-- ── MAIN APPLICATION WINDOW ────────────────────────────────────────────────
local function initMainWindow()
    local gui = mk("ScreenGui", { Name = "Bridger_Hub", ResetOnSpawn = false, IgnoreGuiInset = true })
    parentGui(gui)
    UI.gui = gui

    local vp = WS.CurrentCamera and WS.CurrentCamera.ViewportSize or Vector2.new(1000, 700)
    local W, H = math.min(580, vp.X - 30), math.min(460, vp.Y - 60)
    local main = mk("Frame", {
        Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BackgroundColor3 = TH.bg,
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
    }, gui)
    corner(main, 12)
    stroke(main, TH.border)
    UI.main = main

    -- Top Header
    local header = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = TH.header,
        BorderSizePixel = 0,
    }, main)
    corner(header, 12)
    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = TH.header,
        BorderSizePixel = 0,
    }, header)

    local logoBadge = mk("Frame", {
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = TH.accent,
    }, header)
    corner(logoBadge, 6)
    mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        Text = "B",
        TextColor3 = TH.darkText,
        TextSize = 14,
    }, logoBadge)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(42, 0),
        Size = UDim2.fromOffset(65, 42),
        Font = Enum.Font.GothamBold,
        Text = "BRIDGER",
        TextColor3 = TH.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(110, 0),
        Size = UDim2.fromOffset(45, 42),
        Font = Enum.Font.Gotham,
        Text = VERSION,
        TextColor3 = TH.accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    -- Quick Stats Pill in Header
    local quickStatsPill = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -145, 0.5, 0),
        Size = UDim2.fromOffset(180, 24),
        BackgroundColor3 = TH.card,
    }, header)
    corner(quickStatsPill, 6)
    stroke(quickStatsPill, TH.border)

    local quickStatsLabel = mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamMedium,
        Text = "$0  •  0 Bait  •  0 Caught",
        TextColor3 = TH.dim,
        TextSize = 11,
    }, quickStatsPill)
    UI.quickStatsLabel = quickStatsLabel

    local afkQuickBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -98, 0.5, 0),
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = "AFK",
        TextColor3 = S.blackscreen and TH.accent or TH.dim,
        TextSize = 10,
        AutoButtonColor = false,
    }, header)
    corner(afkQuickBtn, 6)
    stroke(afkQuickBtn, TH.border)
    UI.afkQuickBtn = afkQuickBtn

    local hudToggleBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -66, 0.5, 0),
        Size = UDim2.fromOffset(28, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamMedium,
        Text = "HUD",
        TextColor3 = S.showHud and TH.accent or TH.dim,
        TextSize = 10,
        AutoButtonColor = false,
    }, header)
    corner(hudToggleBtn, 6)
    stroke(hudToggleBtn, TH.border)
    UI.hudToggleBtn = hudToggleBtn

    local isMinimized = false
    local minBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -36, 0.5, 0),
        Size = UDim2.fromOffset(26, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = "-",
        TextColor3 = TH.dim,
        TextSize = 14,
        AutoButtonColor = false,
    }, header)
    corner(minBtn, 6)
    stroke(minBtn, TH.border)

    local closeBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = TH.card,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = TH.dim,
        TextSize = 16,
        AutoButtonColor = false,
    }, header)
    corner(closeBtn, 6)
    stroke(closeBtn, TH.border)
    UI.closeBtn = closeBtn

    -- Content Container for clean minimizing
    local contentContainer = mk("Frame", {
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        BackgroundTransparency = 1,
    }, main)

    track(minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        contentContainer.Visible = not isMinimized
        if isMinimized then
            main.Size = UDim2.fromOffset(W, 42)
            minBtn.Text = "+"
        else
            main.Size = UDim2.fromOffset(W, H)
            minBtn.Text = "-"
        end
    end))

    track(afkQuickBtn.MouseButton1Click:Connect(function()
        UI.setBlackscreen(not S.blackscreen)
    end))

    -- Persistent Live Status Banner (Height 54px, High-Visibility Stand Card)
    local statusBanner = mk("Frame", {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 54),
        BackgroundColor3 = TH.card,
    }, contentContainer)
    corner(statusBanner, 8)
    stroke(statusBanner, TH.border)

    local bannerDot = mk("Frame", {
        Position = UDim2.fromOffset(12, 14),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = TH.accent,
    }, statusBanner)
    corner(bannerDot, 5)
    UI.bannerDot = bannerDot

    local bannerState = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 9),
        Size = UDim2.fromOffset(70, 18),
        Font = Enum.Font.GothamBold,
        Text = "[IDLE]",
        TextColor3 = TH.accent,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, statusBanner)
    UI.bannerState = bannerState

    local bannerAction = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(102, 9),
        Size = UDim2.new(1, -415, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = "Ready to start",
        TextColor3 = TH.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, statusBanner)
    UI.bannerAction = bannerAction

    local bannerDetail = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 30),
        Size = UDim2.new(1, -345, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = "All systems operational",
        TextColor3 = TH.dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, statusBanner)
    UI.bannerDetail = bannerDetail

    local logsJumpBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(58, 38),
        BackgroundColor3 = TH.cardHover,
        Font = Enum.Font.GothamMedium,
        Text = "Logs →",
        TextColor3 = TH.accent,
        TextSize = 12,
        AutoButtonColor = false,
    }, statusBanner)
    corner(logsJumpBtn, 6)
    stroke(logsJumpBtn, TH.border)
    UI.logsJumpBtn = logsJumpBtn

    -- Stand & Character Badge (2-line high-contrast card)
    local bannerStandCard = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -72, 0.5, 0),
        Size = UDim2.fromOffset(250, 42),
        BackgroundColor3 = TH.header,
    }, statusBanner)
    corner(bannerStandCard, 6)
    stroke(bannerStandCard, TH.border)
    UI.bannerStandCard = bannerStandCard

    local bannerStandPath = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 4),
        Size = UDim2.new(1, -16, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = "⚔️ Stand: Loading...",
        TextColor3 = TH.accent,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, bannerStandCard)
    UI.bannerStandPath = bannerStandPath

    local bannerStandDetail = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 22),
        Size = UDim2.new(1, -16, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = "Tier -  •  Alignment -",
        TextColor3 = TH.dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, bannerStandCard)
    UI.bannerStandDetail = bannerStandDetail

    UI.updateBanner = function()
        if not gui.Parent then return end
        bannerDot.BackgroundColor3 = Status.color
        bannerState.Text = "[" .. Status.state .. "]"
        bannerState.TextColor3 = Status.color
        bannerAction.Text = Status.action
        bannerDetail.Text = Status.detail
        if UI.bannerStandPath and UI.bannerStandDetail then
            local myStand, myTier, myAlign, myExp = getStandInfo()
            UI.bannerStandPath.Text = ("⚔️ %s  [Tier %s]"):format(myStand, myTier)
            UI.bannerStandDetail.Text = ("%s  •  EXP: %s"):format(myAlign, myExp)
        end
    end

    -- Tab Navigation
    local tabBar = mk("Frame", {
        Position = UDim2.fromOffset(12, 66),
        Size = UDim2.new(1, -24, 0, 28),
        BackgroundTransparency = 1,
    }, contentContainer)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 5),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, tabBar)

    local body = mk("Frame", {
        Position = UDim2.fromOffset(0, 98),
        Size = UDim2.new(1, 0, 1, -98),
        BackgroundTransparency = 1,
    }, contentContainer)

    local function selectTab(target)
        for _, t in ipairs(UI.tabs) do
            local active = (t == target)
            t.page.Visible = active
            t.btn.BackgroundColor3 = active and TH.accent or TH.card
            t.btn.TextColor3 = active and TH.darkText or TH.dim
        end
        if UI and UI.refreshSpotsUI then pcall(UI.refreshSpotsUI) end
    end
    UI.selectTab = selectTab

    local function addTab(name)
        local btn = mk("TextButton", {
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = TH.card,
            Font = Enum.Font.GothamMedium,
            Text = "   " .. name .. "   ",
            TextColor3 = TH.dim,
            TextSize = 12,
            AutoButtonColor = false,
        }, tabBar)
        corner(btn, 6)
        stroke(btn, TH.border)

        local page = mk("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = TH.accent,
            BorderSizePixel = 0,
        }, body)
        mk("UIListLayout", { Padding = UDim.new(0, 8) }, page)
        mk("UIPadding", {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 16),
        }, page)

        local t = { name = name, btn = btn, page = page }
        track(btn.MouseButton1Click:Connect(function() selectTab(t) end))
        UI.tabs[#UI.tabs + 1] = t
        if #UI.tabs == 1 then selectTab(t) end
        return t
    end
    UI.addTab = addTab
end
initMainWindow()


UI.TH = TH
UI.mk = mk
UI.corner = corner
UI.stroke = stroke
UI.parentGui = parentGui
UI.card = card
UI.toggle = toggle
UI.slider = slider
UI.button = button
UI.statLabel = statLabel
UI.keybind = keybind
UI.textInput = textInput
UI.dropdown = dropdown
UI.togglesByKey = togglesByKey
UI.updateAllTogglesUI = updateAllTogglesUI

return UI
