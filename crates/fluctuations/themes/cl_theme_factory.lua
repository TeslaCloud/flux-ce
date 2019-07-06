-- Create the default Theme that other themes will derive from.
THEME.author = 'TeslaCloud Studios'
THEME.id = 'factory'
THEME.description = 'Factory Theme. This is a fail-safety Theme that other themes use as a base.'
THEME.should_reload = true

function THEME:on_loaded()
  local scrw, scrh = ScrW(), ScrH()

  self:set_option('frame_header_size', math.scale(24))
  self:set_option('frame_line_weight', math.scale(2))
  self:set_option('menu_sidebar_width', 300)
  self:set_option('menu_sidebar_height', scrh)
  self:set_option('menu_sidebar_x', 0)
  self:set_option('menu_sidebar_y', 0)
  self:set_option('menu_sidebar_margin', -1)
  self:set_option('menu_sidebar_logo', 'flux/flux_icon.png')
  self:set_option('menu_sidebar_logo_space', scrh / 3)
  self:set_option('menu_sidebar_button_height', math.scale(42))
  self:set_option('menu_sidebar_button_offset_x', 16)
  self:set_option('menu_sidebar_button_centered', false)
  self:set_option('menu_logo_height', 100)
  self:set_option('menu_logo_width', 110)
  self:set_option('menu_anim_duration', 0.2)

  self:set_sound('button_click_success_sound', 'garrysmod/ui_click.wav')
  self:set_sound('button_click_danger_sound', 'buttons/button8.wav')
  self:set_sound('menu_music', '')

  self:register_asset('gradient', 'materials/flux/gradient.png', { sizes = { 1, 2, 4 } })
  self:register_asset('gradient_full', 'materials/flux/gradient_fs.png', { sizes = { 1, 2, 4 } })

  local accent_color        = self:set_color('accent', Color(90, 90, 190))
  local main_color          = self:set_color('main', Color(50, 50, 50))
  local outline_color       = self:set_color('outline', Color(65, 65, 65))
  local background_color    = self:set_color('background', Color(20, 20, 20))
  local text_color          = self:set_color('text', util.text_color_from_base(background_color))

  self:set_color('accent_dark', accent_color:darken(20))
  self:set_color('accent_light', accent_color:lighten(20))
  self:set_color('main_dark', main_color:darken(15))
  self:set_color('main_light', main_color:lighten(15))
  self:set_color('background_dark', background_color:darken(20))
  self:set_color('background_light', background_color:lighten(20))
  self:set_color('schema_text', text_color)
  self:set_color('menu_background', self:get_color('background_dark'))

  self:set_color('esp_red', Color(255, 0, 0))
  self:set_color('esp_blue', Color(0, 0, 255))
  self:set_color('esp_grey', Color(100, 100, 100))

  local main_font           = self:set_font('main_font', 'flRoboto', math.scale(16))
  local main_font_condensed = self:set_font('main_font_condensed', 'flRobotoCondensed', math.scale(16))
  local light_font          = self:set_font('light_font', 'flRobotoLight', math.scale(16))
  self:set_font('menu_titles', 'flRobotoLight', math.scale(14))
  self:set_font('menu_tiny', 'flRobotoLt', math.scale(16))
  self:set_font('menu_small', 'flRobotoLt', math.scale(20))
  self:set_font('menu_normal', main_font_condensed, math.scale(24))
  self:set_font('menu_large', main_font_condensed, math.scale(30))
  self:set_font('menu_larger', main_font_condensed, math.scale(42))
  self:set_font('main_menu_title', light_font, math.scale(48))
  self:set_font('main_menu_large', light_font, math.scale(42))
  self:set_font('main_menu_normal_large', light_font, math.scale(36))
  self:set_font('main_menu_titles', light_font, math.scale(24))
  self:set_font('main_menu_normal', light_font, math.scale(20))
  self:set_font('main_menu_small', light_font, math.scale(18))
  self:set_font('tooltip_small', main_font_condensed, math.scale(16))
  self:set_font('tooltip_normal', main_font_condensed, math.scale(21))
  self:set_font('tooltip_large', main_font_condensed, math.scale(26))
  self:set_font('text_largest', main_font, math.scale(90))
  self:set_font('text_large', main_font, math.scale(48))
  self:set_font('text_normal_large', main_font, math.scale(36))
  self:set_font('text_normal', main_font, math.scale(23))
  self:set_font('text_normal_smaller', main_font, math.scale(20))
  self:set_font('text_small', main_font, math.scale(18))
  self:set_font('text_smaller', main_font, math.scale(16))
  self:set_font('text_smallest', main_font, math.scale(14))
  self:set_font('text_bar', main_font, math.scale(17), { weight = 600 })
  self:set_font('text_3d2d', main_font, 256)

  -- Set from schema Theme.
  -- self:set_material('schema_logo', 'materials/flux/hl2rp/logo.png')
  self:set_material('gradient_up', 'vgui/gradient-u')
  self:set_material('gradient_down', 'vgui/gradient-d')

  self:add_panel('tab_menu', function(id, parent, ...)
    return vgui.Create('fl_tab_menu', parent)
  end)
