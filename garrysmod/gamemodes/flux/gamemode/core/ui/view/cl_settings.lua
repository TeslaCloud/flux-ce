--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local PANEL = {}

local colorWhite = Color(255, 255, 255, 255)
local colorBlack = Color(0, 0, 0, 200)

local outlineSize = 0.5
local expandDuration = 0.15

local menuFont = "menu_thin"
local menuFontSmall = "menu_thin_small"

function PANEL:Init()
  local scrW, scrH = ScrW(), ScrH()

  self:SetSize(scrW * 0.6, scrH * 0.6)

  self.elementCallbacks = {}

  self.elementCallbacks["DCheckBox"] = function(panel, parent, setting)
    local boxSize = parent:GetTall() * 0.4

    panel:SetSize(boxSize, boxSize)
    panel:SetPos(parent:GetWide() * 0.99 - panel:GetWide(), parent:GetTall() * 0.5 - panel:GetTall() * 0.5)
    panel:SetConVar("FL_"..setting.id)

    function panel:Paint(w, h)
      local curTime = CurTime()
      if (self:IsHovered() and !self.hovered) then
        self.lerpTime = curTime
        self.hovered = true
      elseif (!self:IsHovered() and self.hovered) then
        self.lerpTime = curTime
        self.hovered = false
      end

      if (self.lerpTime) then
        local fraction = (curTime - self.lerpTime) / expandDuration

        if (self.hovered) then
          self.textAlpha = Lerp(fraction, colorWhite.a, 170)
        else
          self.textAlpha = Lerp(fraction, 170, colorWhite.a)
        end
      end

      draw.RoundedBox(5, 0, 0, w, h, ColorAlpha(fl.settings:GetColor("TextColor"), self.textAlpha))

      if (self:GetChecked() and self.checked) then
        self.checkTime = curTime
        self.checked = false
      elseif (!self:GetChecked() and !self.checked) then
        self.checkTime = curTime
        self.checked = true
      end

      if (self.checkTime) then
        local fraction = (curTime - self.checkTime) / expandDuration

        if (self.checked) then
          self.iconAlpha = Lerp(fraction, colorBlack.a, 0)
          self.size = Lerp(fraction, h * 0.95, 0)
        else
          self.iconAlpha = Lerp(fraction, 0, colorBlack.a)
          self.size = Lerp(fraction, 0, h * 0.95)
        end
      end

      fl.fa:Draw("fa-check", w * 0.5, h * 0.5, self.size or h * 0.95, ColorAlpha(colorBlack, self.iconAlpha or colorBlack.a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
  end

  self.elementCallbacks["DComboBox"] = function(panel, parent, setting)
    panel:SetSize(parent:GetWide() * 0.98, parent:GetTall() * 0.6)
    panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25)

    parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall())

    if (istable(setting.info)) then
      for k, v in pairs(setting.info) do
        panel:AddChoice(v, k)
      end
    end

    function panel:OnSelect(index, value, data)
      if (data) then
        value = data
      end

      fl.settings:SetValue(setting.id, value)
    end

    panel:SetConVar("FL_"..setting.id)
  end

  self.elementCallbacks["DTextEntry"] = function(panel, parent, setting)
    panel:SetSize(parent:GetWide() * 0.98, parent:GetTall() * 0.6)
    panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25)
    panel:SetConVar("FL_"..setting.id)
    panel:SetFont(theme.GetFont("Menu_Tiny"))
    panel:SetTextColor(fl.settings:GetColor("TextColor"))
    panel:SetDrawBackground(false)
    panel.oldThink = panel.Think

    panel.Think = function(entry)
      entry:SetTextColor(fl.settings:GetColor("TextColor"))
      entry:oldThink()
    end

    local back = vgui.Create("EditablePanel", parent)
    back:SetPos(panel.x, panel.y)
    back:SetSize(panel:GetWide(), panel:GetTall())
    back:MoveToBefore(panel)

    function back:Paint(w, h)
      surface.SetDrawColor(colorBlack)
      surface.DrawRect(0, 0, w, h)
    end

    parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall())
  end

  self.elementCallbacks["DColorMixer"] = function(panel, parent, setting)
    panel:SetSize(parent:GetWide() * 0.98, ScrH() * 0.23)
    panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25)
    panel:SetConVarR("FL_"..setting.id.."_R")
    panel:SetConVarG("FL_"..setting.id.."_G")
    panel:SetConVarB("FL_"..setting.id.."_B")
    panel:SetConVarA("FL_"..setting.id.."_A")

    parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall())
  end

  self.elementCallbacks["DNumSlider"] = function(panel, parent, setting)
    local w, h = parent:GetWide(), parent:GetTall()
    local offset = w * 0.77
    local decimals = 0

    if (setting.info) then
      if (setting.info.min) then
        panel:SetMin(setting.info.min)
      end

      if (setting.info.max) then
        panel:SetMax(setting.info.max)
      end

      if (setting.info.decimals) then
        panel:SetDecimals(setting.info.decimals)
      end

      if (setting.info.decimals) then
        decimals = setting.info.decimals
      end
    end

    panel:SetSize(w + offset, h * 0.8)
    panel:SetPos(w - panel:GetWide() * 0.98, parent.label.y + parent.label:GetTall() * 1.25)
    panel:SetConVar("FL_"..setting.id)
    panel:SetText("")

    panel.Slider.Paint = function(slider, w, h)
      local num = slider:GetNotches()

      surface.SetDrawColor(fl.settings:GetColor("TextColor"))
      surface.DrawRect(8, h * 0.5 - 1, w - 15, 1)

      if (!num) then return end

      local x, y = 8, h * 0.5 - 1
      local space = w / num

      for i = 0, num do
        surface.DrawRect(x + i * space, y + 4, 1, 5)
      end
    end

    panel.TextArea.Paint = function(label, w, h)
    end

    parent.numLabel = vgui.Create("DTextEntry", parent)
    parent.numLabel:SetFont("menu_thin_smaller")
    parent.numLabel:SetText(panel:GetValue())
    parent.numLabel:SetTextColor(fl.settings:GetColor("TextColor"))
    parent.numLabel:SizeToContents()
    parent.numLabel:SetPos(parent:GetWide() * 0.01, panel.y + panel:GetTall() * 1.1)
    parent.numLabel:SetSize(parent:GetWide(), parent.numLabel:GetTall())
    parent.numLabel:SetConVar("FL_"..setting.id)
    parent.numLabel:SetDrawBackground(false)

    parent:SetSize(w, h + parent.label:GetTall() * 0.1 + panel:GetTall() * 1.1 + parent.numLabel:GetTall())
  end

  hook.Run("AdjustSettingCallbacks", self.elementCallbacks)

  self.categoryList = vgui.Create("DScrollPanel", self)
  self.categoryList:SetSize(self:GetWide() * 0.2, self:GetTall())
  self.categoryList:SetPos(0, self:GetTall() * 0.5 - self.categoryList:GetTall() * 0.5)
  self.categoryList.Paint = function(panel, w, h)
    surface.SetDrawColor(fl.settings:GetColor("MenuBackColor"))
    surface.DrawRect(0, 0, w, h)
  end

  self.settingList = vgui.Create("DScrollPanel", self)
  self.settingList:SetSize(self:GetWide() - self.categoryList:GetWide() * 1.05, self:GetTall())
  self.settingList:SetPos(
    self.categoryList.x + self.categoryList:GetWide() * 1.05,
    self:GetTall() * 0.5 - self.settingList:GetTall() * 0.5
  )

  self.settingList.Paint = function(panel, w, h)
    surface.SetDrawColor(fl.settings:GetColor("MenuBackColor"))
    surface.DrawRect(0, 0, w, h)
  end

  self:BuildCategoryList()
