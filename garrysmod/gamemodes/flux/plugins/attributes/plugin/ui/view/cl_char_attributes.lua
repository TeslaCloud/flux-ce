--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.uniqueID = "attributes"
PANEL.text = "#CharCreate_Attributes"
PANEL.model = ""
PANEL.models = {}
PANEL.buttons = {}

function PANEL:Init()
	self.points = 30

	self.Label = vgui.Create("DLabel", self)
	self.Label:SetPos(32, 64)
	self.Label:SetSize(128, 32)
	self.Label:SetText("Points: "..self.points)
	self.Label:SetFont(theme.GetFont("Text_Normal"))

	self.List = vgui.Create("flSidebar", self)
	self.List:SetPos(32, 100)
	self.List:SetSize(ScrW() / 3, ScrH() - 290)
	self.List:AddSpace(2)
end

function PANEL:Rebuild()

end

function PANEL:OnOpen(parent)

end

function PANEL:OnClose(parent)

end

vgui.Register("flCharCreationAttributes", PANEL, "flCharCreationBase")