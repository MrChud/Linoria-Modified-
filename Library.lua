

local Library = {}
Library.ThemeList = {}

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local UIBlox


---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function new(inst, props, parent)
    local obj = Instance.new(inst)
    if props then
        for k, v in pairs(props) do obj[k] = v end
    end
    if parent then obj.Parent = parent end
    return obj
end


local function tween(obj, props, time)
    if TweenService and time and time > 0 then
        local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end
    for k, v in pairs(props) do obj[k] = v end
end


local function mouseInside(frame, pos)
    local p, a = frame.AbsolutePosition, frame.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + a.X and pos.Y >= p.Y and pos.Y <= p.Y + a.Y
end


local function sliderDrag(fill, minSize, callback, endCallback)
    local dragging = false
    local update = function()
        local p = UserInputService:GetMouseLocation()
        local track = fill.Parent
        local wid = math.max(track.AbsoluteSize.X - minSize, 1)
        local x = p.X - track.AbsolutePosition.X - minSize / 2
        callback(math.clamp(x / wid, 0, 1))
    end
    fill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then
                dragging = false
                if endCallback then endCallback() end
            end
        end
    end)
end


local function hueColorSeq()
    local keys = {}
    for i = 0, 11 do
        local h = i / 12
        local c = Color3.fromHSV(h, 1, 1)
        table.insert(keys, ColorSequenceKeypoint.new(h, c))
    end
    return ColorSequence.new(keys)
end


