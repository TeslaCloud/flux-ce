-- Create the default theme that other themes will derive from.
THEME.author = 'TeslaCloud Studios'
THEME.id = 'factory'
THEME.description = 'Factory theme. This is a fail-safety theme that other themes use as a base.'
THEME.should_reload = true

function THEME:OnLoaded()
  local scrW, scrH = ScrW(), ScrH()

  self:SetOption('Frame_HeaderSize', 24)
  self:SetOption('Frame_LineWeight', 2)
  self:SetOption('MainMenu_SidebarWidth', 300)
  self:SetOption('MainMenu_SidebarHeight', scrH)
  self:SetOption('MainMenu_SidebarX', 0)
  self:SetOption('MainMenu_SidebarY', 0)
  self:SetOption('MainMenu_SidebarMargin', -1)
  self:SetOption('MainMenu_SidebarLogo', 'flux/flux_icon.png')
  self:SetOption('MainMenu_SidebarLogoSpace', scrH / 3)
  self:SetOption('MainMenu_SidebarButtonHeight', font.Scale(42)) -- We can cheat and scale buttons the same way we scale fonts!
  self:SetOption('MainMenu_SidebarButtonOffsetX', 16)
  self:SetOption('MainMenu_SidebarButtonCentered', false)
  self:SetOption('MainMenu_LogoHeight', 100)
  self:SetOption('MainMenu_LogoWidth', 110)
  self:SetOption('Button_Click_Success', 'garrysmod/ui_click.wav')
  self:SetOption('Button_Click_Fail', 'buttons/button8.wav')
  self:SetOption('MenuMusic', '')

  local accentColor     = self:SetColor('Accent', Color(90, 90, 190))
  local mainColor     = self:SetColor('Main', Color(50, 50, 50))
  local outlineColor     = self:SetColor('Outline', Color(65, 65, 65))
  local backgroundColor   = self:SetColor('Background', Color(20, 20, 20))
  local textColor     = self:SetColor('Text', util.text_color_from_base(backgroundColor))

  self:SetColor('AccentDark', accentColor:darken(20))
  self:SetColor('AccentLight', accentColor:lighten(20))
  self:SetColor('MainDark', mainColor:darken(15))
  self:SetColor('MainLight', mainColor:lighten(15))
  self:SetColor('BackgroundDark', backgroundColor:darken(20))
  self:SetColor('BackgroundLight', backgroundColor:lighten(20))
  self:SetColor('SchemaText', textColor)
  self:SetColor('MainMenu_Background', self:GetColor('BackgroundDark'))

  self:SetColor('ESP_Red', Color(255, 0, 0))
  self:SetColor('ESP_Blue', Color(0, 0, 255))
  self:SetColor('ESP_Grey', Color(100, 100, 100))

  self:SetFont('MainFont', 'flRoboto', font.Scale(16))
  self:SetFont('MainFontCondensed', 'flRobotoCondensed', font.Scale(16))
  self:SetFont('MenuTitles', 'flRoboto', font.Scale(14))
  self:SetFont('Menu_Tiny', 'flRobotoLt', font.Scale(16))
  self:SetFont('Menu_Small', 'flRobotoLt', font.Scale(20))
  self:SetFont('Menu_Normal', self:GetFont('MainFontCondensed'), font.Scale(24), {weight = 500})
  self:SetFont('Menu_Large', self:GetFont('MainFontCondensed'), font.Scale(30), {weight = 500})
  self:SetFont('Menu_Larger', self:GetFont('MainFontCondensed'), font.Scale(42), {weight = 500})
  self:SetFont('Tooltip_Small', self:GetFont('MainFontCondensed'), font.Scale(16))
  self:SetFont('Tooltip_Large', self:GetFont('MainFontCondensed'), font.Scale(26))
  self:SetFont('Text_Largest', self:GetFont('MainFont'), font.Scale(90))
  self:SetFont('Text_Larger', self:GetFont('MainFont'), font.Scale(60))
  self:SetFont('Text_Large', self:GetFont('MainFont'), font.Scale(48))
  self:SetFont('Text_NormalLarge', self:GetFont('MainFont'), font.Scale(36))
  self:SetFont('Text_NormalBig', self:GetFont('MainFont'), font.Scale(29))
  self:SetFont('Text_Normal', self:GetFont('MainFont'), font.Scale(23))
  self:SetFont('Text_NormalSmaller', self:GetFont('MainFont'), font.Scale(20))
  self:SetFont('Text_Small', self:GetFont('MainFont'), font.Scale(18))
  self:SetFont('Text_Smaller', self:GetFont('MainFont'), font.Scale(16))
  self:SetFont('Text_Smallest', self:GetFont('MainFont'), font.Scale(14))
  self:SetFont('Text_Bar', self:GetFont('MainFont'), font.Scale(17), {weight = 600})
  self:SetFont('Text_Tiny', self:GetFont('MainFont'), font.Scale(11))
  self:SetFont('Text_3D2D', self:GetFont('MainFont'), 256)

  -- Set from schema theme.
  -- self:SetMaterial('Schema_Logo', 'materials/flux/hl2rp/logo.png')

  self:AddPanel('TabMenu', function(id, parent, ...)
    return vgui.Create('fl_tab_menu', parent)
  end)

  self:AddPanel('Admin_PermissionsEditor', function(id, parent, ...)
    return vgui.Create('permissionsEditor', parent)
  end)
