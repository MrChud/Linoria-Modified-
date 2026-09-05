

local HttpService = game:GetService("HttpService")

local SaveManager = {}
SaveManager.__index = SaveManager

SaveManager.Folder = "ModernUI"
SaveManager.Ext    = ".json"

local WindowRef   = nil
local ThemeRef    = nil
local LoadOnStart = false
local LastConfig  = nil


---------------------------------------------------------------------
-- serialization helpers
---------------------------------------------------------------------
local function joinEntry(e)
    local parts = { e.Tab, e.Box, e.Section, e.Key }
    local out = {}
    for _, p in ipairs(parts) do
        if p and p ~= "" then table.insert(out, p) end
    end
    return table.concat(out, "|")
end


local function sanitize(name)
    return tostring(name):gsub("[\\/:*?\"<>|]", "_")
end


local function encodeValue(etype, val)
    if etype == "Color" then
        return { r = val.R * 255, g = val.G * 255, b = val.B * 255 }
    end
    if etype == "Keybind" or etype == "MenuKeybind" then
        return val.Name
    end
    return val
end


local function decodeValue(etype, val)
    if etype == "Color" and type(val) == "table" then
        return Color3.fromRGB(val.r, val.g, val.b)
    end
    if etype == "Keybind" or etype == "MenuKeybind" then
        return Enum.KeyCode[val] or Enum.KeyCode.Unknown
    end
    return val
end


---------------------------------------------------------------------
-- folder / global marker
---------------------------------------------------------------------
function SaveManager:SetFolder(name)
    self.Folder = tostring(name)
    return self
end


function SaveManager:SetThemeManager(tm)
    ThemeRef = tm
    return self
end


function SaveManager:EnsureFolder()
    if not (isfolder and makefolder and writefile and readfile and isfile) then return false end
    local path = ""
    for part in self.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then makefolder(path) end
    end
    return true
end


local function globalPath()
    return SaveManager.Folder .. "/_global" .. SaveManager.Ext
end


function SaveManager:LoadGlobal()
    local p = globalPath()
    if isfile and isfile(p) then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(p))
        if ok and type(data) == "table" then
            LoadOnStart = data.LoadOnStart or false
            LastConfig  = data.LastConfig or nil
        end
    end
end


function SaveManager:SaveGlobal()
    if not self:EnsureFolder() then return end
    pcall(writefile, globalPath(), HttpService:JSONEncode({
        LoadOnStart = LoadOnStart or false,
        LastConfig  = LastConfig or nil,
    }))
end


---------------------------------------------------------------------
-- core config operations
---------------------------------------------------------------------
local function configPath(self, name)
    return self.Folder .. "/" .. sanitize(name) .. self.Ext
end


local function configExists(name)
    local p = configPath(SaveManager, name)
    return isfile and isfile(p)
end


function SaveManager:ListConfigs()
    local list = {}
    if not (isfolder and isfolder(self.Folder)) then return list end
    for _, f in ipairs(listfiles(self.Folder)) do
        if f:sub(-#self.Ext) == self.Ext and not f:match("\\_global") and not f:match("/_global") then
            table.insert(list, f:gsub(".*[\\/]", ""):gsub("%" .. self.Ext .. "$", ""))
        end
    end
    return list
end


local function buildSaveData()
    local ui = {}
    for _, e in ipairs(WindowRef.Elements) do
        local ok, v = pcall(function() return e.Get() end)
        if ok and v ~= nil then
            ui[joinEntry(e)] = encodeValue(e.Type, v)
        end
    end
    local data = { Version = 1, UI = ui }
    if ThemeRef then data.Theme = ThemeRef.Current end
    local a = WindowRef:GetAccentColor()
    data.Accent = { a.R * 255, a.G * 255, a.B * 255 }
    local bg = WindowRef:GetThemeColor("Background") or Color3.fromRGB(22, 22, 22)
    data.Background = { bg.R * 255, bg.G * 255, bg.B * 255 }
    data.BackgroundMode = WindowRef:GetBackgroundMode()
    return data
end


-- CREATE: writes a brand-new config. Refuses to touch one that exists.
function SaveManager:CreateConfig(name)
    local n = sanitize(name)
    if n == "" or configExists(n) or not WindowRef then return false end
    if not self:EnsureFolder() then return false end
    local ok = pcall(writefile, self.Folder .. "/" .. n .. self.Ext, HttpService:JSONEncode(buildSaveData()))
    if ok then
        LastConfig = n
        self:SaveGlobal()
    end
    return ok
end


-- OVERWRITE: saves over an EXISTING config only (strict).
function SaveManager:SaveConfig(name)
    local n = sanitize(name)
    if n == "" or not configExists(n) or not WindowRef then return false end
    if not self:EnsureFolder() then return false end
    local ok = pcall(writefile, self.Folder .. "/" .. n .. self.Ext, HttpService:JSONEncode(buildSaveData()))
    if ok then
        LastConfig = n
        self:SaveGlobal()
    end
    return ok
end


function SaveManager:OverwriteConfig(name)
    return self:SaveConfig(name)
end


-- LOAD: apply a config onto the UI.
function SaveManager:LoadConfig(name)
    local n = sanitize(name)
    if n == "" or not WindowRef then return false end
    local path = self.Folder .. "/" .. n .. self.Ext
    if not (isfile and isfile(path)) then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(path))
    if not ok or type(data) ~= "table" then return false end

    -- theme + accent + background first so elements repaint before state sets
    if data.Theme and ThemeRef then
        pcall(function() ThemeRef:ApplyTheme(data.Theme) end)
    elseif data.Accent and type(data.Accent) == "table" then
        WindowRef:SetAccentColor(Color3.fromRGB(data.Accent[1], data.Accent[2], data.Accent[3]))
    end
    if data.BackgroundMode then WindowRef:SetBackgroundMode(data.BackgroundMode) end
    if data.Background and type(data.Background) == "table" then
        WindowRef:SetThemeColor("Background", Color3.fromRGB(data.Background[1], data.Background[2], data.Background[3]))
    end

    -- restore every element; active tab last so the layout is settled
    local deferred
    if type(data.UI) == "table" then
        for _, e in ipairs(WindowRef.Elements) do
            local v = data.UI[joinEntry(e)]
            if v ~= nil then
                local dv = decodeValue(e.Type, v)
                if e.Type == "Tab" then
                    deferred = { e, dv }
                else
                    pcall(e.Set, e, dv)
                end
            end
        end
    end
    if deferred then pcall(deferred[1].Set, deferred[1], deferred[2]) end

    LastConfig = n
    self:SaveGlobal()
    return true
