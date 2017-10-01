--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local colorBlack = Color(0, 0, 0, 255)
local colorWhite = Color(255, 255, 255, 255)

local PANEL = {}

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()

	self:SetSize(scrW, scrH)
	self:SetPos(0, 0)

	self:StartAnimation(scrW, scrH)

	hook.Run("OnIntroPanelCreated", self)
end

function PANEL:Paint(w, h)
	local alpha = 255 * (math.abs(math.sin(CurTime())))

	surface.SetDrawColor(colorBlack)
	surface.DrawRect(0, 0, w, h)

	draw.SimpleText("Press any key to skip intro!", "default", w * 0.5, h * 0.95, ColorAlpha(colorWhite, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

function PANEL:CloseMenu(bForce)
	self:Remove()

	hook.Run("OnIntroPanelRemoved")
end

function PANEL:OnKeyCodeReleased(nKey)
	self:CloseMenu()
end

function PANEL:StartAnimation(scrW, scrH)

end

derma.DefineControl("flIntro", "", PANEL, "EditablePanel")