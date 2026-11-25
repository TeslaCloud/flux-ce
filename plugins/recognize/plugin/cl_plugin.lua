--- Client side of the Recognize plugin that is not a hook handler: the history of the false
-- names that the local player has introduced their active character under, which the menus
-- offer again. Every character has a history of its own, kept in a data file named after
-- the ID of the character.

--- How many false names the history of a character keeps.
const name_history_size = 5

--- Returns the false names that the active character of the local player has introduced
-- itself under, the latest first.
-- @return [List<String> at most five names, empty without an active character]
function Recognition:get_name_history()
  local character_id = PLAYER:get_character_id()

  if !character_id then return {} end

  local history = Data.load('name_history/'..character_id, {})

  return istable(history) and history or {}
end

--- Puts a false name at the front of the history of the active character of the local
-- player, unless it is the real name of the character or in the history already. The oldest
-- name is dropped once the history is full.
-- @param name [String]
function Recognition:remember_false_name(name)
  local character_id = PLAYER:get_character_id()

  if !character_id or !isstring(name) or name == '' or name == PLAYER:name(true) then return end

  local history = self:get_name_history()

  if table.HasValue(history, name) then return end

  table.insert(history, 1, name)

  if #history > name_history_size then
    table.remove(history, name_history_size + 1)
  end

  Data.save('name_history/'..character_id, history)
end
