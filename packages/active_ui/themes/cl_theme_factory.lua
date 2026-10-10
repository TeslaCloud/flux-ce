--- The factory theme: Flux's default theme and the base that other themes derive from.
-- `on_loaded` defines the default options, sounds, colors, fonts and materials that the
-- interface reads through `Theme.get_option`, `Theme.get_color`, `Theme.get_font` and their
-- siblings, and registers the 'tab_menu' panel. The `Paint...` and `Draw...` methods are the
-- theme hooks that panels and HUD code call through `Theme.hook` to draw frames, buttons,
-- bars, the scoreboard, the tab menu, the inventories and the character screens. The
-- 'Flux' Derma skin is recolored from the colors of the theme when it is loaded (see
-- `SKIN:apply_theme`); `THEME.skin` holds any further overrides of single skin fields. A
-- schema theme sets `THEME.parent = 'factory'` and overrides only what it changes.
--
-- The look is a dark, slightly cool palette on blurred backgrounds. The semantic colors are:
--
-- * `background`, `background_dark` and `background_light`: the darkest layers, behind
--   everything else.
-- * `surface`: the cards and windows that content sits on; `surface_raised` for rows, hovered
--   things and controls that sit on a surface; `surface_sunken` and `field` for lists, text
--   fields and other wells.
-- * `border` and `border_light`: the outlines of cards and fields.
-- * `text`, `text_muted` and `text_dim`: primary, secondary and disabled text.
-- * `accent`, `accent_dark`, `accent_light` and `accent_text`: the highlight color, its darker
--   and lighter shades for text on dark backgrounds, and the text drawn on top of it.
-- * `success`, `warning`, `danger` and `info`: states.
-- * `scrim`: the dark tint over the blurred game behind the menus; `hud_backdrop`: the box
--   behind HUD elements.
--
-- `main`, `main_dark`, `main_light`, `outline`, `menu_background` and `schema_text` are kept
-- for the themes and plugins that read them.
--
-- The drawing helpers `DrawCard` and `DrawTitleTag`, and the generic hooks `PaintSurface`,
-- `PaintSectionTitle`, `PaintRow` and `PaintTextEntry`, are what the panels of Flux use for
-- their cards, titles, list rows and fields, so a theme that overrides them restyles all of
-- those at once.

local math_clamp = math.Clamp
local math_max = math.max
local math_floor = math.floor
local text_size = util.text_size
local draw_rounded_box = draw.RoundedBox
local draw_rounded_box_ex = draw.RoundedBoxEx
local draw_simple_text = draw.SimpleText
local textured_rect = draw.textured_rect
local surface_set_draw_color = surface.SetDrawColor
local surface_draw_rect = surface.DrawRect
local lerp_color = LerpColor

local color_white_faded = Color(255, 255, 255, 150)
local color_model_background = Color(0, 0, 0, 90)
local color_slot_gradient = Color(255, 255, 255, 10)
local color_perm_not_set = Color(150, 158, 178)

THEME.author        = 'TeslaCloud Studios'
THEME.id            = 'factory'
THEME.description   = 'Factory Theme. This is a fail-safe Theme that other themes use as a base.'
THEME.should_reload = true

