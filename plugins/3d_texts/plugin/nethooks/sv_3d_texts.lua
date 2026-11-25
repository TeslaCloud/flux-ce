--- Server-side receivers of the 3D Texts plugin: removing the text or picture that a client
-- has found under the aim of its player, by its ID, for players with the 'manage_texts' or
-- 'manage_pictures' permission.

Cable.receive('fl_surface_text_remove', function(actor, id)
  if !IsValid(actor) or !isnumber(id) or !actor:can('manage_texts') then return end

  if SurfaceText:delete_text(id) then
    actor:notify('notification.3d_text.text_removed')
  end
end)

Cable.receive('fl_surface_picture_remove', function(actor, id)
  if !IsValid(actor) or !isnumber(id) or !actor:can('manage_pictures') then return end

  if SurfaceText:delete_picture(id) then
    actor:notify('notification.3d_picture.removed')
  end
end)
