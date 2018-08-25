local PANEL = {}
PANEL.id = "base"
PANEL.text = "Click sidebar buttons to open character creation menus."

function PANEL:Init() end

function PANEL:Paint(w, h)
  theme.Hook("PaintCharCreationPanel", self, w, h)

  if (isstring(self.text)) then
    draw.SimpleText(self.text, theme.GetFont("Text_Normal"), 28, 16, theme.GetColor("Text"))
  end
end

vgui.Register("flCharCreationBase", PANEL, "flBasePanel")

local PANEL = {}
PANEL.id = "general"
PANEL.text = "#CharCreate_GenText"

function PANEL:Init()
  local w, h = self:GetSize()

  self.nameLabel = vgui.Create("DLabel", self)
  self.nameLabel:SetPos(32, 68)
  self.nameLabel:SetText("#CharCreate_Name")
  self.nameLabel:SetFont(theme.GetFont("Text_Small"))

  self.nameEntry = vgui.Create("DTextEntry", self)
  self.nameEntry:SetPos(32 + self.nameLabel:GetWide(), 66)
  self.nameEntry:SetSize(300, 24)
  self.nameEntry:SetFont(theme.GetFont("Text_Smaller"))
  self.nameEntry:SetText("")

  self.DescLabel = vgui.Create("DLabel", self)
  self.DescLabel:SetPos(32, 96)
  self.DescLabel:SetText("#CharCreate_Desc")
  self.DescLabel:SetFont(theme.GetFont("Text_Small"))
  self.DescLabel:SizeToContents()

  self.DescEntry = vgui.Create("DTextEntry", self)
  self.DescEntry:SetPos(32, 98 + self.DescLabel:GetTall())
  self.DescEntry:SetSize(ScrW() * 0.5 + self.nameLabel:GetWide(), 400)
  self.DescEntry:SetFont(theme.GetFont("Text_Smaller"))
  self.DescEntry:SetText("")
  self.DescEntry:SetMultiline(true)

  self.GenderLabel = vgui.Create("DLabel", self)
  self.GenderLabel:SetPos(self.DescEntry:GetWide() - 128, 64 - self.nameLabel:GetTall())
  self.GenderLabel:SetText("#CharCreate_Gender")
  self.GenderLabel:SetFont(theme.GetFont("Text_Small"))

  self.GenderChooser = vgui.Create("DComboBox", self)
  self.GenderChooser:SetPos(self.DescEntry:GetWide() - 128, 66)
  self.GenderChooser:SetSize(100, 20)
  self.GenderChooser:SetValue("#CharCreate_Gender_S")
  self.GenderChooser:AddChoice("#CharCreate_Gender_M")
  self.GenderChooser:AddChoice("#CharCreate_Gender_F")
end

function PANEL:OnOpen(parent)
  self.nameEntry:SetText(parent.CharData.name or "")
  self.DescEntry:SetText(parent.CharData.description or "")
  self.GenderChooser:SetValue(parent.CharData.gender or "#CharCreate_Gender_S")
end

function PANEL:OnClose(parent)
  parent:CollectData({
    name = self.nameEntry:GetValue(),
    description = self.DescEntry:GetValue(),
    gender = self.GenderChooser:GetValue()
  })
end

vgui.Register("flCharCreationGeneral", PANEL, "flCharCreationBase")

local PANEL = {}
PANEL.id = "model"
PANEL.text = "#CharCreate_Model_S"
PANEL.model = ""
PANEL.models = {}
PANEL.buttons = {}

function PANEL:Init()
  self.Label = vgui.Create("DLabel", self)
  self.Label:SetPos(32, 64)
  self.Label:SetText("")
  self.Label:SetFont(theme.GetFont("Text_Normal"))
end

function PANEL:Rebuild()
  local i = 0
  local offset = 4

  self.scrollpanel = vgui.Create("flSidebar", self)
  self.scrollpanel:SetSize(8 * 68 + 8, 68 * 5 + 8)
  self.scrollpanel:SetPos(30, 50)

  for k, v in ipairs(self.models) do
    if (i >= 8) then
      offset = offset + 68
      i = 0
    end

    self.buttons[i] = vgui.Create("SpawnIcon", self.scrollpanel)
    self.buttons[i]:SetSize(64, 64)
    self.buttons[i]:SetModel(v)
    self.buttons[i]:SetPos(i * 68 + 4, offset)
    self.buttons[i].DoClick = function(btn)
      if (IsValid(self.prevBtn)) then
        self.prevBtn.isActive = false
      end

      self.model = v
      self:GetParent().CharData.model = self.model

      btn.isActive = true
      self.prevBtn = btn
    end

    if (self.model == v) then
      self.buttons[i].isActive = true
      self.prevBtn = self.buttons[i]
    end

    self.buttons[i].Paint = function(btn, w, h)
      btn.OverlayFade = math.Clamp((btn.OverlayFade or 0) - RealFrameTime() * 640 * 2, 0, 255)

      if (dragndrop.IsDragging() or (!btn:IsHovered() and !btn.isActive)) then return end

      btn.OverlayFade = math.Clamp(btn.OverlayFade + RealFrameTime() * 640 * 8, 0, 255)
    end

    i = i + 1
  end
end

function PANEL:OnOpen(parent)
  if (!parent.CharData.faction or parent.CharData.faction == "" or parent.CharData.gender == "#CharCreate_Gender_S" or parent.CharData.gender == "") then
    self.Label:SetText("#CharCreate_GenFacWarning")
    self.Label:SetTextColor(Color(220, 100, 100))
    self.Label:SizeToContents()
  else
    local factionTable
    local charData = parent.CharData

    self.model = charData.model or ""

    if (charData and charData.faction) then
      factionTable = faction.FindByID(charData.faction)
    end

    if (factionTable) then
      if (charData.gender == "Male") then
        self.models = factionTable.models.male
      elseif (charData.gender == "Female") then
        self.models = factionTable.models.female
      else
        self.models = factionTable.models.universal
      end

      self:Rebuild()
    end
  end
end

function PANEL:OnClose(parent)
  parent.CharData.model = self.model
end

vgui.Register("flCharCreationModel", PANEL, "flCharCreationBase")
