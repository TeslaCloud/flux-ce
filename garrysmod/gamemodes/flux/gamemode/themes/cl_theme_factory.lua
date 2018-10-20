-- Create the default theme that other themes will derive from.
THEME.author = 'TeslaCloud Studios'
THEME.id = 'factory'
THEME.description = 'Factory theme. This is a fail-safety theme that other themes use as a base.'
THEME.should_reload = true

function THEME:on_loaded()
  local scrw, scrh = ScrW(), ScrH()

  self:set_option('frame_header_size', 24)
  self:set_option('frame_line_weight', 2)
  self:set_option('menu_sidebar_width', 300)
  self:set_option('menu_sidebar_height', scrh)
  self:set_option('menu_sidebar_x', 0)
  self:set_option('menu_sidebar_y', 0)
  self:set_option('menu_sidebar_margin', -1)
  self:set_option('menu_sidebar_logo', 'flux/flux_icon.png')
  self:set_option('menu_sidebar_logo_space', scrh / 3)
  self:set_option('menu_sidebar_button_height', font.Scale(42)) -- We can cheat and scale buttons the same way we scale fonts!
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

  local main_font           = self:set_font('main_font', 'flRoboto', font.Scale(16))
  local main_font_condensed = self:set_font('main_font_condensed', 'flRobotoCondensed', font.Scale(16))
  local light_font          = self:set_font('light_font', 'flRobotoLight', font.Scale(16))
  self:set_font('menu_titles', 'flRobotoLight', font.Scale(14))
  self:set_font('menu_tiny', 'flRobotoLt', font.Scale(16))
  self:set_font('menu_small', 'flRobotoLt', font.Scale(20))
  self:set_font('menu_normal', main_font_condensed, font.Scale(24))
  self:set_font('menu_large', main_font_condensed, font.Scale(30))
  self:set_font('menu_larger', main_font_condensed, font.Scale(42))
  self:set_font('main_menu_title', light_font, font.Scale(48))
  self:set_font('main_menu_large', light_font, font.Scale(42))
  self:set_font('main_menu_titles', light_font, font.Scale(24))
  self:set_font('main_menu_normal', light_font, font.Scale(20))
  self:set_font('main_menu_small', light_font, font.Scale(18))
  self:set_font('tooltip_small', main_font_condensed, font.Scale(16))
  self:set_font('tooltip_large', main_font_condensed, font.Scale(26))
  self:set_font('text_largest', main_font, font.Scale(90))
  self:set_font('text_large', main_font, font.Scale(48))
  self:set_font('text_normal_large', main_font, font.Scale(36))
  self:set_font('text_normal', main_font, font.Scale(23))
  self:set_font('text_normal_smaller', main_font, font.Scale(20))
  self:set_font('text_small', main_font, font.Scale(18))
  self:set_font('text_smaller', main_font, font.Scale(16))
  self:set_font('text_smallest', main_font, font.Scale(14))
  self:set_font('text_bar', main_font, font.Scale(17), {weight = 600})
  self:set_font('text_3d2d', main_font, 256)

  -- Set from schema theme.
  -- self:set_material('schema_logo', 'materials/flux/hl2rp/logo.png')

  self:add_panel('tab_menu', function(id, parent, ...)
    return vgui.Create('fl_tab_menu', parent)
  end)

  self:add_panel('admin_permissions_editor', function(id, parent, ...)
    return vgui.Create('permissions_editor', parent)
  end)
end

function THEME:CreateMainMenu(panel) end

function THEME:PaintFrame(panel, width, height)
  local title = panel:GetTitle()
  local accent_color = panel:GetAccentColor()
  local header_size = self:get_option('frame_header_size')
  local lineWeight = self:get_option('frame_line_weight')

  surface.SetDrawColor(accent_color:darken(30))
  surface.DrawRect(0, header_size - lineWeight, width, lineWeight)

  surface.SetDrawColor(self:get_color('main_dark'))
  surface.DrawRect(0, header_size, width, height - header_size)

  draw.textured_rect(self:get_material('gradient'), 0, 0, w, header_size, accent_color)

  if title then
    local font = font.GetSize(self:get_font('text_small'), 16)
    local fontSize = util.font_size(font)

    draw.SimpleText(title, font, 6, 3 * (16 / fontSize), panel:GetTextColor())
  end