--- Defines the defaults of the factory theme: options, sounds, assets, colors, fonts,
-- materials and the tab menu panel.
function THEME:on_loaded()
  local scrw, scrh = ScrW(), ScrH()

  self:set_option('corner_radius_base',           6)
  self:set_option('corner_radius_small_base',     4)
  self:set_option('corner_radius',                math.scale(6))
  self:set_option('corner_radius_small',          math.scale(4))
  self:set_option('panel_padding',                math.scale(12))
  self:set_option('frame_header_size',            math.scale(36))
  self:set_option('frame_line_weight',            math.scale(2))
  self:set_option('menu_sidebar_width',           300)
  self:set_option('menu_sidebar_height',          scrh)
  self:set_option('menu_sidebar_x',               0)
  self:set_option('menu_sidebar_y',               0)
  self:set_option('menu_sidebar_margin',          -1)
  self:set_option('menu_sidebar_logo',            'flux/flux_icon.png')
  self:set_option('menu_sidebar_logo_space',      scrh / 3)
  self:set_option('menu_sidebar_button_height',   math.scale(44))
  self:set_option('menu_sidebar_button_offset_x', 16)
  self:set_option('menu_sidebar_button_centered', false)
  self:set_option('menu_logo_height',             100)
  self:set_option('menu_logo_width',              110)
  self:set_option('menu_anim_duration',           0.2)
  self:set_option('tab_menu_bar_height',          math.scale(64))
  self:set_option('tab_menu_button_height',       math.scale(40))

  self:set_sound('button_click_success_sound',    'garrysmod/ui_click.wav')
  self:set_sound('button_click_danger_sound',     'buttons/button8.wav')
  self:set_sound('menu_music',                    '')

  self:register_asset('gradient',       'materials/flux/gradient.png',    { sizes = { 1, 2, 4 } })
  self:register_asset('gradient_full',  'materials/flux/gradient_fs.png', { sizes = { 1, 2, 4 } })

  local accent_color      = self:set_color('accent',          Color(120, 132, 232))
  local background_color  = self:set_color('background',      Color(17, 19, 26))
  local surface_color     = self:set_color('surface',         Color(30, 33, 44, 244))
  local text_color        = self:set_color('text',            Color(240, 242, 248))

  self:set_color('background_dark',   Color(10, 12, 17))
  self:set_color('background_light',  Color(28, 31, 41))
  self:set_color('surface_raised',    Color(42, 46, 60))
  self:set_color('surface_sunken',    Color(22, 24, 33))
  self:set_color('surface_header',    Color(38, 42, 54))
  self:set_color('field',             Color(20, 22, 30))
  self:set_color('border',            Color(74, 80, 104))
  self:set_color('border_light',      Color(255, 255, 255, 28))
  self:set_color('text_muted',        Color(168, 176, 196))
  self:set_color('text_dim',          Color(118, 126, 148))
  self:set_color('accent_dark',       Color(92, 102, 196))
  self:set_color('accent_light',      Color(164, 174, 255))
  self:set_color('accent_text',       Color(255, 255, 255))
  self:set_color('success',           Color(98, 200, 130))
  self:set_color('warning',           Color(236, 186, 86))
  self:set_color('danger',            Color(228, 92, 104))
  self:set_color('info',              Color(96, 180, 236))
  self:set_color('scrim',             Color(10, 12, 18, 150))
  self:set_color('hud_backdrop',      Color(17, 19, 26, 200))

  self:set_color('main',              Color(36, 40, 52))
  self:set_color('main_dark',         Color(26, 29, 38))
  self:set_color('main_light',        Color(56, 61, 80))
  self:set_color('outline',           Color(74, 80, 104))
  self:set_color('schema_text',       text_color)
  self:set_color('menu_background',   Color(12, 14, 20, 190))

  self:set_color('esp_red',           Color(255, 90, 90))
  self:set_color('esp_blue',          Color(110, 150, 255))
  self:set_color('esp_grey',          Color(100, 106, 124))

  local main_font           = self:set_font('main_font',            'flRoboto',           math.scale(16))
  local main_font_condensed = self:set_font('main_font_condensed',  'flRobotoCondensed',  math.scale(16))
  local light_font          = self:set_font('light_font',           'flRobotoLight',      math.scale(16))
  self:set_font('menu_titles',              'flRobotoLight',        math.scale(14))
  self:set_font('menu_tiny',                'flRobotoLt',           math.scale(16))
  self:set_font('menu_small',               'flRobotoLt',           math.scale(20))
  self:set_font('menu_normal',              main_font_condensed,    math.scale(24))
  self:set_font('menu_large',               main_font_condensed,    math.scale(30))
  self:set_font('menu_larger',              main_font_condensed,    math.scale(42))
  self:set_font('main_menu_title',          light_font,             math.scale(48))
  self:set_font('main_menu_large',          light_font,             math.scale(42))
  self:set_font('main_menu_normal_large',   light_font,             math.scale(36))
  self:set_font('main_menu_titles',         light_font,             math.scale(24))
  self:set_font('main_menu_normal',         light_font,             math.scale(20))
  self:set_font('main_menu_small',          light_font,             math.scale(18))
  self:set_font('tooltip_small',            main_font_condensed,    math.scale(16))
  self:set_font('tooltip_normal',           main_font_condensed,    math.scale(21))
  self:set_font('tooltip_large',            main_font_condensed,    math.scale(26))
  self:set_font('text_largest',             main_font,              math.scale(90))
  self:set_font('text_large',               main_font,              math.scale(48))
  self:set_font('text_normal_large',        main_font,              math.scale(36))
  self:set_font('text_normal',              main_font,              math.scale(23))
  self:set_font('text_normal_smaller',      main_font,              math.scale(20))
  self:set_font('text_small',               main_font,              math.scale(18))
  self:set_font('text_smaller',             main_font,              math.scale(16))
  self:set_font('text_smallest',            main_font,              math.scale(14))
  self:set_font('text_bar',                 main_font,              math.scale(17), { weight = 600 })
  self:set_font('text_3d2d',                main_font,              256)
  self:set_font('text_bold',                'flRobotoLtBold',       math.scale(16), { weight = 1500 })
  self:set_font('section_title',            'flRobotoLtBold',       math.scale(18), { weight = 800 })

  self:set_material('gradient_up',    'vgui/gradient-u')
  self:set_material('gradient_down',  'vgui/gradient-d')

  self:add_panel('tab_menu', function(id, parent, ...)
    return vgui.Create('fl_tab_menu', parent)
  end)
