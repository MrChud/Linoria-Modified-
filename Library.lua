--[[    ModernUI Library — old/plain cheat-menu skin (polish pass)


    Changelog vs previous version:
    1. More visible borders everywhere (brighter border color + outlined
       columns/tabs), so it doesn't read as "bland".
    2. Keybind fix: AddMenuKeybind() actually rewires the real menu
       show/hide key. (Plain AddKeybind() is still just a bindable key
       for your own features and intentionally does NOT touch the menu key
       unless you use AddMenuKeybind.)
    3. Color pickers are now a separate floating popup window (hue strip +
       saturation/value square), not an inline dropdown — click a swatch,
       a small window pops out, drag it around independently.
    4. Duplication fix: the ScreenGui now has a fixed name and destroys any
       previous instance of itself in PlayerGui before creating a new one,
       so re-running the script (or anything re-calling CreateWindow) can't
       stack multiple menus. Combined with the earlier drag-connection fix.
    5. Tabs now have a real 1px border box around them instead of just
       looking like floating text.
    6. Every element (checkbox/slider/combo/keybind/button/label/color
       picker) takes an optional trailing `risky` boolean — pass true and
       its label renders in red. Toggle it per-element, nothing global.
    7/8. General spacing/contrast polish + a native UIShadow under the
       window, tinted to match the current accent color and updated live
       if you call Window:SetAccentColor().
    9. Window is now resizable via a grip in the bottom-right corner
       (min size 300x220), on top of the title-bar drag.
    10. Dropdowns (AddCombo) restyled to match the rest of the menu:
        bordered box, hover/open states, accent border while open,
        accent selection bar + highlighted row on the selected option.
    11. SV cursor in the color popup is a small circle with a soft white
        glow halo.
    12. Columns are scrolling frames — when the window is resized too
        small, content is clipped instead of sticking out below the
        menu, and you can scroll down to reach the rest.
    13. Checkbox fills completely with the accent color when toggled on.

    USAGE:
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("menu")
        local Tab = Window:CreateTab("Main")
        local Box = Tab:CreateBox("General")
        Box:AddCheckbox("Enabled", false, function(v) print(v) end)
        Box:AddCheckbox("Bunnyhop", false, function(v) print(v) end, true) -- risky = red label
]]


local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")


local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")


local GUI_NAME = "ModernUI_CheatMenu" -- fixed name so we can detect/kill old instances


--// Theme
local Theme = {
    Background = Color3.fromRGB(22, 22, 22),
    Panel      = Color3.fromRGB(28, 28, 28),
    Header     = Color3.fromRGB(34, 34, 34),
    Track      = Color3.fromRGB(18, 18, 18),
    Text       = Color3.fromRGB(215, 215, 215),
    SubText    = Color3.fromRGB(135, 135, 135),
    Border     = Color3.fromRGB(72, 72, 72),   -- brighter than before, more visible outlines
    Risky      = Color3.fromRGB(225, 60, 60),
    Accent     = Color3.fromRGB(60, 130, 220),
}


local FONT = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold


--// Helpers
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end


local function panel(props)
    props = props or {}
    props.BorderSizePixel = 1
    props.BorderColor3 = props.BorderColor3 or Theme.Border
    props.BackgroundColor3 = props.BackgroundColor3 or Theme.Panel
    return new("Frame", props)
end


local function pad(parent, x, y)
    y = y or x
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x),
        PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y),
        Parent = parent,
    })
end


local function labelColor(risky)
    return risky and Theme.Risky or Theme.Text
end


local function hoverFlash(btn, onColor, offColor, propName)
    propName = propName or "TextColor3"
    btn.MouseEnter:Connect(function() btn[propName] = onColor end)
    btn.MouseLeave:Connect(function() btn[propName] = offColor end)
end


