local PANEL = {}
PANEL.char_data = {}

function PANEL:Init()
  local fa_icon_size = math.scale(16)

  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())

  self.button_close:safe_remove()

  self.stage = 1
  self.stages = {}

  hook.run('AddCharacterCreationMenuStages', self)

  self:open_panel(self.stages[1])

  local x, y = self:GetWide() * 0.25, self:GetTall() / 6 + 8

  self.back = vgui.Create('fl_button', self)
  self.back:SetSize(self.panel:GetWide() * 0.25, Theme.get_option('menu_sidebar_button_height'))
  self.back:SetPos(x, y + self.panel:GetTall() + self.back:GetTall())
  self.back:SetFont(Theme.get_font('main_menu_normal'))
  self.back:SetTitle(t'ui.char_create.main_menu')
  self.back:SetDrawBackground(false)
  self.back:set_icon('fa-chevron-left')
  self.back:set_icon_size(fa_icon_size)
  self.back:set_centered(true)

  self.back.DoClick = function(btn)
    local cur_time = CurTime()

    if !self.back.next_click or self.back.next_click < cur_time then
      surface.PlaySound(Theme.get_sound('button_click_success_sound'))

      self:prev_stage()

      self.back.next_click = cur_time + 1
    end
  end

  self.next = vgui.Create('fl_button', self)
  self.next:SetSize(self.panel:GetWide() * 0.25, Theme.get_option('menu_sidebar_button_height'))
  self.next:SetPos(x + self.panel:GetWide() - self.next:GetWide(), y + self.panel:GetTall() + self.next:GetTall())
  self.next:SetFont(Theme.get_font('main_menu_normal'))
  self.next:SetTitle(t'ui.char_create.next')
  self.next:SetDrawBackground(false)
  self.next:set_icon('fa-chevron-right', true)
  self.next:set_icon_size(fa_icon_size)
  self.next:set_centered(true)

  self.next.DoClick = function(btn)
    local cur_time = CurTime()

    if !self.next.next_click or self.next.next_click < cur_time then
      surface.PlaySound(Theme.get_sound('button_click_success_sound'))

      self:next_stage()

      self.next.next_click = cur_time + 1
    end
  end

  self.stage_list = vgui.Create('fl_horizontalbar', self)
  self.stage_list:SetSize(self.panel:GetWide(), Theme.get_option('menu_sidebar_button_height'))
  self.stage_list:SetPos(x, y + self.panel:GetTall() + self.next:GetTall() * 2)
  self.stage_list:SetOverlap(4)
  self.stage_list:set_centered(true)

  self:rebuild()
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharCreationMainPanel', self, w, h)
  end
end

do
  local color_black_transparent = Color(0, 0, 0, 200)

  function PANEL:PaintOver(w, h)
    if self.request_sent then
      local cx, cy = ScrC()
      local font = Theme.get_font('main_menu_normal')
      local diff_time = CurTime() - self.request_sent
      local text = ''

      draw.RoundedBox(0, 0, 0, w, h, color_black_transparent)

      if diff_time > 15 then
        text = t'ui.char_create.error.fatal'
      elseif diff_time > 10 then
        text = t'ui.char_create.error.critical'
      elseif diff_time > 5 then
        text = t'ui.char_create.error.lag'
      end

      local tx, ty = util.text_size(text, font)

      Flux.draw_rotating_cog(cx - 32, cy - 64, 64, 64, color_white)
      draw.SimpleText(text, font, cx - tx * 0.5, cy + 128, color_white)

      return true
    end
  end
end

function PANEL:rebuild()
  self.stage_list:Clear()

  for k, v in ipairs(self.stages) do
    local button = vgui.Create('fl_button', self.stage_list)
    button:SetSize(self.panel:GetWide() / 5, Theme.get_option('menu_sidebar_button_height'))
    button:SetFont(Theme.get_font('main_menu_normal'))
    button:SetTitle(t(v))
    button:SetDrawBackground(false)
    button:set_icon('fa-chevron-right', true)
    button:set_icon_size(math.scale(16))
    button:set_centered(true)
    button:SizeToContents()

    if k > self.stage then
      button:set_enabled(false)
    elseif k == self.stage then
      button:set_enabled(true)
      button:set_text_color(Theme.get_color('accent'))
    end

    button.DoClick = function(btn)
      if self.stage > k then
        local cur_time = CurTime()

        if !self.stage_list.next_click or self.stage_list.next_click <= cur_time then
          self:goto_stage(k)

          self.stage_list.next_click = cur_time + 1
        end
      end
    end

    self.stage_list:AddPanel(button)
  end
end

