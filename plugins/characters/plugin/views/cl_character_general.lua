local PANEL = {}
PANEL.id = 'base'
PANEL.text = 'Click sidebar buttons to open character creation menus.'

function PANEL:Init() end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharCreationBasePanel', self, w, h)
  end
end

vgui.Register('fl_character_creation_base', PANEL, 'fl_base_panel')

local PANEL = {}
PANEL.id = 'general'
PANEL.text = 'ui.char_create.general'

function PANEL:Init()
  local fa_icon_size = math.scale(24)
  local margin = math.scale(20)
  local scrw, scrh = ScrW(), ScrH()
  local faction_table = Factions.find_by_id(self:GetParent().char_data.faction)

  self.gender_label = vgui.Create('DLabel', self)
  self.gender_label:SetText(t'ui.char_create.gender')
  self.gender_label:SetFont(Theme.get_font('main_menu_normal'))
  self.gender_label:SetTextColor(Color('white'))
  self.gender_label:SizeToContents()
  self.gender_label:SetPos(scrw * 0.125 - self.gender_label:GetWide() - 4, math.scale(36) + 6)

  self.gender_male = vgui.Create('fl_button', self)
  self.gender_male:SetPos(scrw * 0.125 + 8, math.scale(36) + 4)
  self.gender_male:SetSize(fa_icon_size, fa_icon_size)
  self.gender_male:SetDrawBackground(false)
  self.gender_male:set_icon('fa-mars')
  self.gender_male:set_icon_size(fa_icon_size, fa_icon_size)
  self.gender_male.DoClick = function(btn)
    if !btn:is_active() then
      surface.PlaySound('buttons/blip1.wav')

      if self.gender_female:is_active() then
        self.gender_female:set_active(false)
        self.gender_female:set_text_color(Theme.get_color('text'))
      end

      self:GetParent().char_data.gender = 'male'
      self:rebuild_models()

      btn:set_active(true)
      btn:set_text_color(Color('blue'):lighten(40))
    end
  end

  self.gender_female = vgui.Create('fl_button', self)
  self.gender_female:SetPos(scrw * 0.125 + self.gender_male:GetWide() + margin, math.scale(36) + 4)
  self.gender_female:SetSize(fa_icon_size, fa_icon_size)
  self.gender_female:SetDrawBackground(false)
  self.gender_female:set_icon('fa-venus')
  self.gender_female:set_icon_size(fa_icon_size, fa_icon_size)
  self.gender_female.DoClick = function(btn)
    if !btn:is_active() then
      surface.PlaySound('buttons/blip1.wav')

      if self.gender_male:is_active() then
        self.gender_male:set_active(false)
        self.gender_male:set_text_color(Theme.get_color('text'))
      end

      self:GetParent().char_data.gender = 'female'
      self:rebuild_models()

      btn:set_active(true)
      btn:set_text_color(Color('red'):lighten(40))
    end
  end

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetText(t'ui.char_create.name')
  self.name_label:SetFont(Theme.get_font('main_menu_normal'))
  self.name_label:SetTextColor(Color('white'))
  self.name_label:SizeToContents()
  self.name_label:SetPos(scrw * 0.125 - self.name_label:GetWide() - 4, math.scale(72) + 2)

  self.name_entry = vgui.Create('DTextEntry', self)
  self.name_entry:SetPos(scrw * 0.125 + 4, math.scale(72))
  self.name_entry:SetSize(scrw * 0.125, fa_icon_size)
  self.name_entry:SetFont(Theme.get_font('main_menu_normal'))
  self.name_entry:SetText('')

  if SCHEMA.get_random_name then
    self.name_random = vgui.Create('fl_button', self)
    self.name_random:SetPos(scrw * 0.125 + self.name_entry:GetWide() + 8, math.scale(72.5))
    self.name_random:SetSize(fa_icon_size, fa_icon_size)
    self.name_random:set_icon('fa-random')
    self.name_random:set_icon_size(fa_icon_size, fa_icon_size)
    self.name_random:SetTooltip(t'ui.char_create.random_name')
    self.name_random:SetDrawBackground(false)
    self.name_random.DoClick = function(btn)
      surface.PlaySound('buttons/blip1.wav')

      self.name_entry:SetText(SCHEMA:get_random_name(self:GetParent().char_data.gender))
    end
  end

  self.desc_label = vgui.Create('DLabel', self)
  self.desc_label:SetText(t'ui.char_create.desc')
  self.desc_label:SetFont(Theme.get_font('main_menu_normal'))
  self.desc_label:SetTextColor(Color('white'))
  self.desc_label:SizeToContents()
  self.desc_label:SetPos(scrw * 0.125 - self.desc_label:GetWide() - 4, math.scale(108) + 2)

  self.desc_entry = vgui.Create('DTextEntry', self)
  self.desc_entry:SetPos(scrw * 0.125 + 4, math.scale(108))
  self.desc_entry:SetSize(scrw * 0.125, math.scale(72))
  self.desc_entry:SetFont(Theme.get_font('main_menu_normal'))
  self.desc_entry:SetText('')
  self.desc_entry:SetMultiline(true)
  self.desc_entry:SetVerticalScrollbarEnabled(true)

  self.models_list = vgui.Create('fl_sidebar', self)
  self.models_list:SetPos(4, math.scale(180) + 4)
  self.models_list:SetSize(scrw * 0.25, 136)
  self.models_list:SetVisible(false)
  self.models_list.Paint = function() end

  self.model = vgui.Create('DModelPanel', self)
  self.model:SetPos(scrw * 0.25 + 32, 32)
  self.model:SetSize(scrw * 0.25, scrh * 0.5 - 36)
  self.model:SetFOV(50)
  self.model:SetCamPos(Vector(80, 0, 50))
  self.model:SetLookAt(Vector(0, 0, 37))
  self.model:SetAnimated(true)
  self.model.LayoutEntity = function(entity) end
  self.model.angles = Angle(0, 0, 0)

  self.model.DragMousePress = function(pnl)
    pnl.press_x, pnl.press_y = gui.MousePos()
    pnl.pressed = true
  end

  self.model.DragMouseRelease = function(pnl)
    pnl.pressed = false
  end

  self.model.LayoutEntity = function(pnl, ent)
    if pnl.pressed then
      local mx, my = gui.MousePos()

      pnl.angles = pnl.angles - Angle(0, (pnl.press_x or mx) - mx, 0)
      pnl.press_x, pnl.press_y = mx, my
    end

    ent:SetAngles(pnl.angles)
  end
  self.skin = vgui.Create('fl_counter', self)
  self.skin:SetSize(32, 64)
  self.skin:SetPos(scrw * 0.25 + 48, 48)
  self.skin:set_text(t'ui.char_create.skin')
  self.skin:set_font(Theme.get_font('tooltip_small'))
  self.skin:set_value(1)
  self.skin:SetVisible(false)
  self.skin:set_min(1)
  self.skin.on_click = function(panel, value)
    surface.PlaySound('buttons/blip1.wav')

    self.model.Entity:SetSkin(value - 1)
  end

  if !faction_table.has_gender then
    self.gender_label:SetVisible(false)
    self.gender_female:SetVisible(false)
    self.gender_male:SetVisible(false)

    self:GetParent().char_data.gender = 'universal'
    self:rebuild_models()
  end

  if !faction_table.has_description then
    self.desc_label:SetVisible(false)
    self.desc_entry:SetVisible(false)
  end

  if !faction_table.has_name then
    self.name_label:SetVisible(false)
    self.name_entry:SetVisible(false)
    if self.name_random then
      self.name_random:SetVisible(false)
    end
  end

