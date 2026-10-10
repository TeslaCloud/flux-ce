--- The factory theme: Flux's default theme and the base that other themes derive from.
-- `on_loaded` defines the default options, sounds, colors, fonts and materials that the
-- interface reads through `Theme.get_option`, `Theme.get_color`, `Theme.get_font` and their
-- siblings, and registers the 'tab_menu' panel. The `Paint...` and `Draw...` methods are the
-- theme hooks that panels and HUD code call through `Theme.hook` to draw frames, buttons,
-- bars, the scoreboard, the tab menu, the inventories and the character screens. `THEME.skin`
-- holds the colors, fonts and paint functions that are copied into the 'Flux' Derma skin when
-- the theme is loaded. A schema theme sets `THEME.parent = 'factory'` and overrides only what
-- it changes.

local math_clamp = math.Clamp
local text_size = util.text_size
local draw_rounded_box = draw.RoundedBox
local draw_simple_text = draw.SimpleText
local textured_rect = draw.textured_rect
local surface_set_draw_color = surface.SetDrawColor
local surface_draw_rect = surface.DrawRect

local color_white_faded = Color(255, 255, 255, 150)
local color_frame_background = Color(50, 50, 50, 200)
local color_backdrop = Color(50, 50, 50, 100)
local color_slot_gradient = Color(30, 30, 30, 100)
local color_model_background = Color(0, 0, 0, 100)
local color_bar_fill = Color(230, 230, 230)
local color_perm_not_set = Color(120, 120, 120)
local color_perm_allow = Color(100, 220, 100)
local color_perm_never = Color(220, 100, 100)
local color_skin_tab = Color(40, 40, 40)
local color_skin_line = Color(50, 50, 50, 255)
local color_skin_line_hovered = Color(100, 100, 100, 255)
local color_skin_line_alt = Color(75, 75, 75, 255)
local color_skin_menu = Color(15, 15, 15, 255)
local color_skin_option_depressed = Color(225, 225, 225, 255)
local color_skin_button = Color(40, 40, 40, 255)
local color_skin_frame = Color(10, 10, 10, 150)
local color_skin_category = Color(30, 30, 30)

-- Create the default Theme that other themes will derive from.
THEME.author        = 'TeslaCloud Studios'
THEME.id            = 'factory'
THEME.description   = 'Factory Theme. This is a fail-safe Theme that other themes use as a base.'
THEME.should_reload = true

--- Defines the defaults of the factory theme: options, sounds, assets, colors, fonts,
-- materials and the tab menu panel.
function THEME:on_loaded()
  local scrw, scrh = ScrW(), ScrH()

  self:set_option('frame_header_size',            math.scale(24))
  self:set_option('frame_line_weight',            math.scale(2))
  self:set_option('menu_sidebar_width',           300)
  self:set_option('menu_sidebar_height',          scrh)
  self:set_option('menu_sidebar_x',               0)
  self:set_option('menu_sidebar_y',               0)
  self:set_option('menu_sidebar_margin',          -1)
  self:set_option('menu_sidebar_logo',            'flux/flux_icon.png')
  self:set_option('menu_sidebar_logo_space',      scrh / 3)
  self:set_option('menu_sidebar_button_height',   math.scale(42))
  self:set_option('menu_sidebar_button_offset_x', 16)
  self:set_option('menu_sidebar_button_centered', false)
  self:set_option('menu_logo_height',             100)
  self:set_option('menu_logo_width',              110)
  self:set_option('menu_anim_duration',           0.2)

  self:set_sound('button_click_success_sound',    'garrysmod/ui_click.wav')
  self:set_sound('button_click_danger_sound',     'buttons/button8.wav')
  self:set_sound('menu_music',                    '')

  self:register_asset('gradient',       'materials/flux/gradient.png',    { sizes = { 1, 2, 4 } })
  self:register_asset('gradient_full',  'materials/flux/gradient_fs.png', { sizes = { 1, 2, 4 } })

  local accent_color      = self:set_color('accent',      Color(90, 90, 190))
  local main_color        = self:set_color('main',        Color(50, 50, 50))
  local outline_color     = self:set_color('outline',     Color(65, 65, 65))
  local background_color  = self:set_color('background',  Color(20, 20, 20))
  local text_color        = self:set_color('text',        util.text_color_from_base(background_color))

  self:set_color('accent_dark',       accent_color:darken(20))
  self:set_color('accent_light',      accent_color:lighten(20))
  self:set_color('main_dark',         main_color:darken(15))
  self:set_color('main_light',        main_color:lighten(15))
  self:set_color('background_dark',   background_color:darken(20))
  self:set_color('background_light',  background_color:lighten(20))
  self:set_color('schema_text',       text_color)
  self:set_color('menu_background',   self:get_color('background_dark'))

  self:set_color('esp_red',           Color(255, 0, 0))
  self:set_color('esp_blue',          Color(0, 0, 255))
  self:set_color('esp_grey',          Color(100, 100, 100))

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

  -- Set from the schema Theme.
  -- self:set_material('schema_logo', 'materials/flux/hl2rp/logo.png')
  self:set_material('gradient_up',    'vgui/gradient-u')
  self:set_material('gradient_down',  'vgui/gradient-d')

  self:add_panel('tab_menu', function(id, parent, ...)
    return vgui.Create('fl_tab_menu', parent)
  end)
