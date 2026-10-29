--- Client-side receivers of the RolePlay Commands plugin: the static texts that the server
-- sends, adds and removes.

Cable.receive('fl_static_text_add', function(data)
  table.insert(RPCommands.texts, data)
end)

Cable.receive('fl_static_text_set', function(data)
  RPCommands.texts = data
end)

Cable.receive('fl_static_text_remove', function(id)
  table.remove(RPCommands.texts, id)
end)
