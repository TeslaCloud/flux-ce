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

function Theme:on_loaded() end
function Theme:on_unloaded() end

function Theme:remove()
  return theme.remove_theme(self.id)
end

function Theme:add_panel(id, callback)
  self.panels[id] = callback
end

function Theme:create_panel(id, parent, ...)
  if self.panels[id] then
    return self.panels[id](id, parent, ...)
  end
end

function Theme:register_asset(name, path, options)
  options = options or {}

  if path:find('%.mdl') then
    util.PrecacheModel(path)
  elseif path:find('%.png') or path:find('%.jp[e]?g') then
    if options.sizes then
      local scrh = ScrH()
      local base_size = 720

      for k, v in ipairs(options.sizes) do
        if scrh < base_size then
          return self:set_material(name, path)
        elseif scrh <= base_size * v then
          return self:set_material(name, path:gsub('%.', '_'..v..'x.'))
        end
      end

      return self:set_material(name, path)
    else
      return self:set_material(name, path)
    end
  end
end

function Theme:set_option(key, value)
  if key then
    self.options[key] = value
  end

  return self.options[key]
end

function Theme:set_font(key, value, scale, data)
  if key then
    self.fonts[key] = font.GetSize(value, scale, data)
  end

  return self.fonts[key]
end

function Theme:set_color(id, val)
  val = val or Color(255, 255, 255)

  self.colors[id] = val

  return val
end

function Theme:set_material(id, val)
  self.materials[id] = (!isstring(val) and val) or util.get_material(val)
  return self.materials[id]
end

function Theme:set_sound(id, val)
  self.sounds[id] = val or Sound()
  return self.sounds[id]
end

function Theme:get_font(key, default)
  return self.fonts[key] or default
end

function Theme:get_option(key, default)
  return self.options[key] or default
end

function Theme:get_color(id, failsafe)
  local col = self.colors[id]

  if col then
    return col
  else
    return failsafe or Color(255, 255, 255)
  end
end

function Theme:get_material(id, failsafe)
  local mat = self.materials[id]

  if mat then
    return mat
  else
    return failsafe
  end
end

function Theme:get_sound(id, failsafe)
  local sound = self.sounds[id]

  if sound then
    return sound
  else
    return failsafe or Sound()
  end
end

function Theme:register()
  return theme.register_theme(self)
end

function Theme:__tostring()
  return 'Theme ['..self.name..']'
end
