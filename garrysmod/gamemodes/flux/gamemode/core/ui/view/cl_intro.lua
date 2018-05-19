--[[
	Flux © 2016-2018 TeslaCloud Studios
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

	timer.Simple(4, function()
		self:CloseMenu()
	end)

	hook.Run("OnIntroPanelCreated", self)
end

local logoW, logoH = 600, 110
local curAlpha, curRadius = 0, 0
local exX, exY = 0, 0
local randomColor = Color(255, 255, 255)
local removeAlpha = 255

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, removeAlpha))

	if (!self.shouldRemove) then
		surface.SetDrawColor(randomColor.r, randomColor.g, randomColor.b, curAlpha)
		surface.DrawCircle(exX, exY, curRadius, 180)
	else
		self:MoveToFront()

		removeAlpha = math.Clamp(removeAlpha - 3, 0, 255)
	end

	draw.TexturedRect(util.GetMaterial("materials/flux/tc_logo.png"), w * 0.5 - logoW * 0.5, h * 0.5 - logoH * 0.5, logoW, logoH, Color(255, 255, 255, removeAlpha))

	if (!self.shouldRemove) then
		curRadius = curRadius + 2
		curAlpha = math.Clamp(Lerp(FrameTime() * 8, curAlpha, 0), 0, 255)

		if (math.floor(curAlpha) <= 1) then
			local w, h = self:GetSize()

			curAlpha = 255
			curRadius = 0

			randomColor = Color(math.random(0, 255), math.random(0, 255), math.random(0, 255))

			exX = math.random(math.Round(w * 0.2), math.Round(w * 0.8))
			exY = math.random(math.Round(h * 0.2), math.Round(h * 0.8))
		end
	end
end

function PANEL:CloseMenu()
	self.shouldRemove = true

	timer.Simple(1, function()
		self:Remove()
	end)

	hook.Run("OnIntroPanelRemoved")
end

function PANEL:StartAnimation(scrW, scrH)

end

derma.DefineControl("flIntro", "", PANEL, "EditablePanel")