local function hexToRGB(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end


local function rgbToHex(c)
    return string.format("%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end


---------------------------------------------------------------------
-- theme
---------------------------------------------------------------------
Library.Theme = {
    Accent         = Color3.fromRGB(128, 140, 160),
    Text           = Color3.fromRGB(236, 238, 244),
    SubText        = Color3.fromRGB(148, 153, 168),
    Header         = Color3.fromRGB(200, 205, 220),
    Background     = Color3.fromRGB(22, 22, 26),
    BackgroundDark = Color3.fromRGB(13, 13, 16),
    BackgroundLight= Color3.fromRGB(31, 32, 38),
    TabRow         = Color3.fromRGB(17, 17, 21),
    SideBar        = Color3.fromRGB(26, 27, 33),
}


function Library:syncAccent(win, color, instant)
    for i = 1, #win._accent do
        local f = win._accent[i]
        if f and f.Parent then
            tween(f, { BackgroundColor3 = color }, instant and 0 or 0.1)
        end
    end
end


function Library:ThemeApply(win, key, value, instant)
    if key == "Accent" then
        Library.Theme.Accent = value
        Library:syncAccent(win, value, instant)
    else
        Library.Theme[key] = value
        local binds = win._bound[key]
        if binds then
            for i = 1, #binds do
                tween(binds[i], { BackgroundColor3 = value }, instant and 0 or 0.12)
            end
        end
        if key == "Background" then
            win:SetBackgroundMode(win.BackgroundMode)
        end
    end
    win.CurrentTheme[key] = value
end


---------------------------------------------------------------------
-- window
---------------------------------------------------------------------
function Library:CreateWindow(config)
    config = config or {}
    if UIBlox and UIBlox.Parent then UIBlox:Destroy() end

    local size = config.Size or UDim2.fromOffset(405, 590)

    UIBlox = new("ScreenGui", {
        Name            = "MyLibrary",
        IgnoreGuiInset  = true,
        ResetOnSpawn    = false,
        ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    local Main = new("Frame", {
        Name               = "Main",
        BackgroundColor3   = Library.Theme.Background,
        BorderSizePixel    = 0,
        Position           = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint        = Vector2.new(0.5, 0.5),
        Size               = size,
    }, UIBlox)

    local BgGradient = new("Frame", {
        Name               = "BgGradient",
        BackgroundColor3   = Library.Theme.BackgroundDark,
        BorderSizePixel    = 0,
    }, Main)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(1, 1, 1)) }, BgGradient)

    local window = {}
    window.Configuration  = config
    window.Main           = Main
    window.BgGradient     = BgGradient
    window.Pages          = {}
    window.TabButtons     = {}
    window.Elements       = {}
    window._bound         = { Background = {}, BackgroundDark = {}, BackgroundLight = {} }
    window._accent        = {}
    window.BackgroundMode = "Solid"
    window.CurrentTheme   = {}
    for k, v in pairs(Library.Theme) do window.CurrentTheme[k] = v end
    table.insert(Library.ThemeList, window)

    window.bindColor = function(self, key, frame)
        if not self._bound[key] then self._bound[key] = {} end
        table.insert(self._bound[key], frame)
    end
    window.bindAccent = function(self, frame)
        table.insert(self._accent, frame)
        frame.BackgroundColor3 = Library.Theme.Accent
    end

    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 46, 55) }, Main)

    local TitleBar = new("Frame", {
        BackgroundColor3      = Library.Theme.SideBar,
        BorderSizePixel       = 0,
        Size                  = UDim2.new(1, 0, 0, 33),
    }, Main)
    window.TitleBar = TitleBar

    local Title = new("TextLabel", {
        BackgroundTransparency = 1,
        Font          = Enum.Font.GothamBold,
        Size          = UDim2.new(0, 150, 1, 0),
        Text          = config.Title or "Defusal Hub",
        TextColor3    = Library.Theme.Text,
        TextSize      = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, TitleBar)
    new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, Title)

    if config.SubTitle then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Font          = Enum.Font.Gotham,
            Position      = UDim2.new(0, 170, 0, 0),
            Size          = UDim2.new(1, -170, 1, 0),
            Text          = config.SubTitle,
            TextColor3    = Library.Theme.SubText,
            TextSize      = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, TitleBar)
    end

    local AccentBar = new("Frame", {
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel  = 0,
        Size             = UDim2.new(0, 4, 1, 0),
        ZIndex           = 2,
    }, TitleBar)
    window.bindAccent(AccentBar)

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            window.Dragging = { off = input.Position - Main.AbsolutePosition }
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if window.Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            Main.Position = UDim2.fromOffset(
                math.clamp(input.Position.X - window.Dragging.off.X, -Main.AbsoluteSize.X + 40, 9999),
                math.clamp(input.Position.Y - window.Dragging.off.Y, -Main.AbsoluteSize.Y + 40, 9999)
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            window.Dragging = false
        end
    end)

    local TabRow = new("Frame", {
        BackgroundColor3      = Library.Theme.TabRow,
        BorderSizePixel       = 0,
        Position              = UDim2.new(0, 0, 0, 33),
        Size                  = UDim2.new(1, 0, 0, 27),
    }, Main)
    window.bindColor("Background", TabRow)

    local TabScroll = new("ScrollingFrame", {
        CanvasSize          = UDim2.new(2, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel     = 0,
        ScrollBarThickness  = 0,
        ScrollingDirection  = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        Size                = UDim2.new(1, 0, 1, 0),
    }, TabRow)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, 2),
    }, TabScroll)
    new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, TabScroll)

    local PageHolder = new("Frame", {
        BackgroundColor3      = Library.Theme.Background,
        BorderSizePixel       = 0,
        Position              = UDim2.new(0, 0, 0, 60),
        Size                  = UDim2.new(1, 0, 1, -60),
    }, Main)
    window.bindColor("Background", PageHolder)
    window:bindColor("Background", Main)

    local BoxHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, PageHolder)

    window.SelectTab = function(self, tabObjOrName)
        local target = tabObjOrName
        if type(tabObjOrName) == "string" then
            target = window._tabObjs[tabObjOrName]
        end
        if not target then return end
        for name, tb in pairs(window.TabButtons) do
            local on = tb.TabName == target.TabName
            tb.Selected.Visible = on
            tb.Label.TextColor3 = on and Library.Theme.Text or Library.Theme.SubText
        end
        for name, pg in pairs(window.Pages) do
            pg.Visible = (name == target.TabName)
        end
        window.ActiveTab = target.TabName
    end

    window.CreateTab = function(self, name)
        local page = new("Frame", { BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 1, 0) }, BoxHolder)

        local tabBtn = new("Frame", {
            BackgroundColor3 = Library.Theme.TabRow,
            BorderSizePixel  = 0,
            Size             = UDim2.new(0, 60, 1, 0),
            LayoutOrder      = #window.TabButtons + 1,
        }, TabScroll)

        local selected = new("Frame", {
            BackgroundColor3 = Library.Theme.Accent,
            BorderSizePixel  = 0,
            Size             = UDim2.new(1, 0, 0, 2),
            Visible          = false,
            ZIndex           = 3,
        }, tabBtn)
        window.bindAccent(selected)

        local label = new("TextLabel", {
            BackgroundTransparency = 1,
            Font          = Enum.Font.GothamBold,
            Text          = name,
            TextColor3    = Library.Theme.SubText,
            TextSize      = 13,
            Size          = UDim2.new(1, 0, 1, 0),
            ZIndex        = 2,
        }, tabBtn)

        tabBtn.TabName = name
        tabBtn.Selected = selected
        tabBtn.Label = label
        tabBtn.Size = UDim2.new(0, math.clamp(#name * 9 + 24, 52, 95), 1, 0)
        tabBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                window:SelectTab(tabBtn)
            end
        end)

        window.Pages[name] = page
        window.TabButtons[name] = tabBtn
        window._tabObjs = window._tabObjs or {}

        local tabObj = { TabName = name, Frame = page, Container = page }
        window._tabObjs[name] = tabObj

        table.insert(window.Elements, {
            Tab = name, Box = "", Key = "Active", Type = "Tab",
            Get = function() return window.ActiveTab == name end,
            Set = function(v)
                if v and window.ActiveTab ~= name then window:SelectTab(tabObj) end
            end,
        })

        tabObj.CreateBox = function(self2, title, col)
            return createBox(window, tabObj, title, col or 1)
        end

        return tabObj
    end

    window.GetAccentColor = function(self) return Library.Theme.Accent end
    window.SetAccentColor = function(self, color, instant)
        Library.Theme.Accent = color
        Library:syncAccent(window, color, instant)
    end
    window.GetThemeColor = function(self, key)
        if key == "Accent" then return Library.Theme.Accent end
        return Library.Theme[key] or Library.Theme.Background
    end
    window.SetThemeColor = function(self, key, value, instant)
        Library:ThemeApply(window, key, value, instant)
    end
    window.GetBackgroundMode = function(self) return window.BackgroundMode end
    window.SetBackgroundMode = function(self, mode)
        window.BackgroundMode = mode
        BgGradient.Visible = (mode == "Gradient")
        tween(Main, { BackgroundColor3 = Library.Theme.Background }, 0.15)
    end
    window.Toggle = function(self) Main.Visible = not Main.Visible end
    window.Close = function(self)
        if UIBlox then UIBlox:Destroy() end
    end

    local Intro = new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 20,
    }, Main)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 46, 55) }, Intro)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Font     = Enum.Font.GothamBold,
        Position = UDim2.new(0, 20, 0, 200),
        Size     = UDim2.new(1, -40, 0, 30),
        Text     = (config.Title or "My Library") .. "  |  " .. (config.SubTitle or ""),
        TextColor3 = Library.Theme.Text,
        TextSize = 22,
    }, Intro)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font     = Enum.Font.Gotham,
        Position = UDim2.new(0, 20, 0, 240),
        Size     = UDim2.new(1, -40, 0, 20),
        Text     = "press any key to close",
        TextColor3 = Library.Theme.SubText,
        TextSize = 12,
    }, Intro)

    local introClose = new("Frame", {
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 20, 0, 280),
        Size             = UDim2.new(0, 100, 0, 30),
    }, Intro)
    window.bindAccent(introClose)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Size  = UDim2.new(1, 0, 1, 0),
        Text  = "Close",
        TextColor3 = Library.Theme.Text,
        TextSize = 13,
    }, introClose)
    introClose.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Intro.Visible = false
        end
    end)

    task.defer(function()
        local first = next(window.Pages)
        if first and window._tabObjs[first] then
            window:SelectTab(window._tabObjs[first])
        end
    end)

    return window
