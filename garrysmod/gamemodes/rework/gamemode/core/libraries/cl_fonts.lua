--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

library.New("fonts", rw);
rw.fonts.stored = rw.fonts.stored or {};

function rw.fonts:CreateFont(name, fontData)
	if (name == nil or typeof(fontData) != "table") then return; end;
	if (self.stored[name]) then return; end;

	-- Force UTF-8 range by default.
	fontData.extended = true;

	surface.CreateFont(name, fontData);
	self.stored[name] = fontData;
end;

function rw.fonts:GetSize(name, size)
	if (!self.stored[name..size]) then
		local fontData = self.stored[name];
		fontData.size = size;
		
		self:CreateFont(name..size, fontData);
		self.stored[name..size] = fontData;
	end;

	return name..size;
end;