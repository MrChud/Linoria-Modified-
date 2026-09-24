-- =====================================================================
--  Drawing UI Library  |  bottom-tab layout, modern dark theme
--  If nothing renders on your executor, change OPAQUE to 1 (some
--  Drawing implementations invert Transparency).
-- =====================================================================
local OPAQUE = 0

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Theme = {
    Background   = Color3.fromRGB(17, 17, 20),
    Topbar       = Color3.fromRGB(23, 23, 27),
    Tabbar       = Color3.fromRGB(21, 21, 25),
    Content      = Color3.fromRGB(19, 19, 23),
    Section      = Color3.fromRGB(26, 26, 31),
    SectionHead  = Color3.fromRGB(31, 31, 37),
    Element      = Color3.fromRGB(34, 34, 40),
    ElementHover = Color3.fromRGB(41, 41, 49),
    Outline      = Color3.fromRGB(44, 44, 52),
    Accent       = Color3.fromRGB(120, 170, 255),
    Text         = Color3.fromRGB(236, 236, 240),
    SubText      = Color3.fromRGB(150, 150, 160),
    Off          = Color3.fromRGB(78, 78, 88),
    Handle       = Color3.fromRGB(220, 220, 230),
}

local function sq()
    local s = Drawing.new("Square")
    s.Filled = true
    s.Thickness = 1
    s.Transparency = OPAQUE
    s.Visible = false
    return s
end

local function txt(size)
    local t = Drawing.new("Text")
    t.Size = size or 13
    t.Center = false
    t.Outline = false
    t.Transparency = OPAQUE
    t.Visible = false
    return t
end

local function circle()
    local c = Drawing.new("Circle")
    c.NumSides = 40
    c.Filled = true
    c.Thickness = 1
    c.Transparency = OPAQUE
    c.Visible = false
    return c
end

local function contains(rect, m)
    return m.X >= rect.x and m.X <= rect.x + rect.w and m.Y >= rect.y and m.Y <= rect.y + rect.h
end

local Library = {}
Library.Windows = {}
Library.OpenOverlay = nil
Library.Drag = nil
Library.Capture = nil

-- ---------------------------------------------------------------------
--  COLOR PICKER OVERLAY (shared by all pickers)
-- ---------------------------------------------------------------------
local CP = { open = nil }
do
    CP.size = 150
    CP.gridN = 12
    CP.sv = {}
    for i = 1, CP.gridN * CP.gridN do
        CP.sv[i] = sq()
    end
    CP.hue = {}
    CP.hueN = 20
    for i = 1, CP.hueN do
        CP.hue[i] = sq()
    end
    CP.hueX, CP.hueY, CP.hueW, CP.hueH = 0, 0, 0, 8
    CP.svX, CP.svY = 0, 0

    function CP:HsvToRgb(h, s, v)
        return Color3.fromHSV(h, s, v)
    end

    function CP:Render()
        if not self.open then
            for _, o in ipairs(self.sv) do o.Visible = false end
            for _, o in ipairs(self.hue) do o.Visible = false end
            return
        end
        local h, s, v = self.open.H, self.open.S, self.open.V
        local n = self.gridN
        local cell = self.size / n
        for row = 0, n - 1 do
            for col = 0, n - 1 do
                local idx = row * n + col + 1
                local o = self.sv[idx]
                o.Position = Vector2.new(self.svX + col * cell, self.svY + row * cell)
                o.Size = Vector2.new(cell + 1, cell + 1)
                o.Color = Color3.fromHSV(h, col / (n - 1), 1 - row / (n - 1))
                o.Visible = true
            end
        end
        local hw = (self.size - (self.hueN - 1) * 2) / self.hueN
        for i = 1, self.hueN do
            local o = self.hue[i]
            o.Position = Vector2.new(self.hueX + (i - 1) * (hw + 2), self.hueY)
            o.Size = Vector2.new(hw, self.hueH)
            o.Color = Color3.fromHSV((i - 1) / (self.hueN - 1), 1, 1)
            o.Visible = true
        end
    end

    function CP:Click(m)
        local svRect = { x = self.svX, y = self.svY, w = self.size, h = self.size }
        local hueRect = { x = self.hueX, y = self.hueY, w = self.size, h = self.hueH }
        if contains(svRect, m) then
            Library.Drag = { kind = "sv" }
            self:Apply(m)
            return true
        end
        if contains(hueRect, m) then
            Library.Drag = { kind = "hue" }
            self:Apply(m)
            return true
        end
        return false
    end

    function CP:Apply(m)
        local p = self.open
        if not p then return end
        if Library.Drag and Library.Drag.kind == "hue" then
            local t = math.clamp((m.X - self.hueX) / self.size, 0, 1)
            p.H = t
        elseif Library.Drag and Library.Drag.kind == "sv" then
            local sx = math.clamp((m.X - self.svX) / self.size, 0, 1)
            local sy = math.clamp((m.Y - self.svY) / self.size, 0, 1)
            p.S = sx
            p.V = 1 - sy
        end
        p.Color = Color3.fromHSV(p.H, p.S, p.V)
        if p.Callback then p.Callback(p.Color, p.Alpha) end
    end

    function CP:Close()
        if self.open then self.open:SetOpen(false) end
        self.open = nil
        Library.OpenOverlay = nil
    end
