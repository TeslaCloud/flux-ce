class 'Theme'

Theme.colors = {}
Theme.sounds = {}
Theme.materials = {}
Theme.options = {}
Theme.panels = {}
Theme.fonts = {}
Theme.skin = {}
Theme.should_reload = true

--[[ Basic Skeleton --]]
function Theme:init(name, parent)
  self.name = name or 'Unknown'
  self.id = self.name:to_id() -- temporary unique ID
  self.parent = parent

  if !self.id then
    error('Cannot create a theme without a valid unique ID!')
  end
end

function Theme:OnLoaded() end
function Theme:OnUnloaded() end

function Theme:Remove()
  return theme.RemoveTheme(self.id)
end

function Theme:AddPanel(id, callback)
  self.panels[id] = callback
end

function Theme:CreatePanel(id, parent, ...)
  if self.panels[id] then
    return self.panels[id](id, parent, ...)
  end
end

function Theme:SetOption(key, value)
  if key then
    self.options[key] = value
  end
end

function Theme:SetFont(key, value, scale, data)
  if key then
    self.fonts[key] = font.GetSize(value, scale, data)
  end
end

function Theme:SetColor(id, val)
  val = val or Color(255, 255, 255)

  self.colors[id] = val

  return val
end

function Theme:SetMaterial(id, val)
  self.materials[id] = (!isstring(val) and val) or util.get_material(val)
end

function Theme:SetSound(id, val)
  self.sounds[id] = val or Sound()
end

function Theme:GetFont(key, default)
  return self.fonts[key] or default
end

function Theme:GetOption(key, default)
  return self.options[key] or default
end

function Theme:GetColor(id, failsafe)
  local col = self.colors[id]

  if col then
    return col
  else
    return failsafe or Color(255, 255, 255)
  end
end

function Theme:GetMaterial(id, failsafe)
  local mat = self.materials[id]

  if mat then
    return mat
  else
    return failsafe
  end
end

function Theme:GetSound(id, failsafe)
  local sound = self.sounds[id]

  if sound then
    return sound
  else
    return failsafe or Sound()
  end
end

function Theme:register()
  return theme.RegisterTheme(self)
end

function Theme:__tostring()
  return 'Theme ['..self.name..']'
end
