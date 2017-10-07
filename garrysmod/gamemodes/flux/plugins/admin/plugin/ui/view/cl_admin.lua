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
	local headerSize = theme.GetOption("Frame_HeaderSize")

	self:SetTitle("Admin")
	self:SetSize(width, height)
	self:SetPos(scrW / 2 - width * 0.5, scrH / 2 - height * 0.5)

	self.sidebar = vgui.Create("flSidebar", self)
	self.sidebar:SetSize(width / 5, height - headerSize)
	self.sidebar:SetPos(0, headerSize)

	hook.Run("AddAdminMenuItems", self, self.sidebar)
end

function PANEL:PaintOver(w, h)
	theme.Call("AdminPanelPaintOver", self, w, h)
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

		local scrW, scrH = ScrW(), ScrH()
		local sW, sH = self.sidebar:GetWide(), self.sidebar:GetTall()
		local headerSize = theme.GetOption("Frame_HeaderSize")

		self.curPanel = theme.CreatePanel(panel.uniqueID, self, unpack(panel.arguments))
		self.curPanel:SetPos(sW, headerSize)
		self.curPanel:SetSize(self:GetWide() - sW, self:GetTall() - headerSize)

		if (self.curPanel.OnOpened) then
			self.curPanel:OnOpened(self, panel)
		end
	end
end

function PANEL:SetFullscreen(bFullscreen)
	local headerSize = theme.GetOption("Frame_HeaderSize")

	if (bFullscreen) then
		self.sidebar:MoveTo(-self.sidebar:GetWide(), headerSize, 0.3)
		self:SetTitle("")

		self.backBtn = vgui.Create("DButton", self)
		self.backBtn:SetPos(0, 0)
		self.backBtn:SetSize(100, headerSize)
		self.backBtn:SetText("")

		self.backBtn.Paint = function(btn, w, h)
			local font = fl.fonts:GetSize(theme.GetFont("Text_Small"), 16)
			local fontSize = util.GetFontSize(font)

			fl.fa:Draw("fa-chevron-left", 6, 5, 14, Color(255, 255, 255))
			draw.SimpleText("Go Back", font, 24, 3 * (16 / fontSize), Color(255, 255, 255))
		end

		self.backBtn.DoClick = function(btn)
			self:SetFullscreen(false)
		end
	else
		self.sidebar:MoveTo(0, headerSize, 0.3)
		self:SetTitle("Admin")

		self.backBtn:SafeRemove()
	end
end

vgui.Register("flAdminPanel", PANEL, "flFrame")

concommand.Add("fl_admin_test", function()
	local panel = vgui.Create("flAdminPanel")
	panel:MakePopup()
end)