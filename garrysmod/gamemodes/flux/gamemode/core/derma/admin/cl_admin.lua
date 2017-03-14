--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.curPanel = nil
PANEL.panels = {}

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()
	local width, height = scrW / 2, scrH / 2

	self:SetTitle("Admin")
	self:SetSize(width, height)
	self:SetPos(scrW / 2 - width / 2, scrH / 2 - height / 2)

	self.sidebar = vgui.Create("flSidebar", self)
	self.sidebar:SetSize(width / 4, height)

	hook.Run("AddAdminMenuItems", self, self.sidebar)
end

function PANEL:AddPanel(id, title, permission, ...)
	self.panels[id] = {
		uniqueID = id,
		title = title,
		permission = permission,
		arguments = {...}
	}

	self.sidebar:AddButton(title, function(btn)
		self:OpenPanel(id)
	end)
end

function PANEL:RemovePanel(id)
	self.panels[id] = nil
end

function PANEL:OpenPanel(id)
	local panel = self.panels[id]

	if (istable(panel)) then
		if (panel.permission and !fl.client:HasPermission(panel.permission)) then return end

		self.curPanel = theme.CreatePanel(panel.uniqueID, self, unpack(panel.arguments))

		if (self.curPanel.OnOpened) then
			self.curPanel:OnOpened(self, panel)
		end
	end
end

vgui.Register("flAdminPanel", PANEL, "flFrame")



concommand.Add("fl_admin_test", function()
	local panel = vgui.Create("flAdminPanel")
	panel:MakePopup()
end)