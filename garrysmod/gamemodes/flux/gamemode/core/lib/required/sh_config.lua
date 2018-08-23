-- This library is for serverside configs only!
-- For clientside configs, see cl_settings.lua!

library.New "config"

local stored = config.stored or {}
config.stored = stored

local cache = {}

function config.GetAll()
  return stored
end

function config.GetCache()
  return cache
end

if SERVER then
  function config.Set(key, value, bIsHidden, nFromConfig)
    if (key != nil) then
      if (!stored[key]) then
        stored[key] = {}

        if (PLUGIN) then
          stored[key].addedBy = PLUGIN:get_name()
        elseif (Schema) then
          stored[key].addedBy = "Schema"
        else
          stored[key].addedBy = "Flux"
        end

        if (isnumber(nFromConfig)) then
          if (nFromConfig == CONFIG_FLUX) then
            stored[key].addedBy = "Flux Config"
          elseif (nFromConfig == CONFIG_SCHEMA) then
            stored[key].addedBy = "Schema Config"
          elseif (PLUGIN and nFromConfig == CONFIG_PLUGIN) then
            stored[key].addedBy = PLUGIN:get_name().." Config"
          end
        end
      end

      stored[key].value = value

      if (stored[key].hidden == nil or bIsHidden != nil) then
        stored[key].hidden = bIsHidden or false
      end

      if (!stored[key].hidden) then
        netstream.Start(nil, "Flux::Config::SetVar", key, stored[key].value)
      end

      cache[key] = value
    end
  end

  local player_meta = FindMetaTable("Player")

  function player_meta:SendConfig()
    for k, v in pairs(stored) do
      if (!v.hidden) then
        netstream.Start(self, "Flux::Config::SetVar", k, v.value)
      end
    end

    player.flHasSentConfig = true
  end
else
  local menuItems = config.menuItems or {}
  config.menuItems = menuItems

  function config.Set(key, value)
    if (key != nil) then
      if (!stored[key]) then
        stored[key] = {}
      end

      stored[key].value = value
      cache[key] = value
    end
  end

  function config.CreateCategory(id, name, description)
    id = id or "other"

    menuItems[id] = {
      category = {name = name or "Other", description = description or ""},
      AddKey = function(key, name, description, dataType, data)
        config.AddToMenu(id, key, name, description, dataType, data)
      end,
      AddSlider = function(key, name, description, data)
        config.AddToMenu(id, key, name, description, "number", data)
      end,
      AddTableEditor = function(key, name, description, data)
        config.AddToMenu(id, key, name, description, "table", data)
      end,
      AddTextBox = function(key, name, description, data)
        config.AddToMenu(id, key, name, description, "string", data)
      end,
      AddCheckbox = function(key, name, description, data)
        config.AddToMenu(id, key, name, description, "bool", data)
      end,
      AddDropdown = function(key, name, description, data)
        config.AddToMenu(id, key, name, description, "dropdown", data)
      end,
      configs = {}
    }

    return menuItems[id]
  end

  function config.GetCategory(id)
    return menuItems[id]
  end

  function config.AddToMenu(category, key, name, description, dataType, data)
    if (!category or !key) then return end

    menuItems[category] = menuItems[category] or {}
    menuItems[category].configs = menuItems[category].configs or {}

    table.insert(menuItems[category].configs, {
      name = name or key,
      description = description or "This config has no description set.",
      type = dataType,
      data = data or {}
    })
  end

  function config.GetMenuKeys()
    return menuItems
  end

  netstream.Hook("Flux::Config::SetVar", function(key, value)
    if (key == nil) then return end

    print(key, value)

    stored[key] = stored[key] or {}
    stored[key].value = value
    cache[key] = value
  end)
end

function config.Get(key, default)
  if (cache[key]) then
    return cache[key]
  end

  if (stored[key] != nil) then
    if (stored[key].value != nil) then
      cache[key] = stored[key].value

      return stored[key].value
    end
  end

  cache[key] = default

  return default
end

if SERVER then
  function config.Import(contents, from_config)
    if (!isstring(contents) or contents == "") then return end

    local config_table = YAML.eval(contents)

    for k, v in pairs(config_table) do
      if (k != "depends" and plugin.call("ShouldConfigImport", k, v) == nil) then
        config.Set(k, v, nil, from_config)
      end
    end

    return config_table
  end
end
