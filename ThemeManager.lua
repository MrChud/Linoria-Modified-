

local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.Folder = "ModernUI"
ThemeManager.Ext    = ".json"

-- Builtin presets: each carries Accent + Background (extra keys allowed).
ThemeManager.BuiltinThemes = {
    Default = {
        Accent     = Color3.fromRGB(128, 140, 160),
        Background = Color3.fromRGB(22, 22, 25),
    },
    Ocean = {
        Accent     = Color3.fromRGB(0, 168, 255),
        Background = Color3.fromRGB(12, 20, 32),
    },
    Fire = {
        Accent     = Color3.fromRGB(255, 84, 32),
        Background = Color3.fromRGB(28, 14, 12),
    },
    Lime = {
        Accent     = Color3.fromRGB(100, 225, 80),
        Background = Color3.fromRGB(10, 26, 14),
    },
    Royal = {
        Accent     = Color3.fromRGB(130, 90, 255),
        Background = Color3.fromRGB(18, 16, 30),
    },
    Galaxy = {
        Accent     = Color3.fromRGB(200, 120, 255),
        Background = Color3.fromRGB(10, 10, 28),
    },
}

local WindowRef  = nil
local Custom     = {}                 -- name -> {Accent=Color3, Background=Color3}
local Current    = "Default"
local BgMode     = "Solid"
local saveTask   = nil

local pickerBox, themeCombo, accentSlider, bgSlider, modeCombo, nameTb


---------------------------------------------------------------------
-- serialization
---------------------------------------------------------------------
local function c3t(c)  return { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) } end
local function t3c(t)  return Color3.fromRGB(math.clamp(t[1], 0, 255), math.clamp(t[2], 0, 255), math.clamp(t[3], 0, 255)) end


function ThemeManager:SetFolder(name)
    self.Folder = tostring(name)
    return self
end


function ThemeManager:EnsureFolder()
    if not (isfolder and makefolder) then return false end
    local path = ""
    for part in self.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then makefolder(path) end
    end
    return true
end


local function themesPath()
    return ThemeManager.Folder .. "/themes" .. ThemeManager.Ext
end


---------------------------------------------------------------------
-- save / load (debounced)
---------------------------------------------------------------------
function ThemeManager:ScheduleSave()
    if saveTask then saveTask:Cancel() end
    saveTask = task.delay(1, function()
        saveTask = nil
        self:Save()
    end)
end


function ThemeManager:Save()
    if not self:EnsureFolder() then return end
    local payload = {
        Current        = Current,
        BackgroundMode = BgMode,
        Custom         = Custom,
    }
    local encoded = {}
    for name, th in pairs(Custom) do
        encoded[name] = { Accent = c3t(th.Accent), Background = c3t(th.Background) }
    end
    payload.Custom = encoded
    pcall(writefile, themesPath(), HttpService:JSONEncode(payload))
end


function ThemeManager:Load()
    if not (isfile and isfile(themesPath())) then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(themesPath()))
    if not ok or type(data) ~= "table" then return end
    if type(data.Custom) == "table" then
        for name, th in pairs(data.Custom) do
            if type(th) == "table" and th.Accent and th.Background then
                Custom[name] = { Accent = t3c(th.Accent), Background = t3c(th.Background) }
            end
        end
    end
    if data.BackgroundMode == "Solid" or data.BackgroundMode == "Gradient" then
        BgMode = data.BackgroundMode
    end
    if type(data.Current) == "string" then
        Current = data.Current
    end
end


---------------------------------------------------------------------
-- applying
---------------------------------------------------------------------
local function unresolvedTheme(name)
    if ThemeManager.BuiltinThemes[name] then return ThemeManager.BuiltinThemes[name] end
    return Custom[name]
end


-- Apply a theme by name (preset or custom). Returns false if unknown.
function ThemeManager:ApplyTheme(name)
    if not WindowRef then return false end
    local th = unresolvedTheme(name)
    if not th then return false end

    Current = name
    for k, v in pairs(th) do
        if k ~= "Accent" then
            WindowRef:SetThemeColor(k, v, true)
        end
    end
    WindowRef:SetAccentColor(th.Accent or WindowRef:GetThemeColor("Accent"), true)

    -- auto-stick to Custom for the picker dropdown so edits feel live
    self:ScheduleSave()
    self:syncUI()
    return true
end


function ThemeManager:GetAccent()
    if not WindowRef then return Color3.fromRGB(128, 140, 160) end
    return WindowRef:GetAccentColor()
end


