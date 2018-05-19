--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

library.New("undo", fl)

local queue = {}
local buffer = {}

function fl.undo:Create(id, name)
  buffer = {
    uniqueID = id,
    name = name,
    player = nil,
    functions = {}
  }
end

function fl.undo:Add(callback, ...)
  table.insert(buffer.functions, {func = callback, args = {...}})
end

function fl.undo:SetPlayer(player)
  buffer.player = player
end

function fl.undo:Finish()
  if (istable(buffer) and IsValid(buffer.player)) then
    queue[buffer.player] = queue[buffer.player] or {}

    table.insert(queue[buffer.player], buffer)
  end

  buffer = {}
end

function fl.undo:Remove(player, id)
  local queueTable = queue[player]

  if (queueTable) then
    for k, v in ipairs(queueTable) do
      if (v.uniqueID == id) then
        queue[player][k] = nil
      end
    end
  end
end

function fl.undo:Do(obj)
  if (istable(obj) and istable(obj.functions)) then
    for k, v in ipairs(obj.functions) do
      try {
        v.func, obj, unpack(v.args)
      } catch {
        function(exception)
          ErrorNoHalt("[Flux:Undo] Failed to undo!\n"..tostring(exception).."\n")
        end
      }
    end
  end
end

function fl.undo:DoPlayer(player)
  local count = (queue[player] and #queue[player]) or 0

  if (count > 0) then
    -- do the top of the queue
    self:Do(queue[player][count])
    table.remove(queue[player], count)
  end
end

function fl.undo:GetPlayer(player)
  return queue[player] or {}
end