end


---------------------------------------------------------------------
-- boxes / elements
---------------------------------------------------------------------
local BoxMT = {}
Library.Box = BoxMT
local BoxIndex = setmetatable({}, { __index = BoxMT })


local function regElement(win, tabName, boxObj, etype, key, get, set, extra)
    table.insert(win.Elements, {
        Tab = tabName,
        Box = boxObj.Title,
        Key = key,
        Type = etype,
        Get = get,
        Set = set,
        SetOptions = extra and extra.SetOptions or nil,
    })
end


local function createBox(win, tab, title, col)
    local frame = new("Frame", {
        BackgroundColor3 = Library.Theme.BackgroundLight,
        BorderSizePixel  = 0,
        Size             = UDim2.new(0, 190, 0, 90),
        Position         = UDim2.new(0, 12, 0, 8),
    }, tab.Container)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 46, 55) }, frame)

    local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 29) }, frame)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Size  = UDim2.new(1, -20, 1, 0),
        Text  = title,
        TextColor3 = Library.Theme.Header,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 9) }, header)
    new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 27),
        Size             = UDim2.new(1, -24, 0, 1),
    }, header)

    local content = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0, 29),
        Size             = UDim2.new(1, 0, 1, -29),
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, frame)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
    }, content)
    new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, content)

    local box = {
        Window = win,
        Tab    = tab.TabName,
        Title  = title,
        Columns = col,
        Container = tab.Container,
        Frame  = frame,
        Content = content,
    }
    return setmetatable(box, BoxIndex)