end

function THEME:PaintMainMenu(panel, width, height)
  local wide = self:get_option('menu_sidebar_width') * 0.5
  local title, desc, author = Schema:get_name(), Schema:get_description(), t('main_menu.developed_by', Schema:get_author())
  local logo = self:get_material('schema_logo')
  local title_w, title_h = util.text_size(title, self:get_font('text_largest'))
  local desc_w, desc_h = util.text_size(desc, self:get_font('main_menu_titles'))
  local author_w, author_h = util.text_size(author, self:get_font('main_menu_titles'))

  surface.SetDrawColor(self:get_color('menu_background'))
  surface.DrawRect(0, 0, width, width)

  surface.SetDrawColor(self:get_color('menu_background'):lighten(40))
  surface.DrawRect(0, 0, width, 128)

  if !logo then
    draw.SimpleText(title, self:get_font('text_largest'), wide + width * 0.5 - title_w * 0.5, 150, self:get_color('schema_text'))
  else
    draw.textured_rect(logo, width * 0.5 - 200, 16, 400, 96, Color(255, 255, 255))
  end

  draw.SimpleText(desc, self:get_font('main_menu_titles'), 16, 128 - desc_h - 8, self:get_color('schema_text'))
  draw.SimpleText(author, self:get_font('main_menu_titles'), width - author_w - 16, 128 - author_h - 8, self:get_color('schema_text'))
end

function THEME:PaintButton(panel, w, h)
  local curAmt = panel.m_CurAmt
  local text_color = panel.m_TextColorOverride or self:get_color('text'):darken(curAmt)
  local title = panel.m_Title
  local font = panel.m_Font
  local icon = panel.m_Icon
  local left = panel.m_IconLeft

  if panel.m_DrawBackground then
    if !panel.m_Active then
      surface.SetDrawColor(self:get_color('outline'))
      surface.DrawRect(0, 0, w, h)

      surface.SetDrawColor(self:get_color('main'):lighten(curAmt))
      surface.DrawRect(1, 1, w - 2, h - 2)
    else
      surface.SetDrawColor(self:get_color('outline'))
      surface.DrawRect(0, 0, w, h)

      surface.SetDrawColor(self:get_color('main_dark'))
      surface.DrawRect(1, 1, w - 1, h - 2)
    end
  end

  if icon then
    if !panel.m_Centered then
      if panel.m_IconLeft then
        fl.fa:Draw(icon, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), text_color)
      else
        fl.fa:Draw(icon, w - panel.m_IconSize - 8, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), text_color)
      end
    end
  end

  if title and title != '' then
    local width, height = util.text_size(title, font)

    if panel.m_Autopos then
      if icon then
        if panel.m_Centered then
          local textPos = (w - width - panel.m_IconSize) * 0.5

          if panel.m_IconLeft then
            fl.fa:Draw(icon, textPos - panel.m_IconSize - 8, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), text_color)
          else
            fl.fa:Draw(icon, textPos + width + panel.m_IconSize * 0.5, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), text_color)
          end

          draw.SimpleText(title, font, textPos, h * 0.5 - height * 0.5, text_color)
        else
          draw.SimpleText(title, font, h + 8, h * 0.5 - height * 0.5, text_color)
        end
      else
        draw.SimpleText(title, font, w * 0.5 - width * 0.5, h * 0.5 - height * 0.5, text_color)
      end
    else
      if panel.m_Centered then
        draw.SimpleText(title, font, (w - width) * 0.5, h * 0.5 - height * 0.5, text_color)
      else
        draw.SimpleText(title, font, panel.m_TextPos or 0, h * 0.5 - height * 0.5, text_color)
      end
    end
  else
    if panel.m_Centered then
      fl.fa:Draw(icon, w * 0.5 - panel.m_IconSize * 0.5, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), text_color)
    end
  end
end

