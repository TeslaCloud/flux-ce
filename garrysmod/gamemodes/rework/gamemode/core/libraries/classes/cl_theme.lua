Class "CTheme";

CTheme.colors = {};
CTheme.sounds = {};
CTheme.materials = {};

--[[ Basic Skeleton --]]
function CTheme:CTheme(name, parent)
	self.name = name or "Unknown";
	self.uniqueID = self.name:MakeID()); -- temporary unique ID
	self.parent = parent;

	if (!self.uniqueID) then
		error("Cannot create a theme without a valid unique ID!");
	end;
end;

function CTheme:OnLoaded() end;
function CTheme:OnUnloaded() end;

function CTheme:Remove()
	return theme.RemoveTheme(self.uniqueID);
end;

function CTheme:SetColor(id, val)
	self.colors[id] = val or Color(255, 255, 255);
end;

function CTheme:SetMaterial(id, val)
	self.materials[id] = val or Material();
end;

function CTheme::SetSound(id, val)
	self.sounds[id] = val or Sound();
end;

function CTheme:GetColor(id, failsafe)
	local col = self.colors[id];

	if (col) then
		return col;
	else
		return failsafe or Color(255, 255, 255);
	end;
end;

function CTheme:GetMaterial(id, failsafe)
	local mat = self.materials[id];

	if (mat) then
		return mat;
	else
		return failsafe or Material();
	end;
end;

function CTheme:GetSound(id, failsafe)
	local sound = self.sounds[id];

	if (sound) then
		return sound;
	else
		return failsafe or Sound();
	end;
end;

function CTheme:Register()
	return theme.RegisterTheme(self);
end;

function CTheme:__tostring()
	return "Theme ["..self.name.."]";
end;

// Create an alias of CTheme class for convenience.
Theme = CTheme;