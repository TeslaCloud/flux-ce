--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("theme", rw);
rw.theme.activeTheme = rw.theme.activeTheme or nil;

--[[
	This is to preserve the table through autorefresh,
	and also as a way to get the stored table instead of a function.
--]]
local stored = rw.theme.stored or {};
rw.theme.stored = stored;

local cache = rw.theme.cache or {};
rw.theme.cache = cache;

function rw.theme:SetMenu(sMenu, sValue)
	cache["menu_"..sMenu] = sValue;
end;

function rw.theme:GetMenu(sMenu, fallback)
	return cache["menu_"..sMenu] or fallback;
end;

function rw.theme:OpenMenu(sMenu, parent, fallback)
	local menu = self:GetMenu(sMenu, fallback);

	if (menu) then
		return vgui.Create(menu, parent);
	end;
end;

function rw.theme:SetSound(sSound, sValue)
	cache["sound_"..sSound] = sValue;
end;

function rw.theme:GetSound(sSound, fallback)
	return cache["sound_"..sSound] or fallback;
end;

function rw.theme:SetColor(sColor, cValue)
	cache["color_"..sColor] = cValue;
end;

function rw.theme:GetColor(sColor, fallback)
	return cache["color_"..sColor] or fallback;
end;

function rw.theme:SetMaterial(sMaterial, mMat)
	cache["material_"..sMaterial] = mMat;
end;

function rw.theme:GetMaterial(sMaterial, fallback)
	return cache["material_"..sMaterial] or fallback;
end;

Class "Theme";

--[[ Basic Skeleton --]]
function Theme:Theme(name, data)
	self.m_name = name or (data and data.name) or "Unknown";
	self.m_uniqueID = (data and data.uniqueID) or string.lower(string.gsub(self.m_name, " ", "_")) or "unknown";
	self.m_author = (data and data.author) or "Unknown Author";
	self.m_hooks = (data and data.hooks) or {};

	if (data) then
		table.Merge(self, data);
	end;
end;

function Theme:OnLoaded() end;
function Theme:OnUnloaded() end;

function Theme:Remove()
	return rw.theme:RemoveTheme(self.m_uniqueID);
end;

function Theme:Register()
	return rw.theme.RegisterTheme(self);
end;

function rw.theme.GetStored()
	return stored;
end;

function rw.theme.FindTheme(id)
	return stored[string.lower(string.gsub(id, " ", "_"))];
end;

function rw.theme:RemoveTheme(id)
	if (self.FindTheme(id)) then
		stored[id] = nil;
	end;
end;

function rw.theme.RegisterTheme(themeTable)
	stored[themeTable.m_uniqueID] = themeTable;
end;

function rw.theme:LoadTheme(theme)
	local themeTable = self.FindTheme(theme);

	if (themeTable) then
		self.activeTheme = themeTable;

		if (themeTable.OnLoaded) then
			themeTable:OnLoaded();
		end;
	end;
end;

function rw.theme:UnloadTheme()
	if (self.activeTheme.OnUnloaded) then
		self.activeTheme:OnUnloaded();
	end;

	self.activeTheme = nil;
end;

local themeHooks = {};

function themeHooks:InitPostEntity()
	rw.theme:LoadTheme("Rework");
end;

plugin.AddHooks("rwThemeHooks", themeHooks);

-- Create the default theme that other themes will derive from.
local THEME = Theme("Rework", {author = "TeslaCloud"});

function THEME:OnLoaded()
	if (rw.settings:GetBool("UseTabDash")) then
		rw.theme:SetMenu("TabMenu", "rwTabDash");
	else
		rw.theme:SetMenu("TabMenu", "rwTabClassic");
	end;

	rw.theme:SetMenu("MainMenu", "rwMainMenu");
end;

THEME:Register();