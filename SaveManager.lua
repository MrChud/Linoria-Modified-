-- SaveManager.lua
local HttpService = game:GetService("HttpService")

local SaveManager = {}
SaveManager.__index = SaveManager

local State = {
    Library = nil,
    Window = nil,
    Folder = "",
    SubFolder = "",
    Capturing = true,
    Autoload = false,
    LastConfig = "",
    CurrentConfig = "",
    Elements = {},
    Types = {},
    Ignore = {},
    IgnoreTheme = false,
    Known = {},
    ConfigNameBox = nil,
    ConfigList = nil,
}

local THEME_KEYS = { "Theme", "Preset", "Accent Color", "Reset Accent", "Reset Default" }

--// paths ---------------------------------------------------------------
local function dir()
    if State.SubFolder ~= "" then
        local base = State.Folder == "" and "settings" or (State.Folder .. "/settings")
        return base .. "/" .. State.SubFolder
    end
    return State.Folder
end

local function ensureDir(d)
    if d == "" then return end
    if isfolder(d) then return end
    local parent = d:match("^(.*)/[^/]+$")
    if parent then ensureDir(parent) end
    if not isfolder(d) then pcall(createfolder, d) end
end

local function fullPath(name)
    local d = dir()
    return d == "" and (name .. ".json") or (d .. "/" .. name .. ".json")
end

local function autoloadPath()
    local d = dir()
    return d == "" and "Autoload.json" or (d .. "/Autoload.json")
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

--// serialization -------------------------------------------------------
local function encode(value, kind)
    if kind == "AddColorPicker" and typeof(value) == "Color3" then
        return { __color = true, r = math.round(value.R * 255), g = math.round(value.G * 255), b = math.round(value.B * 255) }
    elseif (kind == "AddKeybind" or kind == "AddMenuKeybind") and typeof(value) == "EnumItem" then
        return { __keybind = true, name = value.Name }
    end
    return value
end

local function decode(value, kind)
    if kind == "AddColorPicker" and type(value) == "table" and value.__color then
        return Color3.fromRGB(value.r, value.g, value.b)
    elseif (kind == "AddKeybind" or kind == "AddMenuKeybind") and type(value) == "table" and value.__keybind then
        return Enum.KeyCode[value.name] or Enum.KeyCode.Unknown
    end
    return value
end

--// element capture ------------------------------------------------------
local function wrapElementModule(module)
    local wrapped = {}
    for _, name in ipairs({ "AddCheckbox", "AddSlider", "AddCombo", "AddKeybind",
                            "AddMenuKeybind", "AddColorPicker", "AddTextBox" }) do
        local orig = module[name]
        if orig then
            wrapped[name] = function(_, ...)
                local handle = orig(module, ...)
                if State.Capturing and handle and type(handle) == "table" and handle.Get then
                    local key = tostring(select(1, ...) or "Option")
                    State.Elements[key] = handle
                    State.Types[key] = name
                end
                return handle
            end
        end
    end
    setmetatable(wrapped, { __index = module })
    return wrapped
end

local function wrapBox(boxObj)
    local origPills = boxObj.CreatePillTabs
    if origPills then
        boxObj.CreatePillTabs = function(self, names)
            local result = origPills(self, names)
            for k, mod in pairs(result) do
                result[k] = wrapElementModule(mod)
            end
            return result
        end
    end
    return wrapElementModule(boxObj)
end

local function ignored(key)
    return State.Ignore[key] or (State.IgnoreTheme and THEME_KEYS[key])
end

local function snapshot()
    local data = {}
    for k, h in pairs(State.Elements) do
        if not ignored(k) then
            data[k] = encode(h.Get(), State.Types[k])
        end
    end
    return data
end

--// public API -----------------------------------------------------------
-- call BEFORE Library:CreateWindow (this is what makes capture work)
function SaveManager:SetLibrary(Library)
    State.Library = Library
    State.Capturing = true

    local origCreateWindow = Library.CreateWindow
    Library.CreateWindow = function(lib, title, opts)
        local Window = origCreateWindow(lib, title, opts)
        State.Window = Window

        local origTab = Window.CreateTab
        Window.CreateTab = function(w, name)
            local TabObj = origTab(w, name)
            local origBox = TabObj.CreateBox
            TabObj.CreateBox = function(t, boxTitle, col, collapsed)
                return wrapBox(origBox(t, boxTitle, col, collapsed))
            end
            return TabObj
        end
        return Window
    end
    return self
end

-- path is relative to the executor workspace, e.g. SetFolder("Chud/gamename")
-- -> workspace/Chud/gamename/
function SaveManager:SetFolder(folder)
    State.Folder = tostring(folder or ""):gsub("/+$", ""):gsub("\\+$", "")
    ensureDir(State.Folder)
    print("[SaveManager] folder -> workspace/" .. State.Folder)
    return self
end

function SaveManager:SetSubFolder(sub)
    State.SubFolder = tostring(sub or ""):gsub("/+$", ""):gsub("\\+$", "")
    ensureDir(dir())
    return self
end

function SaveManager:SetIgnoreIndexes(list)
    for _, k in ipairs(list or {}) do State.Ignore[tostring(k)] = true end
    return self
end

function SaveManager:IgnoreThemeSettings()
    State.IgnoreTheme = true
    return self
end

function SaveManager:SetLoadOnStart(bool)
    State.Autoload = bool or false
    self:SaveAutoload()
    return self
end

