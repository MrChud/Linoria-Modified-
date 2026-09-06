local HttpService = game:GetService("HttpService")

local SaveManager = {}
SaveManager.__index = SaveManager

SaveManager.Folder = "ModernUI"

local WindowRef    = nil
local LoadOnStart  = false
local LastConfig   = nil
local Elements     = {}
local BuildingUI   = false


local function sanitize(name)
    return tostring(name):gsub("[\\/:*?\"<>|]", "_")
end


local function ensureFolder()
    if not (isfolder and makefolder and isfile and readfile and writefile and listfiles and delfile) then return false end
    local path = ""
    for part in SaveManager.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then makefolder(path) end
    end
    return true
end


local function globalPath()
    return SaveManager.Folder .. "/_global.json"
end


local function configPath(name)
    return SaveManager.Folder .. "/" .. sanitize(name) .. ".json"
end


function SaveManager:SetFolder(name)
    SaveManager.Folder = tostring(name)
    return self
end


function SaveManager:LoadGlobal()
    if not (isfile and isfile(globalPath())) then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(globalPath()))
    if ok and type(data) == "table" then
        LoadOnStart = data.LoadOnStart == true
        LastConfig  = data.LastConfig
    end
end


function SaveManager:SaveGlobal()
    ensureFolder()
    pcall(writefile, globalPath(), HttpService:JSONEncode({
        LoadOnStart = LoadOnStart == true,
        LastConfig  = LastConfig or nil,
    }))
end


function SaveManager:ListConfigs()
    local list = {}
    if not (isfolder and isfolder(SaveManager.Folder)) then return list end
    for _, f in ipairs(listfiles(SaveManager.Folder)) do
        if f:sub(-5) == ".json" and not f:match("_global") then
            table.insert(list, f:gsub(".*[\\/]", ""):gsub("%.json$", ""))
        end
    end
    return list
end


local function encodeValue(t, v)
    if t == "Color" and v then
        return { r = math.round(v.R * 255), g = math.round(v.G * 255), b = math.round(v.B * 255) }
    end
    if t == "Keybind" and v then return v.Name end
    return v
end


local function decodeValue(t, v)
    if t == "Color" and type(v) == "table" then
        return Color3.fromRGB(
            math.clamp(v.r or 255, 0, 255),
            math.clamp(v.g or 255, 0, 255),
            math.clamp(v.b or 255, 0, 255)
        )
    end
    if t == "Keybind" and type(v) == "string" then
        return Enum.KeyCode[v] or Enum.KeyCode.Unknown
    end
    return v
end


local function keyFor(e)
    return (e.Tab or "") .. "|" .. (e.Box or "") .. "|" .. (e.Key or "")
end


local function buildSaveData()
    local ui = {}
    for _, e in ipairs(Elements) do
        local ok, v = pcall(e.Get)
        if ok and v ~= nil then ui[keyFor(e)] = encodeValue(e.Type, v) end
    end
    return { Version = 1, UI = ui }
end


-- CREATE: refuses to touch an existing config
function SaveManager:CreateConfig(name)
    local n = sanitize(name)
    if n == "" then return false end
    if isfile and isfile(configPath(n)) then return false end
    ensureFolder()
    local ok = pcall(writefile, configPath(n), HttpService:JSONEncode(buildSaveData()))
    if ok then LastConfig = n end
    SaveManager:SaveGlobal()
    return ok
end


-- OVERWRITE: only an existing config
function SaveManager:SaveConfig(name)
    local n = sanitize(name)
    if n == "" then return false end
    if not (isfile and isfile(configPath(n))) then return false end
    ensureFolder()
    local ok = pcall(writefile, configPath(n), HttpService:JSONEncode(buildSaveData()))
    if ok then LastConfig = n end
    SaveManager:SaveGlobal()
    return ok
end


SaveManager.OverwriteConfig = SaveManager.SaveConfig


function SaveManager:LoadConfig(name)
    local n = sanitize(name)
    local p = configPath(n)
    if not (isfile and isfile(p)) then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(p))
    if not ok or type(data) ~= "table" or type(data.UI) ~= "table" then return false end
    for _, e in ipairs(Elements) do
        local v = data.UI[keyFor(e)]
        if v ~= nil then
            pcall(e.Set, decodeValue(e.Type, v), true)
        end
    end
    LastConfig = n
    SaveManager:SaveGlobal()
    return true
end


function SaveManager:DeleteConfig(name)
    if isfile and isfile(configPath(name)) then delfile(configPath(name)) end
    if LastConfig == sanitize(name) then LastConfig = nil end
    SaveManager:SaveGlobal()
    return true
end


