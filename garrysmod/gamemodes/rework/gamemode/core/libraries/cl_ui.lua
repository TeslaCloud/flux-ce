--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("rwUI", _G);
rwUI.activeTheme = rwUI.activeTheme or nil;

--[[
	This is to preserve the table through autorefresh,
	and also as a way to get the stored table instead of a function.
--]]
local stored = rwUI.stored or {};
rwUI.stored = stored;

local cache = rwUI.cache or {};
rwUI.cache = cache;

Class "Theme";

--[[ Basic Skeleton --]]
function Theme:Theme(name, data)
	self.m_name = name or data.name or "Unknown";
	self.m_uniqueID = data.uniqueID or string.lower(string.gsub(self.m_name, " ", "_")) or "unknown";
	self.m_author = data.author or "Unknown Author";
	self.m_hooks = data.hooks or {};

	table.Merge(self, data);
end;

function Theme:OnLoaded() end;
function Theme:OnUnloaded() end;

function Theme:Remove()
	return rwUI:RemoveTheme(self.m_uniqueID);
end;

function Theme:Register()
	return rwUI.RegisterTheme(self);
end;

function rwUI.GetStored()
	return stored;
end;

function rwUI.FindTheme(id)
	return stored[id];
end;

function rwUI:RemoveTheme(id)
	if (self.FindTheme(id)) then
		stored[id] = nil;
	end;
end;

function rwUI.RegisterTheme(themeTable)
	stored[themeTable.m_uniqueID] = themeTable;
end;

function rwUI:LoadTheme(theme)
	local themeTable = (isstring(theme) and self.FindTheme(theme)) or (istable(theme) and theme);

	self.activeTheme = themeTable;

	if (themeTable.OnLoaded) then
		themeTable:OnLoaded();
	end;
end;

function rwUI:UnloadTheme()
	if (self.activeTheme.OnUnloaded) then
		self.activeTheme:OnUnloaded();
	end;

	self.activeTheme = nil;
end;

-- This doesn't seem to work.
--[[
function rwUI:CapturePanelToMat(panel)
	if (self.cache[panel]) then
		return self.cache[panel];
	end;

	local captureData = render.Capture({
		format = "png",
		quality = 70,
		x = panel.x,
		y = panel.y,
		w = panel:GetWide(),
		h = panel:GetWide()
	});

	local name = os.time();
	local path = "rework/materials/temp/"..name..".txt";

	file.CreateDir("rework/"); file.CreateDir("rework/materials/"); file.CreateDir("rework/materials/temp/");
	file.Write(path, captureData);

	self.cache[panel] = Material("../data/"..path, "noclamp smooth");

	return self.cache[panel];
end;
--]]