--- Client-side receivers of the ban list messages, which hand what the server sends over to
-- the ban list page of the admin panel. The page makes itself known as `Bolt.ban_list` when
-- it is created, and what arrives while it is not open is dropped.

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
