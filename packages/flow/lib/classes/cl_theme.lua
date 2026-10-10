--- Base class of the interface themes. A theme stores the named colors, fonts, sounds,
-- materials and options that the interface looks up through the `Theme` library, the callbacks
-- that create the panels it provides (`ThemeBase:add_panel`), and a `skin` table of overrides
-- for the 'Flux' Derma skin. A file in a `themes` folder receives a new instance as `THEME`:
-- set `THEME.parent` to inherit from another theme, define the values of the theme in
-- `THEME:on_loaded`, and add methods such as `THEME:PaintButton(panel, w, h)` to answer the
-- theme hooks that the interface calls with `Theme.hook`. When a theme is loaded, the
-- `on_loaded` methods of its parents are run on it as well.
-- ```
-- THEME.author = 'TeslaCloud Studios'
-- THEME.id = 'hl2rp'
-- THEME.parent = 'factory'
--
-- function THEME:on_loaded()
--   self:set_color('accent', Color(58, 87, 167))
--   self:set_option('bar_height', 7)
-- end
-- ```

class 'ThemeBase'

ThemeBase.colors    = {}
ThemeBase.sounds    = {}
ThemeBase.materials = {}
ThemeBase.options   = {}
ThemeBase.panels    = {}
ThemeBase.fonts     = {}
ThemeBase.skin      = {}
ThemeBase.should_reload = true

--- Creates a new theme. The ID of the theme is derived from its name.
-- @param name='Unknown' [String]
-- @param parent=nil [String ID of the theme to inherit from]
function ThemeBase:init(name, parent)
  self.name   = name or 'Unknown'
  self.id     = self.name:to_id() -- temporary unique ID
  self.parent = parent

  if !self.id then
    error 'Cannot create a theme without a valid unique ID!\n'
  end
end

--- Called when the theme becomes the active one. Does nothing by default, override it
-- to set the colors, fonts, options and other assets of the theme.
function ThemeBase:on_loaded()
end

--- Called when the theme is unloaded. Does nothing by default.
function ThemeBase:on_unloaded()
end

--- Removes this theme from the list of registered themes.
function ThemeBase:remove()
  return Theme.remove_theme(self.id)
end

--- Registers a callback that creates a panel for this theme. This lets themes replace
-- the panels that are created with Theme.create_panel.
-- ```
-- self:add_panel('tab_menu', function(id, parent, ...)
--   return vgui.Create('fl_tab_menu', parent)
-- end)
-- ```
-- @param id [String panel ID]
-- @param callback [Function receives the panel ID, the parent panel and any extra arguments,
--   must return the created panel]
function ThemeBase:add_panel(id, callback)
  self.panels[id] = callback
end

--- Creates a panel using the callback registered with ThemeBase#add_panel.
-- @param id [String panel ID]
-- @param parent [Panel parent of the new panel, can be nil]
-- @param ... [Vararg extra arguments for the callback]
-- @return [Panel the created panel, or nil if no callback is registered for this ID]
function ThemeBase:create_panel(id, parent, ...)
  local callback = self.panels[id]

  if callback then
    return callback(id, parent, ...)
  end
end

--- Registers an asset of the theme. Models are precached, images (PNG and JPEG) are stored
-- as theme materials. When sizes are specified, the smallest scale that covers the height
-- of the screen relative to 720p is picked, and the image is loaded from the file with the
-- '_<scale>x' suffix instead.
-- ```
-- -- On a 1080p screen this loads 'materials/flux/gradient_2x.png'.
-- self:register_asset('gradient', 'materials/flux/gradient.png', { sizes = { 1, 2, 4 } })
-- ```
-- @param name [String key to store the material under]
-- @param path [String path to the asset]
-- @param options={} [Map sizes: List<Number> of available image scales, in ascending order]
-- @return [Material the stored material, nil if the asset is not an image]
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

--- Sets an option of the theme.
-- @param key [String]
-- @param value [Any]
-- @return [Any the value]
function ThemeBase:set_option(key, value)
  if key then
    self.options[key] = value
  end

  return self.options[key]
end

--- Sets a font of the theme. The font is derived from an existing one with Font.size.
-- ```
-- self:set_font('text_bar', 'flRoboto', math.scale(17), { weight = 600 })
-- ```
-- @param key [String]
-- @param value [String name of an existing font to base this one on]
-- @param scale=nil [Number font size, the base font is used as is if omitted]
-- @param data=nil [Map extra font data to override in the sized font]
-- @return [String name of the font that has been set]
function ThemeBase:set_font(key, value, scale, data)
  if key then
    self.fonts[key] = Font.size(value, scale, data)
  end

  return self.fonts[key]
end

--- Sets a color of the theme.
-- @param id [String]
-- @param val=Color(255, 255, 255) [Color]
-- @return [Color the color that has been set]
function ThemeBase:set_color(id, val)
  val = val or Color(255, 255, 255)

  self.colors[id] = val

  return val
end

--- Sets a material of the theme.
-- @param id [String]
-- @param val [String/Material material, or a path to load it from]
-- @return [Material]
function ThemeBase:set_material(id, val)
  self.materials[id] = (!isstring(val) and val) or util.get_material(val)
  return self.materials[id]
end

--- Sets a sound of the theme.
-- @param id [String]
-- @param val [String path to the sound]
-- @return [String the path that has been set]
function ThemeBase:set_sound(id, val)
  self.sounds[id] = val or Sound()
  return self.sounds[id]
end

--- Returns the name of a font of the theme.
-- @param key [String]
-- @param default=nil [String returned if the font is not set]
-- @return [String font name]
function ThemeBase:get_font(key, default)
  return self.fonts[key] or default
end

--- Returns an option of the theme.
-- @param key [String]
-- @param default=nil [Any returned if the option is not set or is false]
-- @return [Any value of the option]
function ThemeBase:get_option(key, default)
  return self.options[key] or default
end

--- Returns a color of the theme.
-- @param id [String]
-- @param failsafe=Color(255, 255, 255) [Color returned if the color is not set]
-- @return [Color]
function ThemeBase:get_color(id, failsafe)
  local col = self.colors[id]

  if col then
    return col
  else
    return failsafe or Color(255, 255, 255)
  end
end

--- Returns a material of the theme.
-- @param id [String]
-- @param failsafe=nil [Material returned if the material is not set]
-- @return [Material]
function ThemeBase:get_material(id, failsafe)
  local mat = self.materials[id]

  if mat then
    return mat
  else
    return failsafe
  end
end

--- Returns a sound of the theme.
-- @param id [String]
-- @param failsafe=nil [String returned if the sound is not set]
-- @return [String path to the sound]
function ThemeBase:get_sound(id, failsafe)
  local sound_path = self.sounds[id]

  if sound_path then
    return sound_path
  else
    return failsafe or Sound()
  end
end

--- Adds this theme to the list of registered themes.
-- @see [Theme.register_theme]
function ThemeBase:register()
  return Theme.register_theme(self)
end

--- Converts the theme to a string for printing.
-- @return [String]
function ThemeBase:__tostring()
  return '#<Theme:'..self.name..'>'
end
