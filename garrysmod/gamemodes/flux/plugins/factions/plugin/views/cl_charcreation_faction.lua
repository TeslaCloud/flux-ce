local PANEL = {}
PANEL.id = "faction"
PANEL.text = t('char_create.fac.s')
PANEL.factionID = ""

function PANEL:Init()
  self:OnOpen(self:GetParent())

  self.Label = vgui.Create("DLabel", self)
  self.Label:SetPos(32, 64)
  self.Label:SetText(t('char_create.fac_title'))
  self.Label:SetFont(theme.GetFont("Text_Small"))

  self.Chooser = vgui.Create("fl_sidebar", self)
  self.Chooser:SetPos(32, 90)
  self.Chooser:SetSize(500, ScrH() - 290)
  self.Chooser:AddSpace(2)

  for k, v in pairs(faction.GetAll()) do
    if !v.whitelisted or fl.client:HasWhitelist(v.id) then
      local button = vgui.Create("fl_image_button", self)
      button:SetSize(496, 142)
      button:SetPos(0, 0)
      button:SetImage(v.material)
      button.faction = v

      if v.faction_id == self.factionID then
        button:SetActive(true)
        self.prevBtn = button
      end

      local label = vgui.Create("DLabel", button)
      label:Dock(BOTTOM)
      label:SetText(v.name)
      label:SetFont(theme.GetFont("Text_Large"))
      label:SizeToContents()

      button.DoClick = function(btn)
        btn:SetActive(true)

        if IsValid(self.prevBtn) and self.prevBtn != btn then
          self.prevBtn:SetActive(false)
        end

        self.prevBtn = btn

        self:ButtonClicked(btn)
      end

      self.Chooser:AddPanel(button, true)
    end
  end

  self.Chooser:SetVisible(true)
end

function PANEL:ButtonClicked(button)
  self.factionID = button.faction.faction_id
end

function PANEL:OnOpen(parent)
  self.factionID = parent.CharData.faction or ""
end

function PANEL:OnClose(parent)
  parent:CollectData({
    faction = self.factionID
  })
end

vgui.Register("flCharCreationFaction", PANEL, "flCharCreationBase")