end

-- ---------------------------------------------------------------------
--  ELEMENTS
-- ---------------------------------------------------------------------
local Element = {}
Element.__index = Element

local function newElement(section, kind, text, data)
    local el = setmetatable({}, Element)
    el.Section = section
    el.Kind = kind
    el.Text = text or ""
    el.Height = 24
    el.Value = data.Default
    el.Callback = data.Callback
    el.Flag = data.Flag or text
    el.Hovered = false
    el.Open = false
    table.insert(section.Elements, el)
    return el
end

-- Toggle
function Element:SetToggleValue(v)
    self.Value = v
    if self.Callback then self.Callback(v) end
end

local function buildToggle(el)
    el.Row = sq()
    el.Label = txt(13)
    el.Box = sq()
    el.Knob = sq()
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        local bx = x + w - 30
        local by = y + (h - 12) / 2
        self.Box.Position = Vector2.new(bx, by)
        self.Box.Size = Vector2.new(12, 12)
        self.Box.Color = self.Value and Theme.Accent or Theme.Off
        self.Box.Visible = true
        self.Knob.Position = Vector2.new(bx + 3, by + 3)
        self.Knob.Size = Vector2.new(6, 6)
        self.Knob.Color = Theme.White or Color3.new(1, 1, 1)
        self.Knob.Visible = self.Value
    end
    function el:Click(m, rect)
        self:SetToggleValue(not self.Value)
        return true
    end
end

-- Button
local function buildButton(el)
    el.Row = sq()
    el.Label = txt(13)
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Center = true
        self.Label.Position = Vector2.new(x + w / 2, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
    end
    function el:Click(m, rect)
        if self.Callback then self.Callback() end
        return true
    end
end

-- Label
local function buildLabel(el)
    el.Label = txt(13)
    function el:Render(x, y, w)
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (self.Height - 13) / 2 - 1)
        self.Label.Color = Theme.SubText
        self.Label.Visible = true
    end
    function el:Click() return false end
end

-- Divider
local function buildDivider(el)
    el.Line = sq()
    function el:Render(x, y, w)
        self.Line.Position = Vector2.new(x + 6, y + self.Height / 2)
        self.Line.Size = Vector2.new(w - 12, 1)
        self.Line.Color = Theme.Outline
        self.Line.Visible = true
    end
    function el:Click() return false end
end

