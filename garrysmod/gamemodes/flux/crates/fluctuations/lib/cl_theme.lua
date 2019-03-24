-- This library really hates being refreshed :/
if Theme then return end

library 'Theme'

local stored = Theme.stored or {}
local current_theme = Theme.current_theme or nil
local has_initialized = false
Theme.stored = stored
Theme.current_theme = current_theme

function Theme.all()
  return stored
end

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

function Theme.create_panel(panel_id, parent, ...)
  if current_theme and hook.run('ShouldThemeCreatePanel', panel_id, current_theme) != false then
    return current_theme:create_panel(panel_id, parent, ...)
  end
end

function Theme.hook(id, ...)
  if isstring(id) and current_theme and current_theme[id] then
    local result = { pcall(current_theme[id], current_theme, ...) }
    local success = result[1]
    table.remove(result, 1)

    if !success then
      ErrorNoHalt('Theme hook "'..id..'" has failed to run!\n'..result[1]..'\n')
    else
      return unpack(result)
    end
  end
end

Theme.call = Theme.hook

function Theme.get_active_theme()
  return (current_theme and current_theme.id)
end

function Theme.set_sound(key, value)
  if current_theme then
    current_theme:set_sound(key, value)
  end
end

function Theme.get_sound(key, fallback)
  if current_theme then
    return current_theme:get_sound(key, fallback)
  end

  return fallback
end

function Theme.set_color(key, value)
  if current_theme then
    current_theme:set_color(key, value)
  end
end

function Theme.set_font(key, value, scale, data)
  if current_theme then
    current_theme:set_font(key, value, scale, data)
  end
end

function Theme.get_color(key, fallback)
  if current_theme then
    return current_theme:get_color(key, fallback)
  end

  return fallback
end

function Theme.get_font(key, fallback)
  if current_theme then
    return current_theme:get_font(key, fallback)
  end

  return fallback
end

function Theme.set_option(key, value)
  if current_theme then
    current_theme:set_option(key, value)
  end
end

function Theme.set_material(key, value)
  if current_theme then
    current_theme:set_material(key, value)
  end
end

function Theme.get_material(key, fallback)
  if current_theme then
    return current_theme:get_material(key, fallback)
  end

  return fallback
end

function Theme.get_option(key, fallback)
  if current_theme then
    return current_theme:get_option(key, fallback)
  end

  return fallback
end

function Theme.find_theme(id)
  return stored[id:to_id()]
end

function Theme.remove_theme(id)
  if Theme.find_theme(id) then
    stored[id] = nil
  end
end

function Theme.set_derma_skin()
  if current_theme then
    local skin_table = derma.GetNamedSkin('Flux')

    for k, v in pairs(current_theme.skin) do
      skin_table[k] = v
    end
  end

  derma.RefreshSkins()
end

function Theme.load_theme(themeID, reloading)
  local theme_table = Theme.find_theme(themeID)

  if theme_table then
    if !reloading and hook.run('ShouldThemeLoad', theme_table) == false then
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

    hook.run('OnThemeLoaded', current_theme)
  end
end

function Theme.unload_theme()
  if hook.run('ShouldThemeUnload', current_theme) == false then
    return
  end

  if current_theme.on_unloaded then
    current_theme:on_unloaded()

    hook.run('OnThemeUnloaded', current_theme)
  end

  current_theme = nil
end

function Theme.reload()
  if !current_theme then return end

  if (current_theme.should_reload == false) or hook.run('ShouldThemeReload', current_theme) == false then
    return
  end

  Theme.load_theme(current_theme.id)

  Theme.hook('OnReloaded')
  hook.run('OnThemeReloaded', current_theme)
end

function Theme.initialized()
  return has_initialized
end

do
  local theme_hooks = {}

  function theme_hooks:PlayerInitialized()
    if !Schema or !Schema.default_theme then
      Theme.load_theme('factory')
    else
      Theme.load_theme(Schema.default_theme or 'factory')
    end

    has_initialized = true
  end

  function theme_hooks:OnReloaded()
    Theme.reload()
  end

  Plugin.add_hooks('flThemeHooks', theme_hooks)
end
