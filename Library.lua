--[[
    ModernUI Library — classic cheat-menu skin
    (top tab bar w/ sliding underline, collapsible boxed sections with a thin
    accent top-strip, nested pill sub-tabs inside a box, square checkboxes,
    sliders with the value centered on the fill bar)

    Accent color is runtime-customizable via Window:SetAccentColor(), and
    there's a built-in hue-slider (Box:AddAccentPicker) to expose that live.

    USAGE:
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("menu")
        local Tab = Window:CreateTab("Main")
        local Box = Tab:CreateBox("General")
        Box:AddCheckbox("Enabled", false, function(v) print(v) end)
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Theme
local Theme = {
    Background = Color3.fromRGB(15, 15, 18),
    TopBar     = Color3.fromRGB(19, 19, 23),
    Box        = Color3.fromRGB(20, 20, 24),
    BoxHeader  = Color3.fromRGB(24, 24, 28),
    Pill       = Color3.fromRGB(28, 28, 33),
    Text       = Color3.fromRGB(215, 215, 220),
    SubText    = Color3.fromRGB(120, 120, 130),
    Stroke     = Color3.fromRGB(38, 38, 44),
    Track      = Color3.fromRGB(34, 34, 39),
    Accent     = Color3.fromRGB(70, 140, 235),
}

local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

--// Helpers
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function tween(obj, props, time, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 3), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = parent,
    })
end

local function pad(parent, x, y)
    y = y or x
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x),
        PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y),
        Parent = parent,
    })
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

