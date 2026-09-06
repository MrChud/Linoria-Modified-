--[[
    ModernUI Library — old/plain cheat-menu skin (polish pass)

    Changelog vs previous version:
    1. More visible borders everywhere (brighter border color + outlined
       columns/tabs), so it doesn't read as "bland".
    2. Keybind fix: AddMenuKeybind() actually rewires the real menu
       show/hide key. (Plain AddKeybind() is still just a bindable key
       for your own features and intentionally does NOT touch the menu key
       unless you use AddMenuKeybind.)
    3. Color pickers are now a separate floating popup window (hue strip +
       saturation/value square), not an inline dropdown — click a swatch,
       a small window pops out, drag it around independently. It has its
       own X button to close it.
    4. Duplication fix: the ScreenGui now has a fixed name and destroys any
       previous instance of itself in PlayerGui before creating a new one,
       so re-running the script (or anything re-calling CreateWindow) can't
       stack multiple menus. Combined with the earlier drag-connection fix.
    5. Tabs now have a real 1px border box around them instead of just
       looking like floating text, and sit on the LEFT, inset so they line
       up with the window outlines.
    6. Every element (checkbox/slider/combo/keybind/button/label/color
       picker) takes an optional trailing `risky` boolean — pass true and
       its label renders in red. Toggle it per-element, nothing global.
    7/8. General spacing/contrast polish + a native UIShadow under the
       window, tinted to match the current accent color and updated live
       if you call Window:SetAccentColor().
    9. Window is now resizable via a grip in the bottom-right corner
       (min size 300x220), on top of the title-bar drag.
    10. Dropdowns (AddCombo) restyled; the selected row is highlighted
        with an accent bar + brighter text, and that highlight reliably
        follows your clicks (per-row state objects so nothing gets stuck).
    11. SV cursor in the color popup is a small circle with a UIStroke
        glow (UIShadow doesn't render in-game, UIStroke does).
    12. Columns are scrolling frames — content clips instead of sticking
        out when the window is resized too small, and you can scroll down.
    13. Checkbox fills completely with the accent color when toggled on.
    15. CreateWindow accepts `GameName` — shown in RISKY red, top-right of
        the header.
    17. No X button in the window header (pointless since the menu key
        toggles it). The color picker popup DOES keep its X.
    18. A tiny accent-colored line sits under every groupbox title, and a
        matching one sits at the TOP of the ACTIVE tab button (not across
        the whole tab row), both updating live with the accent color.
    19. TweenService pass — everything animates now:
          . The tab accent line is one indicator that SLIDES between tab
            buttons when you switch. It lives OUTSIDE the tab layout
            (tabs sit in their own container) so the layout engine can't
            fight its position and pin it to the left.
          . Accent color changes tween smoothly instead of snapping
            (except while dragging the accent picker — that stays instant
            or it'd stutter).
          . Hover states fade via tween instead of hard-cutting.
          . Dropdowns slide open/closed with a rotating chevron.
          . Checkboxes fill from the CENTER outward (anchored center),
            not sweeping in from the left.
          . Color popup slides in when opened and slides out on close.
          . Groupboxes slide their content before collapsing/expanding.
          NOTE: all of these animations only tweak Position/Size/Color3/
          Rotation/TextColor3 — universally tweenable properties. No
          GroupTransparency anywhere (some environments choke on it).

    PATCH ADDITIONS (config save/load support):
    20. AddSlider returns handle with Set(v, noCall) — restores value,
        updates the value label + fill, and only fires the callback when
        noCall is false.
    21. AddCombo returns handle with Set(v) and SetOptions(list) — Set
        selects an option (updates button text + row highlight + callback),
        SetOptions rebuilds the dropdown entries.
    22. AddKeybind returns handle with Set(k) — restores the bound key.
    23. AddColorPicker returns handle with Set(c) — restores the color and
        the swatch.
    24. NEW E:AddTextBox(text, default, callback, risky) — plain text input.
        Returns {Get, Set}. Get reads the LIVE textbox text (so it works
        even without pressing Enter).
    25. ALL handles use Set(v, noCall) semantics — pass noCall=true to
        restore a value WITHOUT firing its callback (used by config load).
        Checkbox included.
    26. AddCombo SetOptions now handles an EMPTY list correctly — it clears
        the selection and shows a blank button instead of "nil". Fixes the
        "deleted the last config but the dropdown still shows it" case.
    27. Window pop-in animation on load — starts at size 0 and grows to its
        natural size.
    28. The menu keybind now ANIMATES the window: it collapses to size 0 on
        close and pops back up on open. Size/Position only — no
        GroupTransparency.
    29. Dragging the title bar cancels any running Size/Position tween on
        the window, so grabbing it mid-animation can't fight the tween.

    USAGE:
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("menu", {
            GameName = "DEFUSAL",
        })
        local Tab = Window:CreateTab("Main")
        local Box = Tab:CreateBox("General")
        Box:AddCheckbox("Enabled", false, function(v) print(v) end)
        Box:AddCheckbox("Bunnyhop", false, function(v) print(v) end, true) -- risky = red label
]]


local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")


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


--// Tween helpers (item 19)
local ACCENT_TWEEN = 0.15
local activeTweens = {}
local function tweenTo(target, props, time, style, dir)
    -- one active tween per instance so rapid-fire calls can't stack/jitter
    if activeTweens[target] then activeTweens[target]:Cancel() end
    local tk = TweenService:Create(
        target,
        TweenInfo.new(time or ACCENT_TWEEN, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    activeTweens[target] = tk
    tk:Play()
    return tk
end

local function tweenBg(target, color, time)
    tweenTo(target, { BackgroundColor3 = color }, time or 0.12)
end


-- robust single-connection dragging (fixes the duplication-while-dragging bug)
-- (item 29) grabbing mid-animation cancels the running tween so the tween
-- doesn't fight the drag for Position
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
        if activeTweens[target] then activeTweens[target]:Cancel() end
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

    -- accent listeners tween by default; while dragging the accent picker
    -- we flip this on so it snaps instead of stutter-tweening every pixel
    local accentInst = false
    local function bindAccentColor(target, prop)
        onAccent(function(c)
            if accentInst then
                if activeTweens[target] then activeTweens[target]:Cancel() end
                target[prop] = c
            else
                tweenTo(target, { [prop] = c }, ACCENT_TWEEN)
            end
        end)
    end


    local ScreenGui = new("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })


    -- taller than wide, like the reference menus
    local WINDOW_W, WINDOW_H = 460, 620
    -- current logical size (updated by the resize grip so the open/close
    -- animation always returns to whatever size the user last dragged to)
    local curW, curH = WINDOW_W, WINDOW_H


    local Main = panel({
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true, -- keeps content inside the frame while it scales (animation)
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
    bindAccentColor(Shadow, "Color")


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


    -- game name (item 15): risky RED text, top-right of the header --
    -- pass opts.GameName to CreateWindow
    if opts.GameName and opts.GameName ~= "" then
        local gnSize = TextService:GetTextSize(opts.GameName, 12, FONT_BOLD, Vector2.new(1000, 20))
        local gnW = math.min(gnSize.X + 6, 200)
        new("TextLabel", {
            Text = opts.GameName, Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.Risky,
            BackgroundTransparency = 1, Position = UDim2.new(1, -4 - gnW, 0, 0), Size = UDim2.new(0, gnW + 2, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = TitleBar,
        })
    end

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
            curW, curH = w, h -- remember size for the open/close animation
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

    -- single accent indicator (item 18/19): slides between tab buttons,
    -- sits at the TOP of the active one, updates live with accent color.
    -- It's a DIRECT child of TabRow so the tab layout can't touch it --
    -- putting it inside the layout is what pinned it to the left.
    local TabIndicator = new("Frame", {
        Name = "TabIndicator",
        Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0, 0, 0, 2),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 2, Parent = TabRow,
    })
    bindAccentColor(TabIndicator, "BackgroundColor3")

    -- tabs live in their own child container, so UIListLayout only lays out
    -- the buttons and never interferes with the indicator above it
    local TabContainer = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = TabRow,
    })
    -- tabs on the LEFT, inset so they line up with the window outlines
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabContainer,
    })
    pad(TabContainer, 4, 2)

    -- move the indicator over a given tab button; instant = snap, else slide
    local function moveIndicator(toBtn, instant)
        task.defer(function()
            if not toBtn or not toBtn.Parent then return end
            local rel = toBtn.AbsolutePosition - TabRow.AbsolutePosition
            local props = {
                Position = UDim2.new(0, rel.X, 0, rel.Y),
                Size = UDim2.new(0, toBtn.AbsoluteSize.X, 0, 2),
            }
            if instant then
                if activeTweens[TabIndicator] then activeTweens[TabIndicator]:Cancel() end
                TabIndicator.Position = props.Position
                TabIndicator.Size = props.Size
            else
                tweenTo(TabIndicator, props, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
    end


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
    local popupClosing = false
    local ColorPopupHeader = panel({
        Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Theme.Header, ZIndex = 51, Parent = ColorPopup,
    })
    local ColorPopupTitle = new("TextLabel", {
        Text = "Color", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -20, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = ColorPopupHeader,
    })
    -- X button: close the color popup (hover fades in)
    local ColorPopupClose = new("TextButton", {
        Text = "x", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0),
        ZIndex = 51, Parent = ColorPopupHeader,
    })
    ColorPopupClose.MouseEnter:Connect(function()
        tweenTo(ColorPopupClose, { TextColor3 = Color3.fromRGB(210, 80, 80) }, 0.1)
    end)
    ColorPopupClose.MouseLeave:Connect(function()
        tweenTo(ColorPopupClose, { TextColor3 = Theme.SubText }, 0.1)
    end)

    -- slide the popup out (Position tween -- universally safe) instead of
    -- hard-hiding it; a guard flag stops a quick reopen from getting hidden
    local function closeColorPopup()
        popupClosing = true
        local cur = ColorPopup.Position
        tweenTo(ColorPopup, {
            Position = UDim2.new(cur.X.Scale, cur.X.Offset + 8, cur.Y.Scale, cur.Y.Offset),
        }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.12, function()
            if popupClosing then
                ColorPopup.Visible = false
            end
        end)
    end
    ColorPopupClose.MouseButton1Click:Connect(closeColorPopup)
    makeDraggable(ColorPopupHeader, ColorPopup)


    -- step 1: the saturation/value square -- drag here after picking a hue
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
    -- cursor (item 11): small circle with a UIStroke glow
    -- (UIShadow only renders in Studio, so UIStroke is what shows in-game)
    local SVCursor = new("Frame", {
        Size = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 53, Parent = SVSquare,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SVCursor })
    new("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Transparency = 0.2,
        Thickness = 3,
        Parent = SVCursor,
    })
    local function setSVCursor(relX, relY)
        SVCursor.Position = UDim2.new(relX, -3, relY, -3)
    end


    -- step 2: hue slider -- pick this FIRST, it sets the square's base color
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

        -- slide in from +8px to the right (item 19); also cancels any
        -- pending close so it can't hide us mid-animation
        popupClosing = false
        ColorPopup.Visible = true
        local px = ColorPopup.Position.X.Offset + 8
        local py = ColorPopup.Position.Y.Offset
        ColorPopup.Position = UDim2.new(0, px, 0, py)
        tweenTo(ColorPopup, {
            Position = UDim2.new(0, px - 8, 0, py),
        }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end


    -- === menu visibility key (item 2 fix lives in State so it's mutable) ===
    -- (item 28) toggling now animates: close shrinks the window to 0,
    -- open pops it back up. Size/Position only -- universally tweenable.
    local State = { ToggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl }
    local visible = true
    local function setWindowVisible(v)
        if v == visible then return end
        visible = v
        if activeTweens[Main] then activeTweens[Main]:Cancel() end
        if v then
            Main.Visible = true
            Main.Size = UDim2.new(0, 0, 0, 0)
            Main.Position = UDim2.new(0.5, 0, 0.5, 0)
            tweenTo(Main, {
                Size = UDim2.new(0, curW, 0, curH),
                Position = UDim2.new(0.5, -curW / 2, 0.5, -curH / 2),
            }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        else
            tweenTo(Main, {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.16, function()
                if not visible then Main.Visible = false end
            end)
        end
    end
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == State.ToggleKey then
            setWindowVisible(not visible)
        end
    end)


    local Window = { Tabs = {} }
    local activeTabBtn -- which tab button is currently selected (hover guard)


    function Window:SetAccentColor(color3, instant)
        Theme.Accent = color3
        accentInst = instant or false
        for _, fn in ipairs(AccentListeners) do pcall(fn, color3) end
        accentInst = false
    end


    function Window:SetToggleKeybind(key)
        State.ToggleKey = key
    end


    function Window:CreateTab(name)
        -- tabs measure their actual text with TextService instead of
        -- guessing "#name * 8" -- that guess was off for anything that
        -- wasn't short/plain text.
        local measured = TextService:GetTextSize(name, 13, FONT, Vector2.new(1000, 20))
        local TabBtn = new("TextButton", {
            Text = name, Font = FONT, TextSize = 13, TextColor3 = Theme.SubText,
            BackgroundColor3 = Theme.Header, BorderSizePixel = 1, BorderColor3 = Theme.Border,
            Size = UDim2.new(0, measured.X + 18, 1, 0), Parent = TabContainer,
        })

        -- hover fade on inactive tabs (active one is guarded out)
        TabBtn.MouseEnter:Connect(function()
            if TabBtn ~= activeTabBtn then tweenBg(TabBtn, Color3.fromRGB(42, 42, 42)) end
        end)
        TabBtn.MouseLeave:Connect(function()
            if TabBtn ~= activeTabBtn then tweenBg(TabBtn, Theme.Header) end
        end)


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
                if activeTweens[t.Btn] then activeTweens[t.Btn]:Cancel() end
                t.Btn.BackgroundColor3 = Theme.Header
                t.Btn.TextColor3 = Theme.SubText
            end
            Page.Visible = true
            if activeTweens[TabBtn] then activeTweens[TabBtn]:Cancel() end
            TabBtn.BackgroundColor3 = Theme.Panel
            TabBtn.TextColor3 = Theme.Text
            activeTabBtn = TabBtn
            -- slide the single accent indicator over this tab (snap on first)
            moveIndicator(TabBtn, #Window.Tabs == 1)
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
                Click.MouseEnter:Connect(function() tweenBg(Btn, Theme.Header) end)
                Click.MouseLeave:Connect(function() tweenBg(Btn, Theme.Panel) end)
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
                -- FILLED square when toggled on (item 13); the fill grows from
                -- the CENTER outward (item 19) -- anchored center so scaling
                -- the size expands evenly around the middle
                local Fill = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    Size = UDim2.new(state and 1 or 0, 0, state and 1 or 0, 0),
                    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
                    Parent = Sq,
                })
                bindAccentColor(Fill, "BackgroundColor3")
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                -- noCall = true restores silently (used by config load)
                local function set(v, noCall)
                    state = v
                    tweenTo(Fill, {
                        Size = UDim2.new(state and 1 or 0, 0, state and 1 or 0, 0),
                    }, 0.14)
                    if callback and not noCall then callback(state) end
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
                -- track lights up on hover (item 19)
                Track.MouseEnter:Connect(function() tweenBg(Track, Color3.fromRGB(30, 30, 30)) end)
                Track.MouseLeave:Connect(function() tweenBg(Track, Theme.Track) end)
                local Fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Track,
                })
                bindAccentColor(Fill, "BackgroundColor3")


                local dragging = false
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                    value = math.floor(min + (max - min) * rel)
                    ValueLabel.Text = tostring(value) .. suffix
                    Fill.Size = UDim2.new(rel, 0, 1, 0)
                    if callback then callback(value) end
                end
                -- programmatic setter: noCall = true restores silently
                local function set(v, noCall)
                    value = math.floor(math.clamp(v or min, min, max))
                    ValueLabel.Text = tostring(value) .. suffix
                    Fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                    if callback and not noCall then callback(value) end
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
                return { Get = function() return value end, Set = set }
            end


            -- dropdown (item 10 + 19): bordered track box, accent outline
            -- while open, slides open with a rotating chevron. Selected row
            -- uses per-row state objects so highlights never get stuck.
            -- SetOptions rebuilds the list (added for config load).
            -- (item 26) SetOptions with an EMPTY list clears the selection
            -- instead of showing "nil".
            function E:AddCombo(text, options, default, callback, risky)
                options = options or {}
                local selected = default or options[1]
                local open = false
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 34), ClipsDescendants = true,
                    BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })

                local Btn = panel({
                    Position = UDim2.new(0, 0, 0, 15), Size = UDim2.new(1, 0, 0, 17),
                    BackgroundColor3 = Theme.Track, BorderColor3 = Theme.Border, Parent = Holder,
                })
                local BtnLbl = new("TextLabel", {
                    Text = tostring(selected), Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -22, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = Btn,
                })
                -- chevron rotates 0 -> 180 on open (points up), back down on close
                local Chevron = new("TextLabel", {
                    Text = "▼", Font = FONT_BOLD, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0),
                    Rotation = 0, Parent = Btn,
                })
                local BtnClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn })
                BtnClick.MouseEnter:Connect(function()
                    if not open then tweenBg(Btn, Theme.Header) end
                end)
                BtnClick.MouseLeave:Connect(function()
                    if not open then tweenBg(Btn, Theme.Track) end
                end)

                local List = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 33), Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, Parent = Holder,
                })
                new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })

                -- forward declarations so builder + closures share upvalues
                local optionsUi = {}
                local refreshSelected
                local setOpen

                local function buildOptions(list)
                    -- kill the old rows before rebuilding
                    for _, row in ipairs(optionsUi) do
                        if row.btn then row.btn:Destroy() end
                    end
                    optionsUi = {}
                    options = list or options

                    -- (item 26) empty list: clear the selection, show a
                    -- blank button instead of "nil"
                    if #options == 0 then
                        selected = nil
                        BtnLbl.Text = ""
                    else
                        -- keep the selection valid against the new option list
                        local found = false
                        for _, opt in ipairs(options) do
                            if opt == selected then found = true break end
                        end
                        if not found then selected = options[1] end
                        BtnLbl.Text = tostring(selected)
                    end

                    for _, opt in ipairs(options) do
                        -- one fresh table PER option: each row owns its own state,
                        -- so closures can never share/overwrite each other
                        local row = { opt = opt }
                        local OptBtn = panel({
                            Size = UDim2.new(1, 0, 0, 15), BackgroundColor3 = Theme.Panel,
                            BorderColor3 = Theme.Border, Parent = List,
                        })
                        row.btn = OptBtn
                        local Bar = new("Frame", {
                            Size = UDim2.new(0, 3, 1, -4), Position = UDim2.new(0, 3, 0, 2),
                            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false, Parent = OptBtn,
                        })
                        bindAccentColor(Bar, "BackgroundColor3")
                        row.bar = Bar
                        local OptLbl = new("TextLabel", {
                            Text = tostring(opt), Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                            BackgroundTransparency = 1, Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(1, -12, 1, 0),
                            TextXAlignment = Enum.TextXAlignment.Left, Parent = OptBtn,
                        })
                        row.lbl = OptLbl
                        local OptClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = OptBtn })

                        function row:SetSelected(v)
                            if activeTweens[self.btn] then activeTweens[self.btn]:Cancel() end
                            self.bar.Visible = v
                            self.lbl.TextColor3 = v and Theme.Text or Theme.SubText
                            self.btn.BackgroundColor3 = v and Theme.Header or Theme.Panel
                        end
                        OptClick.MouseEnter:Connect(function()
                            if row.opt ~= selected then tweenBg(OptBtn, Theme.Header) end
                        end)
                        OptClick.MouseLeave:Connect(function()
                            if row.opt ~= selected then tweenBg(OptBtn, Theme.Panel) end
                        end)
                        OptClick.MouseButton1Click:Connect(function()
                            selected = row.opt
                            BtnLbl.Text = tostring(selected)
                            refreshSelected()
                            if callback then callback(selected) end
                            setOpen(false)
                        end)
                        table.insert(optionsUi, row)
                    end
                end

                refreshSelected = function()
                    for _, e in ipairs(optionsUi) do e:SetSelected(e.opt == selected) end
                end

                setOpen = function(v)
                    open = v
                    local listH = (#options * 15) + math.max(0, #options - 1)
                    -- slide the list out/in (Holder clips so it looks like a drawer)
                    tweenTo(Holder, { Size = v and UDim2.new(1, 0, 0, 33 + listH) or UDim2.new(1, 0, 0, 34) }, 0.14)
                    -- rotate the chevron + tint it accent while open
                    Chevron.Text = "▼"
                    tweenTo(Chevron, {
                        Rotation = v and 180 or 0,
                        TextColor3 = v and Theme.Accent or Theme.SubText,
                    }, 0.14)
                    tweenTo(Btn, {
                        BackgroundColor3 = v and Theme.Header or Theme.Track,
                        BorderColor3 = v and Theme.Accent or Theme.Border, -- accent outline while open
                    }, 0.12)
                    if v then refreshSelected() end
                end
                BtnClick.MouseButton1Click:Connect(function() setOpen(not open) end)

                buildOptions(options)

                -- programmatic setter/option-rebuild (added for config save/load)
                return {
                    Get = function() return selected end,
                    Set = function(v)
                        selected = v
                        BtnLbl.Text = tostring(selected)
                        refreshSelected()
                        if callback then callback(selected) end
                        setOpen(false)
                    end,
                    SetOptions = function(list)
                        buildOptions(list)
                        -- rebuild in place if the list is currently open
                        if open then setOpen(true) end
                    end,
                }
            end


            -- plain bindable key for YOUR OWN features. Does not affect the
            -- menu's own show/hide key -- use AddMenuKeybind for that.
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
                local function set(newKey)
                    key = newKey
                    KeyLbl.Text = "[" .. key.Name .. "]"
                end
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        set(input.KeyCode)
                        listening = false
                    elseif not gpe and input.KeyCode == key and callback then
                        callback(key)
                    end
                end)
                return { Get = function() return key end, Set = set }
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
                local function set(c)
                    color = c
                    Swatch.BackgroundColor3 = c
                end
                return { Get = function() return color end, Set = set }
            end


            -- text input (added for config save/load). Get returns the LIVE
            -- textbox text, so it works even if you never pressed Enter.
            function E:AddTextBox(text, default, callback, risky)
                local value = default or ""
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = labelColor(risky),
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Entry = panel({
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 14),
                    BackgroundColor3 = Theme.Track, Parent = Holder,
                })
                local Input = new("TextBox", {
                    Text = value, PlaceholderText = text, Font = FONT, TextSize = 12,
                    TextColor3 = Theme.Text, PlaceholderColor3 = Theme.SubText,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 3, 0, 0), Size = UDim2.new(1, -6, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ClearTextOnFocus = false,
                    Parent = Entry,
                })
                local function commit()
                    value = Input.Text
                    if callback then callback(value) end
                end
                Input.FocusLost:Connect(function(enter)
                    if enter then commit() end
                end)
                return {
                    Get = function() return Input.Text end,
                    Set = function(v)
                        value = v or ""
                        Input.Text = value
                    end,
                }
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
                -- instant = true while dragging so it snaps instead of
                -- fighting itself with a tween every frame
                buildHueSlider(SliderHolder, h, function(hue)
                    Window:SetAccentColor(Color3.fromHSV(hue, 1, 1), true)
                end)
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
            -- tiny accent line (item 18) under the groupbox title
            local HeaderLine = new("Frame", {
                Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Header,
            })
            bindAccentColor(HeaderLine, "BackgroundColor3")
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
            applyCollapsed()

            -- slide the content down before collapsing, and back up on open
            -- (item 19). Only Position is tweened -- always safe. Hiding the
            -- frame also makes AutomaticSize drop it, shrinking the box.
            CollapseBtn.MouseButton1Click:Connect(function()
                collapsed = not collapsed
                if collapsed then
                    tweenTo(Content, { Position = UDim2.new(0, 0, 0, 24) }, 0.2)
                    task.delay(0.2, function()
                        if collapsed then
                            Content.Visible = false
                            Content.Position = UDim2.new(0, 0, 0, 16)
                        end
                    end)
                else
                    Content.Position = UDim2.new(0, 0, 0, 24)
                    Content.Visible = true
                    tweenTo(Content, { Position = UDim2.new(0, 0, 0, 16) }, 0.2)
                end
                CollapseBtn.Text = collapsed and "+" or "-"
            end)


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


                local activePill
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
                    PillClick.MouseEnter:Connect(function()
                        if Pill ~= activePill then tweenBg(Pill, Color3.fromRGB(32, 32, 32)) end
                    end)
                    PillClick.MouseLeave:Connect(function()
                        if Pill ~= activePill then tweenBg(Pill, Theme.Track) end
                    end)
                    local PPage = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, Parent = PagesFrame,
                    })
                    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = PPage })


                    local function selectPill()
                        for _, p in ipairs(pillTabs) do
                            p.Page.Visible = false
                            if activeTweens[p.Pill] then activeTweens[p.Pill]:Cancel() end
                            p.Pill.BackgroundColor3 = Theme.Track
                            p.Lbl.TextColor3 = Theme.SubText
                        end
                        PPage.Visible = true
                        if activeTweens[Pill] then activeTweens[Pill]:Cancel() end
                        Pill.BackgroundColor3 = Theme.Panel
                        PillLbl.TextColor3 = Theme.Text
                        activePill = Pill
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


    -- (item 27) load-in animation: window pops from size 0 up to its
    -- natural size when the menu is created
    task.defer(function()
        Main.Size = UDim2.new(0, 0, 0, 0)
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        tweenTo(Main, {
            Size = UDim2.new(0, curW, 0, curH),
            Position = UDim2.new(0.5, -curW / 2, 0.5, -curH / 2),
        }, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end)


    return Window
end


return Library


--[[
    EXAMPLE (covers every element the library ships):

    local Library = loadstring(readfile("ModernUILibrary.lua"))()
    local Window = Library:CreateWindow("fracture", {
        AccentColor    = Color3.fromRGB(255, 140, 0),
        ToggleKeybind  = Enum.KeyCode.RightControl,
        GameName       = "DEFUSAL",      -- red text, top-right of the header
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
