-- ThemeManager.lua
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "ModernUI_CheatMenu"

local PRESETS = {
    Default = {
        Background = Color3.fromRGB(22, 22, 22),
        Panel      = Color3.fromRGB(28, 28, 28),
        Header     = Color3.fromRGB(34, 34, 34),
        Track      = Color3.fromRGB(18, 18, 18),
        Text       = Color3.fromRGB(215, 215, 215),
        SubText    = Color3.fromRGB(135, 135, 135),
        Border     = Color3.fromRGB(72, 72, 72),
        Risky      = Color3.fromRGB(225, 60, 60),
        Accent     = Color3.fromRGB(60, 130, 220),
    },
    Fatality = {
        Background = Color3.fromRGB(14, 12, 12),
        Panel      = Color3.fromRGB(24, 20, 20),
        Header     = Color3.fromRGB(32, 26, 26),
        Track      = Color3.fromRGB(10, 8, 8),
        Text       = Color3.fromRGB(238, 230, 230),
        SubText    = Color3.fromRGB(150, 128, 128),
        Border     = Color3.fromRGB(92, 48, 48),
        Risky      = Color3.fromRGB(242, 55, 55),
        Accent     = Color3.fromRGB(205, 45, 45),
    },
    Midnight = {
        Background = Color3.fromRGB(9, 11, 18),
        Panel      = Color3.fromRGB(18, 21, 34),
        Header     = Color3.fromRGB(25, 29, 45),
        Track      = Color3.fromRGB(7, 9, 15),
        Text       = Color3.fromRGB(222, 226, 240),
        SubText    = Color3.fromRGB(118, 128, 158),
        Border     = Color3.fromRGB(52, 58, 96),
        Risky      = Color3.fromRGB(225, 60, 60),
        Accent     = Color3.fromRGB(88, 120, 255),
    },
    Ocean = {
        Background = Color3.fromRGB(10, 17, 20),
        Panel      = Color3.fromRGB(18, 29, 34),
        Header     = Color3.fromRGB(24, 37, 44),
        Track      = Color3.fromRGB(8, 13, 16),
        Text       = Color3.fromRGB(224, 235, 235),
        SubText    = Color3.fromRGB(118, 146, 152),
        Border     = Color3.fromRGB(44, 76, 88),
        Risky      = Color3.fromRGB(235, 90, 60),
        Accent     = Color3.fromRGB(44, 184, 218),
    },
    Slate = {
        Background = Color3.fromRGB(18, 20, 22),
        Panel      = Color3.fromRGB(26, 28, 31),
        Header     = Color3.fromRGB(33, 36, 40),
        Track      = Color3.fromRGB(14, 15, 17),
        Text       = Color3.fromRGB(215, 218, 222),
        SubText    = Color3.fromRGB(128, 132, 138),
        Border     = Color3.fromRGB(62, 66, 72),
        Risky      = Color3.fromRGB(224, 70, 64),
        Accent     = Color3.fromRGB(150, 160, 175),
    },
}

local State = {
    Window = nil,
    Current = "Default",
    Palette = {},
    Folder = "ModernUI",
}

local function clone(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function ensureFolder(f)
    if not isfolder(f) then createfolder(f) end
end

local function colorsEqual(a, b)
    return a ~= nil and b ~= nil and a.R == b.R and a.G == b.G and a.B == b.B
end

local PALETTE_PROPS = { "BackgroundColor3", "BorderColor3", "TextColor3", "ScrollBarImageColor3" }

local function recolorWalls(root, changeMap)
    local count = 0
    for _ in pairs(changeMap) do count = count + 1 end
    if count == 0 then return end

    local function walk(inst)
        for _, prop in ipairs(PALETTE_PROPS) do
            local v = inst[prop]
            if typeof(v) == "Color3" then
                local nc = changeMap[v]
                if nc then inst[prop] = nc end
            end
        end
        for _, child in ipairs(inst:GetChildren()) do walk(child) end
    end
    walk(root)
end

local ThemeManager = {}
ThemeManager.__index = ThemeManager

function ThemeManager:Init(Window, opts)
    State.Window = Window
    opts = opts or {}
    State.Folder = opts.Folder or "ModernUI"
    State.Palette = clone(PRESETS.Default)
    ensureFolder(State.Folder)

    local themesFile = State.Folder .. "/themes.json"
    if isfile(themesFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(themesFile)) end)
        if ok and type(data) == "table" then
            if data.Current and PRESETS[data.Current] then
                self:ApplyPreset(data.Current, false)
            end
            if data.Accent then
                local a = data.Accent
                State.Palette.Accent = Color3.fromRGB(a[1], a[2], a[3])
                if State.Window then State.Window:SetAccentColor(State.Palette.Accent, true) end
            end
        end
    end
    return self
end

function ThemeManager:ApplyPreset(name, save)
    local preset = PRESETS[name]
    if not preset then return self end

    local changeMap = {}
    for k, v in pairs(preset) do
        if k ~= "Accent" then
            local old = State.Palette[k]
            if old and not colorsEqual(old, v) then
                changeMap[old] = v
            end
        end
    end

    State.Palette = clone(preset)
    State.Current = name

    local root = PlayerGui:FindFirstChild(GUI_NAME)
    if root then recolorWalls(root, changeMap) end
    if State.Window and preset.Accent then
        State.Window:SetAccentColor(preset.Accent, true)
    end

    if save ~= false then self:Save() end
    return self
end

function ThemeManager:SetAccent(color3)
    State.Palette.Accent = color3 or PRESETS.Default.Accent
    if State.Window then State.Window:SetAccentColor(State.Palette.Accent, true) end
    self:Save()
    return self
end

function ThemeManager:Reset()
    return self:ApplyPreset("Default")
end

function ThemeManager:CurrentPreset()
    return State.Current
end

function ThemeManager:Save()
    ensureFolder(State.Folder)
    local a = State.Palette.Accent or PRESETS.Default.Accent
    writefile(State.Folder .. "/themes.json", HttpService:JSONEncode({
        Current = State.Current,
        Accent = { a.R * 255, a.G * 255, a.B * 255 },
    }))
end

function ThemeManager:AddThemePicker(tab, opts)
    opts = opts or {}
    local E = tab:CreateBox("Theme", opts.Column or 1)

    local names = {}
    for n in pairs(PRESETS) do table.insert(names, n) end
    table.sort(names)

    E:AddCombo("Preset", names, State.Current, function(v)
        self:ApplyPreset(v)
    end)

    E:AddColorPicker("Accent Color", State.Palette.Accent or PRESETS.Default.Accent, function(c)
        self:SetAccent(c)
    end)

    E:AddButton("Reset Default", function()
        self:Reset()
    end)

    return self
end

return ThemeManager