-- Slider
local function buildSlider(el)
    el.Row = sq()
    el.Label = txt(12)
    el.ValueText = txt(12)
    el.Track = sq()
    el.Fill = sq()
    el.Handle = circle()
    el.Min = el.Data.Min or 0
    el.Max = el.Data.Max or 100
    el.Decimals = el.Data.Decimals or el.Data.Rounding or 0
    el.Suffix = el.Data.Suffix or ""
    el.Height = 36
    function el:SetSliderValue(v)
        self.Value = math.clamp(v, self.Min, self.Max)
        if self.Callback then self.Callback(self.Value) end
    end
    function el:Format(v)
        if self.Decimals == 0 then return tostring(math.floor(v)) .. self.Suffix end
        return string.format("%." .. self.Decimals .. "f", v) .. self.Suffix
    end
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + 4)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        self.ValueText.Text = self:Format(self.Value or self.Min)
        self.ValueText.Position = Vector2.new(x + w - 8 - self.ValueText.TextBounds.X, y + 4)
        self.ValueText.Color = Theme.Accent
        self.ValueText.Visible = true
        local tx, tw = x + 8, w - 16
        local ty = y + h - 12
        self.Track.Position = Vector2.new(tx, ty)
        self.Track.Size = Vector2.new(tw, 4)
        self.Track.Color = Theme.Off
        self.Track.Visible = true
        local pct = (self.Value - self.Min) / math.max(self.Max - self.Min, 1e-6)
        self.Fill.Position = Vector2.new(tx, ty)
        self.Fill.Size = Vector2.new(tw * pct, 4)
        self.Fill.Color = Theme.Accent
        self.Fill.Visible = true
        self.Handle.Position = Vector2.new(tx + tw * pct, ty + 2)
        self.Handle.Radius = 6
        self.Handle.Color = Theme.Handle
        self.Handle.Visible = true
        self._tx, self._tw, self._ty = tx, tw, ty
    end
    function el:Click(m, rect)
        Library.Drag = { kind = "slider", el = self }
        self:ApplyMouse(m)
        return true
    end
    function el:ApplyMouse(m)
        local pct = math.clamp((m.X - self._tx) / self._tw, 0, 1)
        local raw = self.Min + pct * (self.Max - self.Min)
        if self.Decimals == 0 then raw = math.floor(raw + 0.5) end
        self:SetSliderValue(raw)
    end
end