end


---------------------------------------------------------------------
-- element builders
---------------------------------------------------------------------
function BoxMT:AddFullWidth(height)
    local obj = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, -14, 0, height),
        LayoutOrder      = #self.Content:GetChildren() + 1,
    }, self.Content)
    return obj
end


function BoxMT:AddLabel(text)
    local obj = self:AddFullWidth(24)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Size  = UDim2.new(1, 0, 1, 0),
        Text  = text,
        TextColor3 = Library.Theme.Header,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, obj)
    return obj
end


function BoxMT:AddParagraph(title, body)
    local obj = self:AddFullWidth(42)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Position = UDim2.new(0, 12, 0, 0),
        Size  = UDim2.new(1, -24, 0, 18),
        Text  = title,
        TextColor3 = Library.Theme.Header,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 19),
        Size  = UDim2.new(1, -24, 0, 18),
        Text  = body or "",
        TextColor3 = Library.Theme.SubText,
        TextSize = 11,
        TextWrap = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)
    return obj
end


function BoxMT:AddDivider()
    local obj = self:AddFullWidth(10)
    new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, -24, 0, 1),
    }, obj)
    return obj
end


function BoxMT:AddCheckbox(text, default, callback)
    local obj = self:AddFullWidth(34)
    local btn = new("Frame", {
        BackgroundColor3 = Library.Theme.BackgroundLight,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 7),
        Size             = UDim2.new(0, 90, 0, 20),
    }, obj)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(55, 56, 65) }, btn)

    local box = new("Frame", {
        BackgroundColor3      = Library.Theme.Accent,
        BackgroundTransparency = (default and 0 or 1),
        BorderSizePixel       = 0,
        Size                  = UDim2.new(0, 18, 0, 18),
    }, btn)
    self.Window:bindAccent(box)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 0),
        Size  = UDim2.new(1, -24, 1, 0),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, obj)

    local value = default == true
    local handle = {}
    handle.Get = function() return value end
    handle.Set = function(v)
        value = v == true
        box.BackgroundTransparency = value and 0 or 1
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            handle.Set(not value)
            if callback then pcall(callback, value) end
        end
    end)

    regElement(self.Window, self.Tab, self, "Checkbox", text, handle.Get, handle.Set)
    return handle
end


