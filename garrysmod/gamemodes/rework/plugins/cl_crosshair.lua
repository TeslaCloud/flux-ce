--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

PLUGIN:SetName("Crosshair");
PLUGIN:SetAuthor("Mr. Meow");
PLUGIN:SetDescription("Adds crosshair.");

CreateClientConVar("cl_crosshair_thickness", "1");
CreateClientConVar("cl_crosshair_size", "4");
CreateClientConVar("cl_crosshair_gap", "1");
CreateClientConVar("cl_crosshair_outline", "1");
CreateClientConVar("cl_crosshair_dot", "0");
CreateClientConVar("cl_crosshair_style", "1");
CreateClientConVar("cl_crosshair_color_r", "255");
CreateClientConVar("cl_crosshair_color_g", "255");
CreateClientConVar("cl_crosshair_color_b", "255");
CreateClientConVar("cl_crosshair_color_a", "255");

local startTime = CurTime();
local prevDistance = nil;
local curSize = nil;

function PLUGIN:HUDPaint()
	if (!plugin.Call("PreDrawCrosshair")) then
		local trace = rw.client:GetEyeTraceNoCursor();
		local distance = trace.StartPos:Distance(trace.HitPos);
		local drawColor = plugin.Call("AdjustCrosshairColor", trace, distance) or Color(255, 255, 255, 150);
		local radius = plugin.Call("AdjustCrosshairRadius", trace, distance) or math.Clamp(4 / distance, 2, 6);

		surface.SetDrawColor(drawColor);
		surface.DrawOutlinedCircle(ScrW() / 2, ScrH() / 2, radius, 1, 32, false);
	end;
end;

function PLUGIN:AdjustCrosshairColor(trace, distance)
	local r, g, b = 255, 255, 255;
	local alpha = 150;

	if (distance > 1000) then
		alpha = math.Clamp(alpha - (distance - 1000) / 30, 50, 200);
	end;

	if (distance < 750 and IsValid(trace.Entity)) then
		r = 175;
		g = 175;
	end;

	return Color(r, g, b, alpha);
end;

function PLUGIN:AdjustCrosshairRadius(trace, distance)
	local dist = math.Clamp(distance * 3, 200, 2400) / 1000;
	local curTime = CurTime();

	if (!prevDistance or math.abs(prevDistance - distance) > 35) then
		prevDistance = distance;
		startTime = curTime;
	end;

	local fraction = (curTime - startTime) / 2;
	local target = math.Clamp(4 / dist, 2, 6);

	if (!curSize) then
		curSize = target;
	end

	curSize = Lerp(fraction, curSize, target);
	return curSize;
end;