end


-- DELETE: remove a config file.
function SaveManager:DeleteConfig(name)
    local n = sanitize(name)
    local path = self.Folder .. "/" .. n .. self.Ext
    if isfile and isfile(path) then
        delfile(path)
        if LastConfig == n then
            LastConfig = nil
            self:SaveGlobal()
        end
        return true
    end
    return false
end


function SaveManager:RenameConfig(oldName, newName)
    if not configExists(oldName) or configExists(newName) then return false end
    if not self:LoadConfig(oldName) then return false end
    local wrote = self:SaveConfig(newName) -- SaveConfig requires existing -> use CreateConfig
    -- (SaveConfig is strict overwrite, so use CreateConfig for the fresh name)
    wrote = self:CreateConfig(newName)
    self:DeleteConfig(oldName)
    return wrote
end


function SaveManager:LoadLastConfig()
    if LastConfig then return self:LoadConfig(LastConfig) end
    return false
end


---------------------------------------------------------------------
-- init + auto-load
---------------------------------------------------------------------
function SaveManager:Init(window, loadOnStart)
    WindowRef = window
    self:LoadGlobal()
    if loadOnStart ~= nil then LoadOnStart = loadOnStart end
    if LoadOnStart and LastConfig then
        task.defer(function()
            if WindowRef then self:LoadConfig(LastConfig) end
        end)
    end
    return self
end


---------------------------------------------------------------------
-- UI: create / overwrite / load / delete
---------------------------------------------------------------------
local function refreshCombo(combo)
    combo.SetOptions(SaveManager:ListConfigs())
end


function SaveManager:AddConfigBox(box, opts)
    opts = opts or {}
    box:AddLabel(opts.Label or "Configs")

    local nameTb = box:AddTextBox(opts.NameLabel or "Config Name")
    nameTb:Set(LastConfig or "")

    local combo = box:AddCombo(opts.ComboLabel or "Configs", self:ListConfigs(), LastConfig, function(v)
        -- picking a config from the list LOADS it
        if v and v ~= "" then
            if self:LoadConfig(v) then
                nameTb:Set(v)
            end
        end
    end)

    box:AddCheckbox(opts.OnStartLabel or "Load on Start", LoadOnStart, function(v)
        LoadOnStart = v
        if LoadOnStart and LastConfig then self:SaveGlobal() end
    end)

    -- CREATE: brand-new config only
    box:AddButton(opts.CreateLabel or "Create", function()
        local n = nameTb:Get()
        if n and n ~= "" then
            if self:CreateConfig(n) then
                nameTb:Set(n)
                refreshCombo(combo)
                combo:Set(n)
            end
        end
    end)

    -- OVERWRITE: save current settings over an existing config
    box:AddButton(opts.OverwriteLabel or "Overwrite", function()
        local n = nameTb:Get()
        if n == "" then n = combo:Get() end
        if n and n ~= "" and self:SaveConfig(n) then
            nameTb:Set(n)
            combo:Set(n)
        end
    end)

    -- LOAD: by typed name (or current selection)
    box:AddButton(opts.LoadLabel or "Load", function()
        local n = nameTb:Get()
        if n == "" then n = combo:Get() end
        if n and n ~= "" and self:LoadConfig(n) then
            nameTb:Set(n)
            combo:Set(n)
        end
    end)

    -- DELETE (red, destructive)
    box:AddButton(opts.DeleteLabel or "Delete", function()
        local n = combo:Get()
        if n == "" or not n then n = nameTb:Get() end
        if n and n ~= "" and self:DeleteConfig(n) then
            nameTb:Set("")
            refreshCombo(combo)
        end
    end, true)

    return combo
end


-- convenience: creates the box on a tab for you — only the tab is required
function SaveManager:AddConfigSection(tab, opts)
    opts = opts or {}
    local box = tab:CreateBox(opts.Title or "Configs", opts.Column or 1)
    self:AddConfigBox(box, opts)
    return box
end


return SaveManager
