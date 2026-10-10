--- The 'Flux' Derma skin, which Flux makes the default skin of all Derma panels: a flat, dark
-- skin that draws the stock controls (frames, buttons, text entries, lists, trees, menus,
-- sliders, tabs and tooltips) with rounded boxes and FontAwesome glyphs instead of the GWEN
-- texture atlas. Its colors are a palette of plain fields on the skin table, so that a theme can
-- recolor the whole of Derma: `SKIN:apply_theme` maps the semantic colors of the active theme
-- ('surface', 'border', 'text', 'accent' and so on) onto those fields and is run by
-- `Theme.set_derma_skin` whenever a theme is loaded, after the `skin` table of the theme has
-- been copied over. The defaults below match the factory theme, so the skin looks right before
-- any theme has loaded.

local set_draw_color = surface.SetDrawColor
local draw_rect      = surface.DrawRect
local rounded_box    = draw.RoundedBox
local rounded_box_ex = draw.RoundedBoxEx
local math_max       = math.max
local math_floor     = math.floor

--- Scales a size designed for 1080p like the stock Derma panels do (see cl_derma_scale.lua,
-- which loads after this file).
-- @param size [Number]
-- @return [Number]
local function scale(size)
  return DermaScale and DermaScale.scale(size) or size
end

--- Draws a rounded box with a 1 pixel border: the border color first, the fill inset by one
-- pixel on top of it.
-- @param radius [Number corner radius]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @param fill [Color]
-- @param border [Color border, nil for none]
local function card(radius, x, y, w, h, fill, border)
  if border then
    rounded_box(radius, x, y, w, h, border)
    rounded_box(math_max(radius - 1, 0), x + 1, y + 1, w - 2, h - 2, fill)
  else
    rounded_box(radius, x, y, w, h, fill)
  end
end

