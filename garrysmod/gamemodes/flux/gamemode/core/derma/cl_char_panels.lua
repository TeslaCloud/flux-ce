--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.uniqueID = "base"
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
PANEL.uniqueID = "general"
PANEL.text = "General Character Info"

function PANEL:Init()
	local w, h = self:GetSize()

	local factionTable
	local charData = self:GetParent().CharData

	if (charData and charData.faction) then
		factionTable = faction.FindByID(charData.faction)
	end

	self.NameLabel = vgui.Create("DLabel", self)
	self.NameLabel:SetPos(32, 68)
	self.NameLabel:SetText("Name:")
	self.NameLabel:SetFont(theme.GetFont("Text_Small"))

	self.NameEntry = vgui.Create("DTextEntry", self)
	self.NameEntry:SetPos(32 + self.NameLabel:GetWide(), 66)
	self.NameEntry:SetSize(300, 24)
	self.NameEntry:SetFont(theme.GetFont("Text_Smaller"))
	self.NameEntry:SetText("")

	self.DescLabel = vgui.Create("DLabel", self)
	self.DescLabel:SetPos(32, 96)
	self.DescLabel:SetText("Description:")
	self.DescLabel:SetFont(theme.GetFont("Text_Small"))
	self.DescLabel:SizeToContents()

	self.DescEntry = vgui.Create("DTextEntry", self)
	self.DescEntry:SetPos(32, 98 + self.DescLabel:GetTall())
	self.DescEntry:SetSize(300 + self.NameLabel:GetWide(), 400)
	self.DescEntry:SetFont(theme.GetFont("Text_Smaller"))
	self.DescEntry:SetText("")
	self.DescEntry:SetMultiline(true)

	self.GenderLabel = vgui.Create("DLabel", self)
	self.GenderLabel:SetPos(64 + self.DescEntry:GetWide(), 64 - self.NameLabel:GetTall())
	self.GenderLabel:SetText("Gender:")
	self.GenderLabel:SetFont(theme.GetFont("Text_Small"))

	self.GenderChooser = vgui.Create("DComboBox", self)
	self.GenderChooser:SetPos(64 + self.DescEntry:GetWide(), 66)
	self.GenderChooser:SetSize(100, 20)
	self.GenderChooser:SetValue("select gender")
	self.GenderChooser:AddChoice("Male")
	self.GenderChooser:AddChoice("Female")

	if (factionTable and !factionTable.HasName) then
		self.NameLabel:SetVisible(false)
		self.NameEntry:SetVisible(false)

		self.DescLabel:SetPos(32, 64 - self.NameLabel:GetTall())
		self.DescEntry:SetPos(32, 66)
	end

	if (factionTable and !factionTable.HasDescription) then
		self.DescLabel:SetVisible(false)
		self.DescEntry:SetVisible(false)
	end

	if (factionTable and !factionTable.HasGender) then
		self.GenderLabel:SetVisible(false)
		self.GenderChooser:SetVisible(false)
	end
end

function PANEL:OnOpen(parent)
	self.NameEntry:SetText(parent.CharData.name or "")
	self.DescEntry:SetText(parent.CharData.description or "")
	self.GenderChooser:SetValue(parent.CharData.gender or "select gender")
end

function PANEL:OnClose(parent)
	parent:CollectData({
		name = self.NameEntry:GetValue(),
		description = self.DescEntry:GetValue(),
		gender = self.GenderChooser:GetValue()
	})
end

vgui.Register("flCharCreationGeneral", PANEL, "flCharCreationBase")

local PANEL = {}
PANEL.uniqueID = "model"
PANEL.text = "Select a model"
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

	for k, v in ipairs(self.Models) do
		if (i >= 8) then offset = offset + 68; i = 0; end

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
	if (!parent.CharData.faction or parent.CharData.faction == "" or parent.CharData.gender == "select gender" or parent.CharData.gender == "") then
		self.Label:SetText("You have to select a faction and a gender first!")
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
				self.Models = factionTable.Models.male
			elseif (charData.gender == "Female") then
				self.Models = factionTable.Models.female
			else
				self.Models = factionTable.Models.universal
			end

			self:Rebuild()
		end
	end
end

function PANEL:OnClose(parent)
	parent.CharData.model = self.model
end

vgui.Register("flCharCreationModel", PANEL, "flCharCreationBase")

local PANEL = {}
PANEL.uniqueID = "faction"
PANEL.text = "Select a faction"
PANEL.factionID = ""

function PANEL:Init()
	self:OnOpen(self:GetParent())

	self.Label = vgui.Create("DLabel", self)
	self.Label:SetPos(32, 64)
	self.Label:SetText("Faction:")
	self.Label:SetFont(theme.GetFont("Text_Small"))

	self.Chooser = vgui.Create("flSidebar", self)
	self.Chooser:SetPos(32, 90)
	self.Chooser:SetSize(500, ScrH() - 290)
	self.Chooser:AddSpace(2)

	for k, v in pairs(faction.GetAll()) do
		if (!v.Whitelisted or fl.client:HasWhitelist(v.uniqueID)) then
			local button = vgui.Create("flImageButton", self)
			button:SetSize(496, 142)
			button:SetPos(0, 0)
			button:SetImage(v.Material)
			button.faction = v

			if (v.uniqueID == self.factionID) then
				button:SetActive(true)
				self.prevBtn = button
			end

			button.DoClick = function(btn)
				btn:SetActive(true)

				if (IsValid(self.prevBtn) and self.prevBtn != btn) then
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
	self.factionID = button.faction.uniqueID
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