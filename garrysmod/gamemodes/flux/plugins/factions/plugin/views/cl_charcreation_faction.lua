local PANEL = {}
PANEL.id = 'faction'
PANEL.text = 'CharCreation_Faction'
PANEL.faction_id = ''

function PANEL:ButtonClicked(button)
  self.faction_id = button.faction.faction_id
end

function PANEL:OnOpen(parent)
  self.faction_id = parent.char_data.faction or ''

  self.chooser = vgui.Create('fl_horizontalbar', self)
  self.chooser:SetSize(self:GetWide(), self:GetTall() / 8 * 7 - 8)
  self.chooser:SetPos(0, self:GetTall() / 8 + 8)
  self.chooser:SetOverlap(4)

  for k, v in pairs(faction.GetAll()) do
    if !v.whitelisted or fl.client:HasWhitelist(v.faction_id) then
      local button = vgui.Create('fl_image_button')
      button:SetSize(self.chooser:GetWide() / 3, self.chooser:GetTall())
      button:SetImage(v.material)
      button.faction = v

      if v.faction_id == self.faction_id then
        button:SetActive(true)
        self.prevBtn = button
      end

      local label = vgui.Create('DLabel', button)
      label:Dock(BOTTOM)
      label:DockMargin(4, 0, 0, 0)
      label:SetText(v.name)
      label:SetFont(theme.GetFont('text_normal_large'))
      label:SizeToContents()

      button.DoClick = function(btn)
        if button:IsActive() then return end

        local cur_time = CurTime()

        if !self.chooser.next_click or self.chooser.next_click <= cur_time then
          if v.menu_sound then
            surface.PlaySound('buttons/blip1.wav')
            surface.PlaySound(table.Random(v.menu_sound))
          end

          btn:SetActive(true)

          if IsValid(self.prevBtn) and self.prevBtn != btn then
            self.prevBtn:SetActive(false)
          end

          self.prevBtn = btn

          self:ButtonClicked(btn)

          self.chooser.next_click = cur_time + 2
        end
      end

      self.chooser:AddPanel(button)
    end
  end

  self.chooser:SetVisible(true)
end

function PANEL:OnClose(parent)
  parent:CollectData({
    faction = self.faction_id
  })
end

function PANEL:OnValidate()
  if self.faction_id == '' then
    return false, t('char_create.no_faction')
  end

  local faction = faction.find_by_id(self.faction_id)

  if faction.whitelisted and !fl.client:HasWhitelist(self.faction_id) then
    return false, t('char_create.no_whitelist')
  end
end

vgui.Register('flCharCreationFaction', PANEL, 'flCharCreationBase')