end

function PANEL:BuildList()
  local oldList = self.settingList

  if (oldList) then
    oldList:AlphaTo(0, expandDuration, nil, nil, function(animData, panel)
      panel:Remove()
    end)
  end

  self.settingList = vgui.Create("DScrollPanel", self)
  self.settingList:SetSize(self:GetWide() - self.categoryList:GetWide() * 1.05, self:GetTall())
  self.settingList:SetPos(
    self.categoryList.x + self.categoryList:GetWide() * 1.05,
    self:GetTall() * 0.5 - self.settingList:GetTall() * 0.5
  )
  self.settingList.Paint = function(panel, w, h)
    surface.SetDrawColor(fl.settings:GetColor("MenuBackColor"))
    surface.DrawRect(0, 0, w, h)
  end
  self.settingList:SetAlpha(0)
  self.settingList:AlphaTo(255, expandDuration)

  local setList = self.settingList
  local x = setList:GetWide() * 0.01
  local y = x
  local w, h = setList:GetWide() * 0.98, setList:GetTall() * 0.09
  local settings = fl.settings:GetCategorySettings(self.activeCategory)

  setList:Clear()

  table.sort(settings, function(a, b)
    return L("#Settings_"..a.id) < L("#Settings_"..b.id)
  end)

  for k, v in ipairs(settings) do
    local elementCallback = self.elementCallbacks[v.type]

    if ((!v.callback or v.callback()) and isfunction(elementCallback)) then
      local setting = vgui.Create("EditablePanel", setList)

      setting:SetPos(x, y)
      setting:SetSize(w, h)

      setting.label = vgui.Create("DLabel", setting)
      setting.label:SetFont(menuFontSmall)
      setting.label:SetText("#Settings_"..v.id)
      setting.label:SetTextColor(fl.settings:GetColor("TextColor"))
      setting.label:SizeToContents()
      setting.label:SetPos(setting:GetWide() * 0.01, setting:GetTall() * 0.5 - setting.label:GetTall() * 0.5)

      function setting:Paint(w, h)
        surface.SetDrawColor(colorBlack)
        surface.DrawRect(0, 0, w, h)

        self.label:SetTextColor(fl.settings:GetColor("TextColor"))
      end

      setting.element = vgui.Create(v.type, setting)

      elementCallback(setting.element, setting, v)

      y = y + setting:GetTall() + setList:GetWide() * 0.01
    end
  end
