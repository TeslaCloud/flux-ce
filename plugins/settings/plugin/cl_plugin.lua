--- Client side of the Settings plugin: the values of the settings. They are loaded from the
-- 'settings' file of the client data store when the plugin loads, read with
-- `ClientSettings:get`, changed with `ClientSettings:set` and `ClientSettings:reset`, written
-- back to the file shortly after a change, and sent to the server if their setting is
-- networked.

local stored = ClientSettings.stored
local values = ClientSettings.values or Data.load('settings', {})

if !istable(values) then
  values = {}
end

ClientSettings.values = values

local cache = ClientSettings.cache or {}
ClientSettings.cache = cache

local pending = {}

--- Starts or restarts the timer that writes the values to the data store a second after
-- the last change, so that a slider being dragged does not write the file on every step.
local function queue_save()
  timer.Create('fl_settings_save', 1, 1, function()
    ClientSettings:save()
  end)
end

--- Marks a networked setting as changed and starts or restarts the timer that sends the
-- changed settings to the server a quarter of a second after the last change. Nothing is
-- sent before the settings have been sent for the first time, which happens when the
-- map's entities have been created.
-- @param id [String setting id]
local function queue_sync(id)
  pending[id] = true

  if !ClientSettings.ready then return end

  timer.Create('fl_settings_sync', 0.25, 1, function()
    ClientSettings:sync()
  end)
end

--- Saves, networks and announces a change of the value of a setting.
-- @param setting [Map setting definition]
-- @param value [Any new value]
-- @param old_value [Any previous value]
local function value_changed(setting, value, old_value)
  if setting.networked then
    queue_sync(setting.id)
  end

  if isfunction(setting.on_change) then
    setting.on_change(value, old_value, setting)
  end

  --- Called on the client when the value of a setting has changed, after the `on_change`
  -- function of the setting. Do not return anything from the handler, or the plugins after
  -- it are not told.
  -- @param id [String setting id]
  -- @param value [Any new value of the setting]
  -- @param old_value [Any previous value of the setting]
  hook.Run('ClientSettingChanged', setting.id, value, old_value)
end

--- Reads the saved value of a setting again and checks it against the definition of the
-- setting; a saved value that is not valid for the setting is ignored. Called when a
-- setting is registered or removed.
-- @param id [String setting id]
function ClientSettings:load_value(id)
  if stored[id] then
    cache[id] = self:sanitize(id, values[id])
  else
    cache[id] = nil
  end
end

--- Returns the value of a setting: what the player has set it to, or its default.
-- ```
-- function MyPlugin:HUDPaint()
--   if ClientSettings:get('my_plugin_clock') then
--     draw.SimpleText(os.date('%H:%M'), Theme.get_font('text_small'), 16, 16, color_white)
--   end
-- end
-- ```
-- @param id [String setting id]
-- @param default=nil [Any returned if the setting is not registered]
-- @return [Any value of the setting]
function ClientSettings:get(id, default)
  local setting = stored[id]

  if !setting then
    return default
  end

  local value = cache[id]

  if value == nil then
    return setting.default
  end

  return value
end

--- Checks whether a setting is at its default value.
-- @param id [String setting id]
-- @return [Boolean true if it is, also if the setting is not registered]
function ClientSettings:is_default(id)
  local setting = stored[id]

  if !setting then
    return true
  end

  return self:get(id) == setting.default
end

--- Sets the value of a setting. The value is checked against the definition of the setting
-- first. If it differs from the current one, the `on_change` function of the setting and
-- the ClientSettingChanged hook run, and a networked setting is sent to the server.
-- @param id [String setting id]
-- @param value [Any new value]
-- @return [Boolean true if the value has been set, false if the setting is not registered or
--   the value is not valid for it]
function ClientSettings:set(id, value)
  local setting = stored[id]

  if !setting then
    return false
  end

  value = self:sanitize(id, value)

  if value == nil then
    return false
  end

  local old_value = self:get(id)

  cache[id] = value

  if values[id] != value then
    values[id] = value

    queue_save()
  end

  if value != old_value then
    value_changed(setting, value, old_value)
  end

  return true
end

--- Sets a setting back to its default value by forgetting what the player has set it to.
-- Runs the same callbacks as ClientSettings:set if that changes the value.
-- @param id [String setting id]
-- @return [Boolean true if the setting has been reset, false if it is not registered]
function ClientSettings:reset(id)
  local setting = stored[id]

  if !setting then
    return false
  end

  local old_value = self:get(id)

  cache[id] = nil

  if values[id] != nil then
    values[id] = nil

    queue_save()
  end

  if old_value != setting.default then
    value_changed(setting, setting.default, old_value)
  end

  return true
end

--- Checks whether a setting is listed in the settings menu: it is unless it has a
-- `visible` function that returns a falsy value. A setting that is not listed keeps its
-- value and can still be read and set from code.
-- @param id [String setting id]
-- @return [Boolean false if the setting is hidden or not registered]
function ClientSettings:is_visible(id)
  local setting = stored[id]

  if !setting then
    return false
  end

  if isfunction(setting.visible) then
    return setting.visible(setting) and true or false
  end

  return true
end

--- Groups the settings that are listed in the settings menu by category. The categories
-- are sorted by their translated name, the settings of a category by the order in which
-- they have been registered.
-- @return [List<Map> categories: id (String category phrase), name (String translated
--   name) and settings (List<Map> setting definitions)]
function ClientSettings:get_categories()
  local categories = {}
  local by_id = {}

  for id, setting in pairs(stored) do
    if self:is_visible(id) then
      local category = by_id[setting.category]

      if !category then
        category = { id = setting.category, name = t(setting.category), settings = {} }
        by_id[setting.category] = category

        table.insert(categories, category)
      end

      table.insert(category.settings, setting)
    end
  end

  for k, v in ipairs(categories) do
    table.sort(v.settings, function(a, b)
      return a.order < b.order
    end)
  end

  table.sort(categories, function(a, b)
    if a.name == b.name then
      return a.id < b.id
    end

    return a.name < b.name
  end)

  return categories
end

--- Writes the values of the settings to the 'settings' file of the client data store.
-- Called a second after a value has changed and when the game shuts down.
function ClientSettings:save()
  timer.Remove('fl_settings_save')

  Data.save('settings', values)
end

--- Sends the networked settings that have changed since the last time to the server.
-- Called a quarter of a second after a networked setting has changed.
function ClientSettings:sync()
  timer.Remove('fl_settings_sync')

  local data = {}
  local count = 0

  for id, v in pairs(pending) do
    local setting = stored[id]

    if setting and setting.networked then
      data[id] = self:get(id)
      count = count + 1
    end

    pending[id] = nil
  end

  if count > 0 then
    Cable.send('fl_settings_sync', data)
  end
end

--- Sends the value of every networked setting to the server.
-- Called when the map's entities have been created, which is when the client is first able
-- to tell the server, and when the settings are registered again after a code refresh.
function ClientSettings:sync_all()
  self.ready = true

  for id, setting in pairs(stored) do
    if setting.networked then
      pending[id] = true
    end
  end

  self:sync()
end