end

function THEME:CreateMainMenu(panel) end

function THEME:PaintFrame(panel, width, height)
  local title = panel:GetTitle()
  local accentColor = panel:GetAccentColor()
  local headerSize = self:GetOption('Frame_HeaderSize')
  local lineWeight = self:GetOption('Frame_LineWeight')

  surface.SetDrawColor(accentColor)
  surface.DrawRect(0, 0, width, headerSize)

  surface.SetDrawColor(accentColor:darken(30))
  surface.DrawRect(0, headerSize - lineWeight, width, lineWeight)

  surface.SetDrawColor(self:GetColor('MainDark'))
  surface.DrawRect(0, headerSize, width, height - headerSize)

  if title then
    local font = font.GetSize(self:GetFont('Text_Small'), 16)
    local fontSize = util.font_size(font)

    draw.SimpleText(title, font, 6, 3 * (16 / fontSize), panel:GetTextColor())
  end
end

function THEME:PaintMainMenu(panel, width, height)
  local wide = self:GetOption('MainMenu_SidebarWidth') * 0.5
  local title, desc, author = Schema:get_name(), Schema:get_description(), t('main_menu.developed_by', Schema:get_author())
  local logo = self:GetMaterial('Schema_Logo')
  local titleW, titleH = util.text_size(title, self:GetFont('Text_Largest'))
  local descW, descH = util.text_size(desc, self:GetFont('Menu_Normal'))
  local authorW, authorH = util.text_size(author, self:GetFont('Menu_Normal'))

  surface.SetDrawColor(self:GetColor('MainMenu_Background'))
  surface.DrawRect(0, 0, width, width)

  surface.SetDrawColor(self:GetColor('MainMenu_Background'):lighten(40))
  surface.DrawRect(0, 0, width, 128)

  if !logo then
    draw.SimpleText(title, self:GetFont('Text_Largest'), wide + width * 0.5 - titleW * 0.5, 150, self:GetColor('SchemaText'))
  else
    draw.textured_rect(logo, width * 0.5 - 200, 16, 400, 96, Color(255, 255, 255))
  end

  draw.SimpleText(desc, self:GetFont('Menu_Normal'), 16, 128 - descH - 8, self:GetColor('SchemaText'))
  draw.SimpleText(author, self:GetFont('Menu_Normal'), width - authorW - 16, 128 - authorH - 8, self:GetColor('SchemaText'))
end

