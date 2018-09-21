local PANEL = {}
PANEL.id = 'base'
PANEL.text = 'Click sidebar buttons to open character creation menus.'

function PANEL:Init() end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    theme.Hook('PaintCharCreationBasePanel', self, w, h)
  end
end

vgui.Register('flCharCreationBase', PANEL, 'fl_base_panel')

local PANEL = {}
PANEL.id = 'general'
PANEL.text = 'char_create.general'

function PANEL:Init()
  local scrW, scrH = ScrW(), ScrH()

  self.gender_label = vgui.Create('DLabel', self)
  self.gender_label:SetPos(4, font.Scale(36) + 6)
  self.gender_label:SetText(t'char_create.gender')
  self.gender_label:SetFont(theme.GetFont('text_small'))
  self.gender_label:SetTextColor(Color('white'))
  self.gender_label:SizeToContents()

  self.gender_male = vgui.Create('fl_image_button', self)
  self.gender_male:SetPos(self.gender_label:GetWide() + 8, font.Scale(36) + 4)
  self.gender_male:SetSize(24, 24)
  self.gender_male:SetDrawBackground(false)
  self.gender_male:SetImage('icon16/user.png')
  self.gender_male.DoClick = function(btn)
    if !btn:IsActive() then
      surface.PlaySound('buttons/blip1.wav')

      if self.gender_female:IsActive() then
        self.gender_female:SetActive(false)
      end

      self:GetParent().char_data.gender = 'Male'
      self:RebuildModels()

      btn:SetActive(true)
    end
  end

  self.gender_female = vgui.Create('fl_image_button', self)
  self.gender_female:SetPos(self.gender_label:GetWide() + self.gender_male:GetWide() + 12, font.Scale(36) + 4)
  self.gender_female:SetSize(24, 24)
  self.gender_female:SetDrawBackground(false)
  self.gender_female:SetImage('icon16/user_female.png')
  self.gender_female.DoClick = function(btn)
    if !btn:IsActive() then
      surface.PlaySound('buttons/blip1.wav')

      if self.gender_male:IsActive() then
        self.gender_male:SetActive(false)
      end

      self:GetParent().char_data.gender = 'Female'
      self:RebuildModels()

      btn:SetActive(true)
    end
  end

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetPos(4, font.Scale(72) + 2)
  self.name_label:SetText(t'char_create.name')
  self.name_label:SetFont(theme.GetFont('text_small'))
  self.name_label:SetTextColor(Color('white'))
  self.name_label:SizeToContents()

  self.name_entry = vgui.Create('DTextEntry', self)
  self.name_entry:SetPos(self.name_label:GetWide() + 8, font.Scale(72))
  self.name_entry:SetSize(scrW / 8, 24)
  self.name_entry:SetFont(theme.GetFont('text_smaller'))
  self.name_entry:SetText('')

  self.name_random = vgui.Create('DImageButton', self)
  self.name_random:SetPos(self.name_label:GetWide() + self.name_entry:GetWide() + 16, font.Scale(72) + 2)
  self.name_random:SetSize(16, 16)
  self.name_random:SetImage('icon16/wand.png')
  self.name_random:SetTooltip('char_create.random_name')
  self.name_random.DoClick = function(btn)
    surface.PlaySound('buttons/blip1.wav')

    self.name_entry:SetText(Schema:get_random_name(self:GetParent().char_data))
  end

  self.desc_label = vgui.Create('DLabel', self)
  self.desc_label:SetPos(4, font.Scale(108) + 2)
  self.desc_label:SetText(t'char_create.desc')
  self.desc_label:SetFont(theme.GetFont('text_small'))
  self.desc_label:SetTextColor(Color('white'))
  self.desc_label:SizeToContents()

  self.desc_entry = vgui.Create('DTextEntry', self)
  self.desc_entry:SetPos(self.desc_label:GetWide() + 8, font.Scale(108))
  self.desc_entry:SetSize(scrW / 4 - self.desc_label:GetWide() - 4, font.Scale(72))
  self.desc_entry:SetFont(theme.GetFont('text_smaller'))
  self.desc_entry:SetText('')
  self.desc_entry:SetMultiline(true)
  self.desc_entry:SetVerticalScrollbarEnabled(true)

  self.models_list = vgui.Create('fl_sidebar', self)
  self.models_list:SetPos(4, font.Scale(180) + 4)
  self.models_list:SetSize(scrW / 4, 136)
  self.models_list:SetVisible(false)
  self.models_list.Paint = function() end

  self.model = vgui.Create('DModelPanel', self)
  self.model:SetPos(scrW / 4 + 32, 32)
  self.model:SetSize(scrW / 4, scrH / 2 - 36)
  self.model:SetFOV(50)
  self.model:SetCamPos(Vector(80, 0, 50))
  self.model:SetLookAt(Vector(0, 0, 37))
  self.model:SetAnimated(true)
  self.model.LayoutEntity = function(entity) end