function BoxMT:AddSlider(text, options, callback)
    local min   = options.Min or 0
    local max   = options.Max or 100
    local def   = options.Default or min
    local suffix = options.Suffix or ""
    local value = math.clamp(def, min, max)

    local obj = self:AddFullWidth(40)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 0),
        Size  = UDim2.new(0, 140, 0, 16),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)
    local valLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Position = UDim2.new(0, 160, 0, 0),
        Size  = UDim2.new(1, -190, 0, 16),
        Text  = tostring(def) .. suffix,
        TextColor3 = Library.Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, obj)

    local track = new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 24),
        Size             = UDim2.new(1, -24, 0, 8),
    }, obj)
    local fill = new("Frame", {
        BackgroundColor3  = Library.Theme.Accent,
        BorderSizePixel   = 0,
        Size              = UDim2.fromScale((value - min) / (max - min) or 0, 1),
    }, track)
    self.Window:bindAccent(fill)
    local knob = new("Frame", {
        BackgroundColor3 = Library.Theme.Text,
        BorderSizePixel  = 0,
        Position         = UDim2.fromScale((value - min) / (max - min) or 0, 0.5),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Size             = UDim2.fromOffset(10, 10),
    }, track)

    local handle = {}
    handle.Get = function() return math.floor(value) end
    handle.Set = function(v)
        value = math.clamp(v, min, max)
        local p = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(p, 1)
        knob.Position = UDim2.fromScale(p, 0.5)
        valLabel.Text = tostring(math.floor(value)) .. suffix
        if callback then pcall(callback, math.floor(value)) end
    end

    sliderDrag(fill, 6, function(p)
        handle.Set(min + (max - min) * p)
    end)

    regElement(self.Window, self.Tab, self, "Slider", text, handle.Get, handle.Set)
    handle.Set(value)
    return handle
end


function BoxMT:AddCombo(text, list, default, callback)
    local options = list or {}
    local value = default and tostring(default) or (options[1] and tostring(options[1]) or "")
    local obj = self:AddFullWidth(34)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 7),
        Size  = UDim2.new(0, 100, 0, 20),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)

    local btn = new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 105, 0, 7),
        Size             = UDim2.new(1, -120, 0, 20),
    }, obj)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(55, 56, 65) }, btn)

    local selectedLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Size  = UDim2.new(1, -6, 1, 0),
        Text  = "",
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)

    local dd = new("Frame", {
        BackgroundColor3 = Library.Theme.BackgroundLight,
        BorderSizePixel  = 0,
        Visible          = false,
        Size             = UDim2.fromOffset(math.max(btn.AbsoluteSize.X, 90), 0),
        ZIndex           = 10,
    }, self.Window.Main)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 46, 55) }, dd)
    local ddScroll = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Size             = UDim2.new(1, 0, 1, 0),
    }, dd)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }, ddScroll)

    local refreshDD = function()
        for _, c in ipairs(ddScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, opt in ipairs(options) do
            local row = new("Frame", {
                BackgroundColor3 = (tostring(opt) == value) and Library.Theme.Background or Library.Theme.BackgroundLight,
                BorderSizePixel  = 0,
                Size             = UDim2.new(1, 0, 0, 20),
                LayoutOrder      = i,
            }, ddScroll)
            row.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    handle.Set(opt)
                    dd.Visible = false
                    if callback then pcall(callback, tostring(opt), opt) end
                end
            end)
            new("TextLabel", {
                BackgroundTransparency = 1,
                Font  = Enum.Font.Gotham,
                Size  = UDim2.new(1, 0, 1, 0),
                Text  = tostring(opt),
                TextColor3 = (tostring(opt) == value) and Library.Theme.Accent or Library.Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Center,
            }, row)
        end
        dd.Size = UDim2.new(0, math.max(btn.AbsoluteSize.X, 90), 0, math.min(#options * 21, 105))
        dd.Position = UDim2.fromOffset(
            btn.AbsolutePosition.X - self.Window.Main.AbsolutePosition.X,
            btn.AbsolutePosition.Y - self.Window.Main.AbsolutePosition.Y + btn.AbsoluteSize.Y
        )
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dd.Visible = not dd.Visible
            if dd.Visible then refreshDD() end
        end
    end)

    local handle = {}
    handle.Get = function() return value end
    handle.Set = function(v)
        value = tostring(v)
        selectedLbl.Text = value
    end
    handle.SetOptions = function(list2)
        options = list2 or {}
        local found = false
        for _, o in ipairs(options) do
            if tostring(o) == value then found = true break end
        end
        if not found then value = options[1] and tostring(options[1]) or "" end
        handle.Set(value)
    end

    handle.Set(value)
    regElement(self.Window, self.Tab, self, "Combo", text, handle.Get, handle.Set, { SetOptions = handle.SetOptions })
    return handle
end


function BoxMT:AddButton(text, callback, red)
    local obj = self:AddFullWidth(30)
    local btn = new("Frame", {
        BackgroundColor3 = red and Color3.fromRGB(180, 60, 60) or Library.Theme.Background,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 5),
        Size             = UDim2.new(1, -24, 0, 20),
    }, obj)
    new("UIStroke", { Thickness = 1, Color = red and Color3.fromRGB(220, 90, 90) or Color3.fromRGB(70, 72, 82) }, btn)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Size  = UDim2.new(1, 0, 1, 0),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
    }, btn)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if callback then pcall(callback) end
        end
    end)
    return btn