function THEME:PaintButton(panel, w, h)
  local curAmt = panel.m_CurAmt
  local textColor = panel.m_TextColorOverride or self:GetColor('Text'):darken(curAmt)
  local title = panel.m_Title
  local font = panel.m_Font
  local icon = panel.m_Icon
  local left = panel.m_IconLeft

  if panel.m_DrawBackground then
    if !panel.m_Active then
      surface.SetDrawColor(self:GetColor('Outline'))
      surface.DrawRect(0, 0, w, h)

      surface.SetDrawColor(self:GetColor('Main'):lighten(curAmt))
      surface.DrawRect(1, 1, w - 2, h - 2)
    else
      surface.SetDrawColor(self:GetColor('Outline'))
      surface.DrawRect(0, 0, w, h)

      surface.SetDrawColor(self:GetColor('MainDark'))
      surface.DrawRect(1, 1, w - 1, h - 2)
    end
  else
    if curAmt > 0 then
      surface.SetDrawColor(Color(150, 150, 150, curAmt))
      surface.DrawRect(1, 1, w - 2, h - 2)
    end
  end

  if icon then
    if !panel.m_Centered then
      if panel.m_IconLeft then
        fl.fa:Draw(icon, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), textColor)
      else
        fl.fa:Draw(icon, w - panel.m_IconSize - 8, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), textColor)
      end
    end
  end

  if title and title != '' then
    local width, height = util.text_size(title, font)

    if panel.m_Autopos then
      if icon then
        if panel.m_Centered then
          local textPos = (w - width - panel.m_IconSize) / 2

          if panel.m_IconLeft then
            fl.fa:Draw(icon, textPos - panel.m_IconSize - 8, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), textColor)
          else
            fl.fa:Draw(icon, textPos + width + panel.m_IconSize * 0.5 + 8, (panel.m_IconSize and h * 0.5 - panel.m_IconSize * 0.5) or 3, (panel.m_IconSize or h - 6), textColor)
          end

          draw.SimpleText(title, font, textPos, h * 0.5 - height * 0.5, textColor)
        else
          draw.SimpleText(title, font, h + 8, h * 0.5 - height * 0.5, textColor)
        end
      else
        draw.SimpleText(title, font, w * 0.5 - width * 0.5, h * 0.5 - height * 0.5, textColor)
      end
    else
      if panel.m_Centered then
        draw.SimpleText(title, font, (w - width) / 2, h * 0.5 - height * 0.5, textColor)
      else
        draw.SimpleText(title, font, panel.m_TextPos or 0, h * 0.5 - height * 0.5, textColor)
      end
    end
  end
end

function THEME:PaintDeathScreen(curTime, scrW, scrH)
  local respawnTimeRemaining = fl.client:get_nv('respawn_time', 0) - curTime
  local barValue = 100 - 100 * (respawnTimeRemaining / config.get('respawn_delay'))
  local font = self:GetFont('Text_NormalLarge')
  local color_white = Color(255, 255, 255)

  if !fl.client.respawnAlpha then fl.client.respawnAlpha = 0 end

  fl.client.respawnAlpha = math.Clamp(fl.client.respawnAlpha + 1, 0, 200)

  draw.RoundedBox(0, 0, 0, scrW, scrH, Color(0, 0, 0, fl.client.respawnAlpha))

  draw.SimpleText(t'player_message.died', font, 16, 16, color_white)
  draw.SimpleText(t('player_message.respawn', math.ceil(respawnTimeRemaining)), font, 16, 16 + util.font_size(font), color_white)

  draw.RoundedBox(0, 0, 0, scrW / 100 * barValue, 2, color_white)

  if respawnTimeRemaining <= 3 then
    fl.client.whiteAlpha = math.Clamp(255 * (1.5 - respawnTimeRemaining * 0.5), 0, 255)
  else
    fl.client.whiteAlpha = 0
  end
end

function THEME:PaintSidebar(panel, width, height)
  draw.RoundedBox(0, 0, 0, width, height, self:GetColor('MainDark'):lighten(10))
end

function THEME:DrawBarBackground(barInfo)
  draw.RoundedBox(barInfo.cornerRadius, barInfo.x, barInfo.y, barInfo.width, barInfo.height, self:GetColor('MainDark'))
end