-- reusable hue slider (used by both the accent picker and per-element color picker)
local function buildHueSlider(parent, onChange)
    local Track = new("Frame", { Size = UDim2.new(1, 0, 0, 10), Parent = parent })
    corner(Track, 2)
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
        Size = UDim2.new(0, 4, 1, 4), Position = UDim2.new(0, -2, 0, -2),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = Track,
    })
    corner(Handle, 2)
    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Handle.Position = UDim2.new(rel, -2, 0, -2)
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

    local WINDOW_W, WINDOW_H = 620, 420

    local Main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        Parent = ScreenGui,
    })
    corner(Main, 4)
    stroke(Main, Theme.Stroke, 1)

    local TitleBar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.TopBar,
        Parent = Main,
    })
    corner(TitleBar, 4)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6),
        BackgroundColor3 = Theme.TopBar, BorderSizePixel = 0, Parent = TitleBar,
    })
    new("TextLabel", {
        Text = title or "menu", Font = FONT_MED, TextSize = 12, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 200, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar,
    })
    local CloseBtn = new("TextButton", {
        Text = "×", Font = FONT_BOLD, TextSize = 16, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(1, -26, 0, 0),
        Parent = TitleBar,
    })
    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, { TextColor3 = Color3.fromRGB(220, 80, 90) }, 0.1) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, { TextColor3 = Theme.SubText }, 0.1) end)
    CloseBtn.MouseButton1Click:Connect(function()
        tween(Main, { Size = UDim2.new(0, WINDOW_W, 0, 0) }, 0.15)
        task.wait(0.15)
        ScreenGui:Destroy()
    end)
    makeDraggable(TitleBar, Main)

    -- top tab row w/ sliding underline
    local TabRow = new("Frame", {
        Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = Theme.TopBar, Parent = Main,
    })
    stroke(TabRow, Theme.Stroke, 1)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabRow,
    })
    pad(TabRow, 8, 0)

    local Underline = new("Frame", {
        Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Accent, ZIndex = 5, Parent = TabRow,
    })
    onAccent(function(c) Underline.BackgroundColor3 = c end)

    local PageHolder = new("Frame", {
        Size = UDim2.new(1, -12, 1, -66), Position = UDim2.new(0, 6, 0, 60),
        BackgroundTransparency = 1, Parent = Main,
    })

    local visible = true
    local toggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == toggleKey then
            visible = not visible
            tween(Main, { Size = visible and UDim2.new(0, WINDOW_W, 0, WINDOW_H) or UDim2.new(0, WINDOW_W, 0, 0) }, 0.15)
        end
    end)

    local Window = { Tabs = {} }

    function Window:SetAccentColor(color3)
        Theme.Accent = color3
        for _, fn in ipairs(AccentListeners) do pcall(fn, color3) end
    end

    function Window:CreateTab(name)
        local TabBtn = new("TextButton", {
            Text = name, Font = FONT_MED, TextSize = 12, TextColor3 = Theme.SubText,
            BackgroundTransparency = 1, Size = UDim2.new(0, #name * 8 + 20, 1, 0), Parent = TabRow,
        })

        local Page = new("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = PageHolder,
        })
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Page,
        })
        local Columns = {}
        for i = 1, 2 do
            local Col = new("Frame", {
                Size = UDim2.new(0.5, -3, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, Parent = Page,
            })
            new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Col })
            table.insert(Columns, Col)
        end

        local function select()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                tween(t.Btn, { TextColor3 = Theme.SubText }, 0.1)
            end
            Page.Visible = true
            tween(TabBtn, { TextColor3 = Theme.Text }, 0.1)
            tween(Underline, {
                Size = UDim2.new(0, TabBtn.AbsoluteSize.X, 0, 2),
                Position = UDim2.new(0, TabBtn.AbsolutePosition.X - TabRow.AbsolutePosition.X, 1, -1),
            }, 0.15)
        end
        TabBtn.MouseButton1Click:Connect(select)

        local TabObj = { Btn = TabBtn, Page = Page }
        table.insert(Window.Tabs, TabObj)
        if #Window.Tabs == 1 then task.defer(select) end

        local colCounter = 0

        -- shared element-builder: used by both a plain Box's content frame
        -- and a pill sub-tab's content frame, so both get the same widgets
        local function attachElements(Content)
            local E = {}

            function E:AddLabel(text)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Content,
                })
            end

            function E:AddButton(text, callback)
                local Btn = new("TextButton", {
                    Text = text, Font = FONT_MED, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Track, Size = UDim2.new(1, 0, 0, 22), Parent = Content,
                })
                corner(Btn, 2)
                stroke(Btn, Theme.Stroke, 1)
                Btn.MouseEnter:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Pill }, 0.1) end)
                Btn.MouseLeave:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Track }, 0.1) end)
                Btn.MouseButton1Click:Connect(function() if callback then callback() end end)
                return Btn
            end

            function E:AddCheckbox(text, default, callback)
                local state = default or false
                local Row = new("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16), Parent = Content,
                })
                local Sq = new("Frame", {
                    Size = UDim2.new(0, 13, 0, 13), Position = UDim2.new(0, 0, 0.5, -6),
                    BackgroundColor3 = Theme.Track, Parent = Row,
                })
                corner(Sq, 2)
                stroke(Sq, Theme.Stroke, 1)
                local Fill = new("Frame", {
                    Size = UDim2.new(1, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3),
                    BackgroundColor3 = Theme.Accent, BackgroundTransparency = state and 0 or 1, Parent = Sq,
                })
                onAccent(function(c) Fill.BackgroundColor3 = c end)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Position = UDim2.new(0, 21, 0, 0), Size = UDim2.new(1, -21, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local function set(v, fire)
                    state = v
                    Fill.BackgroundTransparency = state and 0 or 1
                    if fire ~= false and callback then callback(state) end
                end
                Row.MouseButton1Click:Connect(function() set(not state) end)
                return { Set = set, Get = function() return state end }
            end

            function E:AddSlider(text, min, max, default, callback, suffix)
                min, max = min or 0, max or 100
                local value = default or min
                suffix = suffix or ""

                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Track = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 14),
                    BackgroundColor3 = Theme.Track, Parent = Holder,
                })
                corner(Track, 2)
                stroke(Track, Theme.Stroke, 1)
                local Fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent, Parent = Track,
                })
                corner(Fill, 2)
                onAccent(function(c) Fill.BackgroundColor3 = c end)
                local ValueLabel = new("TextLabel", {
                    Text = tostring(value) .. suffix, Font = FONT, TextSize = 11, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 2,
                    TextXAlignment = Enum.TextXAlignment.Center, Parent = Track,
                })

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
                    Size = UDim2.new(1, 0, 0, 32), ClipsDescendants = true, BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Btn = new("TextButton", {
                    Text = tostring(selected), Font = FONT, TextSize = 11, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Track, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                corner(Btn, 2)
                stroke(Btn, Theme.Stroke, 1)
                pad(Btn, 6, 0)
                new("TextLabel", {
                    Text = "▾", Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 16, 1, 0),
                    Parent = Btn,
                })
                local List = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, #options * 16),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })
                for _, opt in ipairs(options) do
                    local OptBtn = new("TextButton", {
                        Text = tostring(opt), Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                        BackgroundColor3 = Theme.Box, Size = UDim2.new(1, 0, 0, 16),
                        TextXAlignment = Enum.TextXAlignment.Left, Parent = List,
                    })
                    pad(OptBtn, 6, 0)
                    OptBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        Btn.Text = ""
                        Btn.Text = tostring(opt)
                        if callback then callback(opt) end
                        open = false
                        tween(Holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.12)
                    end)
                end
                Btn.MouseButton1Click:Connect(function()
                    open = not open
                    tween(Holder, { Size = open and UDim2.new(1, 0, 0, 36 + #options * 16) or UDim2.new(1, 0, 0, 32) }, 0.12)
                end)
                return { Get = function() return selected end }
            end

            function E:AddKeybind(text, default, callback)
                local key = default or Enum.KeyCode.Unknown
                local listening = false
                local Row = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, -54, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local KeyBtn = new("TextButton", {
                    Text = "[" .. key.Name .. "]", Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundColor3 = Theme.Track, Position = UDim2.new(1, -50, 0, -1), Size = UDim2.new(0, 50, 0, 16),
                    Parent = Row,
                })
                corner(KeyBtn, 2)
                stroke(KeyBtn, Theme.Stroke, 1)
                KeyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    KeyBtn.Text = "[...]"
                end)
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        KeyBtn.Text = "[" .. key.Name .. "]"
                        listening = false
                    elseif not gpe and input.KeyCode == key and callback then
                        callback(key)
                    end
                end)
                return { Get = function() return key end }
            end

            -- generic color swatch (independent of window accent) — click to
            -- open a hue slider beneath it
            function E:AddColorPicker(text, default, callback)
                local color = default or Color3.fromRGB(255, 255, 255)
                local open = false
                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 16), ClipsDescendants = true, BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Swatch = new("TextButton", {
                    Text = "", BackgroundColor3 = color, Size = UDim2.new(0, 16, 0, 16),
                    Position = UDim2.new(1, -16, 0, 0), Parent = Holder,
                })
                corner(Swatch, 2)
                stroke(Swatch, Theme.Stroke, 1)
                local PickerHolder = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 10),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                buildHueSlider(PickerHolder, function(c)
                    color = c
                    Swatch.BackgroundColor3 = c
                    if callback then callback(c) end
                end)
                Swatch.MouseButton1Click:Connect(function()
                    open = not open
                    tween(Holder, { Size = open and UDim2.new(1, 0, 0, 34) or UDim2.new(1, 0, 0, 16) }, 0.12)
                end)
                return { Get = function() return color end }
            end

            -- ties directly into Window:SetAccentColor — drop this in a
            -- "Settings"/"Appearance" box to let the end user recolor
            -- checkboxes, sliders, the tab underline, and box top-strips live
            function E:AddAccentPicker(text)
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text or "Accent Color", Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local SliderHolder = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 10),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                buildHueSlider(SliderHolder, function(c) Window:SetAccentColor(c) end)
            end

            return E
        end

        function TabObj:CreateBox(boxTitle, column, startCollapsed)
            colCounter = colCounter + 1
            local col = column or ((colCounter - 1) % 2) + 1

            local Box = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Box, Parent = Columns[col],
            })
            corner(Box, 3)
            stroke(Box, Theme.Stroke, 1)
            local TopStrip = new("Frame", {
                Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Theme.Accent, Parent = Box,
            })
            onAccent(function(c) TopStrip.BackgroundColor3 = c end)

            local Header = new("Frame", {
                Position = UDim2.new(0, 0, 0, 2), Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = Theme.BoxHeader, Parent = Box,
            })
            new("TextLabel", {
                Text = boxTitle, Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.Text,
                BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -28, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
            })
            local CollapseBtn = new("TextButton", {
                Text = "-", Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.SubText,
                BackgroundTransparency = 1, Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 20, 1, 0),
                Parent = Header,
            })

            local Content = new("Frame", {
                Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = Box,
            })
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })
            pad(Content, 8, 8)

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

            -- nested pill sub-tabs inside this box (e.g. Enemy/Team/Local)
            function BoxObj:CreatePillTabs(names)
                local PillRow = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = -1, Parent = Content,
                })
                new("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder, Parent = PillRow,
                })
                local PagesFrame = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, LayoutOrder = 0, Parent = Content,
                })

                local pillTabs = {}
                for i, pname in ipairs(names) do
                    local Pill = new("TextButton", {
                        Text = pname, Font = FONT_MED, TextSize = 11, TextColor3 = Theme.SubText,
                        BackgroundColor3 = Theme.Track, Size = UDim2.new(0, #pname * 7 + 14, 1, 0), Parent = PillRow,
                    })
                    corner(Pill, 2)
                    local PPage = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, Parent = PagesFrame,
                    })
                    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = PPage })

                    local function selectPill()
                        for _, p in ipairs(pillTabs) do
                            p.Page.Visible = false
                            tween(p.Btn, { BackgroundColor3 = Theme.Track, TextColor3 = Theme.SubText }, 0.1)
                        end
                        PPage.Visible = true
                        tween(Pill, { TextColor3 = Theme.Text }, 0.1)
                        Pill.BackgroundColor3 = Theme.Accent
                    end
                    onAccent(function(c) if PPage.Visible then Pill.BackgroundColor3 = c end end)
                    Pill.MouseButton1Click:Connect(selectPill)

                    local entry = { Btn = Pill, Page = PPage }
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
