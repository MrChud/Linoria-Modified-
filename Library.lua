--[[
    ModernUI Library — old/plain cheat-menu skin
    Square corners, native 1px borders, default Roblox font, flat colors,
    little to no animation. Structure: top plain tab row -> 2-column boxed
    panels -> plain checkboxes/sliders/dropdowns/keybinds.
 
    USAGE:
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("menu")
        local Tab = Window:CreateTab("Main")
        local Box = Tab:CreateBox("General")
        Box:AddCheckbox("Enabled", false, function(v) print(v) end)
]]
 
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
 
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
 
--// Theme — flat, plain, nothing fancy
local Theme = {
    Background = Color3.fromRGB(22, 22, 22),
    Panel      = Color3.fromRGB(27, 27, 27),
    Header     = Color3.fromRGB(32, 32, 32),
    Track      = Color3.fromRGB(18, 18, 18),
    Text       = Color3.fromRGB(210, 210, 210),
    SubText    = Color3.fromRGB(130, 130, 130),
    Border     = Color3.fromRGB(55, 55, 55),
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
 
-- plain, boxy panel: square corners, native 1px border (no UIStroke/UICorner)
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
 
-- quick, non-fancy hover flash (no easing curves, just an instant-ish linear step)
local function hoverFlash(btn, onColor, offColor, propName)
    propName = propName or "TextColor3"
    btn.MouseEnter:Connect(function() btn[propName] = onColor end)
    btn.MouseLeave:Connect(function() btn[propName] = offColor end)
end
 
local function makeDraggable(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end
 
-- plain flat hue strip (used for color pickers) — no gradient border/rounding
local function buildHueSlider(parent, onChange)
    local Track = panel({ Size = UDim2.new(1, 0, 0, 8), Parent = parent, BackgroundColor3 = Theme.Track })
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
        Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(0, -1, 0, -2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = Track,
    })
    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Handle.Position = UDim2.new(rel, -1, 0, -2)
        onChange(Color3.fromHSV(rel, 1, 1))
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
    return Track
end
 
--// Library
local Library = {}
Library.__index = Library
 
function Library:CreateWindow(title, opts)
    opts = opts or {}
    if opts.AccentColor then Theme.Accent = opts.AccentColor end
 
    local AccentListeners = {}
    local function onAccent(fn)
        table.insert(AccentListeners, fn)
        fn(Theme.Accent)
    end
 
    local ScreenGui = new("ScreenGui", {
        Name = "ModernUI_" .. tostring(math.random(1, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })
 
    local WINDOW_W, WINDOW_H = 600, 400
 
    local Main = panel({
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        Parent = ScreenGui,
    })
 
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
 
    -- plain tab row, flat text, no sliding indicator — just a highlighted
    -- background on whichever tab is active (classic script-hub look)
    local TabRow = panel({
        Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = Theme.Header, Parent = Main,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabRow,
    })
 
    local PageHolder = new("Frame", {
        Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 42),
        BackgroundTransparency = 1, Parent = Main,
    })
    pad(PageHolder, 4, 4)
 
    local visible = true
    local toggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == toggleKey then
            visible = not visible
            Main.Visible = visible
        end
    end)
 
    local Window = { Tabs = {} }
 
    function Window:SetAccentColor(color3)
        Theme.Accent = color3
        for _, fn in ipairs(AccentListeners) do pcall(fn, color3) end
    end
 
    function Window:CreateTab(name)
        local TabBtn = new("TextButton", {
            Text = name, Font = FONT, TextSize = 13, TextColor3 = Theme.SubText,
            BackgroundColor3 = Theme.Header, BorderSizePixel = 0,
            Size = UDim2.new(0, #name * 8 + 16, 1, 0), Parent = TabRow,
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
            local Col = new("Frame", {
                Size = UDim2.new(0.5, -2, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, Parent = Page,
            })
            new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Col })
            table.insert(Columns, Col)
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
 
            function E:AddLabel(text)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Content,
                })
            end
 
            function E:AddButton(text, callback)
                local Btn = panel({
                    Size = UDim2.new(1, 0, 0, 20), Parent = Content,
                })
                local Lbl = new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn,
                })
                local Click = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn })
                hoverFlash(Click, Theme.Panel, Theme.Header, nil)
                Click.MouseEnter:Connect(function() Btn.BackgroundColor3 = Theme.Header end)
                Click.MouseLeave:Connect(function() Btn.BackgroundColor3 = Theme.Panel end)
                Click.MouseButton1Click:Connect(function() if callback then callback() end end)
                return Btn
            end
 
            function E:AddCheckbox(text, default, callback)
                local state = default or false
                local Row = new("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 15), Parent = Content,
                })
                local Sq = panel({
                    Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 0, 0.5, -6),
                    BackgroundColor3 = Theme.Track, Parent = Row,
                })
                local Fill = new("Frame", {
                    Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
                    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
                    Visible = state, Parent = Sq,
                })
                onAccent(function(c) Fill.BackgroundColor3 = c end)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
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
 
            function E:AddSlider(text, min, max, default, callback, suffix)
                min, max = min or 0, max or 100
                local value = default or min
                suffix = suffix or ""
 
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
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
 
            function E:AddCombo(text, options, default, callback)
                options = options or {}
                local selected = default or options[1]
                local open = false
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 30), ClipsDescendants = true, BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Btn = panel({
                    Position = UDim2.new(0, 0, 0, 15), Size = UDim2.new(1, 0, 0, 15),
                    BackgroundColor3 = Theme.Track, Parent = Holder,
                })
                local BtnLbl = new("TextLabel", {
                    Text = tostring(selected), Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -18, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Btn,
                })
                new("TextLabel", {
                    Text = "v", Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0, 14, 1, 0),
                    Parent = Btn,
                })
                local ClickCatcher = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn })
                local List = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, #options * 15),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })
                for _, opt in ipairs(options) do
                    local OptBtn = panel({
                        Size = UDim2.new(1, 0, 0, 15), BackgroundColor3 = Theme.Panel, Parent = List,
                    })
                    local OptLbl = new("TextLabel", {
                        Text = tostring(opt), Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -4, 1, 0),
                        TextXAlignment = Enum.TextXAlignment.Left, Parent = OptBtn,
                    })
                    local OptClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = OptBtn })
                    OptClick.MouseButton1Click:Connect(function()
                        selected = opt
                        BtnLbl.Text = tostring(opt)
                        if callback then callback(opt) end
                        open = false
                        Holder.Size = UDim2.new(1, 0, 0, 30)
                    end)
                end
                ClickCatcher.MouseButton1Click:Connect(function()
                    open = not open
                    Holder.Size = open and UDim2.new(1, 0, 0, 30 + #options * 15) or UDim2.new(1, 0, 0, 30)
                end)
                return { Get = function() return selected end }
            end
 
            function E:AddKeybind(text, default, callback)
                local key = default or Enum.KeyCode.Unknown
                local listening = false
                local Row = new("Frame", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
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
 
            function E:AddColorPicker(text, default, callback)
                local color = default or Color3.fromRGB(255, 255, 255)
                local open = false
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 15), ClipsDescendants = true, BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 15),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Swatch = panel({
                    BackgroundColor3 = color, Size = UDim2.new(0, 15, 0, 15),
                    Position = UDim2.new(1, -15, 0, 0), Parent = Holder,
                })
                local SwatchClick = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Swatch })
                local PickerHolder = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 19), Size = UDim2.new(1, 0, 0, 8),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                buildHueSlider(PickerHolder, function(c)
                    color = c
                    Swatch.BackgroundColor3 = c
                    if callback then callback(c) end
                end)
                SwatchClick.MouseButton1Click:Connect(function()
                    open = not open
                    Holder.Size = open and UDim2.new(1, 0, 0, 30) or UDim2.new(1, 0, 0, 15)
                end)
                return { Get = function() return color end }
            end
 
            function E:AddAccentPicker(text)
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text or "Accent Color", Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local SliderHolder = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 8),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                buildHueSlider(SliderHolder, function(c) Window:SetAccentColor(c) end)
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
    EXAMPLE:
 
    local Library = loadstring(readfile("ModernUILibrary.lua"))()
    local Window = Library:CreateWindow("fracture")
 
    local Visuals = Window:CreateTab("Visuals")
    local Box1 = Visuals:CreateBox("ESP", 1)
    local pills = Box1:CreatePillTabs({"Enemy", "Team", "Local"})
    pills["Enemy"]:AddCheckbox("Enabled", false)
    pills["Enemy"]:AddCheckbox("Box", false)
    pills["Enemy"]:AddColorPicker("Box Color", Color3.fromRGB(255, 165, 0))
    pills["Enemy"]:AddSlider("Render Distance", 0, 5000, 2500, nil, "m")
 
    local Box2 = Visuals:CreateBox("Camera", 2)
    Box2:AddButton("Reset Camera", function() end)
 
    local Settings = Window:CreateTab("Settings")
    local Box3 = Settings:CreateBox("Appearance", 1)
    Box3:AddAccentPicker("Accent Color")
    Box3:AddKeybind("Toggle Menu", Enum.KeyCode.RightControl)
]]
