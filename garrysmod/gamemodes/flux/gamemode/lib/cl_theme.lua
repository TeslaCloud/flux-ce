library.new 'theme'
local current_theme = theme.current_theme or nil
theme.current_theme = current_theme
local stored = theme.stored or {}
theme.stored = stored

function theme.get_all()
  return stored
end

function theme.register_theme(obj)
  if obj.parent then
    local parent_theme = stored[obj.parent:to_id()]

    if parent_theme then
      local new_obj = table.Copy(parent_theme)

      obj.theme = nil

      table.safe_merge(new_obj, obj)

      obj = new_obj
      obj.base = parent_theme
    end
  end

  stored[obj.id] = obj
end

function theme.create_panel(panelID, parent, ...)
  if current_theme and hook.run('ShouldThemeCreatePanel', panelID, current_theme) != false then
    return current_theme:create_panel(panelID, parent, ...)
  end
end

function theme.hook(id, ...)
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

theme.call = theme.hook

function theme.get_active_theme()
  return (current_theme and current_theme.id)
end

function theme.set_sound(key, value)
  if current_theme then
    current_theme:set_sound(key, value)
  end
end

function theme.get_sound(key, fallback)
  if current_theme then
    return current_theme:get_sound(key, fallback)
  end

  return fallback
end

function theme.set_color(key, value)
  if current_theme then
    current_theme:set_color(key, value)
  end
end

function theme.set_font(key, value, scale, data)
  if current_theme then
    current_theme:set_font(key, value, scale, data)
  end
end

function theme.get_color(key, fallback)
  if current_theme then
    return current_theme:get_color(key, fallback)
  end

  return fallback
end

function theme.get_font(key, fallback)
  if current_theme then
    return current_theme:get_font(key, fallback)
  end

  return fallback
end

function theme.set_option(key, value)
  if current_theme then
    current_theme:set_option(key, value)
  end
end

function theme.set_material(key, value)
  if current_theme then
    current_theme:set_material(key, value)
  end
end

function theme.get_material(key, fallback)
  if current_theme then
    return current_theme:get_material(key, fallback)
  end

  return fallback
end

function theme.get_option(key, fallback)
  if current_theme then
    return current_theme:get_option(key, fallback)
  end

  return fallback
end

function theme.find_theme(id)
  return stored[id:to_id()]
end

function theme.remove_theme(id)
  if theme.find_theme(id) then
    stored[id] = nil
  end
end

function theme.set_derma_skin()
  if current_theme then
    local skin_table = derma.GetNamedSkin('Flux')

    for k, v in pairs(current_theme.skin) do
      skin_table[k] = v
    end
  end

  derma.RefreshSkins()
end

function theme.load_theme(themeID, b_is_reloading)
  local theme_table = theme.find_theme(themeID)

  if theme_table then
    if !b_is_reloading and hook.run('ShouldThemeLoad', theme_table) == false then
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

    if !b_is_reloading and current_theme.on_loaded then
      current_theme:on_loaded()
    end

    theme.set_derma_skin()

    hook.run('OnThemeLoaded', current_theme)
  end
end

function theme.unload_theme()
  if hook.run('ShouldThemeUnload', current_theme) == false then
    return
  end

  if current_theme.on_unloaded then
    current_theme:on_unloaded()

    hook.run('OnThemeUnloaded', current_theme)
  end

  current_theme = nil
end

function theme.reload()
  if !current_theme then return end

  if (current_theme.should_reload == false) or hook.run('ShouldThemeReload', current_theme) == false then
    return
  end

  theme.load_theme(current_theme.id)

  theme.hook('OnReloaded')
  hook.run('OnThemeReloaded', current_theme)
end

do
  local theme_hooks = {}

  function theme_hooks:PlayerInitialized()
    if !Schema or !Schema.DefaultTheme then
      theme.load_theme('factory')
    else
      theme.load_theme(Schema.DefaultTheme or 'factory')
    end
  end

  function theme_hooks:OnReloaded()
    theme.reload()
  end

  plugin.add_hooks('flThemeHooks', theme_hooks)
end
