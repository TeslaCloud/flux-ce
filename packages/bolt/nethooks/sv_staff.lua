--- Server-side receivers of the staff page of the admin panel: sending the staff list, at
-- most twice a second for each player, and demoting a member of the staff, connected or not.
-- The sender needs the 'manage_permissions' permission.

local staff_list_interval = 0.5

Cable.receive('fl_bolt_staff_request', function(actor)
  if !actor:can('manage_permissions') then return end

  local cur_time = CurTime()

  if (actor.next_staff_list_request or 0) > cur_time then return end

  actor.next_staff_list_request = cur_time + staff_list_interval

  Bolt:send_staff_list(actor)
end)

Cable.receive('fl_bolt_demote', function(actor, steam_id)
  if !actor:can('manage_permissions') then return end
  if !player.is_steam_id(steam_id) then return end

  steam_id = player.normalize_steam_id(steam_id)

  Bolt:demote_steam_id(actor, steam_id, function(name)
    Command:notify_staff('command.role.remove.message', {
      player = get_player_name(actor),
      target = name
    })

    if IsValid(actor) and actor:can('manage_permissions') then
      Bolt:send_staff_list(actor)
    end
  end)
end)
