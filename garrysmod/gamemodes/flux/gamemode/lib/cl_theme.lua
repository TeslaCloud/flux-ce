library.new "theme"
local current_theme = theme.current_theme or nil
theme.current_theme = current_theme
local stored = theme.stored or {}
theme.stored = stored

function theme.GetAll()
  return stored
end

function theme.RegisterTheme(obj)
  if (obj.parent) then
    local parentTheme = stored[obj.parent:to_id()]

    if (parentTheme) then
      local newObj = table.Copy(parentTheme)

      obj.Theme = nil

      table.safe_merge(newObj, obj)

      obj = newObj
      obj.base = parentTheme
    end
  end

  stored[obj.id] = obj
end

function theme.CreatePanel(panelID, parent, ...)
  if (current_theme and hook.run("ShouldThemeCreatePanel", panelID, current_theme) != false) then
    return current_theme:CreatePanel(panelID, parent, ...)
  end
end

function theme.Hook(id, ...)
  if (isstring(id) and current_theme and current_theme[id]) then
    local result = {pcall(current_theme[id], current_theme, ...)}
    local success = result[1]
    table.remove(result, 1)

    if (!success) then
      ErrorNoHalt("Theme hook '"..id.."' has failed to run!\n"..result[1].."\n")
    else
      return unpack(result)
    end
  end
end

theme.Call = theme.Hook

function theme.GetActiveTheme()
  return (current_theme and current_theme.id)
end

function theme.SetSound(key, value)
  if (current_theme) then
    current_theme:SetSound(key, value)
  end
end

function theme.GetSound(key, fallback)
  if (current_theme) then
    return current_theme:GetSound(key, fallback)
  end

  return fallback
end

function theme.SetColor(key, value)
  if (current_theme) then
    current_theme:SetColor(key, value)
  end
end

function theme.SetFont(key, value, scale, data)
  if (current_theme) then
    current_theme:SetFont(key, value, scale, data)
  end
end

function theme.GetColor(key, fallback)
  if (current_theme) then
    return current_theme:GetColor(key, fallback)
  end

  return fallback
end

function theme.GetFont(key, fallback)
  if (current_theme) then
    return current_theme:GetFont(key, fallback)
  end

  return fallback
end

function theme.SetOption(key, value)
  if (current_theme) then
    current_theme:SetOption(key, value)
  end
end

function theme.SetMaterial(key, value)
  if (current_theme) then
    current_theme:SetMaterial(key, value)
  end
end

function theme.GetMaterial(key, fallback)
  if (current_theme) then
    return current_theme:GetMaterial(key, fallback)
  end

  return fallback
end

function theme.GetOption(key, fallback)
  if (current_theme) then
    return current_theme:GetOption(key, fallback)
  end

  return fallback
end

function theme.FindTheme(id)
  return stored[id:to_id()]
end

function theme.RemoveTheme(id)
  if (theme.FindTheme(id)) then
    stored[id] = nil
  end
end

function theme.SetDermaSkin()
  if (current_theme) then
    local skinTable = derma.GetNamedSkin("Flux")

    for k, v in pairs(current_theme.skin) do
      skinTable[k] = v
    end
  end

  derma.RefreshSkins()
end

function theme.LoadTheme(themeID, bIsReloading)
  local themeTable = theme.FindTheme(themeID)

  if (themeTable) then
    if (!bIsReloading and hook.run("ShouldThemeLoad", themeTable) == false) then
      return
    end

    current_theme = themeTable

    local next = themeTable.base

    while (next) do
      if (next.OnLoaded) then
        next.OnLoaded(current_theme)
      end

      next = next.base
    end

    if (!bIsReloading and current_theme.OnLoaded) then
      current_theme:OnLoaded()
    end

    theme.SetDermaSkin()

    hook.run("OnThemeLoaded", current_theme)
  end
end

function theme.UnloadTheme()
  if (hook.run("ShouldThemeUnload", current_theme) == false) then
    return
  end

  if (current_theme.OnUnloaded) then
    current_theme:OnUnloaded()

    hook.run("OnThemeUnloaded", current_theme)
  end

  current_theme = nil
end

function theme.Reload()
  if (!current_theme) then return end

  if ((current_theme.should_reload == false) or hook.run("ShouldThemeReload", current_theme) == false) then
    return
  end

  theme.LoadTheme(current_theme.id)

  theme.Hook("OnReloaded")
  hook.run("OnThemeReloaded", current_theme)
end

do
  local themeHooks = {}

  function themeHooks:PlayerInitialized()
    if (!Schema or !Schema.DefaultTheme) then
      theme.LoadTheme("factory")
    else
      theme.LoadTheme(Schema.DefaultTheme or "factory")
    end
  end

  function themeHooks:OnReloaded()
    theme.Reload()
  end

  plugin.add_hooks("flThemeHooks", themeHooks)
end