end

--- Called when the main menu is created, so that a theme can customize it. Does nothing
-- in the factory theme.
-- @param panel [Panel the main menu]
function THEME:CreateMainMenu(panel)
end

--- Draws the background and the title of an fl_frame.
-- @param panel [Panel the frame being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintFrame(panel, w, h)
  local text            = t(panel.title)
  local font            = self:get_font('main_menu_titles')

  draw_rounded_box(0, 0, 0, w, h, color_frame_background)
  draw_simple_text(text, font, math.scale(4), math.scale(2), color_white)
end

--- Draws the background of the main menu and its top bar with the schema's logo (or name),
-- description and author.
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
  local menu_background     = self:get_color('menu_background')
  local title_w,  title_h   = text_size(title, title_font)
  local desc_w,   desc_h    = text_size(desc, titles_font)
  local author_w, author_h  = text_size(author, titles_font)
  local bar_height          = math.scale(128)
  local padding             = math.scale(16)
  local text_padding        = math.scale(8)

  surface_set_draw_color(menu_background)
  surface_draw_rect(0, 0, width, height)

  surface_set_draw_color(menu_background:lighten(40))
  surface_draw_rect(0, 0, width, bar_height)

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

  draw_simple_text(
    desc,
    titles_font,
    padding,
    bar_height - desc_h - text_padding,
    schema_text_color
  )
  draw_simple_text(
    author,
    titles_font,
    width - author_w - padding,
    bar_height - author_h - text_padding,
    schema_text_color
  )
end

--- Draws an fl_button: the outline, background, title and FontAwesome icon, according to
-- the settings of the button.
-- @param panel [Panel the button being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintButton(panel, w, h)
  local text_w, text_h, icon_w, icon_h
  local cur_amt           = panel.cur_amt
  local text_color        = panel.text_color_override or self:get_color('text'):darken(cur_amt)
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

  if panel.draw_background then
    if panel.draw_outline then
      surface_set_draw_color(self:get_color('outline'))
      surface_draw_rect(0, 0, w, h)
    end

    if background_color != nil then
      surface_set_draw_color(panel.active and background_color or background_color:lighten(cur_amt))
      surface_draw_rect(math.scale_x(1), math.scale(1), w - math.scale_x(2), h - math.scale(2))
    end
  end

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
  local bar_value     = 100 - 100 * (respawn_time / Config.get('respawn_delay'))
  local font          = self:get_font('text_normal_large')
  local respawn_alpha = math_clamp((client.respawn_alpha or 0) + 1, 0, 200)

  client.respawn_alpha = respawn_alpha

  surface_set_draw_color(0, 0, 0, respawn_alpha)
  surface_draw_rect(0, 0, scrw, scrh)

  draw_simple_text(t'ui.hud.player_message.died', font, 16, 16, color_white)
  draw_simple_text(
    t('ui.hud.player_message.respawn', { time = math.ceil(respawn_time) }),
    font,
    16,
    16 + util.font_size(font),
    color_white
  )

  draw_rounded_box(0, 0, 0, scrw * 0.01 * bar_value, 2, color_white)

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
  draw_rounded_box(0, 0, 0, width, height, self:get_color('main_dark'):lighten(10))
end

--- Draws the background of a HUD bar.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarBackground(bar_info)
  draw_rounded_box(
    bar_info.corner_radius,
    bar_info.x,
    bar_info.y,
    bar_info.width,
    bar_info.height,
    self:get_color('main_dark')
  )
end

--- Draws the hindered portion at the right end of a HUD bar.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarHindrance(bar_info)
  local length = bar_info.width * (bar_info.hinder_value / bar_info.max_value)

  draw_rounded_box(
    bar_info.corner_radius,
    bar_info.x + bar_info.width - length - 1,
    bar_info.y + 1,
    length,
    bar_info.height - 2,
    bar_info.hinder_color
  )
end

--- Draws the filled portion of a HUD bar. While the displayed fill is catching up with the
-- actual value, the difference between the two is drawn in the color of the bar.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarFill(bar_info)
  local radius          = bar_info.corner_radius
  local x, y            = bar_info.x + 1, bar_info.y + 1
  local fill_h          = bar_info.height - 2
  local fill_width      = bar_info.fill_width
  local real_fill_width = bar_info.real_fill_width
  local fill_w          = (fill_width or bar_info.width) - 2

  if real_fill_width < fill_width then
    draw_rounded_box(radius, x, y, fill_w, fill_h, bar_info.color)
    draw_rounded_box(radius, x, y, real_fill_width - 2, fill_h, color_bar_fill)
  elseif real_fill_width > fill_width then
    draw_rounded_box(radius, x, y, real_fill_width - 2, fill_h, bar_info.color)
    draw_rounded_box(radius, x, y, fill_w, fill_h, color_bar_fill)
  else
    draw_rounded_box(radius, x, y, fill_w, fill_h, color_bar_fill)
  end
end

--- Draws the text of a HUD bar, in different colors over its filled and empty portions,
-- and the hindrance text when the hindrance is displayed.
-- @param bar_info [Map data of the bar, as stored by Flux.Bars]
function THEME:DrawBarTexts(bar_info)
  local font            = Theme.get_font(bar_info.font)
  local x, y            = bar_info.x, bar_info.y
  local width           = bar_info.width
  local bottom          = y + bar_info.height
  local fill_right      = x + bar_info.real_fill_width
  local text            = bar_info.text
  local text_x, text_y  = x + 8, y + bar_info.text_offset

  render.SetScissorRect(x + 1, y + 1, fill_right, bottom, true)
    draw_simple_text(text, font, text_x, text_y, self:get_color('main_dark'))
  render.SetScissorRect(0, 0, 0, 0, false)

  render.SetScissorRect(fill_right, y + 1, x + width, bottom, true)
    draw_simple_text(text, font, text_x, text_y, self:get_color('text'))
  render.SetScissorRect(0, 0, 0, 0, false)

  local hinder_display = bar_info.hinder_display

  if hinder_display and hinder_display <= bar_info.hinder_value then
    local text_wide = text_size(bar_info.hinder_text, font)
    local length    = width * (bar_info.hinder_value / bar_info.max_value)

    render.SetScissorRect(x + width - length, y, x + width, bottom, true)
      draw_simple_text(bar_info.hinder_text, font, x + width - text_wide - 8, text_y, color_white)
    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

--- Draws the footer below the admin panel with the Steam name and user group of the local
-- player and the version of the admin mod.
-- @param panel [Panel the admin panel]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:AdminPanelPaintOver(panel, width, height)
  local smallest_font   = Font.size(self:get_font('text_smallest'), 14)
  local text_color      = self:get_color('text')
  local version_string  = 'Admin Mod Version: v0.2.0 (indev)'

  DisableClipping(true)
    draw.RoundedBox(0, 0, height, width, 16, self:get_color('background'))

    draw.SimpleText(PLAYER:steam_name()..' ('..PLAYER:GetUserGroup()..')', smallest_font, 6, height + 1, text_color)

    local w, h = util.text_size(version_string, smallest_font)

    draw.SimpleText(version_string, smallest_font, width - w - 6, height + 1, text_color)
  DisableClipping(false)
end

--- Draws a darker background on the lines of the config editor that are marked as dark.
-- @param panel [Panel the config line being painted]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintConfigLine(panel, w, h)
  if panel.dark then
    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
  end
end

--- Draws a button of the permission editor, colored and labeled after its permission
-- value, with a selection box and a clock icon for temporary permissions.
-- @param perm_panel [Panel the permission row the button belongs to]
-- @param btn [Panel the button being painted]
-- @param w [Number button width]
-- @param h [Number button height]
function THEME:PaintPermissionButton(perm_panel, btn, w, h)
  local color     = color_white
  local title     = ''
  local perm_type = btn.perm_value
  local font      = self:get_font('text_small')

  if perm_type == PERM_NO then
    color = color_perm_not_set
    title = t'ui.permission.not_set'
  elseif perm_type == PERM_ALLOW then
    color = color_perm_allow
    title = t'ui.permission.allow'
  elseif perm_type == PERM_NEVER then
    color = color_perm_never
    title = t'ui.permission.never'
  else
    title = t'ui.permission.error'
  end

  local text_color = color:darken(75)

  if btn:IsHovered() then
    color = color:lighten(30)
  end

  draw_rounded_box(0, 0, 0, w, h, text_color)
  draw_rounded_box(0, 1, 1, w - 2, h - 1, color)

  local tw, th = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - tw * 0.5, 2, text_color)

  local sqr_size = h * 0.5
  local sqr_pos = sqr_size * 0.5

  draw_rounded_box(0, sqr_pos, sqr_pos, sqr_size, sqr_size, color_white)

  if btn.is_selected then
    draw_rounded_box(0, sqr_pos + 2, sqr_pos + 2, sqr_size - 4, sqr_size - 4, color_black)
  end

  if btn.is_temp then
    FontAwesome:draw('fa-clock-o', w - h - 2, 2, h - 4, color_white)
  end
end

--- Draws the background, title and column headers of the scoreboard, with the amount of
-- players online in the middle of the header.
-- @param panel [Panel the scoreboard]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintScoreboard(panel, width, height)
  local text            = t'ui.scoreboard.title'
  local font            = self:get_font('main_menu_large')
  local text_w, text_h  = text_size(text, font)
  local text_color      = self:get_color('text')

  DisableClipping(true)
    draw_rounded_box(0, -4, -4, width + 8, height + 8, color_backdrop)
    textured_rect(self:get_material('gradient_down'), -4, -text_h - 4, text_w + 8, text_h, color_backdrop)
    draw_simple_text(text, font, 0, -text_h - 4, color_white)
  DisableClipping(false)

  font = self:get_font('text_small')

  draw_simple_text(t'ui.scoreboard.help', font, 4, 0, text_color)

  if panel.get_online_text then
    text = panel:get_online_text()
    text_w, text_h = text_size(text, font)

    draw_simple_text(text, font, width * 0.5 - text_w * 0.5, 0, text_color)
  end

  text = t'ui.scoreboard.ping'
  text_w, text_h = text_size(text, font)

  draw_simple_text(text, font, width - text_w - 8, 0, text_color)
end

--- Draws the translucent background of the button bar of the tab menu.
-- @param panel [Panel the tab menu that owns the button bar]
-- @param width [Number width of the button bar]
-- @param height [Number height of the button bar]
function THEME:PaintTabMenuButtonPanel(panel, width, height)
  draw_rounded_box(0, 0, 0, width, height, self:get_color('background'):alpha(125))
end

--- Blurs the screen behind the tab menu, easing the blur size toward the blur target of
-- the menu.
-- @param panel [Panel the tab menu]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:PaintTabMenu(panel, width, height)
  local fraction = FrameTime() * 8

  Flux.blur_size = Lerp(fraction, Flux.blur_size, panel.blur_target)

  draw.blur_panel(panel)
end

--- Draws the gradient background of an inventory item slot.
-- @param panel [Panel the item slot]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintItemSlot(panel, w, h)
  textured_rect(self:get_material('gradient_up'), 0, 0, w, h, color_slot_gradient)
end

--- Draws the translucent backdrop around an inventory panel.
-- @param panel [Panel the inventory panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintInventoryBackground(panel, w, h)
  DisableClipping(true)
    draw_rounded_box(0, -4, -4, w + 8, h + 8, color_backdrop)
  DisableClipping(false)
end

--- Draws the frame, the gradients and the character name around the player model of the
-- inventory tab. Does nothing if the panel has no player model.
-- @param panel [Panel the inventory menu]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintTabInventoryBackground(panel, w, h)
  local player_model = panel.player_model

  if IsValid(player_model) then
    local x, y                = player_model:GetPos()
    local player_w, player_h  = player_model:GetSize()
    local text                = PLAYER:name()
    local font                = self:get_font('main_menu_large')
    local text_w, text_h      = text_size(text, font)

    DisableClipping(true)
      draw_rounded_box(0, x - 4, y - 4, player_w + 8, player_h + 8, color_backdrop)
      draw_rounded_box(0, x, y, player_w, player_h, color_model_background)
      textured_rect(self:get_material('gradient_up'), x, y, player_w, player_h, color_slot_gradient)
      textured_rect(
        self:get_material('gradient_down'),
        x - 4,
        y - text_h - 4,
        text_w + 8,
        text_h,
        color_backdrop
      )
      draw_simple_text(text, font, x, -text_h, color_white_faded)
    DisableClipping(false)
  end
end

--- Draws the title of an inventory above its panel, if it has one.
-- @param panel [Panel the inventory panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintOverInventoryBackground(panel, w, h)
  if panel.title then
    local text            = t(panel.title)
    local font            = self:get_font('main_menu_large')
    local text_w, text_h  = text_size(text, font)

    DisableClipping(true)
      textured_rect(
        self:get_material('gradient_down'),
        -4,
        -text_h - 4,
        text_w + 8,
        text_h,
        color_backdrop
      )
      draw_simple_text(text, font, 0, -text_h - 4, color_white_faded)
    DisableClipping(false)
  end
end

--- Draws the background behind the chat history, leaving out the text entry.
-- @param panel [Panel the chatbox]
-- @param width [Number panel width]
-- @param height [Number panel height]
function THEME:ChatboxPaintBackground(panel, width, height)
  DisableClipping(true)
    draw.box(0, -8, width, height - panel.text_entry:GetTall(), self:get_color('menu_background'))
  DisableClipping(false)
end

--- Draws the name of the character on a character card and outlines the card if it
-- belongs to the active character of the local player.
-- @param panel [Panel the character card]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharPanel(panel, w, h)
  if panel.char_data then
    local char_data       = panel.char_data
    local font            = self:get_font('main_menu_titles')
    local name_w, name_h  = text_size(char_data.name, font)

    draw_simple_text(
      char_data.name,
      font,
      w * 0.5 - name_w * 0.5,
      4,
      self:get_color('schema_text')
    )

    if PLAYER:get_character_id() == char_data.character_id then
      surface.SetDrawColor(self:get_color('accent'))
      surface.DrawOutlinedRect(0, 0, w, h)
    end
  end
end

--- Draws the title of the character creation screen.
-- @param panel [Panel the character creation panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationMainPanel(panel, w, h)
  local title, font       = t'ui.char_create.text', Theme.get_font 'main_menu_title'
  local title_w, title_h  = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - title_w * 0.5, h * 0.125)
end

--- Draws the title of the character loading screen.
-- @param panel [Panel the character loading panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationLoadPanel(panel, w, h)
  local title, font       = t'ui.char_create.load', Theme.get_font 'main_menu_title'
  local title_w, title_h  = text_size(title, font)

  draw_simple_text(title, font, w * 0.5 - title_w * 0.5, h * 0.125)
end

--- Draws the title of a character creation stage, if the panel has one.
-- @param panel [Panel the stage panel]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME:PaintCharCreationBasePanel(panel, w, h)
  if isstring(panel.text) then
    local text            = t(panel.text)
    local font            = Theme.get_font('main_menu_large')
    local text_w, text_h  = text_size(text, font)

    draw_simple_text(
      text,
      font,
      w * 0.5 - text_w * 0.5,
      0,
      Theme.get_color('text')
    )
  end
end

THEME.skin.frameBorder            = Color(255, 255, 255, 255)
THEME.skin.frameTitle             = Color(255, 255, 255, 255)

THEME.skin.bgColorBright          = Color(255, 255, 255, 255)
THEME.skin.bgColorSleep           = Color(70, 70, 70, 255)
THEME.skin.bgColorDark            = Color(50, 50, 50, 255)
THEME.skin.bgColor                = Color(40, 40, 40, 240)

THEME.skin.controlColorHighlight  = Color(70, 70, 70, 255)
THEME.skin.controlColorActive     = Color(175, 175, 175, 255)
THEME.skin.controlColorBright     = Color(100, 100, 100, 255)
THEME.skin.controlColorDark       = Color(30, 30, 30, 255)
THEME.skin.controlColor           = Color(60, 60, 60, 255)

THEME.skin.colPropertySheet       = Color(255, 255, 255, 255)
THEME.skin.colTabTextInactive     = Color(0, 0, 0, 255)
THEME.skin.colTabInactive         = Color(255, 255, 255, 255)
THEME.skin.colTabShadow           = Color(0, 0, 0, 170)
THEME.skin.colTabText             = Color(255, 255, 255, 255)
THEME.skin.colTab                 = Color(0, 0, 0, 255)

THEME.skin.fontCategoryHeader     = 'Exo8'
THEME.skin.fontMenuOption         = 'Exo8'
THEME.skin.fontFormLabel          = 'Exo8'
THEME.skin.fontButton             = 'Exo8'
THEME.skin.fontFrame              = 'Exo8'
THEME.skin.fontTab                = 'Exo8'

--- Draws a solid rectangle.
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
-- @param color [Color]
function THEME.skin:DrawGenericBackground(x, y, w, h, color)
  surface_set_draw_color(color)
  surface_draw_rect(x, y, w, h)
end

--- Lays out the title label and the close button of a frame.
-- @param panel [Panel the frame]
function THEME.skin:LayoutFrame(panel)
  panel.lblTitle:SetFont(self.fontFrame)
  panel.lblTitle:SetText(panel.lblTitle:GetText():upper())
  panel.lblTitle:SetTextColor(Color(0, 0, 0, 255))
  panel.lblTitle:SizeToContents()
  panel.lblTitle:SetExpensiveShadow(nil)

  panel.button_close:SetDrawBackground(true)
  panel.button_close:SetPos(panel:GetWide() - 22, 2)
  panel.button_close:SetSize(18, 18)
  panel.lblTitle:SetPos(8, 2)
  panel.lblTitle:SetSize(panel:GetWide() - 25, 20)
end

--- Applies the font, upper case text, color and shadow of the skin to the label of a form.
-- @param panel [Panel the form]
function THEME.skin:SchemeForm(panel)
  panel.Label:SetFont(self.fontFormLabel)
  panel.Label:SetText(panel.Label:GetText():upper())
  panel.Label:SetTextColor(Color(255, 255, 255, 255))
  panel.Label:SetExpensiveShadow(1, Color(0, 0, 0, 200))
end

--- Draws a tab of a property sheet, highlighted if it is the active one.
-- @param panel [Panel the tab]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintTab(panel, w, h)
  if panel:GetPropertySheet():GetActiveTab() == panel then
    local scale = DermaScale.scale
    local margin = scale(8)

    self:DrawGenericBackground(scale(4), 0, w - margin, h - margin, self.colTab:alpha(220))
  else
    self:DrawGenericBackground(0, 0, w, h, color_skin_tab)
  end
end

--- Draws a white background for a list view if its background is enabled.
-- @param panel [Panel the list view]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintListView(panel, w, h)
  if panel.m_bBackground then
    surface.SetDrawColor(255, 255, 255, 255)
    panel:DrawFilledRect()
  end
end

--- Draws a line of a list view, colored after its selected, hovered or alternate state,
-- and sets the text color of its columns.
-- @param panel [Panel the list view line]
function THEME.skin:PaintListViewLine(panel)
  local color       = color_skin_line
  local text_color  = Color(255, 255, 255, 255)

  if panel:IsSelected() then
    color = color_white
    text_color = Color(0, 0, 0, 255)
  elseif panel.Hovered then
    color = color_skin_line_hovered
  elseif panel.m_bAlt then
    color = color_skin_line_alt
  end

  for k, v in pairs(panel.Columns) do
    v:SetTextColor(text_color)
  end

  surface_set_draw_color(color.r, color.g, color.b, color.a)
  surface_draw_rect(0, 0, panel:GetSize())
end

--- Sets the text inset and the text color of a list view label.
-- @param panel [Panel the label]
function THEME.skin:SchemeListViewLabel(panel)
  panel:SetTextInset(3)
  panel:SetTextColor(Color(255, 255, 255, 255))
end

--- Draws the dark background of a Derma menu.
-- @param panel [Panel the menu]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintMenu(panel, w, h)
  surface_set_draw_color(color_skin_menu)
  panel:DrawFilledRect(0, 0, w, h)
end

--- Does nothing: the skin draws nothing over Derma menus.
-- @param panel [Panel the menu]
function THEME.skin:PaintOverMenu(panel) end

--- Sets the text color of a menu option.
-- @param panel [Panel the menu option]
function THEME.skin:SchemeMenuOption(panel)
  panel:SetFGColor(255, 255, 255, 255)
end

--- Draws the highlight of a hovered menu option and sets its text color accordingly.
-- @param panel [Panel the menu option]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintMenuOption(panel, w, h)
  local text_color = color_white

  if panel.m_bBackground and panel.Hovered then
    local color = nil

    if panel.Depressed then
      color = color_skin_option_depressed
    else
      color = color_white
    end

    surface_set_draw_color(color.r, color.g, color.b, color.a)
    surface_draw_rect(0, 0, w, h)

    text_color = color_black
  end

  panel:SetFGColor(text_color)
end

--- Sizes a menu option to fit its text and the width of its menu, and positions its
-- submenu arrow.
-- @param panel [Panel the menu option]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:LayoutMenuOption(panel, w, h)
  panel:SetFont(self.fontMenuOption)
  panel:SizeToContents()
  panel:SetWide(panel:GetWide() + 30)
  panel:SetSize(math.max(panel:GetParent():GetWide(), panel:GetWide()), 18)

  if panel.SubMenuArrow then
    panel.SubMenuArrow:SetSize(panel:GetTall(), panel:GetTall())
    panel.SubMenuArrow:CenterVertical()
    panel.SubMenuArrow:AlignRight()
  end
end

--- Draws a Derma button with a border and a fill that reflects its disabled, pressed or
-- hovered state, and sets its text color.
-- @param panel [Panel the button]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintButton(panel, w, h)
  local text_color = color_white

  if panel.m_bBackground then
    local color = color_skin_button

    if panel:GetDisabled() then
      color = self.controlColorDark
    elseif panel.Depressed then
      color = color_white
      text_color = color_black
    elseif panel.Hovered then
      color = self.controlColorHighlight
    end

    self:DrawGenericBackground(0, 0, w, h, color_black)
    self:DrawGenericBackground(1, 1, w - 2, h - 2, color)
  end

  panel:SetFGColor(text_color)
end

--- Draws the grip of a scroll bar as a black box with a white border.
-- @param panel [Panel the grip]
function THEME.skin:PaintScrollBarGrip(panel)
  local w, h = panel:GetSize()

  self:DrawGenericBackground(0, 0, w, h, color_white)
  self:DrawGenericBackground(1, 1, w - 2, h - 2, color_black)
end

--- Draws the translucent background of a frame and its header gradient in the accent color.
-- @param panel [Panel the frame]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintFrame(panel, w, h)
  local color = Theme.get_color('accent')

  surface_set_draw_color(color_skin_frame)
  surface_draw_rect(0, 0, w, h)

  -- The gradient covers the title bar, which scales with the stock Derma (cl_derma_scale.lua).
  textured_rect(Theme.get_material('gradient'), 0, 0, w, DermaScale.scale(24), color:alpha(200))
end

--- Draws the header background of a collapsible category, darker while it is collapsed,
-- and applies the theme font to its header.
-- @param panel [Panel the category]
-- @param w [Number panel width]
-- @param h [Number panel height]
function THEME.skin:PaintCollapsibleCategory(panel, w, h)
  panel.Header:SetFont(Theme.get_font('text_smaller'))

  -- The bar covers the header, whose height scales with the stock Derma (cl_derma_scale.lua).
  local bar_height = panel:GetHeaderHeight() + 1

  if h < bar_height then
    self:DrawGenericBackground(0, 0, w, bar_height, color_black)
  else
    self:DrawGenericBackground(0, 0, w, bar_height, color_skin_category)
  end
end