-- Dropdown
local function buildDropdown(el)
    el.Row = sq()
    el.Label = txt(13)
    el.ValueText = txt(12)
    el.Arrow = txt(12)
    el.Multi = el.Data.Multi == true
    el.Items = el.Data.Items or el.Data.Values or {}
    el.Height = 24
    el.ListSquares = {}
    el.ListTexts = {}
    el._openRect = { x = 0, y = 0, w = 0, h = 0 }

    if el.Multi then
        el.Value = {}
        for _, v in ipairs(el.Data.Default or {}) do el.Value[v] = true end
    else
        el.Value = el.Data.Default or el.Items[1]
    end

    for i = 1, #el.Items do
        el.ListSquares[i] = sq()
        el.ListTexts[i] = txt(12)
    end
    function el:ValueLabel()
        if self.Multi then
            local out = {}
            for _, v in ipairs(self.Items) do
                if self.Value[v] then table.insert(out, tostring(v)) end
            end
            return #out > 0 and table.concat(out, ", ") or "..."
        end
        return tostring(self.Value or "...")
    end
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        self.ValueText.Text = self:ValueLabel()
        self.ValueText.Center = false
        self.ValueText.Position = Vector2.new(x + w - 22 - self.ValueText.TextBounds.X, y + (h - 12) / 2 - 1)
        self.ValueText.Color = Theme.Accent
        self.ValueText.Visible = true
        self.Arrow.Text = self.Open and "^" or "v"
        self.Arrow.Position = Vector2.new(x + w - 16, y + (h - 12) / 2 - 1)
        self.Arrow.Color = Theme.SubText
        self.Arrow.Visible = true

        if self.Open then
            local ih = 20
            local ly = y + h + 2
            self._openRect = { x = x + 4, y = ly, w = w - 8, h = ih * #self.Items + 6 }
            local bg = self._listBg
            if not bg then
                bg = sq(); self._listBg = bg
            end
            bg.Position = Vector2.new(self._openRect.x, self._openRect.y)
            bg.Size = Vector2.new(self._openRect.w, self._openRect.h)
            bg.Color = Theme.SectionHead
            bg.Visible = true
            for i, item in ipairs(self.Items) do
                local iy = ly + 3 + (i - 1) * ih
                local sel = self.Multi and self.Value[item] or (self.Value == item)
                local hovered = self._hoverIndex == i
                local s = self.ListSquares[i]
                s.Position = Vector2.new(x + 6, iy)
                s.Size = Vector2.new(w - 12, ih)
                s.Color = sel and Theme.Accent or (hovered and Theme.ElementHover or Theme.Element)
                s.Visible = true
                local t = self.ListTexts[i]
                t.Text = tostring(item)
                t.Center = false
                t.Position = Vector2.new(x + 12, iy + (ih - 12) / 2 - 1)
                t.Color = sel and Color3.fromRGB(20, 20, 24) or Theme.Text
                t.Visible = true
            end
        else
            if self._listBg then self._listBg.Visible = false end
            for i = 1, #self.Items do
                self.ListSquares[i].Visible = false
                self.ListTexts[i].Visible = false
            end
        end
    end
    function el:SetOpen(v)
        if v then
            if Library.OpenOverlay and Library.OpenOverlay ~= self then Library.OpenOverlay:SetOpen(false) end
            Library.OpenOverlay = self
        elseif Library.OpenOverlay == self then
            Library.OpenOverlay = nil
        end
        self.Open = v
    end
    function el:Select(item)
        if self.Multi then
            self.Value[item] = not self.Value[item]
        else
            self.Value = item
            self:SetOpen(false)
        end
        if self.Callback then self.Callback(self.Multi and self.Value or item) end
    end
    function el:Click(m, rect)
        self:SetOpen(not self.Open)
        return true
    end
    function el:HandleOverlay(m, press)
        local r = self._openRect
        if not contains(r, m) then
            self:SetOpen(false)
            return false
        end
        local ih = 20
        for i, item in ipairs(self.Items) do
            local iy = r.y + 3 + (i - 1) * ih
            if m.Y >= iy and m.Y <= iy + ih and m.X >= r.x and m.X <= r.x + r.w then
                self._hoverIndex = i
                if press then self:Select(item) end
                return true
            end
        end
        return true
    end
end

-- Color Picker
local function buildColorPicker(el)
    el.Row = sq()
    el.Label = txt(13)
    el.Swatch = sq()
    el.Height = 24
    el.H = 0
    el.S = 1
    el.V = 1
    el.Alpha = 1
    if el.Data.Default then
        el.H, el.S, el.V = el.Data.Default:ToHSV()
        el.Color = el.Data.Default
    else
        el.Color = Color3.new(1, 1, 1)
    end
    el.OptionX = 0
    el.OptionY = 0
    el.OptionW = 0
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        self.Swatch.Position = Vector2.new(x + w - 30, y + (h - 14) / 2)
        self.Swatch.Size = Vector2.new(22, 14)
        self.Swatch.Color = self.Color
        self.Swatch.Visible = true
        self._absX, self._absY, self._absW = x, y, w
    end
    function el:SetOpen(v)
        if v then
            if Library.OpenOverlay and Library.OpenOverlay ~= self then Library.OpenOverlay:SetOpen(false) end
            Library.OpenOverlay = self
            CP.open = self
            CP.size = 150
            CP.svX = self._absX + self._absW - CP.size
            CP.svY = self._absY + self.Height + 6
            CP.hueX = CP.svX
            CP.hueY = CP.svY + CP.size + 6
            CP.hueW = CP.size
        elseif Library.OpenOverlay == self then
            Library.OpenOverlay = nil
            CP.open = nil
        end
        self.Open = v
    end
    function el:Click(m, rect)
        self:SetOpen(not self.Open)
        return true
    end
end

-- Keybind
local function buildKeybind(el)
    el.Row = sq()
    el.Label = txt(13)
    el.Key = txt(12)
    el.Height = 24
    el.Value = el.Data.Default or "None"
    el.Capturing = false
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Hovered and Theme.ElementHover or Theme.Element
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        self.Key.Text = self.Capturing and "[...]" or tostring(self.Value)
        self.Key.Position = Vector2.new(x + w - 12 - self.Key.TextBounds.X, y + (h - 12) / 2 - 1)
        self.Key.Color = self.Capturing and Theme.Accent or Theme.SubText
        self.Key.Visible = true
    end
    function el:Click(m, rect)
        for _, other in ipairs(self.Section.Elements) do
            if other.Kind == "Keybind" and other ~= self then other.Capturing = false end
        end
        self.Capturing = true
        Library.Capture = self
        return true
    end
end

-- Textbox
local function buildTextbox(el)
    el.Row = sq()
    el.Label = txt(13)
    el.ValueText = txt(12)
    el.Height = 24
    el.Value = el.Data.Default or ""
    el.Focused = false
    function el:Render(x, y, w)
        local h = self.Height
        self.Row.Position = Vector2.new(x, y)
        self.Row.Size = Vector2.new(w, h)
        self.Row.Color = self.Focused and Theme.ElementHover or (self.Hovered and Theme.ElementHover or Theme.Element)
        self.Row.Visible = true
        self.Label.Text = self.Text
        self.Label.Position = Vector2.new(x + 8, y + (h - 13) / 2 - 1)
        self.Label.Color = Theme.Text
        self.Label.Visible = true
        self.ValueText.Text = self.Value .. ((self.Focused and math.floor(tick() * 2) % 2 == 0) and "|" or "")
        self.ValueText.Position = Vector2.new(x + w - 12 - self.ValueText.TextBounds.X, y + (h - 12) / 2 - 1)
        self.ValueText.Color = Theme.Accent
        self.ValueText.Visible = true
    end
    function el:Click(m, rect)
        for _, other in ipairs(self.Section.Elements) do
            if other.Kind == "Textbox" and other ~= self then other.Focused = false end
        end
        self.Focused = true
        Library.Capture = self
        return true
    end
end

-- ---------------------------------------------------------------------
--  SECTION / TAB / WINDOW
-- ---------------------------------------------------------------------
local Section = {}
Section.__index = Section

local BUILDERS = {
    Toggle = buildToggle, Slider = buildSlider, Dropdown = buildDropdown,
    ColorPicker = buildColorPicker, Button = buildButton, Label = buildLabel,
    Keybind = buildKeybind, Textbox = buildTextbox, Divider = buildDivider,
}

function Section:Add(kind, text, data)
    data = data or {}
    local el = newElement(self, kind, text, data)
    el.Data = data
    local build = BUILDERS[kind]
    if build then build(el) end
    return el
end

function Section:AddToggle(t, d) return self:Add("Toggle", t, d) end
function Section:AddSlider(t, d) return self:Add("Slider", t, d) end
function Section:AddDropdown(t, d) return self:Add("Dropdown", t, d) end
function Section:AddColorPicker(t, d) return self:Add("ColorPicker", t, d) end
function Section:AddButton(t, d) return self:Add("Button", t, d) end
function Section:AddLabel(t, d) return self:Add("Label", t, d) end
function Section:AddKeybind(t, d) return self:Add("Keybind", t, d) end
function Section:AddTextbox(t, d) return self:Add("Textbox", t, d) end
function Section:AddDivider() return self:Add("Divider", "", {}) end

local Tab = {}
Tab.__index = Tab
function Tab:AddSection(name)
    local s = setmetatable({ Name = name, Elements = {}, Tab = self }, Section)
    table.insert(self.Sections, s)
    return s
end

local Win = {}
Win.__index = Win

function Win:AddTab(name)
    local tab = setmetatable({ Name = name, Sections = {}, Window = self }, Tab)
    table.insert(self.Tabs, tab)
    return tab
end

function Win:Render()
    local pos = self.Position
    local w, h = self.Size.X, self.Size.Y
    local topH, tabH = 32, 30
    local contentTop = pos.Y + topH
    local contentBottom = pos.Y + h - tabH
    local contentH = contentBottom - contentTop

    self.Bg.Position = pos
    self.Bg.Size = self.Size
    self.Bg.Color = Theme.Background
    self.Bg.Visible = true

    self.Topbar.Position = pos
    self.Topbar.Size = Vector2.new(w, topH)
    self.Topbar.Color = Theme.Topbar
    self.Topbar.Visible = true

    self.Title.Text = self.TitleText
    self.Title.Position = Vector2.new(pos.X + 12, pos.Y + (topH - 14) / 2 - 1)
    self.Title.Size = 14
    self.Title.Color = Theme.Text
    self.Title.Visible = true

    self.ContentBg.Position = Vector2.new(pos.X, contentTop)
    self.ContentBg.Size = Vector2.new(w, contentH)
    self.ContentBg.Color = Theme.Content
    self.ContentBg.Visible = true

    self.Tabbar.Position = Vector2.new(pos.X, contentBottom)
    self.Tabbar.Size = Vector2.new(w, tabH)
    self.Tabbar.Color = Theme.Tabbar
    self.Tabbar.Visible = true

    self.Border.Position = pos
    self.Border.Size = self.Size
    self.Border.Color = Theme.Outline
    self.Border.Filled = false
    self.Border.Visible = true

    -- tabs
    local count = #self.Tabs
    local tw = w / math.max(count, 1)
    for i, tab in ipairs(self.Tabs) do
        local tx = pos.X + (i - 1) * tw
        local text = tab.TextDrawings
        if not text then
            text = txt(13)
            tab.TextDrawings = text
        end
        text.Text = tab.Name
        text.Center = true
        text.Position = Vector2.new(tx + tw / 2, contentBottom + (tabH - 13) / 2 - 1)
        text.Color = (self.ActiveTab == i) and Theme.Text or Theme.SubText
        text.Visible = true

        if not tab.Underline then tab.Underline = sq() end
        local ul = tab.Underline
        ul.Position = Vector2.new(tx + tw * 0.25, contentBottom + tabH - 3)
        ul.Size = Vector2.new(tw * 0.5, 2)
        ul.Color = Theme.Accent
        ul.Visible = self.ActiveTab == i
    end

    -- active tab content
    local active = self.Tabs[self.ActiveTab]
    if not active then return end

    local pad = 10
    local secW = w - pad * 2
    local y = contentTop + pad - self.Scroll

    -- layout & render sections
    for _, sec in ipairs(active.Sections) do
        local headH = 24
        sec._absX = pos.X + pad
        sec._absY = y
        sec._headH = headH
        -- measure
        local inner = 4
        local total = headH + inner
        for _, el in ipairs(sec.Elements) do
            total = total + el.Height + 2
        end
        total = total + 4
        sec._height = total

        local visible = not (y + sec._height < contentTop or y > contentBottom)
        sec._visible = visible

        if visible then
            if not sec.Bg then sec.Bg = sq() end
            if not sec.Head then sec.Head = sq() end
            if not sec.HeadText then sec.HeadText = txt(13) end
            sec.Bg.Position = Vector2.new(sec._absX, y)
            sec.Bg.Size = Vector2.new(secW, sec._height)
            sec.Bg.Color = Theme.Section
            sec.Bg.Visible = true
            sec.Head.Position = Vector2.new(sec._absX, y)
            sec.Head.Size = Vector2.new(secW, headH)
            sec.Head.Color = Theme.SectionHead
            sec.Head.Visible = true
            sec.HeadText.Text = sec.Name
            sec.HeadText.Position = Vector2.new(sec._absX + 10, y + (headH - 13) / 2 - 1)
            sec.HeadText.Color = Theme.Text
            sec.HeadText.Visible = true
        else
            if sec.Bg then sec.Bg.Visible = false end
            if sec.Head then sec.Head.Visible = false end
            if sec.HeadText then sec.HeadText.Visible = false end
        end

        local ey = y + headH + 2
        for _, el in ipairs(sec.Elements) do
            local rect = { x = sec._absX + 4, y = ey, w = secW - 8, h = el.Height }
            el._rect = rect
            local elVisible = visible and not (ey + el.Height < contentTop or ey > contentBottom)
            if elVisible then
                el:Render(rect.x, ey, rect.w)
            else
                el:Hide()
            end
            ey = ey + el.Height + 2
        end
        y = y + sec._height + 8
    end

    -- total content height for scrolling
    local totalH = (y + self.Scroll) - (contentTop + pad)
    self._maxScroll = math.max(0, totalH - (contentH - pad * 2))
end

function Element:Hide()
    for _, v in pairs(self) do
        if type(v) == "userdata" then
            pcall(function() v.Visible = false end)
        end
    end
    if self.Box then self.Box.Visible = false end
    if self.Knob then self.Knob.Visible = false end
    if self.Fill then self.Fill.Visible = false end
    if self.Handle then self.Handle.Visible = false end
    if self.Track then self.Track.Visible = false end
    if self.Swatch then self.Swatch.Visible = false end
    if self.ValueText then self.ValueText.Visible = false end
    if self.Arrow then self.Arrow.Visible = false end
    if self.Label then self.Label.Visible = false end
    if self.Row then self.Row.Visible = false end
    if self.ListSquares then for _, o in ipairs(self.ListSquares) do o.Visible = false end end
    if self.ListTexts then for _, o in ipairs(self.ListTexts) do o.Visible = false end end
    if self._listBg then self._listBg.Visible = false end
end

function Win:UpdateInput()
    local m = UserInputService:GetMouseLocation()
    local pos = self.Position
    local w, h = self.Size.X, self.Size.Y
    local topH, tabH = 32, 30
    local contentTop = pos.Y + topH
    local contentBottom = pos.Y + h - tabH

    -- hover pass
    local active = self.Tabs[self.ActiveTab]
    if active then
        for _, sec in ipairs(active.Sections) do
            if sec._visible then
                for _, el in ipairs(sec.Elements) do
                    local r = el._rect
                    el.Hovered = r and contains(r, m)
                end
            end
        end
    end

    -- colorpicker global
    CP:Render()

    self._drag = Library.Drag
    if Library.Drag and Library.Drag.kind == "window" then
        self.Position = m - Library.Drag.off
    elseif Library.Drag and Library.Drag.kind == "slider" then
        Library.Drag.el:ApplyMouse(m)
    elseif Library.Drag and (Library.Drag.kind == "sv" or Library.Drag.kind == "hue") then
        CP:Apply(m)
    end
end

-- ---------------------------------------------------------------------
--  INPUT
-- ---------------------------------------------------------------------
local function windowAt(m)
    for _, win in ipairs(Library.Windows) do
        if contains({ x = win.Position.X, y = win.Position.Y, w = win.Size.X, h = win.Size.Y }, m) then
            return win
        end
    end
    return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        if Library.Capture and input.UserInputType == Enum.UserInputType.Keyboard then
            local cap = Library.Capture
            if cap.Kind == "Keybind" then
                local key = input.KeyCode.Name
                cap.Value = (key == "Unknown" and "None") or key
                cap.Capturing = false
                if cap.Callback then cap.Callback(cap.Value) end
                Library.Capture = nil
            elseif cap.Kind == "Textbox" then
                local key = input.KeyCode
                if key == Enum.KeyCode.Backspace then
                    cap.Value = cap.Value:sub(1, -2)
                elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.Escape then
                    cap.Focused = false
                    Library.Capture = nil
                    if cap.Callback then cap.Callback(cap.Value) end
                else
                    local ch = UserInputService:GetStringForKeyCode(key)
                    if ch and #ch == 1 then cap.Value = cap.Value .. ch end
                end
            end
        end
        return
    end
    if processed then return end
    local m = UserInputService:GetMouseLocation()

    if Library.OpenOverlay then
        local overlay = Library.OpenOverlay
        if overlay.Kind == "ColorPicker" then
            if CP:Click(m) then return end
            overlay:SetOpen(false)
            return
        elseif overlay.Kind == "Dropdown" then
            if overlay:HandleOverlay(m, true) then return end
            return
        end
    end

    local win = windowAt(m)
    if not win then return end

    local pos = win.Position
    local w, h = win.Size.X, win.Size.Y
    local topH, tabH = 32, 30
    local contentBottom = pos.Y + h - tabH
    local contentTop = pos.Y + topH

    if m.Y <= pos.Y + topH then
        Library.Drag = { kind = "window", off = m - pos }
        return
    end

    if m.Y >= contentBottom then
        local count = #win.Tabs
        local tw = w / math.max(count, 1)
        for i = 1, count do
            local tx = pos.X + (i - 1) * tw
            if m.X >= tx and m.X <= tx + tw then
                win.ActiveTab = i
                win.Scroll = 0
                break
            end
        end
        return
    end

    local active = win.Tabs[win.ActiveTab]
    if not active then return end
    for i = #active.Sections, 1, -1 do
        local sec = active.Sections[i]
        if sec._visible then
            for j = #sec.Elements, 1, -1 do
                local el = sec.Elements[j]
                if el._rect and contains(el._rect, m) then
                    if el:Click(m, el._rect) then return end
                end
            end
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local win = Library.Windows[1]
        if win then
            win.Scroll = math.clamp(win.Scroll - input.Position.Z * 24, 0, win._maxScroll or 0)
        end
        return
    end
    if Library.Drag and Library.Drag.kind == "window" then
        local win = windowAt(winpos or Vector2.new())
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Library.Drag = nil
    end
end)

-- ---------------------------------------------------------------------
--  LIBRARY API
-- ---------------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local self = setmetatable({
        Tabs = {},
        Position = cfg.Position or Vector2.new(200, 160),
        Size = cfg.Size or Vector2.new(620, 420),
        TitleText = cfg.Title or "Drawing UI",
        ActiveTab = 1,
        Scroll = 0,
    }, Win)

    self.Bg = sq()
    self.Topbar = sq()
    self.ContentBg = sq()
    self.Tabbar = sq()
    self.Border = sq()
    self.Border.Filled = false
    self.Border.Thickness = 1
    self.Title = txt(14)

    table.insert(Library.Windows, self)

    RunService.RenderStepped:Connect(function()
        self:UpdateInput()
        self:Render()
    end)

    return self
end

getgenv().DrawingUI = Library
return Library