function SaveManager:RenameConfig(oldName, newName)
    oldName, newName = sanitize(oldName), sanitize(newName)
    if not (isfile and isfile(configPath(oldName))) then return false end
    if isfile and isfile(configPath(newName)) then return false end
    ensureFolder()
    local ok = pcall(writefile, configPath(newName), readfile(configPath(oldName)))
    if not ok then return false end
    delfile(configPath(oldName))
    if LastConfig == oldName then LastConfig = newName end
    SaveManager:SaveGlobal()
    return true
end


function SaveManager:LoadLastConfig()
    if LastConfig then return SaveManager:LoadConfig(LastConfig) end
    return false
end


local function registerElement(tabName, boxTitle, m, text, handle)
    if BuildingUI then return end
    if not handle or not handle.Get then return end
    local t
    if m == "AddCheckbox" then t = "Checkbox"
    elseif m == "AddSlider" then t = "Slider"
    elseif m == "AddCombo" then t = "Combo"
    elseif m == "AddKeybind" then t = "Keybind"
    elseif m == "AddColorPicker" then t = "Color"
    elseif m == "AddTextBox" then t = "Textbox"
    else return end
    local e = { Tab = tabName, Box = boxTitle, Key = tostring(text), Type = t, Get = handle.Get }
    if handle.Set then
        e.Set = function(v) return handle.Set(v, true) end
    end
    table.insert(Elements, e)
end


-- CALL THIS RIGHT AFTER CreateWindow, BEFORE any CreateTab
function SaveManager:Init(window, opts)
    opts = opts or {}
    WindowRef = window
    if opts.Folder then SaveManager.Folder = tostring(opts.Folder) end
    SaveManager:LoadGlobal()
    if opts.LoadOnStart ~= nil then LoadOnStart = opts.LoadOnStart == true end

    local origCreateTab = window.CreateTab
    window.CreateTab = function(self, name)
        local tab = origCreateTab(self, name)
        local origCreateBox = tab.CreateBox
        tab.CreateBox = function(_, boxTitle, column, startCollapsed)
            local box = origCreateBox(tab, boxTitle, column, startCollapsed)
            for _, m in ipairs({ "AddLabel", "AddButton", "AddCheckbox", "AddSlider", "AddCombo", "AddKeybind", "AddColorPicker", "AddTextBox" }) do
                local orig = box[m]
                if orig then
                    box[m] = function(self2, text, ...)
                        local h = orig(self2, text, ...)
                        registerElement(name, boxTitle, m, text, h)
                        return h
                    end
                end
            end
            return box
        end
        return tab
    end
    return self
end


-- Obsidian-style: call AFTER all UI is built, pass it the Settings tab object
function SaveManager:AddConfigSection(tab, opts)
    opts = opts or {}
    BuildingUI = true
    local box = tab:CreateBox(opts.Title or "Configs", opts.Column or 1)
    box:AddLabel("Configs")

    local nameTb = box:AddTextBox("Config Name", LastConfig or "")

    local combo
    local function refreshCombo(sel)
        if combo and combo.SetOptions then
            combo.SetOptions(SaveManager:ListConfigs())
            if sel then combo.Set(sel) end
        end
    end

    combo = box:AddCombo("Configs", SaveManager:ListConfigs(), LastConfig, function(v)
        if v and v ~= "" then
            if SaveManager:LoadConfig(v) then nameTb.Set(v) end
        end
    end)

    box:AddCheckbox("Load on Start", LoadOnStart, function(v)
        LoadOnStart = v == true
        SaveManager:SaveGlobal()
    end)

    box:AddButton("Create", function()
        local n = nameTb.Get()
        if n and n ~= "" and SaveManager:CreateConfig(n) then
            nameTb.Set(n)
            refreshCombo(n)
        end
    end)

    box:AddButton("Overwrite", function()
        local n = nameTb.Get()
        if (not n or n == "") and combo then n = combo.Get() end
        if n and n ~= "" and SaveManager:SaveConfig(n) then
            nameTb.Set(n)
            refreshCombo(n)
        end
    end)

    box:AddButton("Load", function()
        local n = nameTb.Get()
        if (not n or n == "") and combo then n = combo.Get() end
        if n and n ~= "" and SaveManager:LoadConfig(n) then
            nameTb.Set(n)
            refreshCombo(n)
        end
    end)

    box:AddButton("Delete", function()
        local n = nameTb.Get()
        if (not n or n == "") and combo then n = combo.Get() end
        if n and n ~= "" and SaveManager:DeleteConfig(n) then
            nameTb.Set("")
            refreshCombo()
        end
    end, true)

    BuildingUI = false

    if LoadOnStart and LastConfig then
        task.defer(function() SaveManager:LoadConfig(LastConfig) end)
    end

    return box
end


return SaveManager
