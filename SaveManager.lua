

local HttpService = game:GetService("HttpService")

local SaveManager = {}
SaveManager.__index = SaveManager

SaveManager.Folder = "ModernUI"
SaveManager.Ext    = ".json"

local WindowRef = nil
local ThemeRef  = nil
local LoadOnStart = false
local LastConfig  = nil


-- stable unique address: Tab|Box|Section|Key (Section only for pill tabs)
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
    -- folder can be nested (e.g. "ModernUI/Defusal") — create each level
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


function SaveManager:Init(window, loadOnStart)
    WindowRef = window
    self:LoadGlobal()
    if loadOnStart ~= nil then LoadOnStart = loadOnStart end
    -- deferred so UI has finished building before we restore anything
    if LoadOnStart and LastConfig then
        task.defer(function()
            self:LoadConfig(LastConfig)
        end)
    end
    return self
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
    data.Window = WindowRef.Tabs and #WindowRef.Tabs or 0 -- keep future compat
    return data
end


function SaveManager:SaveConfig(name)
    local n = sanitize(name)
    if n == "" or not WindowRef then return false end
    if not self:EnsureFolder() then return false end
    local ok = pcall(writefile, self.Folder .. "/" .. n .. self.Ext, HttpService:JSONEncode(buildSaveData()))
    if ok then
        LastConfig = n
        self:SaveGlobal()
    end
    return ok
end


function SaveManager:LoadConfig(name)
    local n = sanitize(name)
    if n == "" or not WindowRef then return false end
    local path = self.Folder .. "/" .. n .. self.Ext
    if not (isfile and isfile(path)) then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(path))
    if not ok or type(data) ~= "table" then return false end

    -- theme first so accent-linked elements repaint before their state sets
    if data.Theme and ThemeRef then
        pcall(function() ThemeRef:ApplyTheme(data.Theme) end)
    elseif data.Accent and type(data.Accent) == "table" then
        WindowRef:SetAccentColor(Color3.fromRGB(data.Accent[1], data.Accent[2], data.Accent[3]))
    end

    -- restore every element; active tab last so the UI is settled first
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
    if not self:LoadConfig(oldName) then return false end
    self:SaveConfig(newName)
    self:DeleteConfig(oldName)
    return true
end


function SaveManager:LoadLastConfig()
    if LastConfig then return self:LoadConfig(LastConfig) end
    return false
end


-- builds the full config UI automatically on a box you already have
function SaveManager:AddConfigBox(box, opts)
    opts = opts or {}
    box:AddLabel(opts.Label or "Configs")

    local nameTb = box:AddTextBox(opts.NameLabel or "Config Name")
    nameTb:Set(LastConfig or "")

    local combo = box:AddCombo(opts.ComboLabel or "Config List", self:ListConfigs(), LastConfig, function(v)
        if v and v ~= "" then self:LoadConfig(v) end
    end)

    box:AddCheckbox(opts.OnStartLabel or "Load on Start", LoadOnStart, function(v)
        LoadOnStart = v
        if LoadOnStart and LastConfig then self:SaveGlobal() end
    end)

    box:AddButton("Save", function()
        local n = nameTb:Get()
        if n and n ~= "" and self:SaveConfig(n) then
            nameTb:Set(n)
            combo.SetOptions(self:ListConfigs())
        end
    end)

    box:AddButton("Load", function()
        local n = nameTb:Get()
        if n and n ~= "" and self:LoadConfig(n) then
            nameTb:Set(n)
            combo.SetOptions(self:ListConfigs())
        end
    end)

    box:AddButton("Delete", function()
        local n = combo:Get() or nameTb:Get()
        if n and n ~= "" and self:DeleteConfig(n) then
            nameTb:Set("")
            combo.SetOptions(self:ListConfigs())
        end
    end, true)  -- red label, destructive

    return combo
end


-- convenience: makes the config box for you on a tab — you only pass the tab
function SaveManager:AddConfigSection(tab, opts)
    opts = opts or {}
    local box = tab:CreateBox(opts.Title or "Configs", opts.Column or 1)
    self:AddConfigBox(box, opts)
    return box
end


return SaveManager