end

--- Draws a rounded card: a box with a one pixel border.
-- ```
-- Theme.hook('DrawCard', 0, 0, w, h, Theme.get_option('corner_radius'), Theme.get_color('surface'))
-- ```
-- @param x [Number]
-- @param y [Number]
-- @param w [Number]
-- @param h [Number]
-- @param radius [Number corner radius]
-- @param fill [Color]
-- @param border=nil [Color border; the 'border' color of the theme when omitted, false for
--   no border]
function THEME:DrawCard(x, y, w, h, radius, fill, border)
  if border == nil then
    border = self:get_color('border')
  end

  if border then
    draw_rounded_box(radius, x, y, w, h, border)
    draw_rounded_box(math_max(radius - 1, 0), x + 1, y + 1, w - 2, h - 2, fill)
  else
    draw_rounded_box(radius, x, y, w, h, fill)
  end
end

--- Draws a title tag: a small rounded label that sits on the top left corner of a card.
-- @param text [String]
-- @param x [Number left edge of the tag]
-- @param y [Number top edge of the tag]
-- @param font=nil [String font; the 'section_title' font of the theme when omitted]
-- @return [Number width of the tag, Number height of the tag]
function THEME:DrawTitleTag(text, x, y, font)
  font = font or self:get_font('section_title')

  local text_w, text_h = text_size(text, font)
  local padding_x, padding_y = math.scale(10), math.scale(4)
  local w, h = text_w + padding_x * 2, text_h + padding_y * 2
  local radius = self:get_option('corner_radius_small')

  draw_rounded_box_ex(radius, x, y, w, h, self:get_color('surface_header'), true, true, false, false)
  draw_rounded_box(0, x, y + h - math.scale(2), w, math.scale(2), self:get_color('accent'))
  draw_simple_text(text, font, x + padding_x, y + padding_y, self:get_color('text'))

  return w, h
end