end

function THEME:CreateMainMenu(panel)
end

function THEME:PaintFrame(panel, width, height)
  local title = panel:GetTitle()
  local accent_color = self:get_color('accent')
  local header_size = self:get_option('frame_header_size')
  local line_weight = self:get_option('frame_line_weight')

  surface.SetDrawColor(accent_color:darken(30))
  surface.DrawRect(0, header_size - line_weight, width, line_weight)

  surface.SetDrawColor(self:get_color('main_dark'))
  surface.DrawRect(0, header_size, width, height - header_size)

  draw.textured_rect(self:get_material('gradient'), 0, 0, width, header_size, accent_color)

  if title then
    local font = Font.size(self:get_font('text_small'), 16)
    local font_size = util.font_size(font)

    draw.SimpleText(title, font, 6, 3 * (16 / font_size), panel:GetTextColor())
  end
end

function THEME:PaintMainMenu(panel, width, height)
  local title, desc, author = SCHEMA:get_name(), SCHEMA:get_description(), t('ui.main_menu.developed_by', SCHEMA:get_author())
  local logo = self:get_material('schema_logo')
  local title_w, title_h = util.text_size(title, self:get_font('text_largest'))
  local desc_w, desc_h = util.text_size(desc, self:get_font('main_menu_titles'))
  local author_w, author_h = util.text_size(author, self:get_font('main_menu_titles'))
  local bar_height = math.scale(128)

  surface.SetDrawColor(self:get_color('menu_background'))
  surface.DrawRect(0, 0, width, width)

  surface.SetDrawColor(self:get_color('menu_background'):lighten(40))
  surface.DrawRect(0, 0, width, bar_height)

  if !logo then
    draw.SimpleText(title, self:get_font('text_largest'), width * 0.5 - title_w * 0.5, bar_height - title_h - 8, self:get_color('schema_text'))
  else
    draw.textured_rect(logo, width * 0.5 - math.scale(200), 16, 400, 96, Color(255, 255, 255))
  end

  draw.SimpleText(desc, self:get_font('main_menu_titles'), 16, bar_height - desc_h - 8, self:get_color('schema_text'))
  draw.SimpleText(author, self:get_font('main_menu_titles'), width - author_w - 16, bar_height - author_h - 8, self:get_color('schema_text'))
end

