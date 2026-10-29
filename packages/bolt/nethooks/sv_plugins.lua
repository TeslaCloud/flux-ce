--- Server-side receiver of the plugin manager of the admin panel: disabling and enabling a
-- plugin, which takes effect when the server restarts. The sender needs the
-- 'manage_plugins' permission, and every change is announced to the staff.

local function known_plugin_name(id)
  for _, plugin_info in ipairs(Plugin.known()) do
    if plugin_info.id == id then
      return plugin_info.name
    end
  end

  return id
end

Cable.receive('fl_bolt_plugin_set_disabled', function(actor, id, disabled, force)
  if !actor:can('manage_plugins') then return end
  if !isstring(id) or !isbool(disabled) then return end

  id = Plugin.normalize_id(id)

  if !id then return end

  if Plugin.disabled_on_restart(id) == disabled then return end

  local name = known_plugin_name(id)
  local success, phrase, dependents = Plugin.set_disabled(id, disabled, force == true)

  if !success then
    actor:notify(phrase, { plugins = table.concat(dependents or {}, ', ') })

    return
  end

  Command:notify_staff(disabled ? 'notification.plugin_disabled' : 'notification.plugin_enabled', {
    player = get_player_name(actor),
    plugin = name
  })
end)
