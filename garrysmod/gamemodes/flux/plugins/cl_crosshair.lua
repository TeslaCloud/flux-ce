--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Crosshair")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds a crosshair.")

fl.hint:Add("RunCrosshair", "Crosshair will change it's size depending on your movement speed\nand distance between you and your view target.")

local curSize = nil
local size = 4
local halfSize = size / 2

function PLUGIN:HUDPaint()
	if (!plugin.Call("PreDrawCrosshair")) then
		local trace = fl.client:GetEyeTraceNoCursor()
		local distance = trace.StartPos:Distance(trace.HitPos)
		local drawColor = plugin.Call("AdjustCrosshairColor", trace, distance)

		if (!drawColor or distance > 750) then return end

		local scrW, scrH, curTime = ScrW(), ScrH(), CurTime()

		draw.RoundedBox(0, scrW / 2 - halfSize - 1, scrH / 2 - halfSize - 1, size + 2, size + 2, Color(0, 0, 0, _alpha))
		draw.RoundedBox(0, scrW / 2 - halfSize, scrH / 2 - halfSize, size, size, drawColor)
	end
end

function PLUGIN:AdjustCrosshairColor(trace, distance)
	local drawColor = Color(255, 255, 255)
	local alpha = 150
	local ent = trace.Entity

	if (distance > 500) then
		alpha = math.Clamp(alpha - (distance - 500) / 1.2, 0, 150)
	end

	if (distance < 300 and IsValid(ent) and !ent:IsWorld()) then
		if (ent:IsPlayer()) then
			drawColor = Color(150, 190, 230)
		elseif (ent:GetClass() == "fl_item") then
			drawColor = Color(210, 175, 230)
		end
	end

	if (fl.client:GetVelocity():Length2D() > 150) then
		alpha = 0
	end

	_alpha = Lerp(FrameTime() * 8, (_alpha or alpha), alpha)

	return ColorAlpha(drawColor, _alpha)
end