function THEME:PaintButton(panel, w, h)
  local cur_amt = panel.cur_amt
  local text_color = panel.text_color_override or self:get_color('text'):darken(cur_amt)
  local title = panel.title
  local font = panel.font
  local icon = panel.icon
  local left = panel.icon_left
  local center = panel.centered
  local offset = panel:get_text_offset()
  local text_x, text_y = offset, 0
  local icon_x, icon_y = 0, 0
  local text_w, text_h, icon_w, icon_h
  local icon_size = panel.icon_size

  if panel.draw_background then
    surface.SetDrawColor(self:get_color('outline'))
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(panel.active and self:get_color('main_dark') or self:get_color('main'):lighten(cur_amt))
    surface.DrawRect(1, 1, w - 2, h - 2)
  end

  if title != '' then
    text_w, text_h = util.text_size(title, font)
    text_y = h / 2 - text_h / 2

    if center then
      text_x = offset + w / 2 - text_w / 2
    end
  end

  if icon then
    local icon_text, text_font = FontAwesome:get(icon)

    icon_w, icon_h = util.text_size(icon_text, Font.size('flFontAwesome', icon_size))
    icon_x = (left and text_x or text_x + text_w)
    icon_y = h / 2 - icon_h / 2

    text_x = text_x + (left and icon_w + 4 or -4)

    if center and title == '' then
      icon_x = w / 2 - icon_w / 2
    end
  end

  if title != '' then
    draw.SimpleText(title, font, text_x, text_y, text_color)
  end

  if icon then
    FontAwesome:draw(icon, icon_x, icon_y, icon_size, text_color)
  end
end

function THEME:PaintDeathScreen(cur_time, scrw, scrh)
  local respawn_time_remaining = PLAYER:get_nv('respawn_time', 0) - cur_time
  local bar_value = 100 - 100 * (respawn_time_remaining / Config.get('respawn_delay'))
  local font = self:get_font('text_normal_large')
  local color_white = Color(255, 255, 255)

  if !PLAYER.respawn_alpha then PLAYER.respawn_alpha = 0 end

  PLAYER.respawn_alpha = math.Clamp(PLAYER.respawn_alpha + 1, 0, 200)

  draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0, PLAYER.respawn_alpha))

  draw.SimpleText(t'ui.hud.player_message.died', font, 16, 16, color_white)
  draw.SimpleText(t('ui.hud.player_message.respawn', { time = math.ceil(respawn_time_remaining) }), font, 16, 16 + util.font_size(font), color_white)

  draw.RoundedBox(0, 0, 0, scrw / 100 * bar_value, 2, color_white)

  if respawn_time_remaining <= 3 then
    PLAYER.white_alpha = math.Clamp(255 * (1.5 - respawn_time_remaining * 0.5), 0, 255)
  else
    PLAYER.white_alpha = 0
  end
end

function THEME:PaintSidebar(panel, width, height)
  draw.RoundedBox(0, 0, 0, width, height, self:get_color('main_dark'):lighten(10))
end

function THEME:DrawBarBackground(bar_info)
  draw.RoundedBox(bar_info.corner_radius, bar_info.x, bar_info.y, bar_info.width, bar_info.height, self:get_color('main_dark'))
end

function THEME:DrawBarHindrance(bar_info)
  local length = bar_info.width * (bar_info.hinder_value / bar_info.max_value)

  draw.RoundedBox(bar_info.corner_radius, bar_info.x + bar_info.width - length - 1, bar_info.y + 1, length, bar_info.height - 2, bar_info.hinder_color)
end

function THEME:DrawBarFill(bar_info)
  if bar_info.real_fill_width < bar_info.fill_width then
    draw.RoundedBox(bar_info.corner_radius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, bar_info.color)
    draw.RoundedBox(bar_info.corner_radius, bar_info.x + 1, bar_info.y + 1, bar_info.real_fill_width - 2, bar_info.height - 2, Color(230, 230, 230))
  elseif bar_info.real_fill_width > bar_info.fill_width then
    draw.RoundedBox(bar_info.corner_radius, bar_info.x + 1, bar_info.y + 1, bar_info.real_fill_width - 2, bar_info.height - 2, bar_info.color)
    draw.RoundedBox(bar_info.corner_radius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, Color(230, 230, 230))
  else
    draw.RoundedBox(bar_info.corner_radius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, Color(230, 230, 230))
  end
end

