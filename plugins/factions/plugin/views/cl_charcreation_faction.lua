local PANEL = {}
PANEL.id = 'faction'
PANEL.text = 'ui.char_create.faction'
PANEL.faction_id = ''

function PANEL:on_open(parent)
  self.faction_id = parent.char_data.faction or self.faction_id

  self.chooser = vgui.Create('fl_horizontalbar', self)
  self.chooser:SetSize(self:GetWide(), self:GetTall() * 0.875 - math.scale(8))
  self.chooser:SetPos(0, self:GetTall() * 0.125 + math.scale(8))
  self.chooser:SetOverlap(math.scale(4))
  self.chooser:set_centered(true)

  for k, v in pairs(Factions.all()) do
    if !v.whitelisted or PLAYER:has_whitelist(v.faction_id) then
      local button = vgui.Create('fl_image_button')
      button:SetSize(self.chooser:GetWide() * 0.33, self.chooser:GetTall())
      button:SetImage(v.material)
      button.faction = v

      if v.faction_id == self.faction_id then
        button:set_active(true)
        self.prev_button = button
      end

      local label = vgui.Create('DLabel', button)
      label:Dock(BOTTOM)
      label:DockMargin(4, 0, 0, 0)
      label:SetText(t(v.name))
      label:SetFont(Theme.get_font('text_normal_large'))
      label:SizeToContents()

      button.DoClick = function(btn)
        if button:is_active() then return end

        local cur_time = CurTime()

        if !self.chooser.next_click or self.chooser.next_click <= cur_time then
          if v.menu_sound then
            surface.PlaySound('buttons/blip1.wav')
            surface.PlaySound(table.Random(v.menu_sound))
          end

          btn:set_active(true)

          if IsValid(self.prev_button) and self.prev_button != btn then
            self.prev_button:set_active(false)
          end

          self.prev_button = btn
          self.faction_id = v.faction_id

          self.chooser.next_click = cur_time + 2
        end
      end

      self.chooser:AddPanel(button)
    end
  end

  self.chooser:SetVisible(true)
end

function PANEL:on_close(parent)
  parent:collect_data({
    faction = self.faction_id
  })
end

function PANEL:on_validate()
  if self.faction_id == '' then
    return false, t'ui.char_create.no_faction'
  end

  local faction = Factions.find_by_id(self.faction_id)

  if faction.whitelisted and !PLAYER:has_whitelist(self.faction_id) then
    return false, t'ui.char_create.no_whitelist'
  end
end

vgui.Register('fl_char_create_faction', PANEL, 'fl_character_creation_base')
