--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.menuItems = {}
PANEL.buttons = {}
PANEL.activePanel = nil

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()

	self:SetPos(0, 0)
	self:SetSize(scrW, scrH)

	local curX, curY = hook.Run("AdjustMenuItemPositions", self)
	curX = curX or 42
	curY = curY or 200

	self.closeButton = vgui.Create("flButton", self)
	self.closeButton:SetFont(theme.GetFont("Menu_Large"))
	self.closeButton:SetText(string.utf8upper(fl.lang:TranslateText("#TabMenu_CloseMenu")))
	self.closeButton:SetPos(6, curY)
	self.closeButton:SetSizeEx(200, 38)
	self.closeButton:SetDrawBackground(false)
	self.closeButton:SetTextAutoposition(true)
	self.closeButton.DoClick = function(btn)
		surface.PlaySound("garrysmod/ui_click.wav")
		self:SetVisible(false)
		self:Remove()
	end

	curY = curY + font.Scale(52)

	self.menuItems = {}

	hook.Run("AddTabMenuItems", self)

	for k, v in ipairs(self.menuItems) do
		local button = vgui.Create("flButton", self)
		button:SetDrawBackground(false)
		button:SetPos(6, curY)
		button:SetSizeEx(200, 30)
		button:SetText(v.title)
		button:SetIcon(v.icon)
		button:SetCentered(true)
		button:SetFont(v.font or theme.GetFont("Menu_Normal"))

		button.DoClick = function(btn)
			if (v.override) then
				v.override(self, btn)

				return
			end

			if (v.panel) then
				surface.PlaySound("garrysmod/ui_hover.wav")

				if (IsValid(self.activePanel)) then
					self.activePanel:SafeRemove()

					self.activeBtn:SetTextColor(nil)
				end

				self.activePanel = vgui.Create(v.panel, self)

				if (self.activePanel.GetMenuSize) then
					self.activePanel:SetSize(self.activePanel:GetMenuSize())
				else
					self.activePanel:SetSize(scrW * 0.5, scrH * 0.5)
				end

				self.activeBtn = btn
				self.activeBtn:SetTextColor(theme.GetColor("AccentLight"))

				if (self.activePanel.Rebuild) then
					self.activePanel:Rebuild()
				end

				hook.Run("OnMenuPanelOpen", self, self.activePanel)
			end

			if (v.callback) then
				v.callback(self, button)
			end
		end

		curY = curY + font.Scale(38)

		self.buttons[k] = button
	end

	self.lerpStart = SysTime()
end

function PANEL:Think()
	if (!IsValid(self.activePanel) and IsValid(self.activeBtn)) then
		self.activeBtn:SetTextColor(nil)
	end
end

function PANEL:AddMenuItem(id, data, index)
	data.uniqueID = id
	data.title = string.utf8upper(fl.lang:TranslateText(data.title) or "error")
	data.icon = data.icon or false

	if (isnumber(index)) then
		table.insert(self.menuItems, index, data)
	else
		table.insert(self.menuItems, data)
	end
end

function PANEL:CloseMenu()
	self:SetVisible(false)
	self:Remove()
end

function PANEL:OnMousePressed()
	if (IsValid(self.activePanel)) then
		self.activePanel:SetVisible(false)
		self.activePanel:Remove()
	end
end

function PANEL:Paint(w, h)
	theme.Hook("PaintTabMenu", self, w, h)
end

vgui.Register("flTabMenu", PANEL, "EditablePanel")