function THEME:DrawBarTexts(bar_info)
  local font = Theme.get_font(bar_info.font)

  render.SetScissorRect(bar_info.x + 1, bar_info.y + 1, bar_info.x + bar_info.real_fill_width, bar_info.y + bar_info.height, true)
    draw.SimpleText(bar_info.text, font, bar_info.x + 8, bar_info.y + bar_info.text_offset, self:get_color('main_dark'))
  render.SetScissorRect(0, 0, 0, 0, false)

  render.SetScissorRect(bar_info.x + bar_info.real_fill_width, bar_info.y + 1, bar_info.x + bar_info.width, bar_info.y + bar_info.height, true)
    draw.SimpleText(bar_info.text, font, bar_info.x + 8, bar_info.y + bar_info.text_offset, self:get_color('text'))
  render.SetScissorRect(0, 0, 0, 0, false)

  if bar_info.hinder_display and bar_info.hinder_display <= bar_info.hinder_value then
    local width = bar_info.width
    local text_wide = util.text_size(bar_info.hinder_text, font)
    local length = width * (bar_info.hinder_value / bar_info.max_value)

    render.SetScissorRect(bar_info.x + width - length, bar_info.y, bar_info.x + width, bar_info.y + bar_info.height, true)
      draw.SimpleText(bar_info.hinder_text, font, bar_info.x + width - text_wide - 8, bar_info.y + bar_info.text_offset, Color(255, 255, 255))
    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

function THEME:AdminPanelPaintOver(panel, width, height)
  local smallest_font = Font.size(self:get_font('text_smallest'), 14)
  local text_color = self:get_color('text')
  local version_string = 'Admin Mod Version: v0.2.0 (indev)'

  DisableClipping(true)
    draw.RoundedBox(0, 0, height, width, 16, self:get_color('background'))

    draw.SimpleText(PLAYER:steam_name()..' ('..PLAYER:GetUserGroup()..')', smallest_font, 6, height + 1, text_color)

    local w, h = util.text_size(version_string, smallest_font)

    draw.SimpleText(version_string, smallest_font, width - w - 6, height + 1, text_color)
  DisableClipping(false)
end

function THEME:PaintConfigLine(panel, w, h)
  if panel.dark then
    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
  end
end

function THEME:PaintPermissionButton(perm_panel, btn, w, h)
  local color = color_white
  local title = ''
  local perm_type = btn.perm_value
  local font = self:get_font('text_small')

  if perm_type == PERM_NO then
    color = Color(120, 120, 120)
    title = t'ui.perm.not_set'
  elseif perm_type == PERM_ALLOW then
    color = Color(100, 220, 100)
    title = t'ui.perm.allow'
  elseif perm_type == PERM_NEVER then
    color = Color(220, 100, 100)
    title = t'ui.perm.never'
  else
    title = t'ui.perm.error'
  end

  local text_color = color:darken(75)

  if btn:IsHovered() then
    color = color:lighten(30)
  end

  draw.RoundedBox(0, 0, 0, w, h, text_color)
  draw.RoundedBox(0, 1, 1, w - 2, h - 1, color)

  local tw, th = util.text_size(title, font)

  draw.SimpleText(title, font, w * 0.5 - tw * 0.5, 2, text_color)

  local sqr_size = h * 0.5

  draw.RoundedBox(0, sqr_size * 0.5, sqr_size * 0.5, sqr_size, sqr_size, Color(255, 255, 255))

  if btn.is_selected then
    draw.RoundedBox(0, sqr_size * 0.5 + 2, sqr_size * 0.5 + 2, sqr_size - 4, sqr_size - 4, Color(0, 0, 0))
  end

  if btn.is_temp then
    FontAwesome:draw('fa-clock-o', w - h - 2, 2, h - 4, Color(255, 255, 255))
  end
end

