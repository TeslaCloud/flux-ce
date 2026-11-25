--- The static texts of the RolePlay Commands plugin on the server: adding and removing them,
-- which sends the change to every player, and saving and loading them with the plugin data.
-- Only the players who may see who placed a text (see `RPCommands:can_see_static_text_authors`)
-- receive the name and the SteamID of its author.

if !RPCommands then
  PLUGIN:set_global('RPCommands')
end

--- Returns a static text as the players who may not see its author receive it.
-- @param data [Map static text]
-- @return [Map the position, the text and the time of the static text]
local function without_author(data)
  return { pos = data.pos, text = data.text, time = data.time }
end

--- Checks whether a player is sent the name and the SteamID of the authors of static texts,
-- which staff see when they hold Alt.
-- @param target [Player]
-- @return [Boolean]
function RPCommands:can_see_static_text_authors(target)
  return target:is_assistant()
end

--- Counts the static texts that a player has placed.
-- @param steamid [String SteamID of the player]
-- @return [Number]
function RPCommands:count_static_texts(steamid)
  local count = 0

  for _, text_data in pairs(self.texts) do
    if text_data.steamid == steamid then
      count += 1
    end
  end

  return count
end

--- Sends every static text to a player, with or without their authors.
-- @param target [Player]
function RPCommands:send_static_texts(target)
  local texts = self.texts

  if !self:can_see_static_text_authors(target) then
    local public = {}

    for index, text_data in ipairs(texts) do
      public[index] = without_author(text_data)
    end

    texts = public
  end

  Cable.send(target, 'fl_static_text_set', texts)
end

--- Adds a static text, saves it and sends it to all players.
-- @param data [Table static text with pos, text, name, steamid and time fields]
function RPCommands.add_static_text(data)
  table.insert(RPCommands.texts, data)

  RPCommands:save()

  local staff, others = {}, {}

  for _, target in player.Iterator() do
    local list = RPCommands:can_see_static_text_authors(target) ? staff : others

    list[#list + 1] = target
  end

  if #staff > 0 then
    Cable.send(staff, 'fl_static_text_add', data)
  end

  if #others > 0 then
    Cable.send(others, 'fl_static_text_add', without_author(data))
  end
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
