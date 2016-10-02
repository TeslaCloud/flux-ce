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

	function rw.fonts.ScaleSize(size)
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

	if (!rw.fonts:GetTable(newName)) then
		local fontData = table.Copy(rw.fonts:GetTable(name));

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

function rw.fonts.CreateFonts()
	rw.fonts:ClearTable();

	rw.fonts:CreateFont("menu_thin", {
		font = "Roboto Lt",
		weight = 400,
		size = rw.fonts.ScaleSize(34)
	});

	rw.fonts:CreateFont("menu_thin_small", {
		font = "Roboto Lt",
		weight = 300,
		size = rw.fonts.ScaleSize(28)
	});

	rw.fonts:CreateFont("menu_thin_smaller", {
		font = "Roboto Lt",
		size = rw.fonts.ScaleSize(22),
		weight = 200
	});

	rw.fonts:CreateFont("menu_light", {
		font = "Roboto Lt",
		size = rw.fonts.ScaleSize(34)
	});

	rw.fonts:CreateFont("menu_light_tiny", {
		font = "Roboto Lt",
		size = rw.fonts.ScaleSize(16)
	});

	rw.fonts:CreateFont("menu_light_small", {
		font = "Roboto Lt",
		size = rw.fonts.ScaleSize(20)
	});

	rw.fonts:CreateFont("hud_small", {
		font = "Roboto Lt",
		size = rw.fonts.ScaleSize(20),
		weight = 200
	});

	plugin.Call("CreateFonts", rw.fonts);
end;