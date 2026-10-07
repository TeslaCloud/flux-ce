mod 'Flux::Undo'

local queue   = {}
local buffer  = {}

--- Starts a new undo entry. Add callbacks to it with Flux.Undo#add, assign it to a player
-- and finish it to put it into the undo queue of that player.
-- ```
-- Flux.Undo:create('prop', 'Prop')
-- Flux.Undo:add(function(obj, ent)
--   if IsValid(ent) then
--     ent:Remove()
--   end
-- end, entity)
-- Flux.Undo:set_player(owner)
-- Flux.Undo:finish()
-- ```
-- @param id [String ID of the entry, entries can be removed by it]
-- @param name [String name of the entry]
function Flux.Undo:create(id, name)
  buffer = {
    id = id,
    name = name,
    player = nil,
    functions = {}
  }
end

--- Adds a function to call when the current undo entry is undone.
-- @param callback [Function receives the undo entry (Map), followed by the extra arguments]
-- @param ... [Vararg extra arguments for the callback]
function Flux.Undo:add(callback, ...)
  table.insert(buffer.functions, { func = callback, args = { ... } })
end

--- Sets the player that the current undo entry belongs to.
-- @param owner [Player]
function Flux.Undo:set_player(owner)
  buffer.player = owner
end

--- Puts the current undo entry on top of its player's undo queue. The entry is discarded
-- if it has no valid player.
function Flux.Undo:finish()
  if istable(buffer) and IsValid(buffer.player) then
    queue[buffer.player] = queue[buffer.player] or {}

    table.insert(queue[buffer.player], buffer)
  end

  buffer = {}
end

--- Removes the undo entries with the specified ID from the undo queue of a player.
-- @param owner [Player]
-- @param id [String ID the entries were created with]
function Flux.Undo:remove(owner, id)
  local queue_table = queue[owner]

  if queue_table then
    for k, v in ipairs(queue_table) do
      if v.id == id then
        queue[owner][k] = nil
      end
    end
  end
end

--- Calls all of the callbacks of an undo entry.
-- @param obj [Map undo entry]
function Flux.Undo:execute(obj)
  if istable(obj) and istable(obj.functions) then
    for k, v in ipairs(obj.functions) do
      local success, exception = pcall(v.func, obj, unpack(v.args))

      if !success then
        error_with_traceback('[Undo] Failed to undo!\n'..tostring(exception))
      end
    end
  end
end

--- Undoes the most recent entry in the undo queue of a player and removes it from the queue.
-- @param owner [Player]
function Flux.Undo:do_player(owner)
  local count = (queue[owner] and #queue[owner]) or 0

  if count > 0 then
    -- do the top of the queue
    self:execute(queue[owner][count])
    table.remove(queue[owner], count)
  end
end

--- Returns the undo queue of a player.
-- @param owner [Player]
-- @return [List<Map> undo entries, oldest first]
function Flux.Undo:get_player(owner)
  return queue[owner] or {}
end
