library 'Flux::Undo'

local queue   = {}
local buffer  = {}

function Flux.Undo:create(id, name)
  buffer = {
    id = id,
    name = name,
    player = nil,
    functions = {}
  }
end

function Flux.Undo:add(callback, ...)
  table.insert(buffer.functions, { func = callback, args = { ... } })
end

function Flux.Undo:set_player(player)
  buffer.player = player
end

function Flux.Undo:finish()
  if istable(buffer) and IsValid(buffer.player) then
    queue[buffer.player] = queue[buffer.player] or {}

    table.insert(queue[buffer.player], buffer)
  end

  buffer = {}
end

function Flux.Undo:remove(player, id)
  local queue_table = queue[player]

  if queue_table then
    for k, v in ipairs(queue_table) do
      if v.id == id then
        queue[player][k] = nil
      end
    end
  end
end

function Flux.Undo:execute(obj)
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

function Flux.Undo:do_player(player)
  local count = (queue[player] and #queue[player]) or 0

  if count > 0 then
    -- do the top of the queue
    self:execute(queue[player][count])
    table.remove(queue[player], count)
  end
end

function Flux.Undo:get_player(player)
  return queue[player] or {}
end
