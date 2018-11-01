library.new('undo', fl)

local queue = {}
local buffer = {}

function fl.undo:create(id, name)
  buffer = {
    id = id,
    name = name,
    player = nil,
    functions = {}
  }
end

function fl.undo:add(callback, ...)
  table.insert(buffer.functions, {func = callback, args = {...}})
end

function fl.undo:set_player(player)
  buffer.player = player
end

function fl.undo:finish()
  if istable(buffer) and IsValid(buffer.player) then
    queue[buffer.player] = queue[buffer.player] or {}

    table.insert(queue[buffer.player], buffer)
  end

  buffer = {}
end

function fl.undo:remove(player, id)
  local queue_table = queue[player]

  if queue_table then
    for k, v in ipairs(queue_table) do
      if v.id == id then
        queue[player][k] = nil
      end
    end
  end
end

function fl.undo:execute(obj)
  if istable(obj) and istable(obj.functions) then
    for k, v in ipairs(obj.functions) do
      try {
        v.func, obj, unpack(v.args)
      } catch {
        function(exception)
          ErrorNoHalt('[Flux:Undo] Failed to undo!\n'..tostring(exception)..'\n')
        end
      }
    end
  end
end

function fl.undo:do_player(player)
  local count = (queue[player] and #queue[player]) or 0

  if count > 0 then
    -- do the top of the queue
    self:execute(queue[player][count])
    table.remove(queue[player], count)
  end
end

function fl.undo:get_player(player)
  return queue[player] or {}
end