function THEME:PaintDeathScreen(cur_time, scrw, scrh)
  local respawnTimeRemaining = fl.client:get_nv('respawn_time', 0) - cur_time
  local barValue = 100 - 100 * (respawnTimeRemaining / config.get('respawn_delay'))
  local font = self:get_font('text_normal_large')
  local color_white = Color(255, 255, 255)

  if !fl.client.respawnAlpha then fl.client.respawnAlpha = 0 end

  fl.client.respawnAlpha = math.Clamp(fl.client.respawnAlpha + 1, 0, 200)

  draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0, fl.client.respawnAlpha))

  draw.SimpleText(t'player_message.died', font, 16, 16, color_white)
  draw.SimpleText(t('player_message.respawn', math.ceil(respawnTimeRemaining)), font, 16, 16 + util.font_size(font), color_white)

  draw.RoundedBox(0, 0, 0, scrw / 100 * barValue, 2, color_white)

  if respawnTimeRemaining <= 3 then
    fl.client.white_alpha = math.Clamp(255 * (1.5 - respawnTimeRemaining * 0.5), 0, 255)
  else
    fl.client.white_alpha = 0
  end
end

function THEME:PaintSidebar(panel, width, height)
  draw.RoundedBox(0, 0, 0, width, height, self:get_color('main_dark'):lighten(10))
end

function THEME:DrawBarBackground(bar_info)
  draw.RoundedBox(bar_info.cornerRadius, bar_info.x, bar_info.y, bar_info.width, bar_info.height, self:get_color('main_dark'))
end

function THEME:DrawBarHindrance(bar_info)
  local length = bar_info.width * (bar_info.hinderValue / bar_info.max_value)

  draw.RoundedBox(bar_info.cornerRadius, bar_info.x + bar_info.width - length - 1, bar_info.y + 1, length, bar_info.height - 2, bar_info.hinderColor)
end

function THEME:DrawBarFill(bar_info)
  if bar_info.real_fill_width < bar_info.fill_width then
    draw.RoundedBox(bar_info.cornerRadius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, bar_info.color)
    draw.RoundedBox(bar_info.cornerRadius, bar_info.x + 1, bar_info.y + 1, bar_info.real_fill_width - 2, bar_info.height - 2, Color(230, 230, 230))
  elseif bar_info.real_fill_width > bar_info.fill_width then
    draw.RoundedBox(bar_info.cornerRadius, bar_info.x + 1, bar_info.y + 1, bar_info.real_fill_width - 2, bar_info.height - 2, bar_info.color)
    draw.RoundedBox(bar_info.cornerRadius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, Color(230, 230, 230))
  else
    draw.RoundedBox(bar_info.cornerRadius, bar_info.x + 1, bar_info.y + 1, (bar_info.fill_width or bar_info.width) - 2, bar_info.height - 2, Color(230, 230, 230))
  end
end

function THEME:DrawBarTexts(bar_info)
  local font = theme.get_font(bar_info.font)

  render.SetScissorRect(bar_info.x + 1, bar_info.y + 1, bar_info.x + bar_info.real_fill_width, bar_info.y + bar_info.height, true)
    draw.SimpleText(bar_info.text, font, bar_info.x + 8, bar_info.y + bar_info.text_offset, self:get_color('main_dark'))
  render.SetScissorRect(0, 0, 0, 0, false)

  render.SetScissorRect(bar_info.x + bar_info.real_fill_width, bar_info.y + 1, bar_info.x + bar_info.width, bar_info.y + bar_info.height, true)
    draw.SimpleText(bar_info.text, font, bar_info.x + 8, bar_info.y + bar_info.text_offset, self:get_color('text'))
  render.SetScissorRect(0, 0, 0, 0, false)

  if bar_info.hinderDisplay and bar_info.hinderDisplay <= bar_info.hinderValue then
    local width = bar_info.width
    local textWide = util.text_size(bar_info.hinderText, font)
    local length = width * (bar_info.hinderValue / bar_info.max_value)

    render.SetScissorRect(bar_info.x + width - length, bar_info.y, bar_info.x + width, bar_info.y + bar_info.height, true)
      draw.SimpleText(bar_info.hinderText, font, bar_info.x + width - textWide - 8, bar_info.y + bar_info.text_offset, Color(255, 255, 255))
    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

function THEME:AdminPanelPaintOver(panel, width, height)
  local smallestFont = font.GetSize(self:get_font('text_smallest'), 14)
  local text_color = self:get_color('text')
  local versionString = 'Admin Mod Version: v0.2.0 (indev)'

  DisableClipping(true)
    draw.RoundedBox(0, 0, height, width, 16, self:get_color('background'))

    draw.SimpleText(fl.client:SteamName()..' ('..fl.client:GetUserGroup()..')', smallestFont, 6, height + 1, text_color)

    local w, h = util.text_size(versionString, smallestFont)

    draw.SimpleText(versionString, smallestFont, width - w - 6, height + 1, text_color)
  DisableClipping(false)
