--- Server side of the Settings plugin: receives the networked settings of the players.
-- A client sends all of its networked settings when it joins and the changed ones afterward.
-- Every value is checked against the definition of its setting before it is stored on the
-- player, where `Player:get_setting` reads it.

Cable.receive('fl_settings_sync', function(actor, data)
  if !istable(data) then return end

  local values = actor.client_settings or {}
  actor.client_settings = values

  for id, setting in pairs(ClientSettings:all()) do
    if !setting.networked then continue end

    local value = ClientSettings:sanitize(id, data[id])

    if value == nil then continue end

    local old_value = actor:get_setting(id)

    values[id] = value

    if value != old_value then
      --- Called on the server when a networked setting of a player has changed, and for
      -- every networked setting that is not at its default value when the player joins.
      -- The settings of a joining player arrive before `PlayerInitialized` runs for them, so
      -- the player may not be initialized yet. Do not return anything from the handler, or
      -- the plugins after it are not told.
      -- @param actor [Player The player whose setting has changed]
      -- @param id [String setting id]
      -- @param value [Any new value of the setting]
      -- @param old_value [Any previous value of the setting]
      hook.Run('PlayerSettingChanged', actor, id, value, old_value)
    end
  end
end)