-- robust single-connection dragging (fixes the duplication-while-dragging bug)
local function makeDraggable(handle, target)
    local dragging = false
    local dragStart, startPos
    local moveConn, endConn


    local function stopDrag()
        dragging = false
        if moveConn then moveConn:Disconnect() moveConn = nil end
        if endConn then endConn:Disconnect() endConn = nil end
    end


    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        stopDrag()
        dragging = true
        dragStart = input.Position
        startPos = target.Position


        moveConn = UserInputService.InputChanged:Connect(function(moveInput)
            if not dragging then return end
            if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = moveInput.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end)


        endConn = UserInputService.InputEnded:Connect(function(endInput)
            if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                stopDrag()
            end
        end)
    end)
end


-- flat hue strip. initialHue 0-1. onHueChange(hue) fires while dragging.
-- returns {SetHue = function(h) ... end} so callers can sync it externally.
local function buildHueSlider(parent, initialHue, onHueChange)
    local Track = panel({ Size = UDim2.new(1, 0, 0, 10), Parent = parent, BackgroundColor3 = Theme.Track })
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(1/6, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(2/6, 1, 1)),
            ColorSequenceKeypoint.new(0.50, Color3.fromHSV(3/6, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(4/6, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(5/6, 1, 1)),
            ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1, 1, 1)),
        }),
        Parent = Track,
    })
    local Handle = new("Frame", {
        Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(initialHue or 0, -1, 0, -2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = Track,
    })
    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Handle.Position = UDim2.new(rel, -1, 0, -2)
        onHueChange(rel)
    end
    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return {
        SetHue = function(h) Handle.Position = UDim2.new(h, -1, 0, -2) end,
    }
end


--// Library
local Library = {}
Library.__index = Library


function Library:CreateWindow(title, opts)
    opts = opts or {}
    if opts.AccentColor then Theme.Accent = opts.AccentColor end


    -- duplication fix: kill any previous menu of ours before making a new one
    local existing = PlayerGui:FindFirstChild(GUI_NAME)
    if existing then existing:Destroy() end


    local AccentListeners = {}
    local function onAccent(fn)
        table.insert(AccentListeners, fn)
        fn(Theme.Accent)
    end


    local ScreenGui = new("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })


    -- taller than wide, like the reference menus
    local WINDOW_W, WINDOW_H = 460, 620


    local Main = panel({
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        Parent = ScreenGui,
    })


    -- native UIShadow, tinted to the accent color, kept in sync live
    local Shadow = new("UIShadow", {
        Color = Theme.Accent,
        Transparency = 0.55,
        BlurRadius = UDim.new(0, 12),
        Offset = UDim2.new(0, 0, 0, 4),
        Spread = UDim2.new(0, 0, 0, 0),
        Parent = Main,
    })
    onAccent(function(c) Shadow.Color = c end)


    local TitleBar = panel({
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundColor3 = Theme.Header,
        Parent = Main,
    })
    new("TextLabel", {
        Text = title or "menu", Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0, 200, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar,
    })
    local CloseBtn = new("TextButton", {
        Text = "X", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Size = UDim2.new(0, 22, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        Parent = TitleBar,
    })
    hoverFlash(CloseBtn, Color3.fromRGB(210, 80, 80), Theme.SubText)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
    makeDraggable(TitleBar, Main)


    -- === resize grip (bottom-right), item 9 ===
    local ResizeGrip = panel({
        Name = "ResizeGrip",
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(1, -14, 1, -14),
        BackgroundColor3 = Theme.Header,
        BorderColor3 = Theme.Border,
        ZIndex = 10, Parent = Main,
    })
    -- little diagonal grip dots so it reads as "grabbable"
    local function gripDot(x, y)
        return new("Frame", {
            Size = UDim2.new(0, 2, 0, 2), Position = UDim2.new(0, x, 0, y),
            BackgroundColor3 = Theme.SubText, BorderSizePixel = 0, ZIndex = 11, Parent = ResizeGrip,
        })
    end
    gripDot(3, 9)
    gripDot(6, 6)
    gripDot(9, 3)

    local ResizeGripClick = new("TextButton", {
        Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 12, Parent = ResizeGrip,
    })

    local MIN_W, MIN_H = 300, 220
    local resizing = false
    local resizeStart, startSize
    local resizeMove, resizeEnd
    local function stopResize()
        resizing = false
        if resizeMove then resizeMove:Disconnect() resizeMove = nil end
        if resizeEnd then resizeEnd:Disconnect() resizeEnd = nil end
    end
    ResizeGripClick.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        stopResize()
        resizing = true
        resizeStart = input.Position
        startSize = Main.AbsoluteSize
        resizeMove = UserInputService.InputChanged:Connect(function(moveInput)
            if not resizing then return end
            if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = moveInput.Position - resizeStart
            local w = math.max(MIN_W, startSize.X + delta.X)
            local h = math.max(MIN_H, startSize.Y + delta.Y)
            Main.Size = UDim2.new(0, w, 0, h)
        end)
        resizeEnd = UserInputService.InputEnded:Connect(function(endInput)
            if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                stopResize()
            end
        end)
    end)


    local TabRow = panel({
        Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = Theme.Header, Parent = Main,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabRow,
    })
    pad(TabRow, 2, 2)


    local PageHolder = panel({
        Size = UDim2.new(1, -8, 1, -50), Position = UDim2.new(0, 4, 0, 46),
        BackgroundColor3 = Theme.Background, Parent = Main,
    })
    pad(PageHolder, 4, 4)


    -- === floating color picker popup (item 3, redone bigger/clearer) ===
    -- one shared popup per window; opening a color swatch re-targets it and
    -- moves it near wherever you clicked
    local ColorPopup = panel({
        Name = "ColorPopup", Visible = false, ZIndex = 50,
        Size = UDim2.new(0, 190, 0, 210),
        Position = UDim2.new(0.5, WINDOW_W / 2 + 6, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Panel, Parent = ScreenGui,
    })
    local ColorPopupHeader = panel({
        Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Theme.Header, ZIndex = 51, Parent = ColorPopup,
    })
    local ColorPopupTitle = new("TextLabel", {
        Text = "Color", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -20, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = ColorPopupHeader,
    })
    local ColorPopupClose = new("TextButton", {
        Text = "x", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0),
        ZIndex = 51, Parent = ColorPopupHeader,
    })
    ColorPopupClose.MouseButton1Click:Connect(function() ColorPopup.Visible = false end)
    makeDraggable(ColorPopupHeader, ColorPopup)


    -- step 1: the saturation/value square — drag here after picking a hue
    local SVSquare = new("Frame", {
        Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -16, 0, 130),
        BackgroundColor3 = Color3.fromHSV(0, 1, 1), BorderSizePixel = 1, BorderColor3 = Theme.Border,
        ZIndex = 51, ClipsDescendants = true, Parent = ColorPopup,
    })
    local WhiteOverlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        ZIndex = 51, Parent = SVSquare,
    })
    new("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = 0, Parent = WhiteOverlay })
    local BlackOverlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        ZIndex = 52, Parent = SVSquare,
    })
    new("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = BlackOverlay })
    -- cursor (item 11): a SMALL CIRCLE with a soft white glow halo around it
    local SVCursorGlow = new("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 52, Parent = SVSquare,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SVCursorGlow })
    local SVCursor = new("Frame", {
        Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 53, Parent = SVSquare,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SVCursor })
    local function setSVCursor(relX, relY)
        SVCursorGlow.Position = UDim2.new(relX, -9, relY, -9)
        SVCursor.Position = UDim2.new(relX, -4, relY, -4)
    end


    -- step 2: hue slider — pick this FIRST, it sets the square's base color
    local HueHolder = new("Frame", {
        Position = UDim2.new(0, 8, 0, 158), Size = UDim2.new(1, -16, 0, 12),
        BackgroundTransparency = 1, ZIndex = 51, Parent = ColorPopup,
    })


    -- live preview: swatch + hex readout so you can actually see it's working
    local PreviewSwatch = panel({
        Position = UDim2.new(0, 8, 0, 178), Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 51, Parent = ColorPopup,
    })
    local PreviewHex = new("TextLabel", {
        Text = "#FFFFFF", Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Position = UDim2.new(0, 30, 0, 178), Size = UDim2.new(1, -38, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = ColorPopup,
    })


    local popupHue, popupSat, popupVal = 0, 1, 1
    local popupApply -- currently-targeted callback


    local function recomputeColor()
        local c = Color3.fromHSV(popupHue, popupSat, popupVal)
        PreviewSwatch.BackgroundColor3 = c
        PreviewHex.Text = "#" .. c:ToHex():upper()
        if popupApply then popupApply(c) end
        return c
    end


    local hueCtl = buildHueSlider(HueHolder, 0, function(h)
        popupHue = h
        SVSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        recomputeColor()
    end)


    local function svUpdate(input)
        local relX = math.clamp((input.Position.X - SVSquare.AbsolutePosition.X) / SVSquare.AbsoluteSize.X, 0, 1)
        local relY = math.clamp((input.Position.Y - SVSquare.AbsolutePosition.Y) / SVSquare.AbsoluteSize.Y, 0, 1)
        popupSat = relX
        popupVal = 1 - relY
        setSVCursor(relX, relY)
        recomputeColor()
    end
    local svDragging = false
    SVSquare.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            svDragging = true
            svUpdate(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if svDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            svUpdate(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            svDragging = false
        end
    end)


    local function openColorPopup(initialColor, applyFn, popupTitle, nearPos)
        local h, s, v = initialColor:ToHSV()
        popupHue, popupSat, popupVal = h, s, v
        popupApply = applyFn
        ColorPopupTitle.Text = popupTitle or "Color"
        SVSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        setSVCursor(s, 1 - v)
        hueCtl.SetHue(h)
        PreviewSwatch.BackgroundColor3 = initialColor
        PreviewHex.Text = "#" .. initialColor:ToHex():upper()
        if nearPos then
            ColorPopup.Position = UDim2.new(0, nearPos.X + 16, 0, math.max(0, nearPos.Y - 60))
        end
        ColorPopup.Visible = true
    end


    -- === menu visibility key (item 2 fix lives in State so it's mutable) ===
    local State = { ToggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl }
    local visible = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == State.ToggleKey then
            visible = not visible
            Main.Visible = visible
        end
    end)


    local Window = { Tabs = {} }


    function Window:SetAccentColor(color3)
        Theme.Accent = color3
        for _, fn in ipairs(AccentListeners) do pcall(fn, color3) end
    end


    function Window:SetToggleKeybind(key)
        State.ToggleKey = key
    end


    function Window:CreateTab(name)
        -- tabs measure their actual text with TextService instead of
        -- guessing "#name * 8" — that guess was off for anything that
        -- wasn't short/plain text.
        local measured = TextService:GetTextSize(name, 13, FONT, Vector2.new(1000, 20))
        local TabBtn = new("TextButton", {
            Text = name, Font = FONT, TextSize = 13, TextColor3 = Theme.SubText,
            BackgroundColor3 = Theme.Header, BorderSizePixel = 1, BorderColor3 = Theme.Border,
            Size = UDim2.new(0, measured.X + 18, 1, 0), Parent = TabRow,
        })


        local Page = new("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = PageHolder,
        })
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Page,
        })
        local Columns = {}
        for i = 1, 2 do
            -- columns are now scrolling frames (item 12): content gets
            -- CLIPPED when the window is resized too small instead of
            -- sticking out, and you can scroll down to reach the rest
            local Col = new("ScrollingFrame", {
                Size = UDim2.new(0.5, -2, 1, 0),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 1, BorderColor3 = Theme.Border,
                LayoutOrder = i, Parent = Page,
                ClipsDescendants = true,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = Theme.SubText,
                ScrollBarImageTransparency = 0.5,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
            })
            local ColInner = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Parent = Col,
            })
            new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ColInner })
            pad(ColInner, 3, 3)
            table.insert(Columns, ColInner)
        end


        local function select()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                t.Btn.BackgroundColor3 = Theme.Header
                t.Btn.TextColor3 = Theme.SubText
            end
            Page.Visible = true
            TabBtn.BackgroundColor3 = Theme.Panel
            TabBtn.TextColor3 = Theme.Text
        end
        TabBtn.MouseButton1Click:Connect(select)


        local TabObj = { Btn = TabBtn, Page = Page }
        table.insert(Window.Tabs, TabObj)
        if #Window.Tabs == 1 then select() end


        local colCounter = 0


        local function attachElements(Content)
            local E = {}


            function E:AddLabel(text, risky)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = risky and Theme.Risky or Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Content,
                })
            end


            function E:AddButton(text, callback, risky)
                local Btn = panel({ Size = UDim2.new(1, 0, 0, 20), Parent = Content })
                local Lbl = new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn,
                })
                local Click = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn })
                Click.MouseEnter:Connect(function() Btn.BackgroundColor3 = Theme.Header end)
                Click.MouseLeave:Connect(function() Btn.BackgroundColor3 = Theme.Panel end)
                Click.MouseButton1Click:Connect(function() if callback then callback() end end)
                return Btn
            end


            function E:AddCheckbox(text, default, callback, risky)
                local state = default or false
                local Row = new("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 15), Parent = Content,
                })
                local Sq = panel({
                    Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 0, 0.5, -6),
                    BackgroundColor3 = Theme.Track, Parent = Row,
                })
                -- FILLED square when toggled on (item 13) instead of a half-empty box
                local Fill = new("Frame", {
                    Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
                    Visible = state, Parent = Sq,
                })
                onAccent(function(c) Fill.BackgroundColor3 = c end)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local function set(v, fire)
                    state = v
                    Fill.Visible = state
                    if fire ~= false and callback then callback(state) end
                end
                Row.MouseButton1Click:Connect(function() set(not state) end)
                return { Set = set, Get = function() return state end }
            end


            function E:AddSlider(text, min, max, default, callback, suffix, risky)
                min, max = min or 0, max or 100
                local value = default or min
                suffix = suffix or ""


                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, -44, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local ValueLabel = new("TextLabel", {
                    Text = tostring(value) .. suffix, Font = FONT, TextSize = 13, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -44, 0, 0), Size = UDim2.new(0, 44, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Right, Parent = Holder,
                })
                local Track = panel({
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 6),
                    BackgroundColor3 = Theme.Track, Parent = Holder,
                })
                local Fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Track,
                })
                onAccent(function(c) Fill.BackgroundColor3 = c end)


                local dragging = false
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                    value = math.floor(min + (max - min) * rel)
                    ValueLabel.Text = tostring(value) .. suffix
                    Fill.Size = UDim2.new(rel, 0, 1, 0)
                    if callback then callback(value) end
                end
                Track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                return { Get = function() return value end }
            end


            -- dropdown (item 10): bordered track box, header-bg on hover,
            -- accent border/chevron while open, accent bar on the selected row
            function E:AddCombo(text, options, default, callback, risky)
                options = options or {}
                local selected = default or options[1]
                local open = false
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 32), ClipsDescendants = true,
                    BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })

                local Btn = panel({
                    Position = UDim2.new(0, 0, 0, 15), Size = UDim2.new(1, 0, 0, 16),
                    BackgroundColor3 = Theme.Track, BorderColor3 = Theme.Border, Parent = Holder,
                })
                local BtnLbl = new("TextLabel", {
                    Text = tostring(selected), Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -22, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Btn,
                })
                local Chevron = new("TextLabel", {
                    Text = "▾", Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0),
                    Parent = Btn,
                })
                local BtnClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn })
                BtnClick.MouseEnter:Connect(function()
                    if not open then Btn.BackgroundColor3 = Theme.Header end
                end)
                BtnClick.MouseLeave:Connect(function()
                    if not open then Btn.BackgroundColor3 = Theme.Track end
                end)

                local List = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 33), Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })

                local optionsUi = {}
                for _, opt in ipairs(options) do
                    local OptBtn = panel({
                        Size = UDim2.new(1, 0, 0, 15), BackgroundColor3 = Theme.Panel,
                        BorderColor3 = Theme.Border, Parent = List,
                    })
                    local Bar = new("Frame", {
                        Size = UDim2.new(0, 3, 1, -4), Position = UDim2.new(0, 3, 0, 2),
                        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false, Parent = OptBtn,
                    })
                    onAccent(function(c) Bar.BackgroundColor3 = c end)
                    local OptLbl = new("TextLabel", {
                        Text = tostring(opt), Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1, Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(1, -12, 1, 0),
                        TextXAlignment = Enum.TextXAlignment.Left, Parent = OptBtn,
                    })
                    local OptClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = OptBtn })
                    OptClick.MouseButton1Click:Connect(function()
                        selected = opt
                        BtnLbl.Text = tostring(opt)
                        if callback then callback(opt) end
                        setOpen(false)
                    end)
                    table.insert(optionsUi, { opt = opt, btn = OptBtn, bar = Bar, lbl = OptLbl })
                end

                local function refreshSelected()
                    for _, entry in ipairs(optionsUi) do
                        local isSel = (entry.opt == selected)
                        entry.bar.Visible = isSel
                        entry.lbl.TextColor3 = isSel and Theme.Text or Theme.SubText
                        entry.btn.BackgroundColor3 = isSel and Theme.Header or Theme.Panel
                    end
                end

                local function setOpen(v)
                    open = v
                    local listH = #options * 15 + math.max(0, #options - 1) * 1
                    Holder.Size = open and UDim2.new(1, 0, 0, 33 + listH) or UDim2.new(1, 0, 0, 32)
                    Chevron.Text = open and "▴" or "▾"
                    Chevron.TextColor3 = open and Theme.Accent or Theme.SubText
                    Btn.BackgroundColor3 = open and Theme.Header or Theme.Track
                    Btn.BorderColor3 = open and Theme.Accent or Theme.Border
                    if open then refreshSelected() end
                end
                BtnClick.MouseButton1Click:Connect(function() setOpen(not open) end)

                return { Get = function() return selected end }
            end


            -- plain bindable key for YOUR OWN features. Does not affect the
            -- menu's own show/hide key — use AddMenuKeybind for that.
            function E:AddKeybind(text, default, callback, risky)
                local key = default or Enum.KeyCode.Unknown
                local listening = false
                local Row = new("Frame", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local KeyBtn = panel({
                    BackgroundColor3 = Theme.Track,
                    Position = UDim2.new(1, -46, 0, 0), Size = UDim2.new(0, 46, 0, 15), Parent = Row,
                })
                local KeyLbl = new("TextLabel", {
                    Text = "[" .. key.Name .. "]", Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = KeyBtn,
                })
                local KeyClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = KeyBtn })
                KeyClick.MouseButton1Click:Connect(function()
                    listening = true
                    KeyLbl.Text = "[...]"
                end)
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        KeyLbl.Text = "[" .. key.Name .. "]"
                        listening = false
                    elseif not gpe and input.KeyCode == key and callback then
                        callback(key)
                    end
                end)
                return { Get = function() return key end }
            end


            -- THIS is the one that actually rebinds the menu's real show/hide
            -- key, via Window:SetToggleKeybind.
            function E:AddMenuKeybind(text, risky)
                local key = State.ToggleKey
                local listening = false
                local Row = new("Frame", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text or "Menu Keybind", Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local KeyBtn = panel({
                    BackgroundColor3 = Theme.Track,
                    Position = UDim2.new(1, -46, 0, 0), Size = UDim2.new(0, 46, 0, 15), Parent = Row,
                })
                local KeyLbl = new("TextLabel", {
                    Text = "[" .. key.Name .. "]", Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = KeyBtn,
                })
                local KeyClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = KeyBtn })
                KeyClick.MouseButton1Click:Connect(function()
                    listening = true
                    KeyLbl.Text = "[...]"
                end)
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        KeyLbl.Text = "[" .. key.Name .. "]"
                        listening = false
                        Window:SetToggleKeybind(key) -- <- the actual fix
                    end
                end)
                return { Get = function() return key end }
            end


            -- opens the shared floating popup instead of an inline dropdown
            function E:AddColorPicker(text, default, callback, risky)
                local color = default or Color3.fromRGB(255, 255, 255)
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 15),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Swatch = panel({
                    BackgroundColor3 = color, Size = UDim2.new(0, 15, 0, 15),
                    Position = UDim2.new(1, -15, 0, 0), Parent = Holder,
                })
                local SwatchClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Swatch })
                SwatchClick.MouseButton1Click:Connect(function()
                    openColorPopup(color, function(c)
                        color = c
                        Swatch.BackgroundColor3 = c
                        if callback then callback(c) end
                    end, text, Swatch.AbsolutePosition)
                end)
                return { Get = function() return color end }
            end


            function E:AddAccentPicker(text, risky)
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text or "Accent Color", Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local SliderHolder = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 8),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                local h = select(1, Theme.Accent:ToHSV())
                buildHueSlider(SliderHolder, h, function(hue) Window:SetAccentColor(Color3.fromHSV(hue, 1, 1)) end)
            end


            return E
        end


        function TabObj:CreateBox(boxTitle, column, startCollapsed)
            colCounter = colCounter + 1
            local col = column or ((colCounter - 1) % 2) + 1


            local Box = panel({
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel, Parent = Columns[col],
            })


            local Header = panel({
                Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Theme.Header, Parent = Box,
            })
            new("TextLabel", {
                Text = boxTitle, Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Text,
                BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -20, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
            })
            local CollapseBtn = new("TextButton", {
                Text = "-", Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.SubText,
                BackgroundTransparency = 1, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0),
                Parent = Header,
            })


            local Content = new("Frame", {
                Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = Box,
            })
            new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })
            pad(Content, 6, 6)


            local collapsed = startCollapsed or false
            local function applyCollapsed()
                Content.Visible = not collapsed
                CollapseBtn.Text = collapsed and "+" or "-"
            end
            CollapseBtn.MouseButton1Click:Connect(function()
                collapsed = not collapsed
                applyCollapsed()
            end)
            applyCollapsed()


            local BoxObj = attachElements(Content)


            function BoxObj:CreatePillTabs(names)
                local PillRow = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, LayoutOrder = -1, Parent = Content,
                })
                new("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder, Parent = PillRow,
                })
                local PagesFrame = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, LayoutOrder = 0, Parent = Content,
                })


                local pillTabs = {}
                for i, pname in ipairs(names) do
                    local Pill = panel({
                        BackgroundColor3 = Theme.Track,
                        Size = UDim2.new(1 / #names, 0, 1, 0), Parent = PillRow,
                    })
                    local PillLbl = new("TextLabel", {
                        Text = pname, Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Pill,
                    })
                    local PillClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Pill })
                    local PPage = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, Parent = PagesFrame,
                    })
                    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = PPage })


                    local function selectPill()
                        for _, p in ipairs(pillTabs) do
                            p.Page.Visible = false
                            p.Pill.BackgroundColor3 = Theme.Track
                            p.Lbl.TextColor3 = Theme.SubText
                        end
                        PPage.Visible = true
                        Pill.BackgroundColor3 = Theme.Panel
                        PillLbl.TextColor3 = Theme.Text
                    end
                    PillClick.MouseButton1Click:Connect(selectPill)


                    local entry = { Pill = Pill, Lbl = PillLbl, Page = PPage }
                    table.insert(pillTabs, entry)
                    if i == 1 then selectPill() end
                end


                local result = {}
                for i, pname in ipairs(names) do
                    result[pname] = attachElements(pillTabs[i].Page)
                end
                return result
            end


            return BoxObj
        end


        return TabObj
    end


    return Window