--- Draws the surface that a content panel sits on: a rounded card in the 'surface' color.
-- @param panel [Panel the panel being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintSurface(panel, w, h)
  self:DrawCard(0, 0, w, h, self:get_option('corner_radius'), self:get_color('surface'))
end

--- Draws the title of a content panel as a tag that sticks out above its top left corner.
-- The panel is expected to call it from `PaintOver` or `Paint` with clipping disabled, as
-- the tag is drawn outside of the panel.
-- @param panel [Panel the panel being painted]
-- @param text [String the title, translated]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintSectionTitle(panel, text, w, h)
  local font = self:get_font('section_title')
  local text_w, text_h = text_size(text, font)
  local tag_h = text_h + math.scale(8)

  DisableClipping(true)
    self:DrawTitleTag(text, 0, -tag_h, font)
  DisableClipping(false)
end

--- Draws the background of a row of a list: every other row darker, and a highlight while it
-- is hovered.
-- @param panel [Panel the row being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
-- @param dark=panel.dark [Boolean whether this is one of the darker rows]
-- @param hovered=nil [Boolean whether the row is hovered; checked on the panel when omitted]
function THEME:PaintRow(panel, w, h, dark, hovered)
  if dark == nil then dark = panel.dark end
  if hovered == nil then hovered = panel:IsHovered() end

  local radius = self:get_option('corner_radius_small')

  if hovered then
    draw_rounded_box(radius, 0, 0, w, h, self:get_color('main_light'))
  elseif dark then
    draw_rounded_box(radius, 0, 0, w, h, self:get_color('surface_raised'))
  end
end

--- Draws an `fl_text_entry`: a sunken field with a border that takes the accent color while
-- the entry has focus, and its text.
-- @param panel [Panel the text entry being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintTextEntry(panel, w, h)
  local text_color = self:get_color('text')
  local border = panel:HasFocus() and self:get_color('accent') or self:get_color('border')

  self:DrawCard(0, 0, w, h, self:get_option('corner_radius_small'), self:get_color('field'), border)

  panel:DrawTextEntryText(text_color, ColorAlpha(self:get_color('accent'), 120), text_color)
end

--- Called when the main menu is created, so that a theme can customize it. Does nothing
-- in the factory theme.
-- @param panel [Panel the main menu]
function THEME:CreateMainMenu(panel)
end

--- Draws an fl_frame: a rounded card with a header band and the title of the frame in it.
-- @param panel [Panel the frame being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintFrame(panel, w, h)
  local text    = t(panel.title)
  local font    = self:get_font('main_menu_titles')
  local header  = self:get_option('frame_header_size')
  local radius  = self:get_option('corner_radius')
  local text_w, text_h = text_size(text, font)

  DisableClipping(true)
    draw_rounded_box(radius + 2, -2, -1, w + 4, h + 4, Color(0, 0, 0, 60))
  DisableClipping(false)

  self:DrawCard(0, 0, w, h, radius, self:get_color('surface'))
  draw_rounded_box_ex(
    math_max(radius - 1, 0),
    1,
    1,
    w - 2,
    header - 1,
    self:get_color('surface_header'),
    true,
    true,
    false,
    false
  )

  surface_set_draw_color(self:get_color('border'))
  surface_draw_rect(1, header, w - 2, 1)

  draw_simple_text(text, font, math.scale(12), header * 0.5 - text_h * 0.5, self:get_color('text'))
end

--- Draws the background of the main menu: the blurred game under a dark tint, a band across
-- the top with the schema's logo (or name), and its description and author below it.
-- @param panel [Panel the main menu]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintMainMenu(panel, width, height)
  local title               = SCHEMA:get_name()
  local desc                = SCHEMA:get_description()
  local author              = t('ui.main_menu.developed_by', { author = SCHEMA:get_author() })
  local logo                = self:get_material('schema_logo')
  local title_font          = self:get_font('text_largest')
  local titles_font         = self:get_font('main_menu_titles')
  local schema_text_color   = self:get_color('schema_text')
  local muted_color         = self:get_color('text_muted')
  local title_w,  title_h   = text_size(title, title_font)
  local desc_w,   desc_h    = text_size(desc, titles_font)
  local author_w, author_h  = text_size(author, titles_font)
  local bar_height          = math.scale(128)
  local padding             = math.scale(16)
  local text_padding        = math.scale(8)

  draw.blur_box(0, 0, width, height)

  surface_set_draw_color(self:get_color('menu_background'))
  surface_draw_rect(0, 0, width, height)

  textured_rect(self:get_material('gradient_up'), 0, height * 0.5, width, height * 0.5, self:get_color('scrim'))

  surface_set_draw_color(ColorAlpha(self:get_color('surface'), 200))
  surface_draw_rect(0, 0, width, bar_height)

  surface_set_draw_color(self:get_color('border'))
  surface_draw_rect(0, bar_height, width, 1)

  if !logo then
    draw_simple_text(
      title,
      title_font,
      width * 0.5 - title_w * 0.5,
      bar_height - title_h - text_padding,
      schema_text_color
    )
  else
    textured_rect(
      logo,
      width * 0.5 - math.scale(200),
      padding,
      math.scale(400),
      math.scale(96),
      color_white
    )
  end

  draw_simple_text(desc, titles_font, padding, bar_height - desc_h - text_padding, muted_color)
  draw_simple_text(author, titles_font, width - author_w - padding, bar_height - author_h - text_padding, muted_color)
end

--- Draws an fl_button: the background, the outline, the title and the FontAwesome icon,
-- according to the settings of the button. A button that draws a background is a rounded
-- card that brightens while it is hovered and takes the accent color while it is active; a
-- button without one is plain text that shifts toward the accent color instead.
-- @param panel [Panel the button being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintButton(panel, w, h)
  local text_w, text_h, icon_w, icon_h
  local hover             = math_clamp((panel.cur_amt or 0) / 20, 0, 1)
  local active            = panel.active
  local enabled           = panel.enabled != false
  local title             = panel.title
  local font              = panel.font
  local icon              = panel.icon
  local left              = panel.icon_left
  local center            = panel.centered
  local offset            = panel:get_text_offset()
  local text_x, text_y    = offset, 0
  local icon_x, icon_y    = 0, 0
  local icon_size         = panel.icon_size
  local background_color  = panel:get_background_color()
  local radius            = self:get_option('corner_radius_small')
  local text_color        = self:get_color('text')
  local draws_background  = panel.draw_background

  if draws_background then
    if active then
      background_color = background_color or self:get_color('accent')
      text_color = self:get_color('accent_text')
    elseif background_color then
      background_color = lerp_color(hover, background_color, self:get_color('main_light'))
    elseif hover > 0 then
      background_color = ColorAlpha(self:get_color('main_light'), 255 * hover)
    end

    if background_color then
      local border = panel.draw_outline and self:get_color('border') or false

      self:DrawCard(0, 0, w, h, radius, background_color, border)
    elseif panel.draw_outline then
      self:DrawCard(0, 0, w, h, radius, ColorAlpha(self:get_color('main'), 0), self:get_color('border'))
    end
  elseif active then
    text_color = self:get_color('accent_light')
  elseif hover > 0 then
    text_color = lerp_color(hover, text_color, self:get_color('accent_light'))
  end

  if !enabled then
    text_color = self:get_color('text_dim')
  end

  text_color = panel.text_color_override or text_color

  local has_title = title != ''

  if has_title then
    text_w, text_h = text_size(title, font)
    text_y = h * 0.5 - text_h * 0.5

    if center then
      text_x = offset + w * 0.5 - text_w * 0.5
    end
  end

  if icon then
    icon_w, icon_h = FontAwesome:get_icon_size(icon, icon_size)

    if has_title then
      text_x = text_x + (left and icon_w * 0.5 or -icon_w * 0.5)
      icon_x = (left and text_x - icon_w - math.scale_x(4) or text_x + text_w + math.scale_x(4))
    else
      icon_x = w * 0.5 - icon_w * 0.5
    end

    icon_y = h * 0.5 - icon_h * 0.5
  end

  if has_title then
    draw_simple_text(title, font, text_x, text_y, text_color)
  end

  if icon then
    FontAwesome:draw(icon, icon_x, icon_y, icon_size, text_color)
  end
end

--- Draws the death screen with the respawn countdown and progress bar, and sets up the
-- white fade for the last 3 seconds before the respawn.
-- @param cur_time [Number current CurTime()]
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
function THEME:PaintDeathScreen(cur_time, scrw, scrh)
  local client        = PLAYER
  local respawn_time  = client:get_nv('respawn_time', 0) - cur_time
  local bar_value     = math_clamp(100 - 100 * (respawn_time / Config.get('respawn_delay')), 0, 100)
  local font          = self:get_font('text_normal_large')
  local small_font    = self:get_font('text_normal')
  local respawn_alpha = math_clamp((client.respawn_alpha or 0) + 1, 0, 200)
  local padding       = math.scale(24)
  local text_color    = self:get_color('text')
  local bar_w, bar_h  = math.scale(320), math.scale(6)

  client.respawn_alpha = respawn_alpha

  surface_set_draw_color(0, 0, 0, respawn_alpha)
  surface_draw_rect(0, 0, scrw, scrh)

  local died = t'ui.hud.player_message.died'
  local respawn = t('ui.hud.player_message.respawn', { time = math.ceil(respawn_time) })
  local died_w, died_h = text_size(died, font)
  local respawn_w, respawn_h = text_size(respawn, small_font)
  local y = scrh * 0.5 - (died_h + respawn_h + bar_h + padding) * 0.5

  draw_simple_text(died, font, scrw * 0.5 - died_w * 0.5, y, text_color)
  draw_simple_text(
    respawn,
    small_font,
    scrw * 0.5 - respawn_w * 0.5,
    y + died_h + math.scale(4),
    self:get_color('text_muted')
  )

  local bar_x, bar_y = scrw * 0.5 - bar_w * 0.5, y + died_h + respawn_h + padding

  draw_rounded_box(bar_h * 0.5, bar_x, bar_y, bar_w, bar_h, self:get_color('surface_raised'))
  draw_rounded_box(bar_h * 0.5, bar_x, bar_y, bar_w * bar_value * 0.01, bar_h, self:get_color('accent'))

  if respawn_time <= 3 then
    client.white_alpha = math_clamp(255 * (1.5 - respawn_time * 0.5), 0, 255)
  else
    client.white_alpha = 0
  end
end

--- Draws the background of an fl_sidebar.
-- @param panel [Panel the sidebar being painted]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintSidebar(panel, width, height)
  draw_rounded_box(self:get_option('corner_radius'), 0, 0, width, height, self:get_color('surface_sunken'))
end

--- Returns the corner radius of a HUD bar: its own, or the small radius of the theme.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
-- @return [Number]
function THEME:get_bar_radius(bar_info)
  local radius = bar_info.corner_radius or 0

  if radius > 0 then
    return radius
  end

  return math.min(self:get_option('corner_radius_small'), math_floor(bar_info.height * 0.5))
end

--- Draws the background of a HUD bar.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarBackground(bar_info)
  self:DrawCard(
    bar_info.x,
    bar_info.y,
    bar_info.width,
    bar_info.height,
    self:get_bar_radius(bar_info),
    self:get_color('hud_backdrop'),
    self:get_color('border_light')
  )
end

--- Draws the hindered portion at the right end of a HUD bar.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarHindrance(bar_info)
  local length = bar_info.width * (bar_info.hinder_value / bar_info.max_value)

  draw_rounded_box(
    self:get_bar_radius(bar_info),
    bar_info.x + bar_info.width - length - 1,
    bar_info.y + 1,
    length,
    bar_info.height - 2,
    bar_info.hinder_color
  )
end

--- Draws the filled portion of a HUD bar in the color of the bar. While the displayed fill is
-- catching up with the actual value, the difference between the two is drawn lighter.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarFill(bar_info)
  local radius          = self:get_bar_radius(bar_info)
  local x, y            = bar_info.x + 1, bar_info.y + 1
  local fill_h          = bar_info.height - 2
  local fill_width      = bar_info.fill_width
  local real_fill_width = bar_info.real_fill_width
  local fill_w          = (fill_width or bar_info.width) - 2
  local color           = bar_info.color
  local trail_color     = ColorAlpha(color, 110)

  if real_fill_width < fill_width then
    draw_rounded_box(radius, x, y, fill_w, fill_h, trail_color)
    draw_rounded_box(radius, x, y, math_max(real_fill_width - 2, 0), fill_h, color)
  elseif real_fill_width > fill_width then
    draw_rounded_box(radius, x, y, math_max(real_fill_width - 2, 0), fill_h, trail_color)
    draw_rounded_box(radius, x, y, fill_w, fill_h, color)
  else
    draw_rounded_box(radius, x, y, fill_w, fill_h, color)
  end
end

--- Draws the text of a HUD bar with a shadow, so that it stays readable over the filled and
-- the empty portions alike, and the hindrance text when the hindrance is displayed.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarTexts(bar_info)
  local font            = Theme.get_font(bar_info.font)
  local x, y            = bar_info.x, bar_info.y
  local width           = bar_info.width
  local text            = bar_info.text
  local text_x, text_y  = x + math.scale(8), y + bar_info.text_offset
  local text_color      = self:get_color('text')
  local shadow          = Color(0, 0, 0, 160)

  draw.SimpleTextOutlined(text, font, text_x, text_y, text_color, nil, nil, 1, shadow)

  local hinder_display = bar_info.hinder_display

  if hinder_display and hinder_display <= bar_info.hinder_value then
    local text_wide = text_size(bar_info.hinder_text, font)

    draw.SimpleTextOutlined(
      bar_info.hinder_text, font, x + width - text_wide - math.scale(8), text_y, text_color, nil, nil, 1, shadow
    )
  end
end

--- Draws the footer below the admin panel with the Steam name and user group of the local
-- player and the version of the admin mod.
-- @param panel [Panel the admin panel]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:AdminPanelPaintOver(panel, width, height)
  local font            = self:get_font('text_smallest')
  local text_color      = self:get_color('text_muted')
  local version_string  = 'Admin Mod Version: v0.2.0 (indev)'
  local footer          = math.scale(22)
  local radius          = self:get_option('corner_radius')
  local padding         = math.scale(10)
  local text_w, text_h  = text_size(version_string, font)
  local text_y          = height + footer * 0.5 - text_h * 0.5

  DisableClipping(true)
    draw_rounded_box_ex(radius, 0, height, width, footer, self:get_color('surface_sunken'), false, false, true, true)
    draw_simple_text(PLAYER:steam_name()..' ('..PLAYER:GetUserGroup()..')', font, padding, text_y, text_color)
    draw_simple_text(version_string, font, width - text_w - padding, text_y, text_color)
  DisableClipping(false)
end

--- Draws the background of a line of the config editor: every other line darker, and a
-- highlight while it is hovered.
-- @param panel [Panel the config line being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintConfigLine(panel, w, h)
  self:PaintRow(panel, w, h)
end

--- Draws a button of the permission editor as a pill colored after its permission value:
-- filled while it is the selected value, outlined otherwise, with a clock icon for temporary
-- permissions.
-- @param perm_panel [Panel the permission row the button belongs to]
-- @param btn [Panel the button being painted]
-- @param w [Number button width]
-- @param h [Number button height]
function THEME:PaintPermissionButton(perm_panel, btn, w, h)
  local color     = color_white
  local title     = ''
  local perm_type = btn.perm_value
  local font      = self:get_font('text_smaller')
  local radius    = math_floor(h * 0.5)
  local selected  = btn.is_selected

  if perm_type == PERM_NO then
    color = color_perm_not_set
    title = t'ui.permission.not_set'
  elseif perm_type == PERM_ALLOW then
    color = self:get_color('success')
    title = t'ui.permission.allow'
  elseif perm_type == PERM_NEVER then
    color = self:get_color('danger')
    title = t'ui.permission.never'
  else
    title = t'ui.permission.error'
  end

  local fill, text_color

  if selected then
    fill = color
    text_color = self:get_color('background')
  else
    fill = ColorAlpha(color, btn:IsHovered() and 50 or 18)
    text_color = color
  end

  self:DrawCard(0, 0, w, h, radius, fill, ColorAlpha(color, selected and 255 or 140))

  local tw, th = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - tw * 0.5, h * 0.5 - th * 0.5, text_color)

  if btn.is_temp then
    local icon_size = math_floor(h * 0.6)

    FontAwesome:draw('far fa-clock', w - icon_size - math.scale(6), h * 0.5 - icon_size * 0.5, icon_size, text_color)
  end
end

--- Draws the card, the title tag and the column headers of the scoreboard, with the amount of
-- players online in the middle of the header.
-- @param panel [Panel the scoreboard]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintScoreboard(panel, width, height)
  local font        = self:get_font('text_small')
  local text_color  = self:get_color('text_muted')
  local padding     = math.scale(12)
  local header      = math.scale(36)

  self:PaintSurface(panel, width, height)
  self:PaintSectionTitle(panel, t'ui.scoreboard.title', width, height)

  draw_simple_text(t'ui.scoreboard.help', font, padding, header * 0.5, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

  if panel.get_online_text then
    draw_simple_text(
      panel:get_online_text(),
      font,
      width * 0.5,
      header * 0.5,
      text_color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  draw_simple_text(
    t'ui.scoreboard.ping',
    font,
    width - padding,
    header * 0.5,
    text_color,
    TEXT_ALIGN_RIGHT,
    TEXT_ALIGN_CENTER
  )

  surface_set_draw_color(self:get_color('border'))
  surface_draw_rect(padding, header - 1, width - padding * 2, 1)
end

--- Draws the card of a player on the scoreboard, highlighted while it is hovered.
-- @param panel [Panel the player card]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintScoreboardPlayer(panel, w, h)
  local hovered = panel:IsHovered() or panel:IsChildHovered()

  draw_rounded_box(
    self:get_option('corner_radius_small'),
    0,
    0,
    w,
    h,
    hovered and self:get_color('main_light') or self:get_color('surface_raised')
  )
end

--- Draws the bar at the top of the tab menu that holds its buttons.
-- @param panel [Panel the tab menu that owns the button bar]
-- @param width [Number width of the button bar]
-- @param height [Number height of the button bar]
function THEME:PaintTabMenuButtonPanel(panel, width, height)
  surface_set_draw_color(ColorAlpha(self:get_color('background'), 235))
  surface_draw_rect(0, 0, width, height)

  surface_set_draw_color(self:get_color('border'))
  surface_draw_rect(0, height - 1, width, 1)
end

--- Blurs the screen behind the tab menu, easing the blur size toward the blur target of
-- the menu, and tints it so that the panels on top of it stand out.
-- @param panel [Panel the tab menu]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintTabMenu(panel, width, height)
  local fraction = FrameTime() * 8

  Flux.blur_size = Lerp(fraction, Flux.blur_size, panel.blur_target)

  draw.blur_panel(panel)

  surface_set_draw_color(self:get_color('scrim'))
  surface_draw_rect(0, 0, width, height)
end

--- Draws a faint sheen over an inventory item slot.
-- @param panel [Panel the item slot]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintItemSlot(panel, w, h)
  textured_rect(self:get_material('gradient_up'), 0, 0, w, h, color_slot_gradient)
end

--- Draws the card around an inventory panel.
-- @param panel [Panel the inventory panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintInventoryBackground(panel, w, h)
  local padding = math.scale(6)

  DisableClipping(true)
    self:DrawCard(
      -padding,
      -padding,
      w + padding * 2,
      h + padding * 2,
      self:get_option('corner_radius'),
      self:get_color('surface')
    )
  DisableClipping(false)
end

--- Draws the card and the character name around the player model of the inventory tab. Does
-- nothing if the panel has no player model.
-- @param panel [Panel the inventory menu]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintTabInventoryBackground(panel, w, h)
  local player_model = panel.player_model

  if IsValid(player_model) then
    local x, y                = player_model:GetPos()
    local player_w, player_h  = player_model:GetSize()
    local padding             = math.scale(6)
    local radius              = self:get_option('corner_radius')
    local font                = self:get_font('section_title')
    local text                = PLAYER:name()
    local text_w, text_h      = text_size(text, font)

    DisableClipping(true)
      self:DrawCard(
        x - padding,
        y - padding,
        player_w + padding * 2,
        player_h + padding * 2,
        radius,
        self:get_color('surface')
      )
      draw_rounded_box(radius - 1, x, y, player_w, player_h, color_model_background)
      textured_rect(self:get_material('gradient_up'), x, y, player_w, player_h, color_slot_gradient)
      self:DrawTitleTag(text, x - padding, y - padding - text_h - math.scale(8), font)
    DisableClipping(false)
  end
end

--- Draws the title of an inventory above its panel, if it has one.
-- @param panel [Panel the inventory panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintOverInventoryBackground(panel, w, h)
  if panel.title then
    local font            = self:get_font('section_title')
    local text            = t(panel.title)
    local text_w, text_h  = text_size(text, font)
    local padding         = math.scale(6)

    DisableClipping(true)
      self:DrawTitleTag(text, -padding, -padding - text_h - math.scale(8), font)
    DisableClipping(false)
  end
end

--- Draws the card behind the chat history, leaving out the text entry.
-- @param panel [Panel the chatbox]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:ChatboxPaintBackground(panel, width, height)
  local padding = math.scale(8)

  DisableClipping(true)
    self:DrawCard(
      -padding,
      -padding,
      width + padding * 2,
      height - panel.text_entry:GetTall() + padding,
      self:get_option('corner_radius'),
      ColorAlpha(self:get_color('surface'), 225)
    )
  DisableClipping(false)
end

--- Draws a character card: its background, the name of the character in a tag at its top and
-- an accent outline if it belongs to the active character of the local player.
-- @param panel [Panel the character card]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharPanel(panel, w, h)
  local radius = self:get_option('corner_radius')
  local char_data = panel.char_data
  local is_active = char_data and PLAYER:get_character_id() == char_data.character_id

  self:DrawCard(0, 0, w, h, radius, self:get_color('surface'), is_active and self:get_color('accent') or nil)

  if char_data then
    local font            = self:get_font('main_menu_titles')
    local name_w, name_h  = text_size(char_data.name, font)

    draw_rounded_box_ex(
      radius,
      1,
      1,
      w - 2,
      name_h + math.scale(8),
      self:get_color('surface_header'),
      true,
      true,
      false,
      false
    )
    draw_simple_text(char_data.name, font, w * 0.5 - name_w * 0.5, math.scale(4), self:get_color('schema_text'))
  end
end

--- Draws the title of the character creation screen.
-- @param panel [Panel the character creation panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationMainPanel(panel, w, h)
  local title, font       = t'ui.char_create.text', Theme.get_font 'main_menu_title'
  local title_w, title_h  = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - title_w * 0.5, h * 0.125, self:get_color('text'))
end

--- Draws the title of the character loading screen.
-- @param panel [Panel the character loading panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationLoadPanel(panel, w, h)
  local title, font       = t'ui.char_create.load', Theme.get_font 'main_menu_title'
  local title_w, title_h  = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - title_w * 0.5, h * 0.125, self:get_color('text'))
end

--- Draws the card of a character creation stage and its title, if the panel has one.
-- @param panel [Panel the stage panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationBasePanel(panel, w, h)
  self:DrawCard(0, 0, w, h, self:get_option('corner_radius'), self:get_color('surface'))

  if isstring(panel.text) then
    local text            = t(panel.text)
    local font            = Theme.get_font('main_menu_large')
    local text_w, text_h  = text_size(text, font)

    draw_simple_text(text, font, w * 0.5 - text_w * 0.5, math.scale(8), Theme.get_color('text'))
  end
end
