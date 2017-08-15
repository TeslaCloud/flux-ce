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
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())

	local curX, curY = hook.Run("AdjustMenuItemPositions", self)
	curX = curX or 42
	curY = curY or 200

	self.closeButton = vgui.Create("flButton", self)
	self.closeButton:SetFont(theme.GetFont("Menu_Large"))
	self.closeButton:SetText("#TabMenu_CloseMenu")
	self.closeButton:SetPos(curX, curY)
	self.closeButton:SetSize(164, 38)
	self.closeButton:SetDrawBackground(false)
	self.closeButton:SetTextAutoposition(false)
	self.closeButton.DoClick = function(btn)
		surface.PlaySound("garrysmod/ui_click.wav")
		self:SetVisible(false)
		self:Remove()
	end

	curY = curY + 42

	hook.Run("AddTabMenuItems", self)

	for k, v in pairs(self.menuItems) do
		local button = vgui.Create("flButton", self)
		button:SetDrawBackground(false)
		button:SetPos(curX - 20, curY)
		button:SetSize(200, 30)
		button:SetText(v.title)
		button:SetIcon(v.icon)
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

				self.activeBtn = btn
				self.activeBtn:SetTextColor(theme.GetColor("AccentLight"))

				hook.Run("OnMenuPanelOpen", self, self.activePanel)
			end

			if (v.callback) then
				v.callback(self, button)
			end
		end

		curY = curY + 32

		self.buttons[k] = button
	end

	self.lerpStart = SysTime()
end

function PANEL:Think()
	if (!IsValid(self.activePanel) and IsValid(self.activeBtn)) then
		self.activeBtn:SetTextColor(nil)
	end
end

function PANEL:AddMenuItem(id, data)
	data.title = data.title or "error"
	data.icon = data.icon or false

	self.menuItems[id] = data
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