function THEME:DrawBarHindrance(barInfo)
  local length = barInfo.width * (barInfo.hinderValue / barInfo.maxValue)

  draw.RoundedBox(barInfo.cornerRadius, barInfo.x + barInfo.width - length - 1, barInfo.y + 1, length, barInfo.height - 2, barInfo.hinderColor)
end

function THEME:DrawBarFill(barInfo)
  if barInfo.realFillWidth < barInfo.fillWidth then
    draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or barInfo.width) - 2, barInfo.height - 2, barInfo.color)
    draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, barInfo.realFillWidth - 2, barInfo.height - 2, Color(230, 230, 230))
  elseif barInfo.realFillWidth > barInfo.fillWidth then
    draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, barInfo.realFillWidth - 2, barInfo.height - 2, barInfo.color)
    draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or barInfo.width) - 2, barInfo.height - 2, Color(230, 230, 230))
  else
    draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or barInfo.width) - 2, barInfo.height - 2, Color(230, 230, 230))
  end
end

function THEME:DrawBarTexts(barInfo)
  local font = theme.GetFont(barInfo.font)

  render.SetScissorRect(barInfo.x + 1, barInfo.y + 1, barInfo.x + barInfo.realFillWidth, barInfo.y + barInfo.height, true)
    draw.SimpleText(barInfo.text, font, barInfo.x + 8, barInfo.y + barInfo.textOffset, self:GetColor('MainDark'))
  render.SetScissorRect(0, 0, 0, 0, false)

  render.SetScissorRect(barInfo.x + barInfo.realFillWidth, barInfo.y + 1, barInfo.x + barInfo.width, barInfo.y + barInfo.height, true)
    draw.SimpleText(barInfo.text, font, barInfo.x + 8, barInfo.y + barInfo.textOffset, self:GetColor('Text'))
  render.SetScissorRect(0, 0, 0, 0, false)

  if barInfo.hinderDisplay and barInfo.hinderDisplay <= barInfo.hinderValue then
    local width = barInfo.width
    local textWide = util.text_size(barInfo.hinderText, font)
    local length = width * (barInfo.hinderValue / barInfo.maxValue)

    render.SetScissorRect(barInfo.x + width - length, barInfo.y, barInfo.x + width, barInfo.y + barInfo.height, true)
      draw.SimpleText(barInfo.hinderText, font, barInfo.x + width - textWide - 8, barInfo.y + barInfo.textOffset, Color(255, 255, 255))
    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

function THEME:AdminPanelPaintOver(panel, width, height)
  local smallestFont = font.GetSize(self:GetFont('Text_Smallest'), 14)
  local textColor = self:GetColor('Text')
  local versionString = 'Admin Mod Version: v0.2.0 (indev)'

  DisableClipping(true)
    draw.RoundedBox(0, 0, height, width, 16, self:GetColor('Background'))

    draw.SimpleText(fl.client:SteamName()..' ('..fl.client:GetUserGroup()..')', smallestFont, 6, height + 1, textColor)

    local w, h = util.text_size(versionString, smallestFont)

    draw.SimpleText(versionString, smallestFont, width - w - 6, height + 1, textColor)
  DisableClipping(false)
end

function THEME:PaintPermissionButton(permPanel, btn, w, h)
  local color = Color(255, 255, 255)
  local title = ''
  local permType = btn.permValue
  local font = self:GetFont('Text_Small')

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

  local textColor = color:darken(75)

  if btn:IsHovered() then
    color = color:lighten(30)
  end

  draw.RoundedBox(0, 0, 0, w, h, textColor)
  draw.RoundedBox(0, 1, 1, w - 2, h - 1, color)

  local tW, tH = util.text_size(title, font)

  draw.SimpleText(title, font, w * 0.5 - tW * 0.5, 2, textColor)

  local sqrSize = h * 0.5

  draw.RoundedBox(0, sqrSize * 0.5, sqrSize * 0.5, sqrSize, sqrSize, Color(255, 255, 255))

  if btn.isSelected then
    draw.RoundedBox(0, sqrSize * 0.5 + 2, sqrSize * 0.5 + 2, sqrSize - 4, sqrSize - 4, Color(0, 0, 0))
  end
