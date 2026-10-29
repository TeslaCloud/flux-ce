--- The static texts of the RolePlay Commands plugin on the server: adding and removing them,
-- which sends the change to every player, and saving and loading them with the plugin data.

if !RPCommands then
  PLUGIN:set_global('RPCommands')
end

--- Adds a static text, saves it and sends it to all players.
-- @param data [Table static text with pos, text, name, steamid and time fields]
function RPCommands.add_static_text(data)
  table.insert(RPCommands.texts, data)

  RPCommands:save()

  Cable.send(nil, 'fl_static_text_add', data)
end

--- Removes a static text, saves the change and removes it for all players.
-- @param id [Number index of the static text]
function RPCommands.remove_static_text(id)
  table.remove(RPCommands.texts, id)

  RPCommands:save()

  Cable.send(nil, 'fl_static_text_remove', id)
end

--- Saves the static texts to the plugin data.
function RPCommands:save()
  Data.save_plugin('rptexts', RPCommands.texts)
end

--- Loads the static texts from the plugin data.
function RPCommands:load()
  self.texts = Data.load_plugin('rptexts', {})
end
