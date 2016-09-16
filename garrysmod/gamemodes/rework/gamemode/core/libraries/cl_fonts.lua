--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("fonts", rw);
rw.fonts.stored = rw.fonts.stored or {};

do
	local aspect = ScrW() / ScrH();

	local function ScreenIsRatio(w, h)
		return (aspect == w / h);
	end;

	function rw.fonts.FontScreenScale(size)
		size = size * 3;

		if (ScreenIsRatio(16, 10)) then
			return size * (ScrH() / 1200);
		elseif (ScreenIsRatio(4, 3)) then
			return size * (ScrH() / 1024)
		end;
				
		return size * (ScrH() / 1080);
	end;

	function rw.fonts.HDFontScreenScale(size)
		if (ScreenIsRatio(16, 10)) then
			return size * (ScrH() / 1200);
		elseif (ScreenIsRatio(4, 3)) then
			return size * (ScrH() / 1024)
		end;
		
		return size * (ScrH() / 1080);
	end;
end;

function rw.fonts:CreateFont(name, fontData)
	if (name == nil or typeof(fontData) != "table") then return; end;
	if (self.stored[name]) then return; end;

	-- Force UTF-8 range by default.
	fontData.extended = true;

	surface.CreateFont(name, fontData);
	self.stored[name] = fontData;
end;

function rw.fonts:GetSize(name, size)
	local newName = name.."\\"..size;

	if (!string.find(name, "\\")) then
		if (!rw.fonts:GetTable(newName)) then
			local fontData = table.Copy(rw.fonts:GetTable(name));

			if (fontData) then
				fontData.size = size;
				
				self:CreateFont(newName, fontData);
				self.stored[newName] = fontData;
			end;
		end;
	else
		newName = name;
	end;

	return newName;
end;

function rw.fonts:GetTable(name)
	return self.stored[name];
end;

rw.fonts:CreateFont("menu_thin", {
	font = "Roboto Th",
	size = rw.fonts.HDFontScreenScale(34)
});

rw.fonts:CreateFont("menu_light", {
	font = "Roboto Lt",
	size = rw.fonts.HDFontScreenScale(34)
});