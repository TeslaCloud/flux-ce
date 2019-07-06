class 'ThemeBase'

ThemeBase.colors    = {}
ThemeBase.sounds    = {}
ThemeBase.materials = {}
ThemeBase.options   = {}
ThemeBase.panels    = {}
ThemeBase.fonts     = {}
ThemeBase.skin      = {}
Theme.should_reload = true

function ThemeBase:init(name, parent)
  self.name   = name or 'Unknown'
  self.id     = self.name:to_id() -- temporary unique ID
  self.parent = parent

  if !self.id then
    error 'Cannot create a theme without a valid unique ID!\n'
  end
end

function ThemeBase:on_loaded()
end

function ThemeBase:on_unloaded()
end

function ThemeBase:remove()
  return Theme.remove_theme(self.id)
end

function ThemeBase:add_panel(id, callback)
  self.panels[id] = callback
end

function ThemeBase:create_panel(id, parent, ...)
  if self.panels[id] then
    return self.panels[id](id, parent, ...)
  end
end

function ThemeBase:register_asset(name, path, options)
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

function ThemeBase:set_option(key, value)
  if key then
    self.options[key] = value
  end

  return self.options[key]
end

function ThemeBase:set_font(key, value, scale, data)
  if key then
    self.fonts[key] = Font.size(value, scale, data)
  end

  return self.fonts[key]
end

function ThemeBase:set_color(id, val)
  val = val or Color(255, 255, 255)

  self.colors[id] = val

  return val
end

function ThemeBase:set_material(id, val)
  self.materials[id] = (!isstring(val) and val) or util.get_material(val)
  return self.materials[id]
end

function ThemeBase:set_sound(id, val)
  self.sounds[id] = val or Sound()
  return self.sounds[id]
end

function ThemeBase:get_font(key, default)
  return self.fonts[key] or default
end

function ThemeBase:get_option(key, default)
  return self.options[key] or default
end

function ThemeBase:get_color(id, failsafe)
  local col = self.colors[id]

  if col then
    return col
  else
    return failsafe or Color(255, 255, 255)
  end
end

function ThemeBase:get_material(id, failsafe)
  local mat = self.materials[id]

  if mat then
    return mat
  else
    return failsafe
  end
end

function ThemeBase:get_sound(id, failsafe)
  local sound = self.sounds[id]

  if sound then
    return sound
  else
    return failsafe or Sound()
  end
end

function ThemeBase:register()
  return Theme.register_theme(self)
end

function ThemeBase:__tostring()
  return 'ThemeBase ['..self.name..']'
end
