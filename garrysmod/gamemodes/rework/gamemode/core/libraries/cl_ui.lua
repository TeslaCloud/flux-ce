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


function rwUI:CapturePanelToMat(panel) end;