end

function PANEL:RebuildModels()
  local char_data = self:GetParent().char_data
  local factionTable = faction.find_by_id(char_data.faction)
  local models

  if char_data.gender == 'Male' then
    models = factionTable.models.male
  elseif char_data.gender == 'Female' then
    models = factionTable.models.female
  else
    models = factionTable.models.universal
  end

  local i = 0
  local offset = 4

  if self.models_list.buttons then
    for k, v in ipairs(self.models_list.buttons) do
      v:Remove()
    end
  end

  self.models_list:SetVisible(true)
  self.models_list.buttons = {}

  if !table.HasValue(models, self.models_list.model) then
    self.models_list.model = nil
    self:GetParent().char_data.model = nil
  end

  self.model:SetModel(self.models_list.model or '')

  for k, v in ipairs(models) do
    if i >= 7 then
      offset = offset + 68
      i = 0
    end

    local button = vgui.Create('SpawnIcon', self.models_list)
    button:SetSize(64, 64)
    button:SetModel(v)
    button:SetPos(i * 68 + 4, offset)
    button.DoClick = function(btn)
      if IsValid(self.models_list.prevBtn) then
        self.models_list.prevBtn.isActive = false
      end

      self.models_list.model = v
      self:GetParent().char_data.model = v
      self.model:SetModel(v)
      self.model.Entity:SetSequence(ACT_IDLE)

      btn.isActive = true

      self.models_list.prevBtn = btn
    end

    if self.models_list.model == v then
      button.isActive = true

      self.models_list.prevBtn = button
    end

    button.Paint = function(btn, w, h)
      btn.OverlayFade = math.Clamp((btn.OverlayFade or 0) - RealFrameTime() * 640 * 2, 0, 255)

      if dragndrop.IsDragging() or (!btn:IsHovered() and !btn.isActive) then return end

      btn.OverlayFade = math.Clamp(btn.OverlayFade + RealFrameTime() * 640 * 8, 0, 255)
    end

    self.models_list.buttons[#self.models_list.buttons + 1] = button

    i = i + 1
  end
end

function PANEL:OnOpen(parent)
  self.name_entry:SetText(parent.char_data.name or '')
  self.desc_entry:SetText(parent.char_data.description or '')
  self.models_list.model = parent.char_data.model

  if parent.char_data.gender == 'Female' then
    self.gender_female:SetActive(true)

    self:RebuildModels()
  elseif parent.char_data.gender == 'Male' then
    self.gender_male:SetActive(true)

    self:RebuildModels()
  end
end

function PANEL:OnClose(parent)
  local gender = (self.gender_female:IsActive() and 'Female') or (self.gender_male:IsActive() and 'Male') or 'Universal'

  parent:CollectData({
    name = self.name_entry:GetValue(),
    description = self.desc_entry:GetValue(),
    gender = gender,
    model = self.models_list.model
  })
end

function PANEL:OnValidate()
  local name = self.name_entry:GetValue()
  local desc = self.desc_entry:GetValue()

  if self.name_entry:IsVisible() then
    if !isstring(name) then
      return false, t'char_create.name_invalid'
    end

    if name:utf8len() < config.get('character_min_name_len')
    or name:utf8len() > config.get('character_max_name_len') then
      return false, t('char_create.name_len', {config.get('character_min_name_len'), config.get('character_max_name_len')})
    end
  end

  if self.desc_entry:IsVisible() then
    if !isstring(desc) then
      return false, t'char_create.desc_invalid'
    end

    if desc:utf8len() < config.get('character_min_desc_len')
      or desc:utf8len() > config.get('character_max_desc_len') then
      return false, t('char_create.desc_len', {config.get('character_min_desc_len'), config.get('character_max_desc_len')})
    end
  end

  if self.models_list:IsVisible() then
    if !self.models_list.model then
      return false, t'char_create.no_model'
    end
  end
end

vgui.Register('fl_character_general', PANEL, 'flCharCreationBase')
