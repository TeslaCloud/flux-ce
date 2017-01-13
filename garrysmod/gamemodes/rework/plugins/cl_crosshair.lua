--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Crosshair");
PLUGIN:SetAuthor("Mr. Meow");
PLUGIN:SetDescription("Adds crosshair.");
PLUGIN.Store = {};
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
local curSize 	= nil;
local _alpha 		= nil;
local _talpha 	= 0;
local TYPE_WORLD	= 0;
local TYPE_PLAYER = 1;
local TYPE_ITEM 	= 2;
local TYPE_USE 		= 3;
local UseItems 		= {"prop_door_rotating", "func_door"};
local ScrW = ScrW;
local ScrH = ScrH;

PLUGIN.Store[TYPE_PLAYER] = {
	object = function(item)
		return item:IsPlayer();
	end,
	color = Color(152,190,230),
	showText = false
};
PLUGIN.Store[TYPE_ITEM] = {
	object = function(item)
		return (item:GetClass() == "rework_item");
	end,
	color = Color(212,176,230),
	showText = true
};
PLUGIN.Store[TYPE_USE] = {
	object = function(item)
		return table.HasValue(UseItems, item:GetClass());
	end,
	color = Color(240,211,152),
	showText = true
};
PLUGIN.Store[TYPE_WORLD] = {
	object = function(item)
		return false;
	end,
	color = Color(255,255,255),
	showText = false
};

function PLUGIN:HUDPaint()
	if (!plugin.Call("PreDrawCrosshair")) then
		local drawColor, showText;
		local trace = rw.client:GetEyeTraceNoCursor();
		local distance = trace.StartPos:Distance(trace.HitPos);
		local radius = plugin.Call("AdjustCrosshairRadius", trace, distance) or math.Clamp(4 / distance, 2, 6);
		drawColor, showText = Color(255, 255, 255, 150), false;
		drawColor, showText = plugin.Call("AdjustCrosshairColor", trace, distance);

		surface.SetDrawColor(drawColor);
		surface.DrawOutlinedCircle(ScrW() / 2, ScrH() / 2, radius, 1, 32, false);
		_talpha = Lerp(FrameTime()*(showText and 4 or 6), _talpha or 0, (showText and drawColor.a < 5 and 255 or 0))
		draw.SimpleText("Press `E` for actions.", "menu_thin_smaller", ScrW()/2, ScrH()/2, Color(255,255,255,_talpha), 1, 1)
	end;
end;

function PLUGIN:AdjustCrosshairColor(trace, distance)
	local r, g, b = 255, 255, 255;
	local alpha = 150;
	local sText = false;

	if (distance > 1000) then
		alpha = math.Clamp(alpha - (distance - 1000) / 30, 50, 200);
	end;

	if (distance < 750 and IsValid(trace.Entity) and !trace.Entity:IsWorld()) then
		local itype = nil;
		for k,v in pairs(self.Store) do
			local obj = v.object(trace.Entity);
			if (obj) then
				itype = k;
			else
				if (k == self.Store) then
					itype = TYPE_WORLD;
				else
					continue;
				end;
			end;
		end;
		local titem = self.Store[itype] or {color = Color(255,255,255), showText = false};
		r, g, b = titem.color.r, titem.color.g, titem.color.b;
		sText = titem.showText;
	end;
	if (distance < 70) then
		alpha = 0;
	end

	_alpha = Lerp(FrameTime() * 4, (_alpha or alpha), alpha)
	return Color(r, g, b, _alpha), sText;
end;

function PLUGIN:AdjustCrosshairRadius(trace, distance)
	local dist = math.Clamp(distance * 3, 200, 2400) / 1000;

	local fraction = FrameTime() * 2;
	local target = math.Clamp(4 / dist, 2, 6);

	if (!curSize) then
		curSize = target;
	end
	if (distance < 70) then
		target = 10;
	end

	curSize = Lerp(fraction, curSize, target);
	return curSize;
end;
