--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

class "CTheme"

CTheme.colors = {}
CTheme.sounds = {}
CTheme.materials = {}
CTheme.options = {}
CTheme.panels = {}
CTheme.fonts = {}
CTheme.skin = {}
CTheme.shouldReload = true

--[[ Basic Skeleton --]]
function CTheme:CTheme(name, parent)
	self.name = name or "Unknown"
	self.uniqueID = self.name:MakeID() -- temporary unique ID
	self.parent = parent

	if (!self.uniqueID) then
		error("Cannot create a theme without a valid unique ID!")
	end
end

function CTheme:OnLoaded() end
function CTheme:OnUnloaded() end

function CTheme:Remove()
	return theme.RemoveTheme(self.uniqueID)
end

function CTheme:AddPanel(id, callback)
	self.panels[id] = callback
end

function CTheme:CreatePanel(id, parent, ...)
	if (self.panels[id]) then
		return self.panels[id](id, parent, ...)
	end
end

function CTheme:SetOption(key, value)
	if (key) then
		self.options[key] = value
	end
end

function CTheme:SetFont(key, value, scale, data)
	if (key) then
		self.fonts[key] = font.GetSize(value, scale, data)
	end
end

function CTheme:SetColor(id, val)
	val = val or Color(255, 255, 255)

	self.colors[id] = val

	return val
end

function CTheme:SetMaterial(id, val)
	self.materials[id] = (!isstring(val) and val) or util.GetMaterial(val)
end

function CTheme:SetSound(id, val)
	self.sounds[id] = val or Sound()
end

function CTheme:GetFont(key, default)
	return self.fonts[key] or default
end

function CTheme:GetOption(key, default)
	return self.options[key] or default
end

function CTheme:GetColor(id, failsafe)
	local col = self.colors[id]

	if (col) then
		return col
	else
		return failsafe or Color(255, 255, 255)
	end
end

function CTheme:GetMaterial(id, failsafe)
	local mat = self.materials[id]

	if (mat) then
		return mat
	else
		return failsafe
	end
end

function CTheme:GetSound(id, failsafe)
	local sound = self.sounds[id]

	if (sound) then
		return sound
	else
		return failsafe or Sound()
	end
end

function CTheme:Register()
	return theme.RegisterTheme(self)
end

function CTheme:__tostring()
	return "Theme ["..self.name.."]"
end

-- Create an alias of CTheme class for convenience.
Theme = CTheme