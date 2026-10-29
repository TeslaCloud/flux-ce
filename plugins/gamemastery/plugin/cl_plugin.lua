--- Client side of the Gamemastery plugin: keeps the list of pool characters that the server
-- sends and sends the requests of the gamemaster panel.

Gamemastery.pool = Gamemastery.pool or {}

--- Returns the list of pool characters the server has sent last.
-- @return [List<Map> entries with the id, name, model, skin, phys_desc, faction, banned,
--   possessed_by and in_world fields]
function Gamemastery.get_pool()
  return Gamemastery.pool
end

--- Finds a pool character in the list the server has sent.
-- @param id [Number character ID]
-- @return [Map the entry, nil when the list has none with the ID]
function Gamemastery.find_character(id)
  for _, char_data in ipairs(Gamemastery.pool) do
    if char_data.id == id then
      return char_data
    end
  end
end

--- Checks whether the local player plays a pool character.
-- @param entry [Map an entry of the pool list]
-- @return [Boolean]
function Gamemastery.is_possessing(entry)
  return IsValid(PLAYER) and istable(entry) and PLAYER:get_character_id() == entry.id
end

--- Asks the server for the list of pool characters.
function Gamemastery.request_pool()
  Cable.send('fl_gm_pool_request')
end

--- Asks the server to let the local player possess a pool character.
-- @param id [Number character ID]
function Gamemastery.request_possess(id)
  Cable.send('fl_gm_possess', id)
end

--- Asks the server to let the local player release the pool character they play.
function Gamemastery.request_release()
  Cable.send('fl_gm_release')
end

--- Asks the server to place a pool character in the world, where a trace from the eyes of
-- the local player along a direction hits.
-- @param id [Number character ID]
-- @param direction [Vector direction in world space]
function Gamemastery.request_spawn(id, direction)
  Cable.send('fl_gm_spawn', id, direction)
end

--- Asks the server to delete a pool character.
-- @param id [Number character ID]
function Gamemastery.request_delete(id)
  Cable.send('fl_gm_delete', id)
end
