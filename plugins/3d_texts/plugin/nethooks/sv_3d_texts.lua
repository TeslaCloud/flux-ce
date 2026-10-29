--- Server-side receivers of the 3D Texts plugin: removing the text or picture that a client
-- has found under the aim of its player, for players with the 'manage_texts' or
-- 'manage_pictures' permission.

local remove = table.remove
local cable_send = Cable.send

Cable.receive('fl_surface_text_remove', function(actor, idx)
  idx = tonumber(idx)

  if idx and SurfaceText.texts[idx] and actor:can('manage_texts') then
    remove(SurfaceText.texts, idx)

    SurfaceText:save()

    cable_send(nil, 'fl_surface_text_remove', idx)

    actor:notify('notification.3d_text.text_removed')
  end
end)

Cable.receive('fl_surface_picture_remove', function(actor, idx)
  idx = tonumber(idx)

  if idx and SurfaceText.pictures[idx] and actor:can('manage_pictures') then
    remove(SurfaceText.pictures, idx)

    SurfaceText:save()

    cable_send(nil, 'fl_surface_picture_remove', idx)

    actor:notify('notification.3d_picture.removed')
  end
end)
