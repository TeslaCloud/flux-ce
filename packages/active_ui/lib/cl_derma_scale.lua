--- Scales the stock Derma interface with the screen resolution. Garry's Mod sizes its panels
-- and fonts in raw pixels that were designed for 1080p, so on a 4K screen the spawn menu,
-- the tool menu, context menus, windows and dialogs come out tiny. The panels of Flux itself
-- already scale through `math.scale` and the theme fonts, so this library does the same for
-- the built-in controls at the framework level:
--
-- * `DermaScale.scale` scales a size designed for 1080p (`DermaScale.factor` is the ratio of
--   the screen height to 1080, never below 1, so nothing changes at 1080p or below).
-- * The built-in fonts ('DermaDefault', 'DermaDefaultBold', 'DermaLarge', 'Default',
--   'Trebuchet18', 'Trebuchet24', 'HudHintTextLarge', 'HudHintTextSmall', 'CenterPrintText',
--   'DebugFixed', 'DebugFixedSmall', 'BudgetLabel', 'ChatFont' and the spawn menu's
--   'ContentHeader') are created again at the scaled size from the `CreateFonts` hook, with
--   the families and weights of Garry's Mod's own definitions, so they follow the same rebuilds
--   as the Flux fonts (load, schema load and resolution change).
-- * The sizes that the stock panel classes hardcode in their `Init`, `PerformLayout` and setup
--   methods are patched on the class tables: `DermaScale.after` wraps a method and re-applies
--   the scaled sizes once the original has run, `DermaScale.replace` swaps a method whose body
--   mixes sizes with other logic for a scaled copy. Classes registered later (or registered
--   again) are patched from a wrapper around `vgui.Register`. Only the stock classes listed in
--   this file are touched; a panel that derives from one of them gets the scaled base once,
--   from the base class `Init`, and its own code keeps using `math.scale` as before. Nothing
--   multiplies `SetSize` globally.
-- * The modal dialogs `Derma_Message`, `Derma_Query` and `Derma_StringRequest` are replaced
--   with scaled copies, and the menu bar of the spawn menu (`menubar` module) is sized again
--   whenever it is attached to a menu.
-- * When the resolution changes the spawn menu is rebuilt, since its panels were sized for
--   the previous one.

mod 'DermaScale'

local IsValid    = IsValid
local math_floor = math.floor
local math_ceil  = math.ceil
local math_min   = math.min
local math_max   = math.max

-- Originals and wrappers survive code reloads so that a method is never wrapped twice.
local store = Flux.derma_scale or {
  originals = {},
  wrappers = setmetatable({}, { __mode = 'k' })
}

Flux.derma_scale = store

local patches = {}

--- Returns the factor by which the stock Derma interface is scaled: the ratio of the screen
-- height to 1080, never below 1 so that screens of 1080p or less keep their native sizes.
-- @return [Number]
function DermaScale.factor()
  return math_max(ScrH() / 1080, 1)
end

--- Scales a size designed for a 1080p screen to the current screen, rounding down.
-- Returns the size unchanged at 1080p or below, and anything that is not a number as is.
-- @param size [Number size at 1080p]
-- @return [Number scaled size]
function DermaScale.scale(size)
  if !isnumber(size) then return size end

  local factor = DermaScale.factor()

  if factor == 1 then return size end

  return math_floor(size * factor)
end

local s = DermaScale.scale

--- Returns the definitions of the built-in fonts that are recreated at a scaled size, keyed by
-- name, at their 1080p sizes. They mirror lua/derma/init.lua, the sandbox gamemode and
-- resource/ClientScheme.res (the 1080p variant of fonts that depend on the resolution).
-- @return [Map font name → font data for surface.CreateFont]
function DermaScale.font_definitions()
  local derma_font, derma_size = 'Tahoma', 13
  local hint_large, hint_small, center_print = 'Verdana', 'Verdana', 'Trebuchet MS'

  if system.IsLinux() then
    derma_font, derma_size = 'DejaVu Sans', 14
  elseif system.IsOSX() then
    hint_large, hint_small, center_print = 'Helvetica Bold', 'Helvetica', 'Helvetica'
  end

  return {
    DermaDefault      = { font = derma_font,      size = derma_size, weight = 500 },
    DermaDefaultBold  = { font = derma_font,      size = derma_size, weight = 800 },
    DermaLarge        = { font = 'Roboto',        size = 32,         weight = 500 },
    ContentHeader     = { font = 'Helvetica',     size = 50,         weight = 1000 },
    Default           = { font = 'Verdana',       size = 12,         weight = 700 },
    Trebuchet18       = { font = 'Trebuchet MS',  size = 18,         weight = 900,  antialias = false },
    Trebuchet24       = { font = 'Trebuchet MS',  size = 24,         weight = 900,  additive = true },
    HudHintTextLarge  = { font = hint_large,      size = 14,         weight = 1000, additive = true },
    HudHintTextSmall  = { font = hint_small,      size = 11,         weight = 0,    additive = true },
    CenterPrintText   = { font = center_print,    size = 18,         weight = 900,  additive = true },
    DebugFixed        = { font = 'Courier New',   size = 14,         weight = 400 },
    DebugFixedSmall   = { font = 'Courier New',   size = 14,         weight = 400 },
    BudgetLabel       = { font = 'Courier New',   size = 14,         weight = 400,  antialias = false, outline = true },
    ChatFont          = { font = 'Verdana',       size = 17,         weight = 700,  antialias = false, shadow = true }
  }
end

--- Creates the built-in fonts again at the scaled size. Does nothing at 1080p or below unless
-- the fonts have been scaled before (after a change of the resolution), so that the original
-- engine fonts stay untouched on screens that do not need scaling.
function DermaScale.create_fonts()
  if DermaScale.factor() == 1 and !store.fonts_scaled then return end

  store.fonts_scaled = true

  for name, data in pairs(DermaScale.font_definitions()) do
    data.size = s(data.size)

    Font.create(name, data)
  end
end

hook.Add('CreateFonts', 'DermaScale', DermaScale.create_fonts)

-- Patching of the stock classes.

local function original_of(class_table, class_name, method)
  local key = class_name..':'..method
  local current = rawget(class_table, method)

  if current == nil then
    current = class_table[method]
  end

  -- A method that is not one of our wrappers is the real one, which may be new if the
  -- class has been registered again.
  if current != nil and !store.wrappers[current] then
    store.originals[key] = current
  end

  return store.originals[key]
end

local function apply_patch(class_name, patch)
  local class_table = vgui.GetControlTable(class_name)

  if !class_table then return end

  local original = original_of(class_table, class_name, patch.method)

  -- An unknown method means a different version of the panel, leave it alone.
  if !original then return end

  local wrapper

  if patch.kind == 'after' then
    local fixup = patch.fn

    wrapper = function(panel, ...)
      local result = original(panel, ...)

      fixup(panel, result, ...)

      return result
    end
  else
    wrapper = patch.fn
  end

  store.wrappers[wrapper] = true
  class_table[patch.method] = wrapper
