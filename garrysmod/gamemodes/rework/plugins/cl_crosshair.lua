--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Crosshair")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds a crosshair.")

CreateClientConVar("cl_crosshair_thickness", "1")
CreateClientConVar("cl_crosshair_size", "4")
CreateClientConVar("cl_crosshair_gap", "1")
CreateClientConVar("cl_crosshair_outline", "1")
CreateClientConVar("cl_crosshair_dot", "0")
CreateClientConVar("cl_crosshair_style", "1")
CreateClientConVar("cl_crosshair_color_r", "255")
CreateClientConVar("cl_crosshair_color_g", "255")
CreateClientConVar("cl_crosshair_color_b", "255")
CreateClientConVar("cl_crosshair_color_a", "255")
CreateClientConVar("cl_crosshair_fadein", "0.5")
CreateClientConVar("cl_crosshair_fadeshow", "1.5")

rw.hint:Add("RunCrosshair", "Crosshair will change it's size depending on your movement speed\nand distance between you and your view target.")

local startTime 	= CurTime()
local curSize 		= nil
local _alpha 		= nil
local _talpha 		= 0
local doors 		= {"prop_door_rotating", "func_door"}
local textStartTime = 0
local prevEnt 		= nil

function PLUGIN:HUDPaint()
	if (!hook.Run("PreDrawCrosshair")) then
		local trace = rw.client:GetEyeTraceNoCursor()
		local distance = trace.StartPos:Distance(trace.HitPos)
		local drawColor, showText = hook.Run("AdjustCrosshairColor", trace, distance)

		if (!drawColor) then return end

		local scrW, scrH, curTime = ScrW(), ScrH(), CurTime()
		local fadein = GetConVar("cl_crosshair_fadein"):GetFloat()
		local fadeshow = GetConVar("cl_crosshair_fadeshow"):GetFloat()
		local radius = hook.Run("AdjustCrosshairRadius", trace, distance) or math.Clamp(4 / distance, 2, 6)

		surface.SetDrawColor(drawColor)
		surface.DrawOutlinedCircle(scrW / 2, scrH / 2, radius, 1, 32, false)

		if (distance < 70) then
			if (prevEnt != trace.Entity) then
				prevEnt = trace.Entity
				textStartTime = curTime
			end
		end

		_talpha = Lerp(
			FrameTime() * (showText and 4 or 6),
			_talpha or 0,
			(
				showText and drawColor.a < 5 and
				255 - 255 / fadein * math.Clamp(curTime - fadeshow - textStartTime, 0, fadein)
				or 0
			)
		)

		draw.SimpleText("#TargetID_Action", "menu_thin_smaller", scrW / 2, scrH / 2, Color(255, 255, 255, _talpha), 1, 1)
	end
end

function PLUGIN:AdjustCrosshairColor(trace, distance)
	local drawColor = Color(255, 255, 255)
	local alpha = 150
	local bShouldDrawText = false
	local ent = trace.Entity

	if (distance > 1000) then
		alpha = math.Clamp(alpha - (distance - 1000) / 30, 50, 200)
	end

	if (distance < 300 and IsValid(ent) and !ent:IsWorld()) then
		if (ent:IsPlayer()) then
			drawColor = Color(150, 190, 230)
		elseif (ent:GetClass() == "rework_item") then
			drawColor = Color(210, 175, 230)
		elseif (table.HasValue(doors, ent:GetClass())) then
			drawColor = Color(240, 210, 150)
			bShouldDrawText = true
		end
	end

	if (rw.client:GetVelocity():Length2D() > 150) then
		alpha = 0
	end

	_alpha = Lerp(FrameTime() * 8, (_alpha or alpha), alpha)

	return ColorAlpha(drawColor, _alpha), bShouldDrawText
end

function PLUGIN:AdjustCrosshairRadius(trace, distance)
	local dist = math.Clamp(distance * 3, 200, 2400) / 1000
	local fraction = FrameTime() * 8
	local target = math.Clamp(3 / dist, 2, 8)

	if (!curSize) then
		curSize = target
	end

	if (rw.client:GetVelocity():Length2D() > 150) then
		target = 10
	end

	curSize = Lerp(fraction, curSize, target)

	return curSize
end