end

function PANEL:BuildCategoryList()
  local catList = self.categoryList
  local x = 0
  local y = x
  local w, h = catList:GetWide(), catList:GetTall() * 0.09
  local categories = fl.settings:GetIndexedCategories(function(a, b)
    return L("#Settings_"..a.id) < L("#Settings_"..b.id)
  end)
  local saved = fl.settings.lastCat

  for k, v in ipairs(categories) do
    local sum = 0

    for k, v in pairs(v.settings) do
      if (!v.callback or v.callback()) then
        sum = sum + 1
      end
    end

    -- If there are no available settings, skip the category.
    if (sum == 0) then
      if (v.id == saved) then
        saved = nil
      end

      table.remove(categories, k)
    end
  end

  for k, v in ipairs(categories) do
    surface.SetFont(menuFont)

    local name = L("#Settings_"..v.id)
    local textW, textH = surface.GetTextSize(name)

    textW = textW + (w * 0.25)

    if (textW > w) then
      catList:SetSize(textW, catList:GetTall())

      local setList = self.settingList

      setList:SetSize(self:GetWide() - catList:GetWide() * 1.05, self:GetTall())
      setList:SetPos(
        catList.x + catList:GetWide() * 1.05,
        self:GetTall() * 0.5 - setList:GetTall() * 0.5
      )

      w = catList:GetWide()
    end

    local button = vgui.Create("DButton", catList)

    button:SetPos(x, y)
    button:SetSize(w, h)
    button.text = name
    button.textAlpha = colorWhite.a
    button:SetText("")
    button.id = v.id

    button.DoClick = function(panel)
      self.activeCategory = panel.id
      self:BuildList()
    end

    function button:Paint(w, h)
      if (self.text) then
        local curTime = CurTime()

        if (self:IsHovered() and !self.hovered) then
          self.lerpTime = curTime
          self.hovered = true
        elseif (!self:IsHovered() and self.hovered) then
          self.lerpTime = curTime
          self.hovered = false
        end

        local textColor = fl.settings:GetColor("TextColor")

        if (self.lerpTime) then
          local fraction = (curTime - self.lerpTime) / expandDuration

          if (self.hovered) then
            self.textAlpha = Lerp(fraction, textColor.a, 170)
          else
            self.textAlpha = Lerp(fraction, 170, textColor.a)
          end
        end

        local alpha = self.textAlpha

        if (self:GetParent():GetParent():GetParent().activeCategory == self.id) then
          alpha = 170
        end

        --Otherwise things like 'y' or 'g' get cut off.
        DisableClipping(true)
          draw.SimpleTextOutlined(self.text, menuFont, w * 0.1, h * 0.5, ColorAlpha(textColor, alpha), TEXT_ALIGN_LEFT, nil, outlineSize, ColorAlpha(colorBlack, alpha))
        DisableClipping(false)
      end
    end

    y = y + h * 1.1
  end

  if (saved) then
    self.activeCategory = saved
    fl.settings.lastCat = nil
  else
    self.activeCategory = categories[1].id
  end

  self:BuildList()
end

function PANEL:OnRemove()
  fl.settings.lastCat = self.activeCategory
end

function PANEL:Paint(w, h) end

derma.DefineControl("flSettings", "", PANEL, "EditablePanel")