end


function BoxMT:AddKeybind(text, defaultKey, mode, callback)
    if type(mode) == "function" then
        callback = mode
        mode = nil
    end
    local current = defaultKey or Enum.KeyCode.F
    local obj = self:AddFullWidth(34)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 7),
        Size  = UDim2.new(0, 130, 0, 20),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)

    local btn = new("Frame", {
        BackgroundColor3 = Library.Theme.BackgroundLight,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 135, 0, 7),
        Size             = UDim2.new(1, -160, 0, 20),
    }, obj)
    local btnLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.GothamBold,
        Size  = UDim2.new(1, 0, 1, 0),
        Text  = current.Name,
        TextColor3 = Library.Theme.Accent,
        TextSize = 12,
    }, btn)

    local capturing = false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            capturing = true
            btnLabel.Text = "..."
        end
    end)
    UserInputService.InputBegan:Connect(function(input)
        if not capturing then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            capturing = false
            current = input.KeyCode
            btnLabel.Text = current.Name
            if callback then pcall(callback, current) end
        end
    end)

    local handle = {}
    handle.Get = function() return current end
    handle.Set = function(k)
        current = k
        btnLabel.Text = k and k.Name or "None"
    end
    regElement(self.Window, self.Tab, self, "Keybind", text, handle.Get, handle.Set)
    return handle
end


function BoxMT:AddTextBox(text, default, callback)
    local obj = self:AddFullWidth(44)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 3),
        Size  = UDim2.new(1, -24, 0, 14),
        Text  = text,
        TextColor3 = Library.Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)

    local box = new("TextBox", {
        BackgroundColor3   = Library.Theme.Background,
        BorderSizePixel    = 0,
        Position           = UDim2.new(0, 12, 0, 20),
        Size               = UDim2.new(1, -24, 0, 18),
        Font               = Enum.Font.Gotham,
        PlaceholderText    = "type here...",
        Text               = tostring(default or ""),
        TextColor3         = Library.Theme.Text,
        TextSize           = 12,
        PlaceholderColor3  = Library.Theme.SubText,
        ClearTextOnFocus   = false,
    }, obj)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(55, 56, 65) }, box)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, box)

    box.FocusLost:Connect(function(enter)
        if callback then pcall(callback, box.Text) end
    end)

    local handle = {}
    handle.Get = function() return box.Text end
    handle.Set = function(v) box.Text = tostring(v or "") end
    regElement(self.Window, self.Tab, self, "Textbox", text, handle.Get, handle.Set)
    return handle
end


