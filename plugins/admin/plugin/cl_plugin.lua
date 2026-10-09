--- Client side of the admin plugin: the network receivers that hand what the server sends
-- over to the pages of the admin panel. A page makes itself known to the plugin when it is
-- created (`Bolt.ban_list`, `Bolt.staff_list`, `Bolt.config_editor` and
-- `Bolt.plugin_manager`), and what arrives while it is not open is dropped.

Cable.receive('fl_bolt_bans', function(data)
  if IsValid(Bolt.ban_list) then
    Bolt.ban_list:set_bans(data)
  end
end)

Cable.receive('fl_bolt_bans_changed', function()
  if IsValid(Bolt.ban_list) then
    Bolt.ban_list:request_bans()
  end
end)

Cable.receive('fl_bolt_staff', function(members)
  if IsValid(Bolt.staff_list) then
    Bolt.staff_list:set_members(members)
  end
end)