function THEME:PaintScoreboard(panel, width, height)
  local text = t('ui.scoreboard.title')
  local font = self:get_font('main_menu_large')
  local text_w, text_h = util.text_size(text, font)

  DisableClipping(true)
    draw.RoundedBox(0, -4, -4, width + 8, height + 8, Color(50, 50, 50, 100))
    draw.textured_rect(self:get_material('gradient_down'), -4, -text_h - 4, text_w + 8, text_h, Color(50, 50, 50, 100))
    draw.SimpleText(text, font, 0, -text_h - 4, color_white)
  DisableClipping(false)

  font = self:get_font('text_small')

  draw.SimpleText(t'ui.scoreboard.help', font, 4, 0, self:get_color('text'))

  text = t'ui.scoreboard.ping'
  text_w, text_h = util.text_size(text, font)

  draw.SimpleText(text, font, width - text_w - 8, 0, self:get_color('text'))
end

function THEME:PaintTabMenuButtonPanel(panel, width, height)
  draw.RoundedBox(0, 0, 0, width, height, self:get_color('background'):alpha(125))
end

function THEME:PaintTabMenu(panel, width, height)
  local fraction = FrameTime() * 8
  local active_panel = panel.active_panel

  Flux.blur_size = Lerp(fraction, Flux.blur_size, panel.blur_target)

  draw.blur_panel(panel)

  if IsValid(active_panel) then
    panel.pos_y = panel.pos_y or 0

    local active_button = panel.activeBtn

    if !IsValid(active_button) then return end

    local x, y = active_button:GetPos()
    local target_h = active_button:GetTall()

    if panel.prev_y != y then
      panel.pos_y = Lerp(fraction, panel.pos_y, y)
    end

    panel.prev_y = panel.pos_y

    if !active_panel.indicator_lerp then
      active_panel.indicator_lerp = 0
    end

    active_panel.indicator_lerp = Lerp(fraction, active_panel.indicator_lerp, target_h)

    draw.RoundedBox(0, 0, panel.pos_y, 6, target_h, self:get_color('accent_light'))
  end
end

function THEME:PaintItemSlot(panel, w, h)
  draw.textured_rect(self:get_material('gradient_up'), 0, 0, w, h, Color(30, 30, 30, 100))
end

function THEME:PaintInventoryBackground(panel, w, h)
  DisableClipping(true)
    draw.RoundedBox(0, -4, -4, w + 8, h + 8, Color(50, 50, 50, 100))
  DisableClipping(false)
end

