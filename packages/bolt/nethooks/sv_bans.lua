--- Server-side receivers of the ban list page of the admin panel: sending a page of the ban
-- list, at most four times a second for each player, and lifting a ban. The sender needs the
-- 'ban' permission.

local ban_list_interval = 0.25

Cable.receive('fl_bolt_bans_request', function(actor, page, search_text)
  if !actor:can('ban') then return end

  local cur_time = CurTime()

  if (actor.next_ban_list_request or 0) > cur_time then return end

  actor.next_ban_list_request = cur_time + ban_list_interval

  Bolt:send_ban_list(actor, page, search_text)
end)

Cable.receive('fl_bolt_unban', function(actor, steam_id)
  if !actor:can('ban') then return end
  if !isstring(steam_id) or steam_id == '' then return end

  local success, data = Bolt:remove_ban(steam_id)

  if success then
    Command:notify_staff('command.ban.remove.message', {
      player = get_player_name(actor),
      target = data.name
    })
  else
    actor:notify('error.not_banned', { steam_id = steam_id })
  end
end)
