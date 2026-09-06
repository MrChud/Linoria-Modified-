local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.Presets = {
    Default = Color3.fromRGB(60, 130, 220),
    Ocean   = Color3.fromRGB(0, 168, 255),
    Fire    = Color3.fromRGB(255, 84, 32),
    Lime    = Color3.fromRGB(120, 255, 80),
    Royal   = Color3.fromRGB(130, 90, 255),
    Blush   = Color3.fromRGB(255, 90, 140),
}

ThemeManager.Folder = "ModernUI"

local WindowRef    = nil
local Current      = "Default"
local CustomAccent = nil
local saveTask     = nil


local function themesPath()
    return ThemeManager.Folder .. "/themes.json"
end


local function ensureFolder()
    if not (isfolder and makefolder and isfile and readfile and writefile) then return false end
    local path = ""
    for part in ThemeManager.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then makefolder(path) end
    end
    return true
end


function ThemeManager:SetFolder(name)
    ThemeManager.Folder = tostring(name)
    return self
end


function ThemeManager:Save()
    ensureFolder()
    local payload = { Current = Current }
    if CustomAccent then
        payload.Accent = { math.round(CustomAccent.R * 255), math.round(CustomAccent.G * 255), math.round(CustomAccent.B * 255) }
    end
    pcall(writefile, themesPath(), HttpService:JSONEncode(payload))
end


function ThemeManager:ScheduleSave()
    if saveTask then saveTask:Cancel() end
    saveTask = task.delay(1, function()
        saveTask = nil
        ThemeManager:Save()
    end)
end


function ThemeManager:Load()
    if not (isfile and isfile(themesPath())) then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(themesPath()))
    if ok and type(data) == "table" then
        if type(data.Current) == "string" then Current = data.Current end
        if type(data.Accent) == "table" and data.Accent[1] then
            CustomAccent = Color3.fromRGB(
                math.clamp(data.Accent[1], 0, 255),
                math.clamp(data.Accent[2] or 255, 0, 255),
                math.clamp(data.Accent[3] or 255, 0, 255)
            )
        end
    end
end


local function getAccent()
    if CustomAccent then return CustomAccent end
    return ThemeManager.Presets[Current] or ThemeManager.Presets.Default
end


function ThemeManager:ApplyAccent(color, instant)
    CustomAccent = color
    if WindowRef and WindowRef.SetAccentColor then
        WindowRef:SetAccentColor(color, instant or false)
    end
    ThemeManager:ScheduleSave()
end


function ThemeManager:Init(window, opts)
    opts = opts or {}
    WindowRef = window
    if opts.Folder then ThemeManager.Folder = tostring(opts.Folder) end
    ThemeManager:Load()
    if WindowRef and WindowRef.SetAccentColor then
        WindowRef:SetAccentColor(getAccent(), true)
    end
    return self
end


function ThemeManager:AddThemePicker(tab, opts)
    opts = opts or {}
    local box = tab:CreateBox(opts.Title or "Theme", opts.Column or 1)
    box:AddLabel("Theme")

    local presetNames = {}
    for k in pairs(ThemeManager.Presets) do table.insert(presetNames, k) end

    local combo = box:AddCombo("Preset", presetNames, Current, function(v)
        if v and v ~= "Custom" and ThemeManager.Presets[v] then
            Current = v
            CustomAccent = nil
            WindowRef:SetAccentColor(ThemeManager.Presets[v])
            ThemeManager:ScheduleSave()
        end
    end)

    box:AddColorPicker("Accent Color", getAccent(), function(c)
        ThemeManager:ApplyAccent(c)
        if combo and combo.Set then combo.Set("Custom") end
    end)

    box:AddButton("Reset Accent", function()
        Current = "Default"
        CustomAccent = nil
        WindowRef:SetAccentColor(ThemeManager.Presets.Default)
        ThemeManager:ScheduleSave()
        if combo and combo.Set then combo.Set("Default") end
    end)

    return box
end


return ThemeManager