end

function PANEL:rebuild_models()
  local char_data = self:GetParent().char_data
  local models = hook.run('GetCharacterCreationModels', char_data)
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
    self.skin:SetVisible(false)
    self:GetParent().char_data.model = nil
    self:GetParent().char_data.skin = 0
  end

  local model = self.models_list.model

  if model then
    self.model:SetModel(model)
    self.model:GetEntity():SetSequence(self.model:GetEntity():get_idle_anim())
  end

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
      if IsValid(self.models_list.prev_btn) then
        self.models_list.prev_btn.is_active = false
      end

      self.models_list.model = v
      self:GetParent().char_data.model = v
      self.model:SetModel(v)
      self.model:GetEntity():SetSequence(self.model:GetEntity():get_idle_anim())

      local skins = self.model.Entity:SkinCount()

      if skins > 1 then
        self.skin:set_max(skins)
        self.skin:set_value(1)
        self.skin:SetVisible(true)
      else
        self.skin:SetVisible(false)
      end

      btn.is_active = true

      self.models_list.prev_btn = btn
    end

    if self.models_list.model == v then
      button.is_active = true

      self.models_list.prev_btn = button
    end

    button.Paint = function(btn, w, h)
      btn.OverlayFade = math.Clamp((btn.OverlayFade or 0) - RealFrameTime() * 640 * 2, 0, 255)

      if dragndrop.IsDragging() or (!btn:IsHovered() and !btn.is_active) then return end

      btn.OverlayFade = math.Clamp(btn.OverlayFade + RealFrameTime() * 640 * 8, 0, 255)
    end

    self.models_list.buttons[#self.models_list.buttons + 1] = button

    i = i + 1
  end
end

function PANEL:on_open(parent)
  self.name_entry:SetText(parent.char_data.name or '')
  self.desc_entry:SetText(parent.char_data.description or '')
  self.models_list.model = parent.char_data.model

  if parent.char_data.gender == 'female' then
    self.gender_female:set_active(true)
    self.gender_female:set_text_color(Color('red'):lighten(40))

    self:rebuild_models()
  elseif parent.char_data.gender == 'male' then
    self.gender_male:set_active(true)
    self.gender_male:set_text_color(Color('blue'):lighten(40))

    self:rebuild_models()
  end

  local skin = parent.char_data.skin

  if IsValid(self.model.Entity) then
    self.model.Entity:SetSkin(skin)

    if skin then
      self.skin:SetVisible(true)
      self.skin:set_max(self.model.Entity:SkinCount())
      self.skin:set_value(skin + 1)
    end
  end
end

function PANEL:on_close(parent)
  local gender = (self.gender_female:is_active() and 'female') or (self.gender_male:is_active() and 'male') or 'universal'

  parent:collect_data({
    name = self.name_entry:GetValue(),
    description = self.desc_entry:GetValue(),
    gender = gender,
    model = self.models_list.model,
    skin = self.skin:get_value() - 1
  })
end

function PANEL:on_validate()
  local name = self.name_entry:GetValue()
  local desc = self.desc_entry:GetValue()

  if self.name_entry:IsVisible() then
    if !isstring(name) then
      return false, t'ui.char_create.name_invalid'
    end

    if utf8.len(name) < Config.get('character_min_name_len') or
    utf8.len(name) > Config.get('character_max_name_len') then
      return false, t('ui.char_create.name_len', { min = Config.get('character_min_name_len'), max = Config.get('character_max_name_len') })
    end
  end

  if self.desc_entry:IsVisible() then
    if !isstring(desc) then
      return false, t'ui.char_create.desc_invalid'
    end

    if utf8.len(desc) < Config.get('character_min_desc_len') or
    utf8.len(desc) > Config.get('character_max_desc_len') then
      return false, t('ui.char_create.desc_len', { min = Config.get('character_min_desc_len'), max = Config.get('character_max_desc_len') })
    end
  end

  if self.models_list:IsVisible() then
    if !self.models_list.model then
      return false, t'ui.char_create.no_model'
    end
  end
end

vgui.Register('fl_char_create_general', PANEL, 'fl_character_creation_base')