function PANEL:goto_stage(stage)
  if stage < self.stage then
    self:prev_stage()

    if self.stage != stage then
      timer.Create('flux_char_panel_change', .1, self.stage - stage, function()
        if IsValid(self) then
          self:prev_stage()
        end
      end)
    end
  elseif stage > self.stage then
    self:next_stage()

    if self.stage != stage then
      timer.Create('flux_char_panel_change', .1, stage - self.stage, function()
        if IsValid(self) then
          self:next_stage()
        end
      end)
    end
  end
end

function PANEL:set_stage(stage)
  if self.stage != stage then
    self:open_panel(self.stages[stage])
    self.stage = stage
    self:rebuild()

    if self.stage == 1 then
        self.back:SetTitle(t'ui.char_create.main_menu')
    else
        self.back:SetTitle(t'ui.char_create.back')
    end

    if self.stage == #self.stages then
        self.next:SetTitle(t'ui.char_create.create')
    else
        self.next:SetTitle(t'ui.char_create.next')
    end
  end
end

function PANEL:next_stage()
  if self.panel and self.panel.on_validate then
    local success, error = self.panel:on_validate()

    if success == false then
      self:GetParent():notify(error or t'ui.char_create.unknown_error')

      return false
    end
  end

  local success, error = hook.run('PreStageChange', self.stages[self.stage],  self.panel)

  if success == false then
    self:GetParent():notify(error or t'ui.char_create.unknown_error')

    return false
  end

  if self.stage != #self.stages then
    self:set_stage(self.stage + 1)
  else
    surface.PlaySound('vo/npc/male01/answer37.wav')

    Derma_Query(t'ui.char_create.confirm_msg', t'ui.char_create.confirm', t'ui.yes', function()
      self:request('fl_create_character', function(response)
        if IsValid(Flux.intro_panel) and IsValid(self) then
          if response.success then
            local chars = PLAYER:get_all_characters()

            self:goto_stage(0)
            self:clear_data()

            if #chars == 1 then
              Flux.intro_panel.hide_sidebar = true

              timer.simple(Theme.get_option('menu_anim_duration') * #self.stages, function()
                hook.run('FirstCharacterCreated', chars[1])

                timer.simple(1.5, function()
                  Cable.send('fl_player_select_character', chars[1].id)
                end)
              end)
            end
          else
            local status = response.status
            local text = t'ui.char_create.unknown_error'
            local hook_text = hook.run('GetCharCreationErrorText', response.success, status)

            if hook_text then
              text = hook_text
            elseif status == CHAR_ERR_NAME then
              text = t('ui.char_create.name_len', { min = Config.get('character_min_name_len'), max = Config.get('character_max_name_len') })
            elseif status == CHAR_ERR_DESC then
              text = t('ui.char_create.desc_len', { min = Config.get('character_min_desc_len'), max = Config.get('character_max_desc_len') })
            elseif status == CHAR_ERR_GENDER then
              text = t'ui.char_create.no_gender'
            elseif status == CHAR_ERR_MODEL then
              text = t'ui.char_create.no_model'
            elseif status == CHAR_ERR_RECORD then
              text = t'ui.char_create.error.record'
            end

            Flux.intro_panel:notify(text)
          end
        end

        self.request_sent = nil
      end, self.char_data)

      self.request_sent = CurTime()
    end,
    t'ui.no')
  end
end

function PANEL:prev_stage()
  if self.stage != 1 then
    self:set_stage(self.stage - 1)
  else
    self:GetParent():to_main_menu()
  end
end

function PANEL:close(callback)
  self:safe_remove()

  if callback then
    callback()
  end
end

function PANEL:collect_data(new_data)
  table.safe_merge(self.char_data, new_data)
end

function PANEL:clear_data()
  table.empty(self.char_data)
end

function PANEL:open_panel(id)
  local x, y = self:GetWide() * 0.25, self:GetTall() / 6 + 8

  if IsValid(self.panel) then
    if self.panel.on_close then
      self.panel:on_close(self)
    end

    local to = self:GetWide()

    if self.stage < table.KeyFromValue(self.stages, id) then
      to = -self.panel:GetWide()
    end

    self.panel:MoveTo(to, y, Theme.get_option('menu_anim_duration'), 0, 0.5)
  end

  self.panel = Theme.create_panel(id, self)
  self.panel:SetSize(self:GetWide() * 0.5, self:GetTall() * 0.5)

  local from

  if self.stage < table.KeyFromValue(self.stages, id) then
    from = self:GetWide()
  elseif self.stage == 1 then
    from = x
  else
    from = -self.panel:GetWide()
  end

  self.panel:SetPos(from, y)
  self.panel:MoveTo(x, y, Theme.get_option('menu_anim_duration'), 0, 0.5)

  if self.panel.on_open then
    self.panel:on_open(self)
  end

  hook.run('CharPanelCreated', id, self.panel)
end

function PANEL:add_stage(id, index)
  if index then
    table.insert(self.stages, index, id)
  else
    table.insert(self.stages, id)
  end
end

vgui.Register('fl_char_create', PANEL, 'fl_frame')
