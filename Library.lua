--[[
    ModernUI Library — "cheat-menu" style skin
    (gamesense/onetap-style: top tab bar w/ sliding underline, boxed grid
    sections, flat thin borders, small square checkboxes, flat sliders)

    Accent color is fully runtime-customizable via Library:SetAccentColor(),
    and there's a built-in hue-slider element (Box:AddAccentPicker) you can
    drop into a settings box to let the end user pick it live.

    USAGE:
        local Library = loadstring(readfile("ModernUILibrary.lua"))()
        local Window = Library:CreateWindow("My Menu")
        local Tab = Window:CreateTab("Main")
        local Box = Tab:CreateBox("General")
        Box:AddCheckbox("Enabled", false, function(v) print(v) end)
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Theme (Accent is mutable at runtime — see Library:SetAccentColor)
local Theme = {
    Background = Color3.fromRGB(18, 18, 21),
    TopBar     = Color3.fromRGB(23, 23, 27),
    Box        = Color3.fromRGB(24, 24, 28),
    BoxHeader  = Color3.fromRGB(28, 28, 33),
    Text       = Color3.fromRGB(225, 225, 230),
    SubText    = Color3.fromRGB(130, 130, 140),
    Stroke     = Color3.fromRGB(40, 40, 46),
    Track      = Color3.fromRGB(38, 38, 44),
    Accent     = Color3.fromRGB(75, 130, 255),
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
        TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
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

--// Library
local Library = {}
Library.__index = Library

function Library:CreateWindow(title, opts)
    opts = opts or {}
    if opts.AccentColor then Theme.Accent = opts.AccentColor end

    -- every UI piece that shows the accent color registers a callback here
    -- so Library:SetAccentColor can repaint everything live
    local AccentListeners = {}
    local function onAccent(fn)
        table.insert(AccentListeners, fn)
        fn(Theme.Accent) -- init immediately
    end

    local ScreenGui = new("ScreenGui", {
        Name = "ModernUI_" .. tostring(math.random(1, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })

    local WINDOW_W, WINDOW_H = 620, 400

    local Main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
        Position = UDim2.new(0.5, -WINDOW_W / 2, 0.5, -WINDOW_H / 2),
        BackgroundColor3 = Theme.Background,
        Parent = ScreenGui,
    })
    corner(Main, 5)
    stroke(Main, Theme.Stroke, 1)

    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.TopBar,
        Parent = Main,
    })
    corner(TopBar, 5)
    new("Frame", { -- square off the bottom corners of the topbar
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 1, -6),
        BackgroundColor3 = Theme.TopBar,
        BorderSizePixel = 0,
        Parent = TopBar,
    })
    stroke(TopBar, Theme.Stroke, 1)

    local TitleLabel = new("TextLabel", {
        Text = title or "menu",
        Font = FONT_BOLD,
        TextSize = 13,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0, 120, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })
    onAccent(function(c) TitleLabel.TextColor3 = c end)

    local CloseBtn = new("TextButton", {
        Text = "×",
        Font = FONT_BOLD,
        TextSize = 18,
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 34, 1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        Parent = TopBar,
    })
    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, { TextColor3 = Color3.fromRGB(230, 80, 90) }, 0.12) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, { TextColor3 = Theme.SubText }, 0.12) end)
    CloseBtn.MouseButton1Click:Connect(function()
        tween(Main, { Size = UDim2.new(0, WINDOW_W, 0, 0) }, 0.16)
        task.wait(0.16)
        ScreenGui:Destroy()
    end)

    makeDraggable(TopBar, Main)

    -- Tab row (top, with a sliding underline indicator)
    local TabRow = new("Frame", {
        Name = "TabRow",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 34),
        BackgroundColor3 = Theme.TopBar,
        Parent = Main,
    })
    stroke(TabRow, Theme.Stroke, 1)
    local TabLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabRow,
    })
    pad(TabRow, 6, 0)

    local Underline = new("Frame", {
        Name = "Underline",
        Size = UDim2.new(0, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Theme.Accent,
        ZIndex = 5,
        Parent = TabRow,
    })
    onAccent(function(c) Underline.BackgroundColor3 = c end)

    local PageHolder = new("Frame", {
        Name = "PageHolder",
        Size = UDim2.new(1, -12, 1, -76),
        Position = UDim2.new(0, 6, 0, 70),
        BackgroundTransparency = 1,
        Parent = Main,
    })

    -- visibility keybind
    local visible = true
    local toggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == toggleKey then
            visible = not visible
            tween(Main, { Size = visible and UDim2.new(0, WINDOW_W, 0, WINDOW_H) or UDim2.new(0, WINDOW_W, 0, 0) }, 0.18)
        end
    end)

    -- open animation (quick fade+scale, not a big glow — kept subtle)
    Main.Size = UDim2.new(0, WINDOW_W, 0, 0)
    tween(Main, { Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H) }, 0.22, Enum.EasingStyle.Quint)

    local Window = { Tabs = {}, ScreenGui = ScreenGui }

    function Window:SetAccentColor(color3)
        Theme.Accent = color3
        for _, fn in ipairs(AccentListeners) do
            local ok = pcall(fn, color3)
            if not ok then end
        end
    end

    function Window:CreateTab(name)
        local TabBtn = new("TextButton", {
            Text = string.upper(name),
            Font = FONT_MED,
            TextSize = 12,
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, math.max(60, #name * 8 + 20), 1, 0),
            Parent = TabRow,
        })

        -- 3 balanced columns for boxes to auto-flow into
        local Page = new("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = PageHolder,
        })
        local ColLayout = new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Page,
        })
        local Columns = {}
        for i = 1, 3 do
            local Col = new("Frame", {
                Size = UDim2.new(1 / 3, -6, 1, 0),
                BackgroundTransparency = 1,
                LayoutOrder = i,
                Parent = Page,
            })
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Col })
            table.insert(Columns, Col)
        end

        local function select()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                tween(t.Btn, { TextColor3 = Theme.SubText }, 0.12)
            end
            Page.Visible = true
            tween(TabBtn, { TextColor3 = Theme.Text }, 0.12)
            tween(Underline, { Size = UDim2.new(0, TabBtn.AbsoluteSize.X, 0, 2), Position = UDim2.new(0, TabBtn.AbsolutePosition.X - TabRow.AbsolutePosition.X, 1, -2) }, 0.18)
        end

        TabBtn.MouseButton1Click:Connect(select)

        local TabObj = { Btn = TabBtn, Page = Page }
        table.insert(Window.Tabs, TabObj)
        if #Window.Tabs == 1 then
            task.defer(select) -- wait a frame so AbsoluteSize/Position are valid
        end

        local colCounter = 0
        function TabObj:CreateBox(boxTitle, column)
            colCounter = colCounter + 1
            local col = column or ((colCounter - 1) % 3) + 1

            local Box = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Box,
                Parent = Columns[col],
            })
            corner(Box, 4)
            stroke(Box, Theme.Stroke, 1)

            local Header = new("Frame", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Theme.BoxHeader,
                Parent = Box,
            })
            corner(Header, 4)
            new("Frame", {
                Size = UDim2.new(1, 0, 0, 4),
                Position = UDim2.new(0, 0, 1, -4),
                BackgroundColor3 = Theme.BoxHeader,
                BorderSizePixel = 0,
                Parent = Header,
            })
            local AccentTick = new("Frame", {
                Size = UDim2.new(0, 3, 0, 12),
                Position = UDim2.new(0, 8, 0.5, -6),
                BackgroundColor3 = Theme.Accent,
                Parent = Header,
            })
            onAccent(function(c) AccentTick.BackgroundColor3 = c end)
            new("TextLabel", {
                Text = boxTitle,
                Font = FONT_BOLD,
                TextSize = 12,
                TextColor3 = Theme.Text,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 18, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Header,
            })

            local Content = new("Frame", {
                Position = UDim2.new(0, 0, 0, 24),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = Box,
            })
            new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })
            pad(Content, 8, 8)

            local BoxObj = {}

            function BoxObj:AddLabel(text)
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Content,
                })
            end

            function BoxObj:AddButton(text, callback)
                local Btn = new("TextButton", {
                    Text = text, Font = FONT_MED, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Track, Size = UDim2.new(1, 0, 0, 24), Parent = Content,
                })
                corner(Btn, 3)
                Btn.MouseEnter:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Stroke }, 0.1) end)
                Btn.MouseLeave:Connect(function() tween(Btn, { BackgroundColor3 = Theme.Track }, 0.1) end)
                Btn.MouseButton1Click:Connect(function() if callback then callback() end end)
                return Btn
            end

            function BoxObj:AddCheckbox(text, default, callback)
                local state = default or false
                local Row = new("TextButton", {
                    Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18), Parent = Content,
                })
                local Box2 = new("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 0, 0.5, -7),
                    BackgroundColor3 = Theme.Track,
                    Parent = Row,
                })
                corner(Box2, 3)
                stroke(Box2, Theme.Stroke, 1)
                local Fill = new("Frame", {
                    Size = UDim2.new(1, -6, 1, -6),
                    Position = UDim2.new(0, 3, 0, 3),
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = state and 0 or 1,
                    Parent = Box2,
                })
                corner(Fill, 1)
                onAccent(function(c) Fill.BackgroundColor3 = c end)

                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 0),
                    Size = UDim2.new(1, -22, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Row,
                })

                local function set(v, fire)
                    state = v
                    tween(Fill, { BackgroundTransparency = state and 0 or 1 }, 0.1)
                    if fire ~= false and callback then callback(state) end
                end
                Row.MouseButton1Click:Connect(function() set(not state) end)
                return { Set = set, Get = function() return state end }
            end

            function BoxObj:AddSlider(text, min, max, default, callback)
                min, max = min or 0, max or 100
                local value = default or min

                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local ValueLabel = new("TextLabel", {
                    Text = tostring(value), Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -40, 0, 0), Size = UDim2.new(0, 40, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Right, Parent = Holder,
                })
                local Track = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 4),
                    BackgroundColor3 = Theme.Track, Parent = Holder,
                })
                corner(Track, 2)
                local Fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Theme.Accent, Parent = Track,
                })
                corner(Fill, 2)
                onAccent(function(c) Fill.BackgroundColor3 = c end)

                local dragging = false
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                    value = math.floor(min + (max - min) * rel)
                    ValueLabel.Text = tostring(value)
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

            function BoxObj:AddCombo(text, options, default, callback)
                options = options or {}
                local selected = default or options[1]
                local open = false

                local Holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 18), ClipsDescendants = true, BackgroundTransparency = 1, Parent = Content,
                })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 18),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Btn = new("TextButton", {
                    Text = tostring(selected) .. "  ▾", Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                    BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 18),
                    TextXAlignment = Enum.TextXAlignment.Right, Parent = Holder,
                })
                local List = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, #options * 18),
                    BackgroundTransparency = 1, Parent = Holder,
                })
                new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })
                for _, opt in ipairs(options) do
                    local OptBtn = new("TextButton", {
                        Text = tostring(opt), Font = FONT, TextSize = 11, TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
                        TextXAlignment = Enum.TextXAlignment.Right, Parent = List,
                    })
                    OptBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        Btn.Text = tostring(opt) .. "  ▾"
                        if callback then callback(opt) end
                        open = false
                        tween(Holder, { Size = UDim2.new(1, 0, 0, 18) }, 0.15)
                    end)
                end
                Btn.MouseButton1Click:Connect(function()
                    open = not open
                    tween(Holder, { Size = open and UDim2.new(1, 0, 0, 20 + #options * 18) or UDim2.new(1, 0, 0, 18) }, 0.15)
                end)
                return { Get = function() return selected end }
            end

            function BoxObj:AddKeybind(text, default, callback)
                local key = default or Enum.KeyCode.Unknown
                local listening = false
                local Row = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Row,
                })
                local KeyBtn = new("TextButton", {
                    Text = key.Name, Font = FONT, TextSize = 11, TextColor3 = Theme.Accent,
                    BackgroundColor3 = Theme.Track, Position = UDim2.new(1, -56, 0, -1), Size = UDim2.new(0, 56, 0, 18),
                    Parent = Row,
                })
                corner(KeyBtn, 3)
                onAccent(function(c) if not listening then KeyBtn.TextColor3 = c end end)
                KeyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    KeyBtn.Text = "..."
                    KeyBtn.TextColor3 = Theme.SubText
                end)
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        key = input.KeyCode
                        KeyBtn.Text = key.Name
                        KeyBtn.TextColor3 = Theme.Accent
                        listening = false
                    elseif not gpe and input.KeyCode == key and callback then
                        callback(key)
                    end
                end)
                return { Get = function() return key end }
            end

            -- Hue-slider accent picker (drop this in a "Settings"/"Config" box
            -- to let the end user recolor the whole menu live)
            function BoxObj:AddAccentPicker(text)
                local Holder = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = Content })
                new("TextLabel", {
                    Text = text or "Accent Color", Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = Holder,
                })
                local Track = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 10),
                    Parent = Holder,
                })
                corner(Track, 3)
                local Gradient = new("UIGradient", {
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
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                    Handle.Position = UDim2.new(rel, -2, 0, -2)
                    Window:SetAccentColor(Color3.fromHSV(rel, 1, 1))
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
    local Window = Library:CreateWindow("menu", { AccentColor = Color3.fromRGB(75, 130, 255) })

    local Main = Window:CreateTab("Main")
    local B1 = Main:CreateBox("General", 1)
    B1:AddCheckbox("Enabled", false, function(v) print("enabled:", v) end)
    B1:AddSlider("Value", 0, 100, 50, function(v) print("value:", v) end)
    B1:AddCombo("Mode", {"A", "B", "C"}, "A", function(v) print("mode:", v) end)

    local Settings = Window:CreateTab("Settings")
    local B2 = Settings:CreateBox("Appearance", 1)
    B2:AddAccentPicker("Accent Color")
    B2:AddKeybind("Toggle Menu", Enum.KeyCode.RightControl)
]]