end

function THEME:PaintPermissionButton(permPanel, btn, w, h)
  local color = Color(255, 255, 255)
  local title = ''
  local permType = btn.permValue
  local font = self:get_font('text_small')

  if permType == PERM_NO then
    color = Color(120, 120, 120)
    title = t'perm.not_set'
  elseif permType == PERM_ALLOW then
    color = Color(100, 220, 100)
    title = t'perm.allow'
  elseif permType == PERM_NEVER then
    color = Color(220, 100, 100)
    title = t'perm.never'
  else
    title = t'perm.error'
  end

  local text_color = color:darken(75)

  if btn:IsHovered() then
    color = color:lighten(30)
  end

  draw.RoundedBox(0, 0, 0, w, h, text_color)
  draw.RoundedBox(0, 1, 1, w - 2, h - 1, color)

  local tW, tH = util.text_size(title, font)

  draw.SimpleText(title, font, w * 0.5 - tW * 0.5, 2, text_color)

  local sqrSize = h * 0.5

  draw.RoundedBox(0, sqrSize * 0.5, sqrSize * 0.5, sqrSize, sqrSize, Color(255, 255, 255))

  if btn.isSelected then
    draw.RoundedBox(0, sqrSize * 0.5 + 2, sqrSize * 0.5 + 2, sqrSize - 4, sqrSize - 4, Color(0, 0, 0))
  end
end

function THEME:PaintScoreboard(panel, width, height)
  local titleFont = self:get_font('menu_large')

  draw.RoundedBox(0, 0, 0, width, height, ColorAlpha(self:get_color('background'), 150))

  local title = t'scoreboard.title'

  DisableClipping(true)
    draw.SimpleText(title, titleFont, 4, -util.text_height(title, titleFont) * 0.5, self:get_color('text'))
  DisableClipping(false)

  draw.SimpleText(t'scoreboard.help', self:get_font('text_small'), 4, 14, self:get_color('text'))
end

function THEME:PaintTabMenu(panel, width, height)
  local fraction = FrameTime() * 8
  local activePanel = panel.activePanel
  local sidebarColor = ColorAlpha(self:get_color('background'), 125)

  fl.blur_size = Lerp(fraction * 0.4, fl.blur_size, 6)

  draw.blur_panel(panel)
  draw.RoundedBox(0, 0, 0, font.Scale(200) + 6, height, sidebarColor)
  draw.RoundedBox(0, 0, 0, 6, height, sidebarColor)

  if IsValid(activePanel) then
    panel.posY = panel.posY or 0

    local activeButton = panel.activeBtn

    if !IsValid(activeButton) then return end

    local x, y = activeButton:GetPos()
    local targetH = activeButton:GetTall()

    if panel.prevY != y then
      panel.posY = Lerp(fraction, panel.posY, y)
    end

    panel.prevY = panel.posY

    if !activePanel.indicatorLerp then
      activePanel.indicatorLerp = 0
    end

    activePanel.indicatorLerp = Lerp(fraction, activePanel.indicatorLerp, targetH)

    draw.RoundedBox(0, 0, panel.posY, 6, targetH, self:get_color('accent_light'))
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

  panel.btnClose:SetDrawBackground(true)
  panel.btnClose:SetPos(panel:GetWide() - 22, 2)
  panel.btnClose:SetSize(18, 18)
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
    self:DrawGenericBackground(4, 0, w - 8, h - 8, ColorAlpha(self.colTab, 220))
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
  local color = theme.get_color('accent')

  draw.blur_panel(panel)

  surface.SetDrawColor(Color(10, 10, 10, 150))
  surface.DrawRect(0, 0, w, h)

  draw.textured_rect(theme.get_material('gradient'), 0, 0, w, 24, ColorAlpha(color, 200))
end

function THEME.skin:PaintCollapsibleCategory(panel, w, h)
  panel.Header:SetFont(theme.get_font('text_smaller'))

  if h < 21 then
    self:DrawGenericBackground(0, 0, w, 21, Color(0, 0, 0))
  else
    self:DrawGenericBackground(0, 0, w, 21, Color(30, 30, 30))
  end
end