function BoxMT:AddColorPicker(text, default, callback)
    local value = default or Library.Theme.Accent
    local obj = self:AddFullWidth(40)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 11),
        Size  = UDim2.new(0, 120, 0, 16),
        Text  = text,
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)

    local swatch = new("Frame", {
        BackgroundColor3 = value,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 136, 0, 9),
        Size             = UDim2.new(0, 40, 0, 18),
    }, obj)
    new("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1) }, swatch)

    local popup = new("Frame", {
        BackgroundColor3 = Library.Theme.BackgroundLight,
        BorderSizePixel  = 0,
        Visible          = false,
        Size             = UDim2.new(0, 160, 0, 158),
        ZIndex           = 20,
    }, self.Window.Main)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 46, 55) }, popup)

    local hueBar = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 10, 0, 10),
        Size             = UDim2.new(1, -20, 0, 126),
    }, popup)
    new("UIGradient", { Color = hueColorSeq() }, hueBar)
    local bright = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 1, 0),
    }, hueBar)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)) }, bright)

    local prev = new("Frame", {
        BackgroundColor3 = value,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 10, 0, 138),
        Size             = UDim2.new(0, 60, 0, 12),
    }, popup)
    local hexTb = new("TextBox", {
        BackgroundColor3 = Library.Theme.Background,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 76, 0, 138),
        Size             = UDim2.new(1, -86, 0, 12),
        Font             = Enum.Font.Code,
        Text             = rgbToHex(value),
        TextColor3       = Library.Theme.Text,
        TextSize         = 9,
        PlaceholderColor3 = Library.Theme.SubText,
    }, popup)

    local apply = function()
        prev.BackgroundColor3 = value
        swatch.BackgroundColor3 = value
        hexTb.Text = rgbToHex(value)
    end

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local p = UserInputService:GetMouseLocation()
            if popup.Visible and mouseInside(bright, p) then
                local rx = math.clamp((p.X - bright.AbsolutePosition.X) / bright.AbsoluteSize.X, 0, 1)
                local ry = math.clamp((p.Y - bright.AbsolutePosition.Y) / bright.AbsoluteSize.Y, 0, 1)
                local c = Color3.fromHSV(rx, 1, 1 - ry)
                value = c
                apply()
                if callback then pcall(callback, value) end
            end
        end
    end)

    hexTb.FocusLost:Connect(function()
        local c = hexToRGB(hexTb.Text)
        if c then
            value = c
            apply()
            if callback then pcall(callback, value) end
        else
            hexTb.Text = rgbToHex(value)
        end
    end)

    swatch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            popup.Visible = not popup.Visible
            if popup.Visible then
                popup.Position = UDim2.fromOffset(
                    swatch.AbsolutePosition.X - self.Window.Main.AbsolutePosition.X,
                    swatch.AbsolutePosition.Y - self.Window.Main.AbsolutePosition.Y + swatch.AbsoluteSize.Y
                )
            end
        end
    end)

    local handle = {}
    handle.Get = function() return value end
    handle.Set = function(c)
        value = c
        apply()
    end
    regElement(self.Window, self.Tab, self, "Color", text, handle.Get, handle.Set)
    return handle
end


function BoxMT:AddHueSlider(text, defaultColor, callback)
    local value = defaultColor or Library.Theme.Accent
    local h, s, v = value:ToHSV()

    local obj = self:AddFullWidth(48)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Gotham,
        Position = UDim2.new(0, 12, 0, 0),
        Size  = UDim2.new(0, 130, 0, 14),
        Text  = text,                                     -- static name, never a color
        TextColor3 = Library.Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, obj)
    local cv = new("TextLabel", {
        BackgroundTransparency = 1,
        Font  = Enum.Font.Code,
        Position = UDim2.new(0, 150, 0, 0),
        Size  = UDim2.new(1, -170, 0, 14),
        Text  = rgbToHex(value),                          -- hex string, not a Color3
        TextColor3 = Library.Theme.SubText,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, obj)

    local hueBar = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 16),
        Size             = UDim2.new(1, -24, 0, 12),
    }, obj)
    new("UIGradient", { Color = hueColorSeq() }, hueBar)

    local brightBar = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 12, 0, 30),
        Size             = UDim2.new(1, -24, 0, 8),
    }, obj)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)) }, brightBar)

    local apply = function()
        cv.Text = rgbToHex(value)
        if callback then pcall(callback, value) end
    end

    sliderDrag(hueBar, 0, function(px)
        h = math.clamp(px, 0, 1)
        value = Color3.fromHSV(h, 1, math.max(v, 0.001))
        apply()
    end)
    sliderDrag(brightBar, 0, function(px)
        v = math.clamp(1 - px, 0.001, 1)
        value = Color3.fromHSV(h, 1, v)
        apply()
    end)

    local handle = {}
    handle.Get = function() return value end
    handle.Set = function(c)
        value = c
        h, s, v = value:ToHSV()
        cv.Text = rgbToHex(value)
    end
    handle.Set(value)
    regElement(self.Window, self.Tab, self, "Color", text, handle.Get, handle.Set)
    return handle
end


return Library