function ThemeManager:GetBackground()
    if not WindowRef then return Color3.fromRGB(22, 22, 25) end
    return WindowRef:GetThemeColor("Background")
end


-- touching color sliders switches to a live "Custom" theme
local function switchToCustom(accent, background)
    Current = "Custom"
    if accent     then WindowRef:SetAccentColor(accent) end
    if background then WindowRef:SetThemeColor("Background", background) end
    ThemeManager:ScheduleSave()
    ThemeManager:syncUI()
end


function ThemeManager:SetAccentColor(color)
    switchToCustom(color, nil)
end


function ThemeManager:SetBackgroundColor(color)
    switchToCustom(nil, color)
end


function ThemeManager:SetBackgroundMode(mode)
    if mode ~= "Solid" and mode ~= "Gradient" then return end
    BgMode = mode
    WindowRef:SetBackgroundMode(mode)
    ThemeManager:ScheduleSave()
    ThemeManager:syncUI()
end


function ThemeManager:GetBackgroundMode()
    return BgMode
end


-- Save current visuals under a named template (added to the dropdown).
function ThemeManager:AddTheme(name)
    name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or name == "Custom" or ThemeManager.BuiltinThemes[name] then return false end
    Custom[name] = { Accent = self:GetAccent(), Background = self:GetBackground() }
    Current = name
    self:ScheduleSave()
    self:syncUI()
    return true
end


function ThemeManager:RemoveTheme(name)
    if not Custom[name] then return false end
    Custom[name] = nil
    Current = "Default"
    self:ScheduleSave()
    self:ApplyTheme("Default")
    self:syncUI()
    return true
end


---------------------------------------------------------------------
-- build the picker UI (needs an existing tab)
---------------------------------------------------------------------
local function themeNames()
    local out = {}
    for name in pairs(ThemeManager.BuiltinThemes) do table.insert(out, name) end
    for name in pairs(Custom) do table.insert(out, name) end
    table.insert(out, "Custom")
    return out
end


function ThemeManager:syncUI()
    if not pickerBox then return end
    if themeCombo  then themeCombo:SetOptions(themeNames()) themeCombo:Set(Current) end
    if nameTb      then nameTb:Set("") end

    local th = unresolvedTheme(Current) or (Current == "Custom" and nil)
    local accent, background
    if th then
        accent    = th.Accent
        background = th.Background
    end
    local curAccent = accent or self:GetAccent()
    local curBg     = background or self:GetBackground()

    if accentSlider then accentSlider:Set(curAccent) end
    if bgSlider     then bgSlider:Set(curBg) end
    if modeCombo    then modeCombo:Set(BgMode) end
end


function ThemeManager:AddThemePicker(tab, opts)
    opts = opts or {}

    -- fallback: a pre-selected accent/background if none applied yet
    if not WindowRef:GetThemeColor("Accent") then
        WindowRef:SetAccentColor(ThemeManager.BuiltinThemes.Default.Accent, true)
    end
    if not WindowRef:GetThemeColor("Background") then
        WindowRef:SetThemeColor("Background", ThemeManager.BuiltinThemes.Default.Background, true)
    end

    pickerBox = tab:CreateBox(opts.Title or "Theme", opts.Column or 1)
    pickerBox:AddLabel("Theme")

    themeCombo = pickerBox:AddCombo("Themes", themeNames(), Current, function(v)
        if v and ThemeManager:ApplyTheme(v) then end
    end)

    accentSlider = pickerBox:AddHueSlider("Accent Color", self:GetAccent(), function(c)
        ThemeManager:SetAccentColor(c)
    end)

    modeCombo = pickerBox:AddCombo("Background Mode", { "Solid", "Gradient" }, BgMode, function(v)
        ThemeManager:SetBackgroundMode(v)
    end)

    bgSlider = pickerBox:AddHueSlider("Background Color", self:GetBackground(), function(c)
        ThemeManager:SetBackgroundColor(c)
    end)

    pickerBox:AddDivider()

    nameTb = pickerBox:AddTextBox("Theme Name", "", function(v) end)
    pickerBox:AddButton("Save Theme", function()
        if nameTb then ThemeManager:AddTheme(nameTb:Get()) end
    end)
    pickerBox:AddButton("Delete Theme", function()
        ThemeManager:RemoveTheme(Current)
    end, true)

    return pickerBox
end


---------------------------------------------------------------------
-- init
---------------------------------------------------------------------
function ThemeManager:Init(window)
    WindowRef = window
    self:Load()
    self:ApplyTheme(Current)
    WindowRef:SetBackgroundMode(BgMode)
    return self
end


return ThemeManager
