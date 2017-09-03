--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Crosshair")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds a crosshair.")

--fl.hint:Add("RunCrosshair", "Crosshair will change it's size depending on your movement speed\nand distance between you and your view target.")

local curSize = nil
local size = 2
local halfSize = size / 2
local gap = 8
local curGap = gap

function PLUGIN:HUDPaint()
	if (!plugin.Call("PreDrawCrosshair")) then
		local trace = fl.client:GetEyeTraceNoCursor()
		local distance = fl.client:GetPos():Distance(trace.HitPos)
		local drawColor = plugin.Call("AdjustCrosshairColor", trace, distance) or Color(255, 255, 255)
		local realGap = plugin.Call("AdjustCrosshairGap", trace, distance) or math.Round(gap * math.Clamp(distance / 400, 0.5, 4))
		curGap = Lerp(FrameTime() * 6, curGap, realGap)

		if (math.abs(curGap - realGap) < 0.5) then
			curGap = realGap
		end

		local scrW, scrH = ScrW(), ScrH()

		draw.RoundedBox(0, scrW / 2 - halfSize, scrH / 2 - halfSize, size, size, drawColor)

		draw.RoundedBox(0, scrW / 2 - halfSize - curGap, scrH / 2 - halfSize, size, size, drawColor)
		draw.RoundedBox(0, scrW / 2 - halfSize + curGap, scrH / 2 - halfSize, size, size, drawColor)

		draw.RoundedBox(0, scrW / 2 - halfSize, scrH / 2 - halfSize - curGap, size, size, drawColor)
		draw.RoundedBox(0, scrW / 2 - halfSize, scrH / 2 - halfSize + curGap, size, size, drawColor)
	end
end