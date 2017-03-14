--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local colorBlack = Color(0, 0, 0, 170)

local PANEL = {}

function PANEL:OnMousePressed(nKey)
	if (!self.waitPress) then
		if (nKey == MOUSE_LEFT) then
			self.waitPress = true
			self:RequestFocus()
		end
	else
		self:SetBind(nKey)
	end
end

function PANEL:OnKeyCodePressed(nKey)
	if (self.waitPress) then
		self:SetBind(nKey)
	end
end

function PANEL:Think()
	if (!self:IsHovered() and self.waitPress) then
		self.waitPress = false
	end
end

function PANEL:SetBind(nKey)
	if (self.setting) then
		fl.settings:SetValue(self.setting.id, nKey)
		fl.binds:SetBind(self.setting.info.command, nKey)

		self.waitPress = false
	end
end

function PANEL:Paint(w, h)
	local text = "Unbound"
	local value = fl.settings:GetNumber(self.setting.id)

	surface.SetDrawColor(colorBlack)
	surface.DrawRect(0, 0, w, h)

	if (self.waitPress) then
		text = "Press a key to bind or mouse away to cancel."
	elseif (value and value > 0) then
		text = string.gsub(string.gsub(fl.binds:GetEnums()[value], "KEY_", ""), "_", " ")

		if (text == "COUNT") then
			text = "MOUSE LEFT"
		end
	end

	draw.SimpleText(text, "menu_light_small", w * 0.5, h * 0.5, fl.settings:GetColor("TextColor"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

derma.DefineControl("flBindSelect", "", PANEL, "EditablePanel")