end

local function add_patch(class_name, method, kind, fn)
  patches[class_name] = patches[class_name] or {}

  table.insert(patches[class_name], { method = method, kind = kind, fn = fn })

  apply_patch(class_name, patches[class_name][#patches[class_name]])
end

--- Wraps a method of a stock panel class so that `fixup` runs after the original. The fixup
-- re-applies the sizes that the original sets, scaled. The class is patched now if it is
-- registered and again whenever it is registered.
-- ```
-- DermaScale.after('DButton', 'Init', function(panel)
--   panel:SetTall(DermaScale.scale(22))
-- end)
-- ```
-- @param class_name [String name of the panel class]
-- @param method [String name of the method]
-- @param fixup [function(panel, result, ...) called after the original with the panel, the
--   value the original returned and the arguments of the call]
function DermaScale.after(class_name, method, fixup)
  add_patch(class_name, method, 'after', fixup)
end

--- Replaces a method of a stock panel class with a scaled copy.
-- @param class_name [String name of the panel class]
-- @param method [String name of the method]
-- @param fn [function the new method]
function DermaScale.replace(class_name, method, fn)
  add_patch(class_name, method, 'replace', fn)
end

--- Applies every patch registered for a class. Called when the class is registered.
-- @param class_name [String name of the panel class]
function DermaScale.apply(class_name)
  if !patches[class_name] then return end

  for k, patch in ipairs(patches[class_name]) do
    apply_patch(class_name, patch)
  end
end

--- Returns the original of a patched method or global function.
-- @param key [String 'ClassName:Method' or '_G.function_name']
-- @return [function]
function DermaScale.original(key)
  return store.originals[key]
end

--- Replaces a global function with a scaled copy, remembering the original.
-- @param name [String name of the global function]
-- @param fn [function the new function]
function DermaScale.replace_global(name, fn)
  local key = '_G.'..name

  if _G[name] != nil and !store.wrappers[_G[name]] then
    store.originals[key] = _G[name]
  end

  store.wrappers[fn] = true
  _G[name] = fn
end

do
  local register = store.originals['vgui.Register'] or vgui.Register

  store.originals['vgui.Register'] = register

  --- Patches a class that is being registered, if there are patches for it.
  function vgui.Register(class_name, class_table, base)
    local result = register(class_name, class_table, base)

    DermaScale.apply(class_name)

    return result
  end
end

local function control_table(class_name)
  return vgui.GetControlTable(class_name)
end

-- Labels, buttons and text entries.

DermaScale.after('DLabel', 'Init', function(panel)
  panel:SetTall(s(20))
end)

DermaScale.after('DLabelURL', 'Init', function(panel)
  panel:SetTall(s(20))
end)

DermaScale.after('DLabelEditable', 'SizeToContents', function(panel)
  local w, h = panel:GetContentSize()

  panel:SetSize(w + s(16), h)
end)

DermaScale.after('DButton', 'Init', function(panel)
  panel:SetTall(s(22))
end)

DermaScale.replace('DButton', 'PerformLayoutImage', function(self)
  if !IsValid(self.m_Image) then return end

  local target_size = math_min(self:GetWide() - s(4), self:GetTall() - s(4))
  local image_w, image_h = self.m_Image.ActualWidth, self.m_Image.ActualHeight

  -- Icons may grow with the screen, but not beyond the scale factor.
  local zoom = math_min(target_size / image_w, target_size / image_h, DermaScale.factor())

  self.m_Image:SetWide(math_ceil(image_w * zoom))
  self.m_Image:SetTall(math_ceil(image_h * zoom))

  if self:GetWide() < self:GetTall() then
    self.m_Image:SetPos(s(4), (self:GetTall() - self.m_Image:GetTall()) * 0.5)
  else
    self.m_Image:SetPos(
      s(2) + (target_size - self.m_Image:GetWide()) * 0.5,
      (self:GetTall() - self.m_Image:GetTall()) * 0.5
    )
  end

  -- For center alignments, reduce the inset of the image, so the text appears more centered visually.
  local alignment = self:GetContentAlignment()

  if alignment == 8 or alignment == 5 or alignment == 2 then
    self:SetTextInset(self.m_Image:GetWide() + s(4), 0)
  else
    self:SetTextInset(self.m_Image:GetWide() + s(8), 0)
  end
end)

DermaScale.replace('DButton', 'SizeToContents', function(self)
  self:PerformLayoutImage()

  local w, h = self:GetContentSize()

  self:SetSize(w + s(8), h + s(4))
end)

DermaScale.replace('DButton', 'SizeToContentsX', function(self, add_value)
  self:PerformLayoutImage()

  local w, h = self:GetContentSize()

  self:SetWide(w + s(8) + (add_value or 0))
end)

DermaScale.after('DTextEntry', 'Init', function(panel)
  panel:SetTall(s(20))
end)

DermaScale.after('DNumberWang', 'Init', function(panel)
  panel:SetTall(s(20))
end)

DermaScale.replace('DNumberWang', 'PerformLayout', function(self)
  local size = math_floor(self:GetTall() * 0.5)

  self.Up:SetSize(size, size - 1)
  self.Up:AlignRight(s(3))
  self.Up:AlignTop(0)

  self.Down:SetSize(size, size - 1)
  self.Down:AlignRight(s(3))
  self.Down:AlignBottom(s(2))
end)

DermaScale.replace('DNumberWang', 'SizeToContents', function(self)
  -- Size based on the max number and max amount of decimals.
  local decimals = self:GetDecimals()
  local min = math.Round(self:GetMin(), decimals)
  local max = math.Round(self:GetMax(), decimals)
  local chars = math_max(string.len(''..min..''), string.len(''..max..''))

  if decimals and decimals > 0 then
    chars = chars + 1 + decimals
  end

  self:InvalidateLayout(true)
  self:SetWide(s(chars * 6 + 20))
  self:InvalidateLayout()
end)

DermaScale.after('DNumberScratch', 'Init', function(panel)
  panel:SetSize(s(16), s(16))
end)

DermaScale.after('DBinder', 'Init', function(panel)
  panel:SetSize(s(60), s(30))
end)

-- Check boxes.

DermaScale.after('DCheckBox', 'Init', function(panel)
  panel:SetSize(s(15), s(15))
end)

DermaScale.after('DCheckBoxLabel', 'Init', function(panel)
  panel:SetTall(s(16))
end)

DermaScale.replace('DCheckBoxLabel', 'PerformLayout', function(self)
  local x = self.m_iIndent or 0

  self.Button:SetSize(s(15), s(15))
  self.Button:SetPos(x, math_floor((self:GetTall() - self.Button:GetTall()) * 0.5))

  self.Label:SizeToContents()
  self.Label:SetPos(x + self.Button:GetWide() + s(9), math_floor((self:GetTall() - self.Label:GetTall()) * 0.5))
end)

-- Combo boxes and menus.

DermaScale.after('DComboBox', 'Init', function(panel)
  panel:SetTall(s(22))
  panel:SetTextInset(s(8), 0)
end)

DermaScale.replace('DComboBox', 'PerformLayout', function(self, w, h)
  self.DropButton:SetSize(s(15), s(15))
  self.DropButton:AlignRight(s(4))
  self.DropButton:CenterVertical()

  -- Make sure the text color is updated.
  control_table('DButton').PerformLayout(self, w, h)
end)

DermaScale.after('DMenu', 'Init', function(panel)
  panel:SetMinimumWidth(s(100))
end)

DermaScale.after('DMenu', 'AddSpacer', function(panel, spacer)
  if IsValid(spacer) then
    spacer:SetTall(s(1))
  end
end)

DermaScale.after('DMenuOption', 'Init', function(panel)
  -- Room for the icon on the left.
  panel:SetTextInset(s(32), 0)
end)

DermaScale.replace('DMenuOption', 'PerformLayout', function(self, w, h)
  local content_w, content_h = self:GetContentSize()
  w = math_max(self:GetParent():GetWide(), content_w + s(30))

  self:SetSize(w, s(22))

  if IsValid(self.SubMenuArrow) then
    self.SubMenuArrow:SetSize(s(15), s(15))
    self.SubMenuArrow:CenterVertical()
    self.SubMenuArrow:AlignRight(s(4))
  end

  control_table('DButton').PerformLayout(self, w, h)
end)

DermaScale.after('DMenuBar', 'Init', function(panel)
  panel:SetTall(s(24))
end)

local function layout_menu_bar_button(button)
  if !IsValid(button) or button.ClassName != 'DButton' then return end

  -- Apply the font again, in case the bar outlived a rebuild of the fonts, then fit the text.
  button:SetFont(button.m_FontName or 'DermaDefault')
  button:SizeToContentsX(s(20))
end

DermaScale.after('DMenuBar', 'AddMenu', function(panel)
  local children = panel:GetChildren()

  layout_menu_bar_button(children[#children])
end)

--- Sizes the menu bar of the spawn menu and the context menu (created once by the `menubar`
-- module when the gamemode loads and kept for good) and its buttons for the current screen.
-- `menubar.ParentTo` forces the bar to 30 pixels every time a menu opens, so it is wrapped to
-- call this afterwards.
function DermaScale.refresh_menu_bar()
  if !menubar or !IsValid(menubar.Control) then return end

  menubar.Control:SetTall(s(30))

  for k, child in ipairs(menubar.Control:GetChildren()) do
    layout_menu_bar_button(child)
  end
end

if menubar then
  local parent_to = store.originals['menubar.ParentTo'] or menubar.ParentTo

  if parent_to then
    store.originals['menubar.ParentTo'] = parent_to

    --- Attaches the menu bar to a menu as the original does, then scales it.
    -- @param panel [Panel the spawn menu or the context menu]
    function menubar.ParentTo(panel)
      parent_to(panel)

      DermaScale.refresh_menu_bar()
    end
  end
end

-- Windows and tooltips.

DermaScale.after('DFrame', 'Init', function(panel)
  panel:SetMinWidth(s(50))
  panel:SetMinHeight(s(50))
  panel:DockPadding(s(5), s(24) + s(5), s(5), s(5))
end)

DermaScale.replace('DFrame', 'PerformLayout', function(self, w, h)
  w = w or self:GetWide()

  local title_push = 0
  local button_w, button_h = s(31), s(24)

  if IsValid(self.imgIcon) then
    self.imgIcon:SetPos(s(5), s(5))
    self.imgIcon:SetSize(s(16), s(16))
    title_push = s(16)
  end

  self.btnClose:SetPos(w - button_w - s(4), 0)
  self.btnClose:SetSize(button_w, button_h)

  self.btnMaxim:SetPos(w - button_w * 2 - s(4), 0)
  self.btnMaxim:SetSize(button_w, button_h)

  self.btnMinim:SetPos(w - button_w * 3 - s(4), 0)
  self.btnMinim:SetSize(button_w, button_h)

  self.lblTitle:SetPos(s(8) + title_push, s(2))
  self.lblTitle:SetSize(w - s(25) - title_push, s(20))
end)

DermaScale.replace('DTooltip', 'PerformLayout', function(self)
  if IsValid(self.Contents) then
    self:SetWide(self.Contents:GetWide() + s(8))
    self:SetTall(self.Contents:GetTall() + s(8))
    self.Contents:SetPos(s(4), s(4))
    self.Contents:SetVisible(true)
  else
    local w, h = self:GetContentSize()

    self:SetSize(w + s(8), h + s(6))
    self:SetContentAlignment(5)
  end
end)

DermaScale.after('DBubbleContainer', 'Init', function(panel)
  panel:DockPadding(0, 0, 0, s(32))
end)

DermaScale.after('DNotify', 'Init', function(panel)
  panel:SetSpacing(s(4))
end)

-- Scroll bars, lists and layouts.

DermaScale.after('DVScrollBar', 'Init', function(panel)
  panel:SetSize(s(15), s(15))
end)

DermaScale.after('DHScrollBar', 'Init', function(panel)
  panel:SetSize(s(15), s(15))
end)

DermaScale.after('DHorizontalScroller', 'PerformLayout', function(panel)
  panel.btnLeft:SetSize(s(15), s(15))
  panel.btnLeft:AlignLeft(s(4))
  panel.btnLeft:AlignBottom(s(5))

  panel.btnRight:SetSize(s(15), s(15))
  panel.btnRight:AlignRight(s(4))
  panel.btnRight:AlignBottom(s(5))
end)

DermaScale.replace('DPanelList', 'PerformLayout', function(self)
  local wide = self:GetWide()
  local tall = self.pnlCanvas:GetTall()
  local y_pos = 0
  local bar_w = s(13)

  self:Rebuild()

  if self.VBar then
    self.VBar:SetPos(self:GetWide() - bar_w, 0)
    self.VBar:SetSize(bar_w, self:GetTall())
    self.VBar:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
    y_pos = self.VBar:GetOffset()

    if self.VBar.Enabled then wide = wide - bar_w end
  end

  self.pnlCanvas:SetPos(0, y_pos)
  self.pnlCanvas:SetWide(wide)

  self:Rebuild()

  if self:GetAutoSize() then
    self:SetTall(self.pnlCanvas:GetTall())
    self.pnlCanvas:SetPos(0, 0)
  end

  if self.VBar and !self:GetAutoSize() and tall != self.pnlCanvas:GetTall() then
    -- Make sure we are not too far down!
    self.VBar:SetScroll(self.VBar:GetScroll())
  end
end)

DermaScale.after('DListView', 'Init', function(panel)
  panel:SetHeaderHeight(s(16))
  panel:SetDataHeight(s(17))
end)

DermaScale.replace('DListView', 'PerformLayout', function(self)
  local wide = self:GetWide()
  local y_pos = 0
  local bar_w = s(16)

  if IsValid(self.VBar) then
    self.VBar:SetPos(self:GetWide() - bar_w, 0)
    self.VBar:SetSize(bar_w, self:GetTall())
    self.VBar:SetUp(self.VBar:GetTall() - self:GetHeaderHeight(), self.pnlCanvas:GetTall())
    y_pos = self.VBar:GetOffset()

    if self.VBar.Enabled then wide = wide - bar_w end
  end

  if self.m_bHideHeaders then
    self.pnlCanvas:SetPos(0, y_pos)
  else
    self.pnlCanvas:SetPos(0, y_pos + self:GetHeaderHeight())
  end

  self.pnlCanvas:SetSize(wide, self.pnlCanvas:GetTall())

  self:FixColumnsLayout()

  -- If the data is dirty, re-layout.
  if self:GetDirty() then
    self:SetDirty(false)

    local y = self:DataLayout()

    self.pnlCanvas:SetTall(y)

    -- Layout again, since stuff has changed.
    self:InvalidateLayout(true)
  end
end)

DermaScale.after('DListView_Column', 'Init', function(panel)
  panel:SetMinWidth(s(10))
end)

DermaScale.after('DListView_Column', 'PerformLayout', function(panel)
  panel.DraggerBar:SetWide(s(4))
  panel.DraggerBar:StretchToParent(nil, 0, nil, 0)
  panel.DraggerBar:AlignRight()
end)

DermaScale.after('DListView_Line', 'Init', function(panel)
  panel:SetTextInset(s(5), 0)
end)

DermaScale.after('DGrid', 'Init', function(panel)
  panel:SetColWide(s(32))
  panel:SetRowHeight(s(32))
end)

DermaScale.after('DIconBrowser', 'Init', function(panel)
  panel.IconLayout:SetBorder(s(4))
end)

DermaScale.after('DPanelSelect', 'Init', function(panel)
  panel:SetSpacing(s(2))
  panel:SetPadding(s(2))
end)

-- Trees.

DermaScale.after('DTree', 'Init', function(panel)
  panel:SetIndentSize(s(14))
  panel:SetLineHeight(s(17))
  panel.RootNode:DockMargin(0, s(4), 0, 0)
end)

DermaScale.after('DExpandButton', 'Init', function(panel)
  panel:SetSize(s(15), s(15))
end)

DermaScale.replace('DTree_Node', 'PerformLayout', function(self)
  if self:IsRootNode() then
    return self:PerformRootNodeLayout()
  end

  if self.animSlide:Active() then return end

  local line_height = self:GetLineHeight()

  if self.m_bHideExpander then
    self.Expander:SetPos(-s(11), 0)
    self.Expander:SetSize(s(15), s(15))
    self.Expander:SetVisible(false)
  else
    self.Expander:SetPos(s(2), 0)
    self.Expander:SetSize(s(15), s(15))
    self.Expander:SetVisible(self:HasChildren() or self:GetForceShowExpander())
    self.Expander:SetZPos(10)
  end

  self.Label:StretchToParent(0, nil, 0, nil)
  self.Label:SetTall(line_height)

  if self:ShowIcons() then
    -- Icons are 16 pixel images, grow them with the screen (from the size of the image, so
    -- that the size does not compound from one layout to the next).
    if self.Icon.ActualWidth and self.Icon.ActualHeight then
      self.Icon:SetSize(s(self.Icon.ActualWidth), s(self.Icon.ActualHeight))
    end

    self.Icon:SetVisible(true)
    self.Icon:SetPos(self.Expander.x + self.Expander:GetWide() + s(4), (line_height - self.Icon:GetTall()) * 0.5)
    self.Label:SetTextInset(self.Icon.x + self.Icon:GetWide() + s(4), 0)
  else
    self.Icon:SetVisible(false)
    self.Label:SetTextInset(self.Expander.x + self.Expander:GetWide() + s(4), 0)
  end

  if !IsValid(self.ChildNodes) or !self.ChildNodes:IsVisible() then
    self:SetTall(line_height)

    return
  end

  self.ChildNodes:SizeToContents()
  self:SetTall(line_height + self.ChildNodes:GetTall())

  self.ChildNodes:StretchToParent(line_height, line_height, 0, 0)

  self:DoChildrenOrder()
end)

-- Categories and forms.

DermaScale.after('DCategoryHeader', 'Init', function(panel)
  panel:SetTextInset(s(5), 0)
end)

DermaScale.after('DCollapsibleCategory', 'Init', function(panel)
  panel.Header:SetTall(s(20))
  panel:DockMargin(0, 0, 0, s(2))
end)

DermaScale.after('DCollapsibleCategory', 'Add', function(panel, button)
  if !IsValid(button) then return end

  button:SetTall(s(17))
  button:SetTextInset(s(4), 0)
  button:DockMargin(s(1), 0, s(1), 0)
end)

DermaScale.after('DCategoryList', 'Init', function(panel)
  panel.pnlCanvas:DockPadding(s(2), s(2), s(2), s(2))
end)

DermaScale.after('DForm', 'Init', function(panel)
  panel:SetSpacing(s(4))
  panel:SetPadding(s(10))
end)

DermaScale.after('DForm', 'AddItem', function(panel, result, left, right)
  if !IsValid(left) then return end

  local row = left:GetParent()

  if !IsValid(row) or row.ClassName != 'DSizeToContents' then return end

  row:DockPadding(s(10), s(10), s(10), 0)

  if IsValid(right) then
    left:SetSize(s(100), s(20))
    right:SetPos(s(110), 0)
  end
end)

DermaScale.after('DForm', 'Help', function(panel, label)
  if IsValid(label) then
    label:DockMargin(s(8), 0, s(8), s(8))
  end
end)

DermaScale.after('DForm', 'ControlHelp', function(panel, label)
  if IsValid(label) then
    label:DockMargin(s(32), 0, s(32), s(8))
  end
end)

-- Property sheets and tabs.

DermaScale.after('DPropertySheet', 'Init', function(panel)
  panel.tabScroller:SetOverlap(s(5))
  panel.tabScroller:DockMargin(s(3), 0, s(3), 0)
  panel:SetPadding(s(8))
end)

DermaScale.after('DPropertySheet', 'AddSheet', function(panel, sheet)
  if istable(sheet) and IsValid(sheet.Panel) then
    sheet.Panel:SetPos(panel:GetPadding(), s(20) + panel:GetPadding())
  end
end)

DermaScale.after('DPropertySheet', 'SetupCloseButton', function(panel)
  if IsValid(panel.CloseButton) then
    panel.CloseButton:DockMargin(s(1), s(1), s(1), s(9))
    panel.CloseButton:SetWide(s(18))
  end
end)

DermaScale.after('DTab', 'Init', function(panel)
  panel:SetTextInset(0, s(4))
end)

DermaScale.replace('DTab', 'GetTabHeight', function(self)
  if self:IsActive() then
    return s(28)
  end

  return s(20)
end)

DermaScale.replace('DTab', 'ApplySchemeSettings', function(self)
  local extra_inset = s(10)

  if self.Image then
    extra_inset = extra_inset + self.Image:GetWide()
  end

  self:SetTextInset(extra_inset, s(4))

  local w, h = self:GetContentSize()
  h = self:GetTabHeight()

  self:SetSize(w + s(10), h)

  control_table('DLabel').ApplySchemeSettings(self)
end)

DermaScale.after('DTab', 'PerformLayout', function(panel)
  if panel.Image then
    panel.Image:SetPos(s(7), s(3))
  end
end)

DermaScale.after('DColumnSheet', 'Init', function(panel)
  panel.Navigation:SetWide(s(100))
  panel.Navigation:DockMargin(s(10), s(10), s(10), 0)
end)

DermaScale.after('DColumnSheet', 'AddSheet', function(panel, sheet)
  if istable(sheet) and IsValid(sheet.Button) then
    sheet.Button:DockMargin(0, s(1), 0, 0)
  end
end)

-- Sliders.

DermaScale.after('DNumSlider', 'Init', function(panel)
  panel.TextArea:SetWide(s(45))
  panel.Slider:SetTall(s(16))
  panel:SetTall(s(32))
end)

DermaScale.after('DSlider', 'Init', function(panel)
  panel.Knob:SetSize(s(15), s(15))
end)

DermaScale.after('DNumPad', 'Init', function(panel)
  panel.Buttons[0]:SetTextInset(s(6), 0)
  panel:SetButtonSize(s(17))
  panel:SetPadding(s(4))
end)

-- Dividers and browsers.

DermaScale.after('DHorizontalDivider', 'Init', function(panel)
  panel:SetDividerWidth(s(8))
  panel:SetLeftWidth(s(100))
  panel:SetLeftMin(s(50))
  panel:SetRightMin(s(50))
end)

DermaScale.after('DVerticalDivider', 'Init', function(panel)
  panel:SetDividerHeight(s(8))
  panel:SetTopHeight(s(100))
  panel:SetTopMin(s(50))
  panel:SetBottomMin(s(50))
end)

DermaScale.after('DFileBrowser', 'Init', function(panel)
  panel.Divider:SetLeftWidth(s(160))
  panel.Divider:SetDividerWidth(s(4))
  panel.Divider:SetLeftMin(s(100))
  panel.Divider:SetRightMin(s(100))
end)

DermaScale.after('DDrawer', 'Init', function(panel)
  panel.ToggleButton:SetSize(s(18), s(18))
end)

DermaScale.after('DHTMLControls', 'Init', function(panel)
  local button_size, margin = s(32), s(2)

  for k, name in ipairs({ 'BackButton', 'ForwardButton', 'RefreshButton', 'HomeButton', 'StopButton' }) do
    local button = panel[name]

    if IsValid(button) then
      button:SetSize(button_size, button_size)
      button:DockMargin(0, margin, 0, margin)
    end
  end

  panel.AddressBar:DockMargin(0, margin * 3, margin * 3, margin * 3)
  panel:SetTall(button_size + margin * 2)
end)

-- Model selection.

DermaScale.replace('DModelSelect', 'SetHeight', function(self, rows)
  self:SetTall(s(66) * (rows or 2) + s(2))
end)

DermaScale.after('DModelSelect', 'SetModelList', function(panel)
  for k, icon in ipairs(panel:GetItems()) do
    if IsValid(icon) then
      icon:SetSize(s(64), s(64))
    end
  end
end)

DermaScale.replace('DModelSelectMulti', 'SetHeight', function(self, rows)
  self:SetTall(s(66) * (rows or 2) + s(26))
end)

DermaScale.after('SpawnIcon', 'Init', function(panel)
  panel:SetSize(s(64), s(64))
end)

DermaScale.replace('SpawnIcon', 'PerformLayout', function(self)
  if self:IsDown() and !self.Dragging then
    self.Icon:StretchToParent(s(6), s(6), s(6), s(6))
  else
    self.Icon:StretchToParent(0, 0, 0, 0)
  end
end)

-- Color controls.

DermaScale.after('DColorMixer', 'Init', function(panel)
  panel.Palette:SetTall(s(75))
  panel.Palette:SetButtonSize(s(16))
  panel.Palette:DockMargin(0, s(8), 0, 0)

  panel.WangsPanel:SetWide(s(50))
  panel.WangsPanel:DockMargin(s(4), 0, 0, 0)

  for k, name in ipairs({ 'txtR', 'txtG', 'txtB', 'txtA' }) do
    panel[name]:SetTall(s(20))

    if name != 'txtR' then
      panel[name]:DockMargin(0, s(4), 0, 0)
    end
  end

  panel.RGB:DockMargin(s(4), 0, 0, 0)
  panel.Alpha:DockMargin(s(4), 0, 0, 0)

  panel:SetSize(s(256), s(230))
end)

DermaScale.after('DColorMixer', 'PerformLayout', function(panel)
  local left, top, right, bottom = panel.Palette:GetDockMargin()

  panel.Palette:DockMargin(left, s(8), right, 0)
end)

DermaScale.after('DAlphaBar', 'Init', function(panel)
  panel:SetSize(s(26), s(26))
end)

DermaScale.after('DColorPalette', 'Init', function(panel)
  panel:SetSize(s(80), s(120))
  panel:SetButtonSize(s(10))
end)

DermaScale.after('DColorButton', 'Init', function(panel)
  panel:SetSize(s(10), s(10))
end)

DermaScale.after('DColorCombo', 'Init', function(panel)
  panel:SetSize(s(256), s(256))

  if IsValid(panel.Mixer) then
    panel.Mixer:DockMargin(s(8), 0, s(8), s(8))
  end

  for k, sheet in ipairs(panel.Items or {}) do
    if IsValid(sheet.Panel) and sheet.Panel.ClassName == 'DColorPalette' then
      sheet.Panel:DockMargin(s(8), 0, s(8), s(8))
      sheet.Panel:SetButtonSize(s(16))
    end
  end
end)

-- Sandbox spawn menu.

DermaScale.after('SpawnMenu', 'Init', function(panel)
  local divider = panel.HorizontalDivider

  divider:SetDividerWidth(s(6))
  divider:SetRightMin(s(ScrW() >= 1024 and 460 or 300))

  panel.ToolToggle:SetSize(s(16), s(16))
end)

DermaScale.after('SpawnMenu', 'PerformLayout', function(panel)
  if IsValid(panel.ToolToggle) then
    panel.ToolToggle:AlignRight(s(6))
    panel.ToolToggle:AlignTop(s(6))
  end
end)

DermaScale.after('ToolPanel', 'Init', function(panel)
  local divider = panel.HorizontalDivider

  divider:SetLeftWidth(s(130))
  divider:SetLeftMin(s(130))
  divider:SetRightMin(s(ScrW() >= 1024 and 256 or 200))
  divider:SetDividerWidth(s(6))

  if IsValid(panel.SearchBar) then
    local search_container = panel.SearchBar:GetParent()

    -- For the checkbox to fit neatly.
    search_container:SetTall(s(21))
    search_container:DockMargin(0, 0, 0, s(5))
  end

  if IsValid(panel.HideDeactivated) then
    panel.HideDeactivated:DockMargin(s(3), s(3), 0, s(3))
  end

  panel.List:SetWide(s(130))

  if IsValid(panel.WarningLabel) then
    panel.WarningLabel:SetTall(s(72))
  end
end)

DermaScale.after('SpawnmenuContentPanel', 'Init', function(panel)
  local divider = panel.HorizontalDivider
  local large = ScrW() >= 1024

  divider:SetLeftWidth(s(192))
  divider:SetLeftMin(s(large and 192 or 100))
  divider:SetRightMin(s(large and 400 or 100))
  divider:SetDividerWidth(s(6))
end)

DermaScale.after('ContentContainer', 'Init', function(panel)
  panel.IconList:SetBaseSize(s(64))
end)

DermaScale.after('ContentContainer', 'PerformLayout', function(panel)
  panel.IconList:SetMinHeight(panel:GetTall() - s(16))
end)

-- Content icons are two tiles of the icon list, so that they always fill whole tiles.
local function content_icon_size()
  return s(64) * 2
end

DermaScale.after('ContentIcon', 'Init', function(panel)
  local size = content_icon_size()

  panel:SetSize(size, size)
  panel.Image:SetPos(s(3), s(3))
  panel.Image:SetSize(size - s(6), size - s(6))
end)

do
  local overlay_normal = Material('gui/ContentIcon-normal.png')
  local overlay_hovered = Material('gui/ContentIcon-hovered.png')
  local overlay_admin_only = Material('icon16/shield.png')
  local overlay_npc_weapon = Material('icon16/monkey.png')
  local overlay_npc_weapon_selected = Material('icon16/monkey_tick.png')
  local shadow_color = Color(0, 0, 0, 200)
  local set_material = surface.SetMaterial
  local draw_textured_rect = surface.DrawTexturedRect

  DermaScale.replace('ContentIcon', 'Paint', function(self, w, h)
    local margin = s(8)

    if self.Depressed and !self.Dragging then
      if self.Border != margin then
        self.Border = margin
        self:OnDepressionChanged(true)
      end
    else
      if self.Border != 0 then
        self.Border = 0
        self:OnDepressionChanged(false)
      end
    end

    local border = self.Border
    local double_border = border * 2
    local image_pos = s(3) + border

    render.PushFilterMag(TEXFILTER.ANISOTROPIC)
    render.PushFilterMin(TEXFILTER.ANISOTROPIC)
      self.Image:PaintAt(image_pos, image_pos, w - margin - double_border, h - margin - double_border)
    render.PopFilterMin()
    render.PopFilterMag()

    surface.SetDrawColor(255, 255, 255, 255)

    local draw_text = false

    if !dragndrop.IsDragging() and (self:IsHovered() or self.Depressed or self:IsChildHovered()) then
      set_material(overlay_hovered)
    else
      set_material(overlay_normal)
      draw_text = true
    end

    draw_textured_rect(border, border, w - double_border, h - double_border)

    local overlay_pos, overlay_size = border + margin, s(16)

    -- Admin only icon.
    if self:GetAdminOnly() then
      set_material(overlay_admin_only)
      draw_textured_rect(overlay_pos, overlay_pos, overlay_size, overlay_size)
    end

    -- NPC weapon support icon.
    if self:GetIsNPCWeapon() then
      set_material(overlay_npc_weapon)

      if self:GetSpawnName() == GetConVarString('gmod_npcweapon') then
        set_material(overlay_npc_weapon_selected)
      end

      draw_textured_rect(w - border - s(24), overlay_pos, overlay_size, overlay_size)
    end

    self:ScanForNPCWeapons()

    if draw_text then
      local buffer = border + s(10)

      -- Set up smaller clipping so cut text looks nicer.
      local px, py = self:LocalToScreen(buffer, 0)
      local pw, ph = self:LocalToScreen(w - buffer, h)

      render.SetScissorRect(px, py, pw, ph, true)

      surface.SetFont('DermaDefault')

      local text_w, text_h = surface.GetTextSize(self.m_NiceName)
      local x = w * 0.5 - text_w * 0.5

      if text_w > (w - buffer * 2) then
        local mx, my = self:ScreenToLocal(input.GetCursorPos())
        local diff = text_w - w + buffer * 2

        x = buffer + math.Remap(math.Clamp(mx, 0, w), 0, w, 0, -diff)
      end

      local text_y = h - text_h - s(9)

      draw.SimpleText(self.m_NiceName, 'DermaDefault', x + 1, text_y + 1, shadow_color)
      draw.SimpleText(self.m_NiceName, 'DermaDefault', x, text_y, color_white)

      render.SetScissorRect(0, 0, 0, 0, false)
    end
  end)
end

DermaScale.after('PostProcessIcon', 'Init', function(panel)
  local size = content_icon_size()

  panel:SetSize(size, size)
end)

DermaScale.after('PostProcessIcon', 'Setup', function(panel)
  if IsValid(panel.checkbox) then
    panel.checkbox:SetSize(s(20), s(20))
    panel.checkbox:SetPos(panel:GetWide() - s(20) - s(8), s(8))
  end
end)

DermaScale.after('ContentHeader', 'Init', function(panel)
  panel:SetSize(s(64), s(64))
end)

DermaScale.replace('ContentHeader', 'SizeToContents', function(self)
  local w = self:GetContentSize()

  -- Don't let the text overflow the parent's width.
  if IsValid(self:GetParent()) then
    w = math_min(w, self:GetParent():GetWide() - s(32))
  end

  -- Add a bit more room so it looks nice as a textbox, and make sure it has at least some width.
  self:SetSize(math_max(w, s(64)) + s(16), s(64))
end)

DermaScale.replace('ContextMenu', 'PerformLayout', function(self)
  local control_panel = spawnmenu.ActiveControlPanel()

  if !IsValid(control_panel) then return end

  control_panel:InvalidateLayout(true)

  local tall = math_min(control_panel:GetTall() + s(10), ScrH() * 0.8)
  local wide = s(320)

  if self.Canvas:GetTall() != tall then self.Canvas:SetTall(tall) end
  if self.Canvas:GetWide() != wide then self.Canvas:SetWide(wide) end

  self.Canvas:SetPos(ScrW() - self.Canvas:GetWide() - s(50), ScrH() - s(50) - tall)
  self.Canvas:InvalidateLayout(true)
end)

-- Sandbox tool controls.

DermaScale.after('ControlPanel', 'ComboBoxMulti', function(panel, combo_box)
  if IsValid(combo_box) then
    combo_box:SetTall(s(25))
  end
end)

DermaScale.after('ControlPanel', 'AddControl', function(panel, control)
  if IsValid(control) and control.ClassName == 'CtrlListBox' then
    control:SetTall(s(25))
  end
end)

DermaScale.after('ControlPresets', 'Init', function(panel)
  panel.Button:SetSize(s(20), s(20))
  panel.AddButton:SetSize(s(20), s(20))
  panel.AddButton:DockMargin(s(2), 0, 0, 0)
  panel:SetTall(s(20))
end)

DermaScale.after('CtrlColor', 'Init', function(panel)
  panel:SetTall(s(245))
end)

DermaScale.after('CtrlColor', 'PerformLayout', function(panel)
  -- Keep the mixer at its target width, which fills the palette rows exactly.
  local margin = math_max((panel:GetWide() - s(272)) * 0.5, 0)

  panel.Mixer:DockMargin(margin, s(8), margin, 0)

  local rows = math_ceil(#panel.Mixer.Palette:GetChildren() / 3)
  local button_size = math_floor(panel:GetWide() / rows)

  panel.Mixer.Palette:SetButtonSize(math_min(button_size, s(17)))
end)

DermaScale.after('CtrlNumPad', 'Init', function(panel)
  panel:SetTall(s(200))
end)

DermaScale.after('CtrlNumPad', 'PerformLayout', function(panel)
  panel:SetTall(s(70))
  panel.NumPad1:SetSize(s(110), s(50))

  if panel.m_ConVar2 then
    panel.NumPad2:SetSize(s(110), s(50))
    panel.NumPad1:CenterHorizontal(0.25)
    panel.NumPad2:CenterHorizontal(0.75)
    panel.NumPad2:AlignTop(s(20))
  else
    panel.NumPad1:CenterHorizontal(0.5)
  end

  panel.NumPad1:AlignTop(s(20))
end)

DermaScale.after('PresetEditor', 'Init', function(panel)
  panel:SetSize(s(450), s(350))
  panel:DockPadding(s(6), s(29), s(6), s(6))

  if IsValid(panel.PresetList) then
    panel.PresetList:DockMargin(0, 0, s(5), 0)
    panel.PresetList:SetWide(s(150))
  end

  if IsValid(panel.pnlDetails) then
    panel.pnlDetails:DockMargin(s(5), s(5), s(5), s(5))
  end

  if IsValid(panel.pnlAdd) then
    panel.pnlAdd:DockPadding(s(5), s(5), s(5), s(5))
    panel.pnlAdd:DockMargin(0, 0, s(5), 0)
  end

  if IsValid(panel.txtName) then
    panel.txtName:DockMargin(0, 0, s(5), 0)
  end
end)

DermaScale.replace('ContextBase', 'PerformLayout', function(self)
  local y = s(5)

  self.Label:SetPos(s(5), y)
  self.Label:SetWide(self:GetWide())

  y = y + self.Label:GetTall()
  y = y + s(5)

  return y
end)

DermaScale.after('MatSelect', 'Init', function(panel)
  panel.List:SetSpacing(s(1))
  panel.List:SetPadding(s(3))
  panel:SetItemWidth(s(128))
end)

DermaScale.replace('MatSelect', 'PerformLayout', function(self)
  self.List:SetPos(0, 0)

  for k, v in pairs(self.List:GetItems()) do
    self:SetItemSize(v)
  end

  if self.m_bSizeToContent then
    self.List:SetWide(self:GetWide())
    self.List:InvalidateLayout(true)
    self:SetTall(self.List:GetTall() + s(5))

    return
  end

  -- Rebuild.
  self.List:InvalidateLayout(true)

  local max_w = self:GetWide()

  if self.List.VBar and self.List.VBar.Enabled then max_w = max_w - self.List.VBar:GetWide() end

  local h = self.ItemHeight

  if h < 1 then
    local num_icons = math_floor(1 / h)

    h = math_floor((max_w - self.List:GetPadding() * 2 - self.List:GetSpacing() * (num_icons - 1)) / num_icons)
  end

  local height = (h * self.Height) + (self.List:GetPadding() * 2) + self.List:GetSpacing() * (self.Height - 1)

  self.List:SetSize(self:GetWide(), height)
  self:SetTall(height + s(5))
end)

DermaScale.after('PropSelect', 'Init', function(panel)
  panel.List:SetSpacing(s(1))
  panel.List:SetPadding(s(3))
end)

DermaScale.replace('PropSelect', 'PerformLayout', function(self, w, h)
  local y = self.BaseClass.PerformLayout(self, w, h)

  if self.Height >= 1 then
    local height =
      (s(64) + self.List:GetSpacing()) * math_max(self.Height, 1) + self.List:GetPadding() * 2 - self.List:GetSpacing()

    self.List:SetPos(0, y)
    self.List:SetSize(self:GetWide(), height)

    y = y + height

    self:SetTall(y + s(5))
  else
    -- Height is set to 0 or less, auto stretch.
    self.List:SetWide(self:GetWide())
    self.List:SizeToChildren(false, true)
    self:SetTall(self.List:GetTall() + s(5))
  end
end)

-- Modal dialogs.

--- Displays a simple message box, scaled with the screen. Replaces Garry's Mod's Derma_Message.
-- @param text [String message]
-- @param title=Message [String title of the window]
-- @param button_text=#dialog.ok [String text of the button]
-- @return [Panel the DFrame]
DermaScale.replace_global('Derma_Message', function(text, title, button_text)
  local window = vgui.Create('DFrame')
  window:SetTitle(title or 'Message')
  window:SetDraggable(false)
  window:ShowCloseButton(false)
  window:SetBackgroundBlur(true)
  window:SetDrawOnTop(true)

  local inner_panel = vgui.Create('Panel', window)

  local label = vgui.Create('DLabel', inner_panel)
  label:SetText(text or 'Message Text')
  label:SizeToContents()
  label:SetContentAlignment(5)
  label:SetTextColor(color_white)

  local button_panel = vgui.Create('DPanel', window)
  button_panel:SetTall(s(30))
  button_panel:SetPaintBackground(false)

  local button = vgui.Create('DButton', button_panel)
  button:SetText(button_text or '#dialog.ok')
  button:SizeToContents()
  button:SetTall(s(20))
  button:SetWide(button:GetWide() + s(20))
  button:SetPos(s(5), s(5))
  button.DoClick = function() window:Close() end

  button_panel:SetWide(button:GetWide() + s(10))

  local w, h = label:GetSize()

  window:SetSize(w + s(50), h + s(25) + s(45) + s(10))
  window:Center()

  inner_panel:StretchToParent(s(5), s(25), s(5), s(45))
  label:StretchToParent(s(5), s(5), s(5), s(5))

  button_panel:CenterHorizontal()
  button_panel:AlignBottom(s(8))

  window:MakePopup()
  window:DoModal()

  return window
end)

--- Asks a question with up to four answers, scaled with the screen. Replaces Garry's Mod's
-- Derma_Query.
-- @param text [String question]
-- @param title [String title of the window]
-- @param ... [String, function pairs of button text and callback]
-- @return [Panel the DFrame, or nil if no answers were given]
DermaScale.replace_global('Derma_Query', function(text, title, ...)
  local window = vgui.Create('DFrame')
  window:SetTitle(title or 'Message Title (First Parameter)')
  window:SetDraggable(false)
  window:ShowCloseButton(false)
  window:SetBackgroundBlur(true)
  window:SetDrawOnTop(true)

  local inner_panel = vgui.Create('DPanel', window)
  inner_panel:SetPaintBackground(false)

  local label = vgui.Create('DLabel', inner_panel)
  label:SetText(text or 'Message Text (Second Parameter)')
  label:SizeToContents()
  label:SetContentAlignment(5)
  label:SetTextColor(color_white)

  local button_panel = vgui.Create('DPanel', window)
  button_panel:SetTall(s(30))
  button_panel:SetPaintBackground(false)

  -- Loop through all the options and create buttons for them.
  local num_options = 0
  local x = s(5)

  for k = 1, 8, 2 do
    local button_text = select(k, ...)

    if button_text == nil then break end

    local callback = select(k + 1, ...) or function() end

    local button = vgui.Create('DButton', button_panel)
    button:SetText(button_text)
    button:SizeToContents()
    button:SetTall(s(20))
    button:SetWide(button:GetWide() + s(20))
    button.DoClick = function() window:Close() callback() end
    button:SetPos(x, s(5))

    x = x + button:GetWide() + s(5)

    button_panel:SetWide(x)

    num_options = num_options + 1
  end

  local w, h = label:GetSize()
  w = math_max(w, button_panel:GetWide())

  window:SetSize(w + s(50), h + s(25) + s(45) + s(10))
  window:Center()

  inner_panel:StretchToParent(s(5), s(25), s(5), s(45))
  label:StretchToParent(s(5), s(5), s(5), s(5))

  button_panel:CenterHorizontal()
  button_panel:AlignBottom(s(8))

  window:MakePopup()
  window:DoModal()

  if num_options == 0 then
    window:Close()
    Error('Derma_Query: Created Query with no Options!?')

    return nil
  end

  return window
end)

--- Requests a string from the player, scaled with the screen. Replaces Garry's Mod's
-- Derma_StringRequest.
-- @param title [String title of the window]
-- @param text [String message]
-- @param default_text [String initial text of the entry]
-- @param on_enter [function(text) called with the entered text when it is confirmed]
-- @param on_cancel=nil [function(text) called when the request is cancelled]
-- @param button_text=#dialog.ok [String text of the confirm button]
-- @param button_cancel_text=#dialog.cancel [String text of the cancel button]
-- @return [Panel the DFrame]
DermaScale.replace_global(
  'Derma_StringRequest',
  function(title, text, default_text, on_enter, on_cancel, button_text, button_cancel_text)
    local window = vgui.Create('DFrame')
    window:SetTitle(title or 'Message Title (First Parameter)')
    window:SetDraggable(false)
    window:ShowCloseButton(false)
    window:SetBackgroundBlur(true)
    window:SetDrawOnTop(true)

    local inner_panel = vgui.Create('DPanel', window)
    inner_panel:SetPaintBackground(false)

    local label = vgui.Create('DLabel', inner_panel)
    label:SetText(text or 'Message Text (Second Parameter)')
    label:SizeToContents()
    label:SetContentAlignment(5)
    label:SetTextColor(color_white)

    local text_entry = vgui.Create('DTextEntry', inner_panel)
    text_entry:SetText(default_text or '')
    text_entry.OnEnter = function() window:Close() on_enter(text_entry:GetValue()) end

    local button_panel = vgui.Create('DPanel', window)
    button_panel:SetTall(s(30))
    button_panel:SetPaintBackground(false)

    local button = vgui.Create('DButton', button_panel)
    button:SetText(button_text or '#dialog.ok')
    button:SizeToContents()
    button:SetTall(s(20))
    button:SetWide(button:GetWide() + s(20))
    button:SetPos(s(5), s(5))
    button.DoClick = function() window:Close() on_enter(text_entry:GetValue()) end

    local button_cancel = vgui.Create('DButton', button_panel)
    button_cancel:SetText(button_cancel_text or '#dialog.cancel')
    button_cancel:SizeToContents()
    button_cancel:SetTall(s(20))
    button_cancel:SetWide(button:GetWide() + s(20))
    button_cancel:SetPos(s(5), s(5))
    button_cancel.DoClick = function()
      window:Close()

      if on_cancel then
        on_cancel(text_entry:GetValue())
      end
    end

    button_cancel:MoveRightOf(button, s(5))

    button_panel:SetWide(button:GetWide() + s(5) + button_cancel:GetWide() + s(10))

    local w, h = label:GetSize()
    w = math_max(w, s(400))

    window:SetSize(w + s(50), h + s(25) + s(75) + s(10))
    window:Center()

    inner_panel:StretchToParent(s(5), s(25), s(5), s(45))
    label:StretchToParent(s(5), s(5), s(5), s(35))

    text_entry:StretchToParent(s(5), nil, s(5), nil)
    text_entry:AlignBottom(s(5))
    text_entry:RequestFocus()
    text_entry:SelectAllText(true)

    button_panel:CenterHorizontal()
    button_panel:AlignBottom(s(8))

    window:MakePopup()
    window:DoModal()

    return window
  end
)

-- Resolution changes.

--- Rebuilds the spawn menu once the fonts have been recreated for the new resolution, since
-- its panels were sized for the previous one. Panels that are open at that moment keep their
-- sizes until they are created again.
hook.Add('OnResolutionChanged', 'DermaScale', function(new_w, new_h, old_w, old_h)
  if math_max(new_h / 1080, 1) == math_max(old_h / 1080, 1) then return end

  timer.Simple(0, function()
    DermaScale.refresh_menu_bar()

    if IsValid(g_SpawnMenu) then
      RunConsoleCommand('spawnmenu_reload')
    end
  end)
end)