--// config list ----------------------------------------------------------
-- only lists JSONs inside OUR folder, never the whole workspace root
function SaveManager:ListConfigs()
    local out, seen = {}, {}
    local d = dir()

    local function harvest(files)
        for _, f in ipairs(files or {}) do
            local n = tostring(f):gsub("\\", "/"):match("([^/]+)%.json$")
            if n and n ~= "Autoload" and not seen[n] then
                seen[n] = true
                table.insert(out, n)
            end
        end
    end

    if d ~= "" then
        pcall(function() harvest(listfiles(d)) end)
        pcall(function() harvest(listfiles(d .. "/")) end)
    else
        pcall(function() harvest(listfiles("")) end)
    end

    local final = {}
    for _, n in ipairs(out) do
        if isfile(fullPath(n)) or State.Known[n] then table.insert(final, n) end
    end
    table.sort(final)
    return final
end

function SaveManager:CreateConfig(name)
    name = trim(name)
    if name == "" then print("[SaveManager] no config name given"); return false end
    if isfile(fullPath(name)) then print("[SaveManager] already exists:", name); return false end
    ensureDir(dir())
    local ok, err = pcall(writefile, fullPath(name), HttpService:JSONEncode(snapshot()))
    if not ok then warn("[SaveManager] write failed:", err); return false end
    State.CurrentConfig = name
    State.LastConfig = name
    State.Known[name] = true
    print("[SaveManager] created -> workspace/" .. fullPath(name))
    return true
end

function SaveManager:SaveConfig(name)
    name = trim(name)
    if name == "" and State.CurrentConfig ~= "" then name = State.CurrentConfig end
    if name == "" then print("[SaveManager] no config name given"); return false end
    ensureDir(dir())
    local ok, err = pcall(writefile, fullPath(name), HttpService:JSONEncode(snapshot()))
    if not ok then warn("[SaveManager] write failed:", err); return false end
    State.CurrentConfig = name
    State.LastConfig = name
    State.Known[name] = true
    print("[SaveManager] saved -> workspace/" .. fullPath(name))
    return true
end

function SaveManager:LoadConfig(name)
    name = trim(name)
    if name == "" then return false end
    if not isfile(fullPath(name)) and not State.Known[name] then
        print("[SaveManager] not found:", name)
        return false
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(fullPath(name))) end)
    if not ok or type(data) ~= "table" then warn("[SaveManager] corrupt config:", name); return false end
    for k, v in pairs(data) do
        local h = State.Elements[k]
        if h and h.Set then
            pcall(h.Set, decode(v, State.Types[k]), true)
        end
    end
    State.CurrentConfig = name
    State.LastConfig = name
    State.Known[name] = true
    if State.ConfigNameBox then State.ConfigNameBox.Set(name) end
    print("[SaveManager] loaded:", name)
    return true
end

function SaveManager:DeleteConfig(name)
    name = trim(name)
    if name == "" or not isfile(fullPath(name)) then print("[SaveManager] nothing to delete"); return false end
    delfile(fullPath(name))
    State.Known[name] = nil
    if State.CurrentConfig == name then State.CurrentConfig = "" end
    self:RefreshList()
    print("[SaveManager] deleted:", name)
    return true
end

function SaveManager:SaveAutoload()
    ensureDir(dir())
    writefile(autoloadPath(), HttpService:JSONEncode({ enabled = State.Autoload, config = State.LastConfig }))
end

function SaveManager:LoadAutoloadConfig()
    if not isfile(autoloadPath()) then return self end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(autoloadPath())) end)
    if ok and type(data) == "table" then
        State.Autoload = data.enabled or false
        State.LastConfig = data.config or ""
    end
    if State.Autoload and State.LastConfig ~= "" then
        self:LoadConfig(State.LastConfig)
    end
    return self
end

-- always refreshes, even to an empty list (deleting the last config clears
-- the dropdown instead of leaving the old entry stuck)
function SaveManager:RefreshList()
    if not State.ConfigList then return end
    State.ConfigList.SetOptions(self:ListConfigs())
end

--// UI ------------------------------------------------------------------
function SaveManager:BuildConfigSection(tab, opts)
    State.Capturing = false
    opts = opts or {}
    local E = tab:CreateBox("Configs", opts.Column or 2)

    local NameBox = E:AddTextBox("Config Name", "", nil)
    State.ConfigNameBox = NameBox

    local Ddl = E:AddCombo("Saved Configs", {}, "", function(name)
        if name and name ~= "" then
            State.CurrentConfig = name
            if State.ConfigNameBox then State.ConfigNameBox.Set(name) end
            self:LoadConfig(name)
        end
    end)
    State.ConfigList = Ddl

    -- fall back to whatever the dropdown is DISPLAYING even if the row was
    -- never clicked again (fixes delete/load on a single config)
    local function selectedName()
        if State.CurrentConfig ~= "" then return State.CurrentConfig end
        if State.ConfigList then return State.ConfigList.Get() or "" end
        return ""
    end

    E:AddCheckbox("Load on Start", State.Autoload, function(v)
        State.Autoload = v
        self:SaveAutoload()
    end)

    E:AddButton("Create Config", function()
        if self:CreateConfig(NameBox.Get()) then self:RefreshList() end
    end)

    E:AddButton("Save / Overwrite", function()
        if self:SaveConfig(NameBox.Get()) then self:RefreshList() end
    end)

    E:AddButton("Load Selected", function()
        local name = selectedName()
        if name ~= "" then self:LoadConfig(name) end
    end)

    E:AddButton("Delete Selected", function()
        local name = selectedName()
        if name ~= "" then self:DeleteConfig(name) end
    end, true)

    self:RefreshList()
    return self
end

return SaveManager
