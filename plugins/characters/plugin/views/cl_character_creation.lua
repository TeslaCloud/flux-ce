--- The character creation screen (`fl_char_create`), a fullscreen frame that takes the player
-- through a list of stages and then asks the server to create the character.
-- A stage is the ID of a theme panel, added with `add_stage` from the
-- AddCharacterCreationMenuStages hook. A stage panel may define on_open(parent),
-- on_close(parent) and on_validate(); it hands over what the player has entered with
-- `collect_data`, and the collected char_data is what is sent to the server.

local PANEL = {}
PANEL.char_data = {}

--- Builds the character creation screen: collects the stages from the
-- AddCharacterCreationMenuStages hook, opens the first one and creates the navigation.
function PANEL:Init()
  local fa_icon_size = math.scale(16)

  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())

  self.button_close:safe_remove()

  self.stage = 1
  self.stages = {}

  --- Lets plugins add their stages to the character creation screen. Called on the client each
  -- time the screen is created, before its first stage is opened.
  -- @param panel [Panel the fl_char_create panel; call its add_stage method with the ID of a
  --   theme panel]
  hook.Run('AddCharacterCreationMenuStages', self)

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

--- Draws the panel through the theme's PaintCharCreationMainPanel hook.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharCreationMainPanel', self, w, h)
  end
end

do
  local color_black_transparent = Color(0, 0, 0, 200)

  --- Draws a dark overlay with a spinner, and a warning once the wait gets long, while a
  -- character creation request is pending.
  -- @param w [Number]
  -- @param h [Number]
  -- @return [Boolean true while a request is pending, otherwise nil]
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

--- Recreates the stage buttons at the bottom and highlights the current stage.
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

--- Steps forward or backward one stage at a time until the given stage is reached.
-- @param stage [Number stage index]
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

--- Opens the panel of a stage and updates the stage buttons and the back and next titles.
-- @param stage [Number stage index]
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

--- Validates the current stage and moves on to the next one. On the last stage it asks for
-- confirmation and sends the character creation request to the server.
-- Does nothing while the server has not responded to a creation request that was already sent.
-- @return [Boolean false when validation failed or a request is pending, otherwise nil]
function PANEL:next_stage()
  if self.request_sent then return false end

  if self.panel and self.panel.on_validate then
    local success, error = self.panel:on_validate()

    if success == false then
      self:GetParent():notify(error or t'ui.char_create.unknown_error')

      return false
    end
  end

  --- Lets plugins keep the player on the current stage of character creation. Called on the
  -- client when the screen is about to move on from a stage (on the last stage, before the
  -- player is asked to confirm), after the on_validate method of the stage panel has passed.
  -- @param id [String ID of the current stage]
  -- @param panel [Panel the panel of that stage]
  -- @return [Boolean return false to stay on the stage, String error text to show; a generic
  --   error is shown when it is omitted]
  local success, error = hook.Run('PreStageChange', self.stages[self.stage], self.panel)

  if success == false then
    self:GetParent():notify(error or t'ui.char_create.unknown_error')

    return false
  end

  if self.stage != #self.stages then
    self:set_stage(self.stage + 1)
  else
    if self.panel.on_close then
      self.panel:on_close(self)
    end

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

              timer.Simple(Theme.get_option('menu_anim_duration') * #self.stages, function()
                --- Called on the client shortly after the local player has created a character
                -- that is their only one, 1.5 seconds before that character is loaded
                -- automatically.
                -- @param char [Map networked data of the new character]
                hook.Run('FirstCharacterCreated', chars[1])

                timer.Simple(1.5, function()
                  Cable.send('fl_player_select_character', chars[1].id)
                end)
              end)
            end
          else
            local status = response.status
            local text = t'ui.char_create.unknown_error'
            --- Lets plugins supply the text shown when the server has refused to create a
            -- character. Called on the client.
            -- @param success [Boolean always false here]
            -- @param status [Number the CHAR_ERR_* code the server answered with]
            -- @return [String translated error text; when nothing is returned the menu uses
            --   its own text for the codes of the Characters plugin]
            local hook_text = hook.Run('GetCharCreationErrorText', response.success, status)

            if hook_text then
              text = hook_text
            elseif status == CHAR_ERR_NAME then
              text = t('ui.char_create.name_len', {
                min = Config.get('character_min_name_len'),
                max = Config.get('character_max_name_len')
              })
            elseif status == CHAR_ERR_DESC then
              text = t('ui.char_create.desc_len', {
                min = Config.get('character_min_desc_len'),
                max = Config.get('character_max_desc_len')
              })
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

--- Goes back one stage, or to the main menu from the first stage.
function PANEL:prev_stage()
  if self.stage != 1 then
    self:set_stage(self.stage - 1)
  else
    self:GetParent():to_main_menu()
  end
end

--- Removes the panel, then calls the callback.
-- @param callback=nil [Function called without arguments]
function PANEL:close(callback)
  self:safe_remove()

  if callback then
    callback()
  end
end

--- Merges the data of a stage into the collected character data.
-- @param new_data [Map]
function PANEL:collect_data(new_data)
  table.safe_merge(self.char_data, new_data)
end

--- Empties the collected character data.
function PANEL:clear_data()
  table.Empty(self.char_data)
end

--- Slides the current stage panel out, then creates the theme panel with the given ID and
-- slides it in. Runs the 'CharPanelCreated' hook with the ID and the new panel afterward.
-- @param id [String ID of one of the added stages]
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

  --- Called on the client after the character creation screen has opened the panel of a stage
  -- and run its on_open method. Lets plugins adjust the stage panels of other plugins.
  -- @param id [String ID of the stage, as it was passed to add_stage]
  -- @param panel [Panel the panel created for the stage]
  hook.Run('CharPanelCreated', id, self.panel)
end

--- Adds a stage to character creation.
-- @param id [String theme panel ID of the stage, also used as its title phrase]
-- @param index=nil [Number position to insert the stage at; added last when omitted]
function PANEL:add_stage(id, index)
  if index then
    table.insert(self.stages, index, id)
  else
    table.insert(self.stages, id)
  end
end

vgui.Register('fl_char_create', PANEL, 'fl_frame')
