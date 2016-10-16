--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("fonts", rw);

local stored = rw.fonts.stored or {};
rw.fonts.stored = stored;

do
	local aspect = ScrW() / ScrH();

	local function ScreenIsRatio(w, h)
		return (aspect == w / h);
	end;

	function rw.fonts:ScaleSize(size)
		if (ScreenIsRatio(16, 10)) then
			return math.floor(size * (ScrH() / 1200));
		elseif (ScreenIsRatio(4, 3)) then
			return math.floor(size * (ScrH() / 1024));
		end;

		return math.floor(size * (ScrH() / 1080));
	end;
end;

function rw.fonts:CreateFont(name, fontData)
	if (name == nil or typeof(fontData) != "table") then return; end;
	if (stored[name]) then return; end;

	-- Force UTF-8 range by default.
	fontData.extended = true;

	surface.CreateFont(name, fontData);
	stored[name] = fontData;
end;

function rw.fonts:GetSize(name, size)
	local newName = name.."\\"..size;

	if (!stored[newName]) then
		local fontData = table.Copy(stored[name]);

		if (fontData) then
			fontData.size = size;

			self:CreateFont(newName, fontData);
		end;
	end;

	return newName;
end;

function rw.fonts:ClearTable()
	stored = {};
end;

function rw.fonts:ClearSizes()
	for k, v in pairs(stored) do
		if (k:find("\\")) then
			stored[k] = nil;
		end;
	end;
end;

function rw.fonts:GetTable(name)
	return stored[name];
end;

function rw.fonts:CreateFonts()
	self:ClearTable();

	self:CreateFont("menu_thin", {
		font = "Roboto Lt",
		weight = 400,
		size = self:ScaleSize(34)
	});

	self:CreateFont("menu_thin_small", {
		font = "Roboto Lt",
		weight = 300,
		size = self:ScaleSize(28)
	});

	self:CreateFont("menu_thin_smaller", {
		font = "Roboto Lt",
		size = self:ScaleSize(22),
		weight = 200
	});

	self:CreateFont("menu_light", {
		font = "Roboto Lt",
		size = self:ScaleSize(34)
	});

	self:CreateFont("menu_light_tiny", {
		font = "Roboto Lt",
		size = self:ScaleSize(16)
	});

	self:CreateFont("menu_light_small", {
		font = "Roboto Lt",
		size = self:ScaleSize(20)
	});

	self:CreateFont("hud_small", {
		font = "Roboto Condensed",
		size = self:ScaleSize(20),
		weight = 200
	});

	self:CreateFont("bar_text", {
		font = "Roboto Condensed",
		size = 18,
		weight = 600
	});

	plugin.Call("CreateFonts", self);
end;