--- Draws a FontAwesome glyph centered in a box, if the FontAwesome package is there.
-- @param icon [String icon ID]
-- @param x [Number left of the box]
-- @param y [Number top of the box]
-- @param w [Number width of the box]
-- @param h [Number height of the box]
-- @param size [Number font size of the glyph]
-- @param color [Color]
local function glyph(icon, x, y, w, h, size, color)
  if !FontAwesome then return end

  FontAwesome:draw(icon, x + w * 0.5, y + h * 0.5, size, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

SKIN                          = {}

SKIN.print_name               = 'Flux Skin'
SKIN.Author                   = 'TeslaCloud Studios'
SKIN.DermaVersion             = 1
SKIN.GwenTexture              = Material('gwenskin/GModDefault.png')

SKIN.radius                   = 6
SKIN.radius_small             = 4

SKIN.bg_color                 = Color(30, 33, 44, 250)
SKIN.bg_color_sleep           = Color(26, 29, 38, 250)
SKIN.bg_color_dark            = Color(17, 19, 26)
SKIN.bg_color_bright          = Color(42, 46, 60)
SKIN.frame_border             = Color(74, 80, 104)
SKIN.frame_header             = Color(38, 42, 54)
SKIN.frame_shadow             = Color(0, 0, 0, 90)

SKIN.control_color            = Color(44, 48, 62)
SKIN.control_color_highlight  = Color(58, 63, 82)
SKIN.control_color_active     = Color(120, 132, 232)
SKIN.control_color_bright     = Color(164, 174, 255)
SKIN.control_color_dark       = Color(34, 37, 48)

SKIN.bg_alt1                  = Color(30, 33, 44)
SKIN.bg_alt2                  = Color(36, 40, 52)

SKIN.listview_hover           = Color(52, 57, 74)
SKIN.listview_selected        = Color(120, 132, 232, 120)

SKIN.text_bright              = Color(250, 251, 255)
SKIN.text_normal              = Color(240, 242, 248)
SKIN.text_muted               = Color(168, 176, 196)
SKIN.text_dark                = Color(118, 126, 148)
SKIN.text_highlight           = Color(164, 174, 255)

SKIN.texGradientUp            = Material('gui/gradient_up')
SKIN.texGradientDown          = Material('gui/gradient_down')

SKIN.panel_transback          = Color(255, 255, 255, 50)
SKIN.tooltip                  = Color(26, 29, 38, 245)

SKIN.colPropertySheet         = Color(30, 33, 44, 250)
SKIN.colTab                   = Color(30, 33, 44, 250)
SKIN.colTabInactive           = Color(22, 24, 33, 250)
SKIN.colTabShadow             = Color(0, 0, 0, 0)
SKIN.colTabText               = Color(240, 242, 248)
SKIN.colTabTextInactive       = Color(168, 176, 196)

SKIN.colCollapsibleCategory   = Color(38, 42, 54)
SKIN.colCategoryText          = Color(240, 242, 248)
SKIN.colCategoryTextInactive  = Color(168, 176, 196)

SKIN.colNumberWangBG          = Color(20, 22, 30)
SKIN.colTextEntryBG           = Color(20, 22, 30)
SKIN.colTextEntryBorder       = Color(74, 80, 104)
SKIN.colTextEntryFocus        = Color(120, 132, 232)
SKIN.colTextEntryText         = Color(240, 242, 248)
SKIN.colTextEntryTextHighlight = Color(120, 132, 232, 120)
SKIN.colTextEntryTextCursor   = Color(240, 242, 248)

SKIN.colMenuBG                = Color(26, 29, 38, 250)
SKIN.colMenuBorder            = Color(74, 80, 104)

SKIN.colButtonText            = Color(240, 242, 248)
SKIN.colButtonTextDisabled    = Color(118, 126, 148)
SKIN.colButtonBorder          = Color(74, 80, 104)
SKIN.colButtonBorderHighlight = Color(255, 255, 255, 50)
SKIN.colButtonBorderShadow    = Color(0, 0, 0, 100)

SKIN.combobox_selected        = SKIN.listview_selected

SKIN.Colours                            = {}

SKIN.Colours.Window                     = {}
SKIN.Colours.Window.TitleActive         = SKIN.text_normal
SKIN.Colours.Window.TitleInactive       = SKIN.text_muted

SKIN.Colours.Button                     = {}
SKIN.Colours.Button.Normal              = SKIN.text_normal
SKIN.Colours.Button.Hover               = SKIN.text_bright
SKIN.Colours.Button.Down                = SKIN.text_bright
SKIN.Colours.Button.Disabled            = SKIN.text_dark

SKIN.Colours.Tab                        = {}
SKIN.Colours.Tab.Active                 = {}
SKIN.Colours.Tab.Active.Normal          = SKIN.text_normal
SKIN.Colours.Tab.Active.Hover           = SKIN.text_bright
SKIN.Colours.Tab.Active.Down            = SKIN.text_bright
SKIN.Colours.Tab.Active.Disabled        = SKIN.text_dark

SKIN.Colours.Tab.Inactive               = {}
SKIN.Colours.Tab.Inactive.Normal        = SKIN.text_muted
SKIN.Colours.Tab.Inactive.Hover         = SKIN.text_normal
SKIN.Colours.Tab.Inactive.Down          = SKIN.text_bright
SKIN.Colours.Tab.Inactive.Disabled      = SKIN.text_dark

SKIN.Colours.Label                      = {}
SKIN.Colours.Label.Default              = SKIN.text_normal
SKIN.Colours.Label.Bright               = SKIN.text_bright
SKIN.Colours.Label.Dark                 = SKIN.text_normal
SKIN.Colours.Label.Highlight            = SKIN.text_highlight

SKIN.Colours.Tree                       = {}
SKIN.Colours.Tree.Lines                 = SKIN.frame_border
SKIN.Colours.Tree.Normal                = SKIN.text_normal
SKIN.Colours.Tree.Hover                 = SKIN.text_bright
SKIN.Colours.Tree.Selected              = SKIN.text_bright

SKIN.Colours.Properties                 = {}
SKIN.Colours.Properties.Line_Normal     = SKIN.bg_alt1
SKIN.Colours.Properties.Line_Selected   = SKIN.listview_selected
SKIN.Colours.Properties.Line_Hover      = SKIN.listview_hover
SKIN.Colours.Properties.Title           = SKIN.text_bright
SKIN.Colours.Properties.Column_Normal   = SKIN.bg_alt2
SKIN.Colours.Properties.Column_Selected = SKIN.listview_selected
SKIN.Colours.Properties.Column_Hover    = SKIN.listview_hover
SKIN.Colours.Properties.Column_Disabled = SKIN.control_color_dark
SKIN.Colours.Properties.Border          = SKIN.frame_border
SKIN.Colours.Properties.Label_Normal    = SKIN.text_normal
SKIN.Colours.Properties.Label_Selected  = SKIN.text_bright
SKIN.Colours.Properties.Label_Hover     = SKIN.text_bright
SKIN.Colours.Properties.Label_Disabled  = SKIN.text_dark

SKIN.Colours.Category                   = {}
SKIN.Colours.Category.Header            = SKIN.text_normal
SKIN.Colours.Category.Header_Closed     = SKIN.text_muted

SKIN.Colours.Category.Line                    = {}
SKIN.Colours.Category.Line.Text               = SKIN.text_normal
SKIN.Colours.Category.Line.Text_Hover         = SKIN.text_bright
SKIN.Colours.Category.Line.Text_Selected      = SKIN.text_bright
SKIN.Colours.Category.Line.Text_Disabled      = SKIN.text_dark
SKIN.Colours.Category.Line.Button             = SKIN.bg_alt1
SKIN.Colours.Category.Line.Button_Hover       = SKIN.listview_hover
SKIN.Colours.Category.Line.Button_Selected    = SKIN.listview_selected

SKIN.Colours.Category.LineAlt                 = {}
SKIN.Colours.Category.LineAlt.Text            = SKIN.text_normal
SKIN.Colours.Category.LineAlt.Text_Hover      = SKIN.text_bright
SKIN.Colours.Category.LineAlt.Text_Selected   = SKIN.text_bright
SKIN.Colours.Category.LineAlt.Text_Disabled   = SKIN.text_dark
SKIN.Colours.Category.LineAlt.Button          = SKIN.bg_alt2
SKIN.Colours.Category.LineAlt.Button_Hover    = SKIN.listview_hover
SKIN.Colours.Category.LineAlt.Button_Selected = SKIN.listview_selected

SKIN.Colours.TooltipText                      = SKIN.text_normal

--- Recolors the skin from the semantic colors of a theme. Every field of the palette and
-- every entry of `Colours` is set, so a theme only has to define its colors; it can still
-- override single fields through its `skin` table, which `Theme.set_derma_skin` copies over
-- before it calls this.
-- @param theme [ThemeBase the theme that has been loaded]
function SKIN:apply_theme(theme)
  local get = function(id, fallback)
    return theme:get_color(id, fallback)
  end

  local surface_color = get('surface', self.bg_color)
  local raised        = get('surface_raised', self.bg_color_bright)
  local sunken        = get('surface_sunken', self.bg_color_sleep)
  local border        = get('border', self.frame_border)
  local text          = get('text', self.text_normal)
  local text_muted    = get('text_muted', self.text_muted)
  local text_dim      = get('text_dim', self.text_dark)
  local accent        = get('accent', self.control_color_active)
  local accent_light  = get('accent_light', self.control_color_bright)
  local main          = get('main', self.control_color)
  local main_light    = get('main_light', self.control_color_highlight)
  local main_dark     = get('main_dark', self.control_color_dark)
  local selection     = ColorAlpha(accent, 120)
  local bright        = Color(255, 255, 255)

  self.radius                   = theme:get_option('corner_radius_base', self.radius)
  self.radius_small             = theme:get_option('corner_radius_small_base', self.radius_small)

  self.bg_color                 = surface_color
  self.bg_color_sleep           = sunken
  self.bg_color_dark            = get('background', self.bg_color_dark)
  self.bg_color_bright          = raised
  self.frame_border             = border
  self.frame_header             = get('surface_header', raised)

  self.control_color            = main
  self.control_color_highlight  = main_light
  self.control_color_active     = accent
  self.control_color_bright     = accent_light
  self.control_color_dark       = main_dark

  self.bg_alt1                  = surface_color
  self.bg_alt2                  = raised
  self.listview_hover           = main_light
  self.listview_selected        = selection
  self.combobox_selected        = selection

  self.text_bright              = bright
  self.text_normal              = text
  self.text_muted               = text_muted
  self.text_dark                = text_dim
  self.text_highlight           = accent_light

  self.tooltip                  = ColorAlpha(sunken, 245)

  self.colPropertySheet         = surface_color
  self.colTab                   = surface_color
  self.colTabInactive           = sunken
  self.colTabText               = text
  self.colTabTextInactive       = text_muted

  self.colCollapsibleCategory   = self.frame_header
  self.colCategoryText          = text
  self.colCategoryTextInactive  = text_muted

  self.colNumberWangBG          = get('field', sunken)
  self.colTextEntryBG           = get('field', sunken)
  self.colTextEntryBorder       = border
  self.colTextEntryFocus        = accent
  self.colTextEntryText         = text
  self.colTextEntryTextHighlight = selection
  self.colTextEntryTextCursor   = text

  self.colMenuBG                = ColorAlpha(sunken, 250)
  self.colMenuBorder            = border

  self.colButtonText            = text
  self.colButtonTextDisabled    = text_dim
  self.colButtonBorder          = border

  local colours = self.Colours

  colours.Window.TitleActive          = text
  colours.Window.TitleInactive        = text_muted

  colours.Button.Normal               = text
  colours.Button.Hover                = bright
  colours.Button.Down                 = bright
  colours.Button.Disabled             = text_dim

  colours.Tab.Active.Normal           = text
  colours.Tab.Active.Hover            = bright
  colours.Tab.Active.Down             = bright
  colours.Tab.Active.Disabled         = text_dim
  colours.Tab.Inactive.Normal         = text_muted
  colours.Tab.Inactive.Hover          = text
  colours.Tab.Inactive.Down           = bright
  colours.Tab.Inactive.Disabled       = text_dim

  colours.Label.Default               = text
  colours.Label.Bright                = bright
  colours.Label.Dark                  = text
  colours.Label.Highlight             = accent_light

  colours.Tree.Lines                  = border
  colours.Tree.Normal                 = text
  colours.Tree.Hover                  = bright
  colours.Tree.Selected               = bright

  colours.Properties.Line_Normal      = surface_color
  colours.Properties.Line_Selected    = selection
  colours.Properties.Line_Hover       = main_light
  colours.Properties.Title            = bright
  colours.Properties.Column_Normal    = raised
  colours.Properties.Column_Selected  = selection
  colours.Properties.Column_Hover     = main_light
  colours.Properties.Column_Disabled  = main_dark
  colours.Properties.Border           = border
  colours.Properties.Label_Normal     = text
  colours.Properties.Label_Selected   = bright
  colours.Properties.Label_Hover      = bright
  colours.Properties.Label_Disabled   = text_dim

  colours.Category.Header             = text
  colours.Category.Header_Closed      = text_muted

  for k, line in ipairs({ colours.Category.Line, colours.Category.LineAlt }) do
    line.Text             = text
    line.Text_Hover       = bright
    line.Text_Selected    = bright
    line.Text_Disabled    = text_dim
    line.Button           = k == 1 and surface_color or raised
    line.Button_Hover     = main_light
    line.Button_Selected  = selection
  end

  colours.TooltipText = text
end

--- Paints the background of a panel, if it has one: a rounded box in its background color.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintPanel(panel, w, h)
  if !panel.m_bBackground then return end

  rounded_box(scale(self.radius_small), 0, 0, w, h, panel.m_bgColor or self.bg_color)
end

--- Paints a soft drop shadow around a panel.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintShadow(panel, w, h)
  local radius = scale(self.radius)
  local shadow = self.frame_shadow

  for i = 1, 3 do
    rounded_box(radius + i, -i, -i + 1, w + i * 2, h + i * 2, ColorAlpha(shadow, shadow.a / (i * 2)))
  end
end

--- Paints a window frame: a rounded card with a header band behind the title bar and a soft
-- shadow, dimmed while the frame does not have focus.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintFrame(panel, w, h)
  local radius = scale(self.radius)
  local header = scale(24)
  local focused = panel:HasHierarchicalFocus()

  if panel.m_bPaintShadow then
    DisableClipping(true)
      self:PaintShadow(panel, w, h)
    DisableClipping(false)
  end

  card(radius, 0, 0, w, h, focused and self.bg_color or self.bg_color_sleep, self.frame_border)
  rounded_box_ex(math_max(radius - 1, 0), 1, 1, w - 2, header, self.frame_header, true, true, false, false)

  set_draw_color(self.frame_border)
  draw_rect(1, header + 1, w - 2, 1)
end

--- Paints the background of a button according to its state: filled with the accent color
-- while it is pressed or selected, lighter while it is hovered and dimmed while it is disabled.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButton(panel, w, h)
  if !panel.m_bBackground then return end

  local radius = scale(self.radius_small)
  local fill = self.control_color
  local border = self.frame_border

  if panel:GetDisabled() then
    fill = self.control_color_dark
    border = ColorAlpha(border, 120)
  elseif panel.Depressed or panel:IsSelected() or panel:GetToggle() then
    fill = self.control_color_active
    border = self.control_color_active
  elseif panel.Hovered then
    fill = self.control_color_highlight
  end

  card(radius, 0, 0, w, h, fill, border)
end

--- Paints the background of a tree view, if it has one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTree(panel, w, h)
  if !panel.m_bBackground then return end

  card(scale(self.radius_small), 0, 0, w, h, panel.m_bgColor or self.bg_color_sleep, self.frame_border)
end

--- Paints a checkbox: an outlined box, filled with the accent color and a check mark while it
-- is checked, dimmed while it is disabled.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCheckBox(panel, w, h)
  local radius = scale(3)
  local disabled = panel:GetDisabled()
  local checked = panel:GetChecked()
  local fill = checked and self.control_color_active or self.colTextEntryBG
  local border = checked and self.control_color_active or self.frame_border

  if disabled then
    fill = ColorAlpha(fill, 120)
    border = ColorAlpha(border, 120)
  elseif panel.Hovered and !checked then
    border = self.control_color_bright
  end

  card(radius, 0, 0, w, h, fill, border)

  if checked then
    glyph('fa-check', 0, 0, w, h, h * 0.7, disabled and self.text_dark or self.text_bright)
  end
end

--- Paints a radio button: an outlined circle with a dot while it is checked.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintRadioButton(panel, w, h)
  local checked = panel:GetChecked()
  local radius = math_floor(math.min(w, h) * 0.5)

  card(radius, 0, 0, w, h, self.colTextEntryBG, checked and self.control_color_active or self.frame_border)

  if checked then
    local inset = math_floor(w * 0.3)

    rounded_box(
      math_floor((w - inset * 2) * 0.5),
      inset,
      inset,
      w - inset * 2,
      h - inset * 2,
      self.control_color_active
    )
  end
end

--- Paints the chevron that expands or collapses a tree node.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintExpandButton(panel, w, h)
  glyph(panel:GetExpanded() and 'fa-chevron-down' or 'fa-chevron-right', 0, 0, w, h, h * 0.6, self.text_muted)
end

--- Paints a text entry: a sunken field with a border that takes the accent color while the
-- entry has focus, then draws its text.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTextEntry(panel, w, h)
  if panel.m_bBackground then
    local border = self.colTextEntryBorder
    local fill = self.colTextEntryBG

    if panel:GetDisabled() then
      fill = ColorAlpha(fill, 150)
      border = ColorAlpha(border, 120)
    elseif panel:HasFocus() then
      border = self.colTextEntryFocus
    end

    card(scale(self.radius_small), 0, 0, w, h, fill, border)
  end

  panel:DrawTextEntryText(panel:GetTextColor(), panel:GetHighlightColor(), panel:GetCursorColor())
end

--- Paints the background of a menu: a rounded card with a border.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenu(panel, w, h)
  card(scale(self.radius_small), 0, 0, w, h, self.colMenuBG, self.colMenuBorder)
end

--- Paints the separator line of a menu.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuSpacer(panel, w, h)
  local inset = scale(8)

  set_draw_color(self.frame_border)
  draw_rect(inset, 0, w - inset * 2, h)
end

--- Paints the highlight of a hovered menu option and the check mark of a checked one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuOption(panel, w, h)
  if panel.m_bBackground and (panel.Hovered or panel.Highlight) then
    local inset = scale(3)

    rounded_box(scale(self.radius_small), inset, 1, w - inset * 2, h - 2, self.control_color_highlight)
  end

  if panel:GetChecked() then
    local size = scale(15)

    glyph('fa-check', scale(5), h * 0.5 - size * 0.5, size, size, size * 0.8, self.control_color_bright)
  end
end

--- Paints the arrow of a menu option that opens a submenu.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuRightArrow(panel, w, h)
  glyph('fa-chevron-right', 0, 0, w, h, h * 0.5, self.text_muted)
end

--- Paints the body of a property sheet below its tabs.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintPropertySheet(panel, w, h)
  local active_tab = panel:GetActiveTab()
  local offset = 0

  if active_tab then offset = active_tab:GetTall() - scale(8) end

  card(scale(self.radius_small), 0, offset, w, h - offset, self.colPropertySheet, self.frame_border)
end

--- Paints a tab of a property sheet, depending on whether it is the active one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTab(panel, w, h)
  if panel:GetPropertySheet():GetActiveTab() == panel then
    return self:PaintActiveTab(panel, w, h)
  end

  local radius = scale(self.radius_small)

  rounded_box_ex(
    radius,
    0,
    scale(2),
    w,
    h - scale(2),
    panel.Hovered and self.control_color_highlight or self.colTabInactive,
    true,
    true,
    false,
    false
  )
end

--- Paints the active tab of a property sheet, joined to the body below it with an accent line
-- at its top.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintActiveTab(panel, w, h)
  local radius = scale(self.radius_small)

  rounded_box_ex(radius, 0, 0, w, h, self.frame_border, true, true, false, false)
  rounded_box_ex(math_max(radius - 1, 0), 1, 1, w - 2, h, self.colTab, true, true, false, false)
  rounded_box_ex(math_max(radius - 1, 0), 1, 1, w - 2, scale(2), self.control_color_active, true, true, false, false)
end

--- Paints one of the buttons of a window title bar as a glyph that lights up while hovered.
-- @param panel [Panel the button]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
-- @param icon [String FontAwesome icon ID]
-- @param hover [Color color of the glyph while the button is hovered]
local function paint_window_button(skin, panel, w, h, icon, hover)
  if !panel.m_bBackground then return end

  local color = skin.text_muted

  if panel:GetDisabled() then
    color = ColorAlpha(skin.text_dark, 120)
  elseif panel.Depressed or panel:IsSelected() then
    color = skin.text_bright
  elseif panel.Hovered then
    color = hover
  end

  glyph(icon, 0, 0, w, h, scale(14), color)
end

--- Paints the close button of a window.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowCloseButton(panel, w, h)
  paint_window_button(self, panel, w, h, 'fa-times', Color(228, 92, 104))
end

--- Paints the minimize button of a window.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowMinimizeButton(panel, w, h)
  paint_window_button(self, panel, w, h, 'fa-minus', self.text_bright)
end

--- Paints the maximize button of a window.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowMaximizeButton(panel, w, h)
  paint_window_button(self, panel, w, h, 'far fa-square', self.text_bright)
end

--- Paints the track of a vertical scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintVScrollBar(panel, w, h)
  local inset = math_floor(w * 0.3)

  rounded_box(math_floor((w - inset * 2) * 0.5), inset, 0, w - inset * 2, h, ColorAlpha(self.bg_color_dark, 120))
end

--- Paints the track of a horizontal scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintHScrollBar(panel, w, h)
  local inset = math_floor(h * 0.3)

  rounded_box(math_floor((h - inset * 2) * 0.5), 0, inset, w, h - inset * 2, ColorAlpha(self.bg_color_dark, 120))
end

--- Paints the grip of a scroll bar as a rounded pill that lights up while hovered.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintScrollBarGrip(panel, w, h)
  local color = self.text_dark

  if panel:GetDisabled() then
    color = ColorAlpha(color, 60)
  elseif panel.Depressed then
    color = self.control_color_bright
  elseif panel.Hovered then
    color = self.text_muted
  end

  local inset = math_floor(math.min(w, h) * 0.3)
  local thickness = math.min(w, h) - inset * 2

  if w < h then
    rounded_box(math_floor(thickness * 0.5), inset, 0, thickness, h, color)
  else
    rounded_box(math_floor(thickness * 0.5), 0, inset, w, thickness, color)
  end
end

--- Paints one of the arrow buttons of a scroll bar or a number entry.
-- @param skin [Map the skin]
-- @param panel [Panel the button]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
-- @param icon [String FontAwesome icon ID of the chevron]
local function paint_arrow_button(skin, panel, w, h, icon)
  if panel.m_bBackground == false then return end

  local color = skin.text_dark

  if panel:GetDisabled() then
    color = ColorAlpha(color, 60)
  elseif panel.Depressed or panel:IsSelected() then
    color = skin.control_color_bright
  elseif panel.Hovered then
    color = skin.text_normal
  end

  glyph(icon, 0, 0, w, h, math.min(w, h) * 0.6, color)
end

--- Paints the 'down' button of a scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonDown(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-chevron-down')
end

--- Paints the 'up' button of a scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonUp(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-chevron-up')
end

--- Paints the 'left' button of a scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonLeft(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-chevron-left')
end

--- Paints the 'right' button of a scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonRight(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-chevron-right')
end

--- Paints the drop-down arrow of a combo box according to the state of the combo box.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintComboDownArrow(panel, w, h)
  local combo_box = panel.ComboBox
  local color = self.text_muted

  if combo_box:GetDisabled() then
    color = ColorAlpha(self.text_dark, 120)
  elseif combo_box.Depressed or combo_box:IsMenuOpen() then
    color = self.control_color_bright
  elseif combo_box.Hovered then
    color = self.text_normal
  end

  glyph(combo_box:IsMenuOpen() and 'fa-chevron-up' or 'fa-chevron-down', 0, 0, w, h, h * 0.55, color)
end

--- Paints the background of a combo box like a text field, with the accent border while its
-- menu is open.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintComboBox(panel, w, h)
  local fill = self.colTextEntryBG
  local border = self.frame_border

  if panel:GetDisabled() then
    fill = ColorAlpha(fill, 150)
    border = ColorAlpha(border, 120)
  elseif panel.Depressed or panel:IsMenuOpen() then
    border = self.control_color_active
  elseif panel.Hovered then
    fill = self.control_color_dark
  end

  card(scale(self.radius_small), 0, 0, w, h, fill, border)
end

--- Paints the background of a list box.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListBox(panel, w, h)
  card(scale(self.radius_small), 0, 0, w, h, self.colTextEntryBG, self.frame_border)
end

--- Paints the 'up' arrow of a number entry.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumberUp(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-caret-up')
end

--- Paints the 'down' arrow of a number entry.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumberDown(panel, w, h)
  paint_arrow_button(self, panel, w, h, 'fa-caret-down')
end

--- Paints the lines that connect a tree node to its parent, if the tree draws lines.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTreeNode(panel, w, h)
  if !panel.m_bDrawLines then return end

  set_draw_color(self.Colours.Tree.Lines)

  local x, y = scale(9), scale(7)

  draw_rect(x, 0, 1, panel.m_bLastChild and y or h)
  draw_rect(x, y, x, 1)
end

--- Paints the selection highlight behind the label of a selected tree node.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTreeNodeButton(panel, w, h)
  if !panel.m_bSelected then return end

  local text_w = panel:GetTextSize()

  rounded_box(scale(self.radius_small), scale(38), 0, text_w + scale(6), h, self.listview_selected)
end

--- Paints a selection highlight.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintSelection(panel, w, h)
  rounded_box(scale(self.radius_small), 0, 0, w, h, self.listview_selected)
end

--- Paints the knob of a slider as a filled circle.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintSliderKnob(panel, w, h)
  local color = self.text_normal
  local border = self.frame_border

  if panel:GetDisabled() then
    color = self.text_dark
  elseif panel.Depressed then
    color = self.control_color_bright
    border = self.control_color_bright
  elseif panel.Hovered then
    color = self.text_bright
    border = self.control_color_active
  end

  local size = math.min(w, h)
  local x, y = (w - size) * 0.5, (h - size) * 0.5

  card(math_floor(size * 0.5), x, y, size, size, color, border)
end

--- Paints the track of a number slider and fills it up to the knob in the accent color.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumSlider(panel, w, h)
  local thickness = scale(4)
  local x, y = scale(8), h * 0.5 - thickness * 0.5
  local track_w = w - scale(15)
  local radius = math_floor(thickness * 0.5)

  rounded_box(radius, x, y, track_w, thickness, ColorAlpha(self.bg_color_dark, 200))

  local knob = panel.Slider and panel.Slider.Knob

  if IsValid(knob) then
    local knob_x = knob:GetPos()
    local fill_w = math.Clamp(knob_x + knob:GetWide() * 0.5 - x, 0, track_w)

    rounded_box(radius, x, y, fill_w, thickness, self.control_color_active)
  end

  local notches = panel.m_iNotches

  if !notches then return end

  local space = (w - scale(16)) / notches
  local notch_y, notch_h = y + thickness + scale(2), scale(4)

  set_draw_color(self.frame_border)

  for i = 0, notches do
    draw_rect(x + i * space, notch_y, 1, notch_h)
  end
end

--- Paints a progress bar filled according to its fraction.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintProgress(panel, w, h)
  local radius = scale(self.radius_small)

  card(radius, 0, 0, w, h, self.colTextEntryBG, self.frame_border)
  rounded_box(
    math_max(radius - 1, 0),
    1,
    1,
    math_max((w - 2) * panel:GetFraction(), 0),
    h - 2,
    self.control_color_active
  )
end

--- Paints a collapsible category: a header band, and the frame of its contents while it is
-- expanded.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCollapsibleCategory(panel, w, h)
  local radius = scale(self.radius_small)
  local header = panel:GetHeaderHeight()

  if h <= header + 1 then
    card(radius, 0, 0, w, h, self.colCollapsibleCategory, self.frame_border)

    return
  end

  card(radius, 0, 0, w, h, self.bg_color, self.frame_border)
  rounded_box_ex(math_max(radius - 1, 0), 1, 1, w - 2, header, self.colCollapsibleCategory, true, true, false, false)
end

--- Paints the background of a category list.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCategoryList(panel, w, h)
  card(scale(self.radius_small), 0, 0, w, h, self.bg_color_sleep, self.frame_border)
end

--- Paints the background of a category button according to its state and line parity.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCategoryButton(panel, w, h)
  local colours = panel.AltLine and self.Colours.Category.LineAlt or self.Colours.Category.Line

  if panel.Depressed or panel.m_bSelected then
    set_draw_color(colours.Button_Selected)
  elseif panel.Hovered then
    set_draw_color(colours.Button_Hover)
  else
    set_draw_color(colours.Button)
  end

  draw_rect(0, 0, w, h)
end

--- Paints the background of a list view line that is selected, hovered or alternate.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListViewLine(panel, w, h)
  if panel:IsSelected() then
    set_draw_color(self.listview_selected)
  elseif panel.Hovered then
    set_draw_color(self.listview_hover)
  elseif panel.m_bAlt then
    set_draw_color(self.bg_alt2)
  else
    return
  end

  draw_rect(0, 0, w, h)
end

--- Paints the background of a list view, if it has one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListView(panel, w, h)
  if !panel.m_bBackground then return end

  card(scale(self.radius_small), 0, 0, w, h, self.bg_alt1, self.frame_border)
end

--- Paints the header of a list view column.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListViewColumn(panel, w, h)
  set_draw_color(self.frame_header)
  draw_rect(0, 0, w, h)

  set_draw_color(self.frame_border)
  draw_rect(0, h - 1, w, 1)
  draw_rect(w - 1, 0, 1, h)
end

--- Paints the background of a tooltip.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTooltip(panel, w, h)
  card(scale(self.radius_small), 0, 0, w, h, self.tooltip, self.frame_border)
end

--- Paints the background of a menu bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuBar(panel, w, h)
  set_draw_color(self.frame_header)
  draw_rect(0, 0, w, h)

  set_draw_color(self.frame_border)
  draw_rect(0, h - 1, w, 1)
end

derma.DefineSkin('Flux', 'The flat, dark skin of Flux.', SKIN)
