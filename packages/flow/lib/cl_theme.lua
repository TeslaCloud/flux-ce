-- This library really hates being refreshed :/
if Theme then return end

mod 'Theme'

local stored          = Theme.stored        or {}
local current_theme   = Theme.current_theme or nil
local has_initialized = false
Theme.stored          = stored
Theme.current_theme   = current_theme

--- Returns all of the registered themes.
-- @return [Map themes by ID]
function Theme.all()
  return stored
end

--- Registers a theme. If the theme has a registered parent, it is replaced with a copy
-- of the parent that has the theme merged on top of it.
-- @param obj [ThemeBase]
function Theme.register_theme(obj)
  if obj.parent then
    local parent_theme = stored[obj.parent:to_id()]

    if parent_theme then
      local new_obj = table.Copy(parent_theme)

      obj.Theme = nil

      table.safe_merge(new_obj, obj)

      obj = new_obj
      obj.base = parent_theme
    end
  end

  stored[obj.id] = obj
end

--- Creates a panel through the active theme, using the callback the theme has registered
-- with ThemeBase#add_panel. Can be prevented with the 'ShouldThemeCreatePanel' hook.
-- @param panel_id [String ID the panel was added to the theme with]
-- @param parent [Panel parent of the new panel, can be nil]
-- @param ... [Vararg extra arguments for the theme's callback]
-- @return [Panel the created panel, or nil if the active theme did not create one]
function Theme.create_panel(panel_id, parent, ...)
  if current_theme and hook.Run('ShouldThemeCreatePanel', panel_id, current_theme) != false then
    return current_theme:create_panel(panel_id, parent, ...)
  end
end

--- Calls a method of the active theme in protected mode. Errors are printed to the console
-- instead of being raised. Also available as Theme.call.
-- ```
-- function PANEL:Paint(w, h)
--   Theme.hook('PaintButton', self, w, h)
-- end
-- ```
-- @param id [String name of the theme method]
-- @param ... [Vararg arguments to pass to the method]
-- @return [Any everything the method has returned; nil if there is no active theme,
--   it has no such method or the method has failed]
function Theme.hook(id, ...)
  if isstring(id) and current_theme and current_theme[id] then
    local result = { pcall(current_theme[id], current_theme, ...) }
    local success = result[1]
    table.remove(result, 1)

    if !success then
      ErrorNoHalt('Theme hook "'..id..'" has failed to run!\n')
      error_with_traceback(result[1])
    else
      return unpack(result)
    end
  end
end

Theme.call = Theme.hook

--- Returns the ID of the theme that is currently loaded.
-- @return [String theme ID, or nil if no theme is loaded]
function Theme.get_active_theme()
  return (current_theme and current_theme.id)
end

--- Sets a sound of the active theme.
-- @param key [String]
-- @param value [String path to the sound]
-- @see [ThemeBase#set_sound]
function Theme.set_sound(key, value)
  if current_theme then
    current_theme:set_sound(key, value)
  end
end

--- Returns a sound of the active theme.
-- @param key [String]
-- @param fallback=nil [String returned if the sound is not set or no theme is loaded]
-- @return [String path to the sound]
function Theme.get_sound(key, fallback)
  if current_theme then
    return current_theme:get_sound(key, fallback)
  end

  return fallback
end

--- Sets a color of the active theme.
-- @param key [String]
-- @param value=Color(255, 255, 255) [Color]
-- @see [ThemeBase#set_color]
function Theme.set_color(key, value)
  if current_theme then
    current_theme:set_color(key, value)
  end
end

--- Sets a font of the active theme.
-- @param key [String]
-- @param value [String name of an existing font to base this one on]
-- @param scale=nil [Number font size, the base font is used as is if omitted]
-- @param data=nil [Map extra font data to override in the sized font]
-- @see [ThemeBase#set_font]
function Theme.set_font(key, value, scale, data)
  if current_theme then
    current_theme:set_font(key, value, scale, data)
  end
end

--- Returns a color of the active theme.
-- @param key [String]
-- @param fallback=nil [Color returned if the color is not set or no theme is loaded]
-- @return [Color the color; white if a theme is loaded but has neither it nor a fallback]
function Theme.get_color(key, fallback)
  if current_theme then
    return current_theme:get_color(key, fallback)
  end

  return fallback
end

--- Returns the name of a font of the active theme.
-- @param key [String]
-- @param fallback=nil [String returned if the font is not set or no theme is loaded]
-- @return [String font name]
function Theme.get_font(key, fallback)
  if current_theme then
    return current_theme:get_font(key, fallback)
  end

  return fallback
end

--- Sets an option of the active theme.
-- @param key [String]
-- @param value [Any]
-- @see [ThemeBase#set_option]
function Theme.set_option(key, value)
  if current_theme then
    current_theme:set_option(key, value)
  end
end

--- Sets a material of the active theme.
-- @param key [String]
-- @param value [String/Material material, or a path to load it from]
-- @see [ThemeBase#set_material]
function Theme.set_material(key, value)
  if current_theme then
    current_theme:set_material(key, value)
  end
end

--- Returns a material of the active theme.
-- @param key [String]
-- @param fallback=nil [Material returned if the material is not set or no theme is loaded]
-- @return [Material]
function Theme.get_material(key, fallback)
  if current_theme then
    return current_theme:get_material(key, fallback)
  end

  return fallback
end

--- Returns an option of the active theme.
-- @param key [String]
-- @param fallback=nil [Any returned if the option is not set (or false), or no theme is loaded]
-- @return [Any value of the option]
function Theme.get_option(key, fallback)
  if current_theme then
    return current_theme:get_option(key, fallback)
  end

  return fallback
end

--- Finds a registered theme.
-- @param id [String ID or name of the theme, converted with string.to_id]
-- @return [ThemeBase the theme, or nil if it is not registered]
function Theme.find_theme(id)
  return stored[id:to_id()]
end

--- Removes a theme from the list of registered themes.
-- @param id [String theme ID]
function Theme.remove_theme(id)
  if Theme.find_theme(id) then
    stored[id] = nil
  end
end

--- Copies the skin overrides of the active theme into the 'Flux' Derma skin
-- and refreshes the skins of all panels.
function Theme.set_derma_skin()
  if current_theme then
    local skin_table = derma.GetNamedSkin('Flux')

    for k, v in pairs(current_theme.skin) do
      skin_table[k] = v
    end
  end

  derma.RefreshSkins()
end

--- Makes the specified theme the active one. Calls on_loaded of every theme it derives from
-- and of the theme itself, applies its Derma skin, and runs the 'OnThemeLoaded' hook.
-- Unless reloading, it can be prevented with the 'ShouldThemeLoad' hook.
-- @param themeID [String ID of a registered theme]
-- @param reloading=false [Boolean skips the 'ShouldThemeLoad' hook and the theme's own on_loaded]
function Theme.load_theme(themeID, reloading)
  local theme_table = Theme.find_theme(themeID)

  if theme_table then
    if !reloading and hook.Run('ShouldThemeLoad', theme_table) == false then
      return
    end

    current_theme = theme_table

    local next = theme_table.base

    while next do
      if next.on_loaded then
        next.on_loaded(current_theme)
      end

      next = next.base
    end

    if !reloading and current_theme.on_loaded then
      current_theme:on_loaded()
    end

    Theme.set_derma_skin()

    hook.Run('OnThemeLoaded', current_theme)
  end
end

--- Unloads the active theme, calling its on_unloaded method and the 'OnThemeUnloaded' hook.
-- Can be prevented with the 'ShouldThemeUnload' hook.
function Theme.unload_theme()
  if hook.Run('ShouldThemeUnload', current_theme) == false then
    return
  end

  if current_theme.on_unloaded then
    current_theme:on_unloaded()

    hook.Run('OnThemeUnloaded', current_theme)
  end

  current_theme = nil
end

--- Loads the active theme again, then calls its 'OnReloaded' method and the 'OnThemeReloaded'
-- hook. Does nothing if the theme has should_reload set to false, or if the
-- 'ShouldThemeReload' hook returns false.
function Theme.reload()
  if !current_theme then return end

  if (current_theme.should_reload == false) or hook.Run('ShouldThemeReload', current_theme) == false then
    return
  end

  Theme.load_theme(current_theme.id)

  Theme.hook('OnReloaded')
  hook.Run('OnThemeReloaded', current_theme)
end

--- Checks whether the default theme has been loaded for the local player.
-- @return [Boolean]
function Theme.initialized()
  return has_initialized
end

do
  local theme_hooks = {}

  --- Loads the default theme of the schema, or the 'factory' theme if there is none.
  function theme_hooks:PlayerInitialized()
    if !SCHEMA or !SCHEMA.default_theme then
      Theme.load_theme('factory')
    else
      Theme.load_theme(SCHEMA.default_theme or 'factory')
    end

    has_initialized = true
  end

  --- Reloads the active theme when the code is refreshed.
  function theme_hooks:OnReloaded()
    Theme.reload()
  end

  Plugin.add_hooks('flThemeHooks', theme_hooks)
end
