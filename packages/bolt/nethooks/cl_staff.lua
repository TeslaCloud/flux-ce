--- Client-side receiver of the staff list, which hands what the server sends over to the
-- staff page of the admin panel. The page makes itself known as `Bolt.staff_list` when it is
-- created, and a list that arrives while it is not open is dropped.

Cable.receive('fl_bolt_staff', function(members)
  if IsValid(Bolt.staff_list) then
    Bolt.staff_list:set_members(members)
  end
end)
