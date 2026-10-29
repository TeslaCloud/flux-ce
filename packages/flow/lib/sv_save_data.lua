--- Saves all persistent data of the server: the config and whatever the `SaveData` handlers of
-- the plugins and the schema save. Runs every `data_save_interval` seconds and when the
-- server shuts down or changes the map.
-- @module [Flux]

--- Saves all persistent data, unless a ShouldSaveData handler returns false: runs the
-- PreSaveData hook, saves the config, then runs the SaveData and PostSaveData hooks.
function Flux.save_data()
  --- Asks whether the persistent data may be saved now. Called on the server every
  -- `data_save_interval` seconds (360 unless configured), for the first time about ten
  -- seconds after the server has started, and when the server shuts down or changes the map.
  -- @return [Boolean Return false to skip this save]
  if hook.Run('ShouldSaveData') == false then return end

  --- Called on the server at the start of a data save, before the config is saved and before
  -- the `SaveData` handlers run, for work that the saved state depends on. The return value
  -- is ignored; a save is skipped with `ShouldSaveData`.
  hook.Run('PreSaveData')

  Config.save()

  --- Called on the server for plugins to save their persistent data, from `Flux.save_data`
  -- after the config has been saved. The counterpart of `LoadData`.
  hook.Run('SaveData')
  --- Called on the server after a data save, when the config has been saved and every
  -- `SaveData` handler has run. This is the place for work that depends on the saved
  -- state, such as a backup or a log entry. Database queries that the handlers have
  -- started may still be running.
  hook.Run('PostSaveData')
end