end


return Library


--[[
    EXAMPLE (covers every element the library ships):

    local Library = loadstring(readfile("ModernUILibrary.lua"))()
    local Window = Library:CreateWindow("fracture", {
        AccentColor    = Color3.fromRGB(255, 140, 0),
        ToggleKeybind  = Enum.KeyCode.RightControl,
    })


    -- ================ MAIN TAB ================
    local MainTab = Window:CreateTab("Main")

    local Combat = MainTab:CreateBox("Combat", 1)          -- column 1
    Combat:AddCheckbox("Enabled", true, function(v) print("enabled", v) end)
    Combat:AddCombo("Resolver", {"Off", "Pitch", "Yaw", "Full"}, "Pitch", function(v) print("mode", v) end)
    Combat:AddSlider("Hitbox Size", 1, 10, 4, function(v) print(v) end, "x", true) -- red label (risky)
    Combat:AddKeybind("Triggerbot", Enum.KeyCode.G, function() print("trigger") end)

    local Visuals = MainTab:CreateBox("Visuals", 1)        -- column 1
    Visuals:AddCheckbox("ESP", true, function(v) end)
    Visuals:AddCombo("ESP Type", {"Box", "Corner", "Tracer"}, "Corner", function(v) end)
    Visuals:AddColorPicker("Box Color", Color3.fromRGB(255, 165, 0), function(c) end)

    local Misc = MainTab:CreateBox("Misc", 2)              -- column 2
    Misc:AddLabel("General options", true)                 -- red label
    Misc:AddButton("Teleport to spawn", function() print("tp") end)
    Misc:AddCheckbox("Anti Aim", false, function(v) end)

    local Extra = MainTab:CreateBox("Extra", 2, true)      -- column 2, starts collapsed
    Extra:AddCheckbox("Collapsed box", false, function(v) end)

    local Pills = MainTab:CreateBox("Pill Tabs", 2)        -- nested sub-tabs
    local pill = Pills:CreatePillTabs({"Enemy", "Team", "Local"})
    pill["Enemy"]:AddCheckbox("Enabled", false, function(v) end)
    pill["Enemy"]:AddSlider("Distance", 0, 100, 50, nil, "m")
    pill["Team"]:AddCheckbox("Team ESP", true, function(v) end)
    pill["Local"]:AddButton("Fake Lag", function() end)


    -- ================ SETTINGS TAB ================
    local SettingsTab = Window:CreateTab("Settings")

    local Appearance = SettingsTab:CreateBox("Appearance", 1)
    Appearance:AddAccentPicker("Accent Color")
    Appearance:AddColorPicker("Text Color", Color3.fromRGB(215, 215, 215), function(c) end)
    Appearance:AddButton("Reset Accent", function()
        Window:SetAccentColor(Color3.fromRGB(60, 130, 220))
    end)

    local Bindings = SettingsTab:CreateBox("Bindings", 2)
    Bindings:AddMenuKeybind("Menu Keybind")                -- actually rebinds show/hide
    Bindings:AddKeybind("Custom Key", Enum.KeyCode.F, function() end)
]]
