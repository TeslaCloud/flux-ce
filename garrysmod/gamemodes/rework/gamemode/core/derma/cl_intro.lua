--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local colorBlack = Color(0, 0, 0, 255)
local colorWhite = Color(255, 255, 255, 255)

local menuThin = "menu_thin_smaller"

local PANEL = {}

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()

	self:SetSize(scrW, scrH)
	self:SetPos(0, 0)

	self:StartAnimation(scrW, scrH)

	self:CloseMenu()
end

function PANEL:Paint(w, h)
	local alpha = 255 * (math.abs(math.sin(CurTime())))

	surface.SetDrawColor(colorBlack)
	surface.DrawRect(0, 0, w, h)

	draw.SimpleText("Press any key to skip intro!", menuThin, w * 0.5, h * 0.95, ColorAlpha(colorWhite, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

function PANEL:CloseMenu(bForce)
	self:Remove()

	rw.IntroPanel = vgui.Create("rwMainMenu")
	rw.IntroPanel:MakePopup()
end

function PANEL:OnKeyCodeReleased(nKey)
	self:CloseMenu()
end

function PANEL:StartAnimation(scrW, scrH)

end

derma.DefineControl("rwIntro", "", PANEL, "EditablePanel")

if (IsValid(rw.IntroPanel)) then
	rw.IntroPanel:Remove()

	rw.IntroPanel = vgui.Create("rwIntro")
	rw.IntroPanel:MakePopup()
end