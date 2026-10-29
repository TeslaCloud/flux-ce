--- Server-side receivers of the config editor of the admin panel: changing and resetting the
-- value of a config. The sender needs the permission to edit configs, and every change that
-- has an effect is announced to the staff.

local function config_values_equal(first, second)
  return first == second or (istable(first) and istable(second) and table.equal(first, second))
end

--- Finds the config that a request of the config editor is about, if its sender may edit
-- it: they need the permission to edit configs, and the config has to exist and must not
-- be hidden, since the editor never lists hidden configs.
-- @param actor [Player the player who sent the request]
-- @param key [Any the value received as the config key]
-- @return [Map the stored config, or nil if the request is to be ignored]
local function editable_config(actor, key)
  if !Config.can_manage(actor) or !isstring(key) then return end

  local entry = Config.find(key)

  if entry and !entry.hidden then
    return entry
  end
end

--- Tells staff that a player has changed a config. The value is shown the way
-- Config.display_value writes it, which masks private configs, and a change that waits for
-- a restart is announced as such.
-- @param actor [Player the player who made the change]
-- @param key [String config key]
-- @param value [Any the value as it was stored]
-- @param pending [Boolean true if the value only takes effect after a restart]
local function announce_config_change(actor, key, value, pending)
  local definition = Config.get_definition(key)

  Command:notify_staff(pending ? 'notification.config_changed_restart' : 'notification.config_changed', {
    player = get_player_name(actor),
    config = definition and definition.name or key,
    value = Config.display_value(key, value)
  })
end

Cable.receive('fl_config_change', function(actor, key, value)
  if !editable_config(actor, key) then return end

  local old_value = Config.get(key)
  local had_pending = Config.get_pending(key)
  local success, result, pending = Config.change(key, value)

  if !success then
    actor:notify(result)

    return
  end

  if pending or had_pending or !config_values_equal(old_value, result) then
    announce_config_change(actor, key, result, pending)
  end
end)

Cable.receive('fl_config_reset', function(actor, key)
  if !editable_config(actor, key) then return end

  local old_value = Config.get(key)
  local had_pending = Config.get_pending(key)
  local success, result, pending = Config.reset(key)

  if !success then
    actor:notify(result)

    return
  end

  if pending or had_pending or !config_values_equal(old_value, result) then
    announce_config_change(actor, key, result, pending)
  end
end)