end

function THEME:PaintScoreboard(panel, width, height)
  local titleFont = self:GetFont('Menu_Large')

  draw.RoundedBox(0, 0, 0, width, height, ColorAlpha(self:GetColor('Background'), 150))

  local title = t'scoreboard.title'

  DisableClipping(true)
    draw.SimpleText(title, titleFont, 4, -util.text_height(title, titleFont) * 0.5, self:GetColor('Text'))
  DisableClipping(false)

  draw.SimpleText(t'scoreboard.help', self:GetFont('Text_Small'), 4, 14, self:GetColor('Text'))
end

function THEME:PaintTabMenu(panel, width, height)
  local fraction = FrameTime() * 8
  local activePanel = panel.activePanel
  local sidebarColor = ColorAlpha(self:GetColor('Background'), 125)

  panel.curAlpha = Lerp(fraction, panel.curAlpha or 0, 200)

  draw.RoundedBox(0, 0, 0, width, height, Color(0, 0, 0, panel.curAlpha))
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

    draw.RoundedBox(0, 0, panel.posY, 6, targetH, self:GetColor('AccentLight'))
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
  local textColor = Color(255, 255, 255, 255)

  if panel:IsSelected() then
    color = Color(255, 255, 255, 255)
    textColor = Color(0, 0, 0, 255)
  elseif panel.Hovered then
    color = Color(100, 100, 100, 255)
  elseif panel.m_bAlt then
    color = Color(75, 75, 75, 255)
  end

  for k, v in pairs(panel.Columns) do
    v:SetTextColor(textColor)
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
  local textColor = Color(255, 255, 255, 255)

  if panel.m_bBackground and panel.Hovered then
    local color = nil

    if panel.Depressed then
      color = Color(225, 225, 225, 255)
    else
      color = Color(255, 255, 255, 255)
    end

    surface.SetDrawColor(color.r, color.g, color.b, color.a)
    surface.DrawRect(0, 0, w, h)

    textColor = Color(0, 0, 0, 255)
  end

  panel:SetFGColor(textColor)
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
  local textColor = Color(255, 255, 255, 255)

  if panel.m_bBackground then
    local color = Color(40, 40, 40, 255)
    local borderColor = Color(0, 0, 0, 255)

    if panel:GetDisabled() then
      color = self.controlColorDark
    elseif panel.Depressed then
      color = Color(255, 255, 255, 255)
      textColor = Color(0, 0, 0, 255)
    elseif panel.Hovered then
      color = self.controlColorHighlight
    end

    self:DrawGenericBackground(0, 0, w, h, borderColor)
    self:DrawGenericBackground(1, 1, w - 2, h - 2, color)
  end

  panel:SetFGColor(textColor)
end

-- Called when a scroll bar grip is painted.
function THEME.skin:PaintScrollBarGrip(panel)
  local w, h = panel:GetSize()
  local color = Color(255, 255, 255, 255)

  self:DrawGenericBackground(0, 0, w, h, color)
  self:DrawGenericBackground(1, 1, w - 2, h - 2, Color(0, 0, 0, 255))
end

function THEME.skin:PaintFrame(panel, w, h)
  local color = theme.GetColor('Accent')

  surface.SetDrawColor(Color(10, 10, 10))
  surface.DrawRect(0, 24, w, h)

  surface.SetDrawColor(Color(40, 40, 40))
  surface.DrawRect(1, 0, w - 2, h - 1)

  surface.SetDrawColor(color:darken(20))
  surface.DrawRect(0, 0, w, 24)
end

function THEME.skin:PaintCollapsibleCategory(panel, w, h)
  panel.Header:SetFont(theme.GetFont('Text_Smaller'))

  if h < 21 then
    self:DrawGenericBackground(0, 0, w, 21, Color(0, 0, 0))
  else
    self:DrawGenericBackground(0, 0, w, 21, Color(30, 30, 30))
  end
end
