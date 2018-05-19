--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]


local PANEL = {}
PANEL.limit = 0

function PANEL:Init()
	self:SetUpdateOnType(true)
end

function PANEL:SetLimit(nLimit)
	PANEL.limit = math.abs(nLimit or 0)
end

function PANEL:Paint(w, h)
	if (!hook.Run("ChatboxEntryPaint", self, 0, 0, w, h)) then
		draw.RoundedBox(2, 0, 0, w, h, theme.GetColor("Background"))

		self:DrawTextEntryText(theme.GetColor("Text"), theme.GetColor("Accent"), theme.GetColor("Text"))
	end
end

function PANEL:Think()
	local text = self:GetValue()

	if (text and text != "") then
		if (string.utf8len(text) > self.limit) then
			self:SetValue(string.utf8sub(text, 0, self.limit))
		end
	end
end

vgui.Register("flTextEntry", PANEL, "DTextEntry")