function THEME:PaintTabInventoryBackground(panel, w, h)
  if IsValid(panel.player_model) then
    local x, y = panel.player_model:GetPos()
    local player_w, player_h = panel.player_model:GetSize()
    local text = PLAYER:name()
    local font = self:get_font('main_menu_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.RoundedBox(0, x - 4, y - 4, player_w + 8, player_h + 8, Color(50, 50, 50, 100))
      draw.RoundedBox(0, x, y, player_w, player_h, Color(0, 0, 0, 100))
      draw.textured_rect(self:get_material('gradient_up'), x, y, player_w, player_h, Color(30, 30, 30, 100))
      draw.textured_rect(self:get_material('gradient_down'), x - 4, y - text_h - 4, text_w + 8, text_h, Color(50, 50, 50, 100))
      draw.SimpleText(text, font, x, -text_h, color_white:alpha(150))
    DisableClipping(false)
  end
end

function THEME:PaintOverInventoryBackground(panel, w, h)
  if panel.title then
    local text = t(panel.title)
    local font = self:get_font('main_menu_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.textured_rect(self:get_material('gradient_down'), -4, -text_h - 4, text_w + 8, text_h, Color(50, 50, 50, 100))
      draw.SimpleText(text, font, 0, -text_h - 4, color_white:alpha(150))
    DisableClipping(false)
  end
end

function THEME:ChatboxPaintBackground(panel, width, height)
  DisableClipping(true)
    draw.box(0, -8, width, height - panel.text_entry:GetTall(), self:get_color('menu_background'))
  DisableClipping(false)
end

function THEME:PaintCharPanel(panel, w, h)
  if panel.char_data then
    local char_data = panel.char_data
    local name_w, name_h = util.text_size(char_data.name, self:get_font('main_menu_titles'))

    draw.SimpleText(char_data.name, self:get_font('main_menu_titles'), w * 0.5 - name_w * 0.5, 4, self:get_color('schema_text'))

    if PLAYER:get_character_id() == char_data.character_id then
      surface.SetDrawColor(self:get_color('accent'))
      surface.DrawOutlinedRect(0, 0, w, h)
    end
  end
end

function THEME:PaintCharCreationMainPanel(panel, w, h)
  local title, font = t'ui.char_create.text', Theme.get_font 'main_menu_title'
  local title_w, title_h = util.text_size(title, font)
  draw.SimpleText(title, font, w * 0.5 - title_w * 0.5, h / 8)
end

function THEME:PaintCharCreationLoadPanel(panel, w, h)
  local title, font = t'ui.char_create.load', Theme.get_font 'main_menu_title'
  local title_w, title_h = util.text_size(title, font)
  draw.SimpleText(title, font, w * 0.5 - title_w * 0.5, h / 8)
end

function THEME:PaintCharCreationBasePanel(panel, w, h)
  if isstring(panel.text) then
    local text_w, text_h = util.text_size(t(panel.text), Theme.get_font('main_menu_large'))
    draw.SimpleText(t(panel.text), Theme.get_font('main_menu_large'), w * 0.5 - text_w * 0.5, 0, Theme.get_color('text'))
  end
end

THEME.skin.frameBorder = Color(255, 255, 255, 255)
THEME.skin.frameTitle = Color(255, 255, 255, 255)

THEME.skin.bgColorBright = Color(255, 255, 255, 255)
THEME.skin.bgColorSleep = Color(70, 70, 70, 255)
THEME.skin.bgColorDark = Color(50, 50, 50, 255)
THEME.skin.bgColor = Color(40, 40, 40, 240)

THEME.skin.controlColorHighlight = Color(70, 70, 70, 255)
THEME.skin.controlColorActive = Color(175, 175, 175, 255)
THEME.skin.controlColorBright = Color(100, 100, 100, 255)
THEME.skin.controlColorDark = Color(30, 30, 30, 255)
THEME.skin.controlColor = Color(60, 60, 60, 255)

THEME.skin.colPropertySheet = Color(255, 255, 255, 255)
THEME.skin.colTabTextInactive = Color(0, 0, 0, 255)
THEME.skin.colTabInactive = Color(255, 255, 255, 255)
THEME.skin.colTabShadow = Color(0, 0, 0, 170)
THEME.skin.colTabText = Color(255, 255, 255, 255)
THEME.skin.colTab = Color(0, 0, 0, 255)

THEME.skin.fontCategoryHeader = 'Exo8'
THEME.skin.fontMenuOption = 'Exo8'
THEME.skin.fontFormLabel = 'Exo8'
THEME.skin.fontButton = 'Exo8'
THEME.skin.fontFrame = 'Exo8'
THEME.skin.fontTab = 'Exo8'

-- A function to draw a generic background.
function THEME.skin:DrawGenericBackground(x, y, w, h, color)
  surface.SetDrawColor(color)
  surface.DrawRect(x, y, w, h)
end

-- Called when a frame is layed out.
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

-- Called when a form is schemed.
function THEME.skin:SchemeForm(panel)
  panel.Label:SetFont(self.fontFormLabel)
  panel.Label:SetText(panel.Label:GetText():upper())
  panel.Label:SetTextColor(Color(255, 255, 255, 255))
  panel.Label:SetExpensiveShadow(1, Color(0, 0, 0, 200))
end

-- Called when a tab is painted.
function THEME.skin:PaintTab(panel, w, h)
  if panel:GetPropertySheet():GetActiveTab() == panel then
    self:DrawGenericBackground(4, 0, w - 8, h - 8, self.colTab:alpha(220))
  else
    self:DrawGenericBackground(0, 0, w, h, Color(40, 40, 40))
  end
end

-- Called when a list view is painted.
function THEME.skin:PaintListView(panel, w, h)
  if panel.m_bBackground then
    surface.SetDrawColor(255, 255, 255, 255)
    panel:DrawFilledRect()
  end
end

-- Called when a list view line is painted.
function THEME.skin:PaintListViewLine(panel)
  local color = Color(50, 50, 50, 255)
  local text_color = Color(255, 255, 255, 255)

  if panel:IsSelected() then
    color = Color(255, 255, 255, 255)
    text_color = Color(0, 0, 0, 255)
  elseif panel.Hovered then
    color = Color(100, 100, 100, 255)
  elseif panel.m_bAlt then
    color = Color(75, 75, 75, 255)
  end

  for k, v in pairs(panel.Columns) do
    v:SetTextColor(text_color)
  end

  surface.SetDrawColor(color.r, color.g, color.b, color.a)
  surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
end

-- Called when a list view label is schemed.
function THEME.skin:SchemeListViewLabel(panel)
  panel:SetTextInset(3)
  panel:SetTextColor(Color(255, 255, 255, 255))
end

-- Called when a menu is painted.
function THEME.skin:PaintMenu(panel, w, h)
  surface.SetDrawColor(Color(15, 15, 15, 255))
  panel:DrawFilledRect(0, 0, w, h)
end

-- Called when a menu is painted over.
function THEME.skin:PaintOverMenu(panel) end

-- Called when a menu option is schemed.
function THEME.skin:SchemeMenuOption(panel)
  panel:SetFGColor(255, 255, 255, 255)
end

-- Called when a menu option is painted.
function THEME.skin:PaintMenuOption(panel, w, h)
  local text_color = Color(255, 255, 255, 255)

  if panel.m_bBackground and panel.Hovered then
    local color = nil

    if panel.Depressed then
      color = Color(225, 225, 225, 255)
    else
      color = Color(255, 255, 255, 255)
    end

    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    surface.DrawRect(0, 0, w, h)

    text_color = Color(0, 0, 0, 255)
  end

  panel:SetFGColor(text_color)
end

-- Called when a menu option is layed out.
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

-- Called when a button is painted.
function THEME.skin:PaintButton(panel, w, h)
  local text_color = Color(255, 255, 255, 255)

  if panel.m_bBackground then
    local color = Color(40, 40, 40, 255)
    local borderColor = Color(0, 0, 0, 255)

    if panel:GetDisabled() then
      color = self.controlColorDark
    elseif panel.Depressed then
      color = Color(255, 255, 255, 255)
      text_color = Color(0, 0, 0, 255)
    elseif panel.Hovered then
      color = self.controlColorHighlight
    end

    self:DrawGenericBackground(0, 0, w, h, borderColor)
    self:DrawGenericBackground(1, 1, w - 2, h - 2, color)
  end

  panel:SetFGColor(text_color)
end

-- Called when a scroll bar grip is painted.
function THEME.skin:PaintScrollBarGrip(panel)
  local w, h = panel:GetSize()
  local color = Color(255, 255, 255, 255)

  self:DrawGenericBackground(0, 0, w, h, color)
  self:DrawGenericBackground(1, 1, w - 2, h - 2, Color(0, 0, 0, 255))
end

function THEME.skin:PaintFrame(panel, w, h)
  local color = Theme.get_color('accent')

  surface.SetDrawColor(Color(10, 10, 10, 150))
  surface.DrawRect(0, 0, w, h)

  draw.textured_rect(Theme.get_material('gradient'), 0, 0, w, 24, color:alpha(200))
end

function THEME.skin:PaintCollapsibleCategory(panel, w, h)
  panel.Header:SetFont(Theme.get_font('text_smaller'))

  if h < 21 then
    self:DrawGenericBackground(0, 0, w, 21, Color(0, 0, 0))
  else
    self:DrawGenericBackground(0, 0, w, 21, Color(30, 30, 30))
  end
end
