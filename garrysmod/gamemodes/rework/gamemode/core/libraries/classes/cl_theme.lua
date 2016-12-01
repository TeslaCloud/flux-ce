Class "CTheme";

--[[ Basic Skeleton --]]
function CTheme:CTheme(name, parent)
	self.m_Name = name or "Unknown";
	self.m_UniqueID = self.m_Name:MakeID()); -- temporary unique ID
	self.parent = parent;

	if (!self.m_UniqueID) then
		error("Cannot create a theme without a valid unique ID!");
	end;
end;

function CTheme:OnLoaded() end;
function CTheme:OnUnloaded() end;

function CTheme:Remove()
	return theme.RemoveTheme(self.m_UniqueID);
end;

function CTheme:Register()
	return theme.RegisterTheme(self);
end;

// Create an alias of CTheme class for convenience.
Theme = CTheme;

// Create the default theme that other themes will derive from.
local THEME = Theme("Factory");
THEME.author = "TeslaCloud Studios"

function THEME:OnLoaded()
	if (rw.settings:GetBool("UseTabDash")) then
		theme.SetPanel("TabMenu", "rwTabDash");
	else
		theme.SetPanel("TabMenu", "rwTabClassic");
	end;

	theme.SetPanel("MainMenu", "rwMainMenu");
end;

THEME:Register();