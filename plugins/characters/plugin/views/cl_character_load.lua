local PANEL = {}
PANEL.chars = {}

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self:SetPos(0, 0)
  self:SetSize(scrw, scrh)

  self.button_close:safe_remove()

  self.list = vgui.Create('fl_horizontalbar', self)
  self.list:SetSize(scrw * 1, scrh * 0.5)
  self.list:SetPos(scrw * 0.5 - self.list:GetWide() * 0.5, scrh * 0.5 - self.list:GetTall() * 0.5)
  self.list:set_centered(true)

  self:rebuild()

  self.back = vgui.Create('fl_button', self)
  self.back:SetSize(self.list:GetWide() * 0.25, Theme.get_option('menu_sidebar_button_height'))
  self.back:SetPos(scrw * 0.5 + self.list:GetWide() * 0.5 - self.back:GetWide(), scrh * 0.5 + self.list:GetTall() * 0.5 + self.back:GetTall())
  self.back:SetFont(Theme.get_font('main_menu_normal'))
  self.back:SetTitle(t'ui.char_create.main_menu')
  self.back:SetDrawBackground(false)
  self.back:set_icon('fa-chevron-right', true)
  self.back:set_icon_size(math.scale(16))
  self.back:set_centered(true)

  self.back.DoClick = function(btn)
    surface.PlaySound(Theme.get_sound('button_click_success_sound'))

    self:GetParent():to_main_menu(true)
  end
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharCreationLoadPanel', self, w, h)
  end
end

function PANEL:rebuild()
  self.list:Clear()

  local characters = PLAYER:get_all_characters()

  for k, v in pairs(characters) do
    self.chars[k] = vgui.Create('fl_character_panel', self)
    self.chars[k]:SetSize(self.list:GetWide() * 0.125, self.list:GetTall())
    self.chars[k]:set_character(v)
    self.chars[k]:SetParent(self)

    self.list:AddPanel(self.chars[k])
  end

  if #characters == 0 then
    self.back:DoClick()
  end
end

function PANEL:close(callback)
  self:safe_remove()

  if callback then
    callback()
  end
end

vgui.Register('fl_char_load', PANEL, 'fl_frame')

local PANEL = {}

function PANEL:Init()
  self:SetPaintBackground(false)

  self.model = vgui.Create('DModelPanel', self)
  self.model:SetFOV(30)
  self.model:SetCamPos(Vector(80, 0, 50))
  self.model:SetLookAt(Vector(0, 0, 37))
  self.model:SetAnimated(true)
  self.model.LayoutEntity = function(entity) end

  self.select = vgui.Create('fl_button', self)
  self.select:SetFont(Theme.get_font('main_menu_normal'))
  self.select:SetTitle(t'ui.char_create.select')
  self.select:SetDrawBackground(false)
  self.select:set_text_color(Color('lightgreen'))
  self.select:set_icon('fa-check')
  self.select:set_icon_size(math.scale(16))
  self.select:set_centered(true)
  self.select.DoClick = function(btn)
    local cur_time = CurTime()

    if !self.next_click or self.next_click <= cur_time then
      Cable.send('fl_player_select_character', self.char_data.id)

      self.next_click = cur_time + 1
    end
  end

  self.delete = vgui.Create('fl_button', self)
  self.delete:SetFont(Theme.get_font('main_menu_normal'))
  self.delete:SetDrawBackground(false)
  self.delete:set_text_color(Color('red'))
  self.delete:set_icon('fa-trash')
  self.delete:set_icon_size(math.scale(32))
  self.delete:set_centered(true)
  self.delete.DoClick = function(btn)
    surface.PlaySound('vo/npc/male01/answer37.wav')

    Derma_StringRequest(t'ui.char_create.delete_confirm', t('ui.char_create.delete_confirm_msg', { name = self.char_data.name }), '',
    function(text)
      if text == self.char_data.name then
        Cable.send('fl_player_delete_character', self.char_data.id)

        self:SetDisabled(true)
        self.model:SetVisible(false)
        self:AlphaTo(0, Theme.get_option('menu_anim_duration'), 0, function()
          Flux.intro_panel.menu:rebuild()
        end)
      end
    end,
    nil, t'ui.char_create.delete')
  end
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharPanel', self, w, h)
  end
end

function PANEL:PerformLayout(w, h)
  self.model:SetPos(4, 28)
  self.model:SetSize(w - 4, h * .80)

  self.select:SetPos(4, h - Theme.get_option('menu_sidebar_button_height'))
  self.select:SetSize(w / 3 * 2 - 4, Theme.get_option('menu_sidebar_button_height'))

  self.delete:SetPos(w / 3 * 2, h - Theme.get_option('menu_sidebar_button_height'))
  self.delete:SetSize(w / 3 - 4, Theme.get_option('menu_sidebar_button_height'))
end

function PANEL:set_character(char_data)
  self.char_data = char_data

  self.model:SetModel(char_data.model)
  self.model:GetEntity():SetSequence(self.model:GetEntity():get_idle_anim())

  if PLAYER:get_character_id() == char_data.id then
    self.select:SetVisible(false)
    self.delete:SetVisible(false)
  end

  hook.run('PanelCharacterSet', self, char_data)
end

vgui.Register('fl_character_panel', PANEL, 'DPanel')
