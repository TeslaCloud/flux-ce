--- Player extension of the Settings plugin: reading the settings of a player on either realm.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Returns the value of a setting of the player.
-- On the server only networked settings are known, and only once the client of the player
-- has sent them, which happens shortly before PlayerInitialized runs for the player; until
-- then, for bots and for settings that are not networked the default of the setting is
-- returned. On the client the settings of the local player are read with
-- `ClientSettings:get`; those of other players are not known and are returned as their
-- defaults.
-- ```
-- function MyPlugin:PlayerInitialized(actor)
--   if actor:get_setting('my_plugin_clock_format') == '12h' then
--     -- ...
--   end
-- end
-- ```
-- @param id [String setting id]
-- @param default=nil [Any returned if the setting is not registered on this realm]
-- @return [Any value of the setting]
function player_meta:get_setting(id, default)
  local setting = ClientSettings:find(id)

  if !setting then
    return default
  end

  if CLIENT then
    if self == LocalPlayer() then
      return ClientSettings:get(id, default)
    end

    return setting.default
  end

  local values = self.client_settings

  if values and values[id] != nil then
    return values[id]
  end

  return setting.default
end
