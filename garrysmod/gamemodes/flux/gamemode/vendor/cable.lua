--[[
  Cable - A simple Garry's Mod net wrapper.
  2018 TeslaCloud Studios
--]]

-- Cable shouldn't be reloaded
if cable then return end
if !pon then include 'pon.lua' end

if !table.map then
  function table.map(t, c)
    local new_table = {}
    for k, v in pairs(t) do
      local val = c(v)
      if val != nil then
        table.insert(new_table, val)
      end
    end
    return new_table
  end
end

_player = _player or player

cable = cable or {}

local net_cache = {}

function cable.receive(id, callback)
  if SERVER then cable.check_networked_string(id) end

  return net.Receive(id, function(length, player)
    local c_len = net.ReadUInt(8)
    local c_tables = table.map(string.Split(net.ReadString(), ';'), function(v) return tonumber(v) end)
    local args = {}

    if c_len > 0 then
      for i = 1, c_len do
        table.insert(args, net.ReadType())
      end
    end

    if c_tables then
      for k, v in ipairs(c_tables) do
        args[v] = pon.decode(args[v])
      end
    end

    if IsValid(player) then
      callback(player, unpack(args))
    else
      callback(unpack(args))
    end
  end)
end

local function write_sendable_args(...)
  local args = {...}
  local length = 0
  local table_header = ''
  local send = {}

  for k, v in ipairs(args) do
    length = length + 1

    if !istable(v) then
      table.insert(send, v != nil and v or false)
    else
      table.insert(send, pon.encode(v))
      table_header = table_header..tostring(length)..';'
    end
  end

  net.WriteUInt(length, 8)
  net.WriteString(table_header)

  for k, v in ipairs(send) do
    net.WriteType(v)
  end
end

if SERVER then
  function cable.check_networked_string(id)
    if !net_cache[id] then
      net_cache[id] = util.AddNetworkString(id)
      return false
    end
    return true
  end

  function cable.send(player, id, ...)
    if !cable.check_networked_string(id) then
      local args = {...}

      -- Allow networked strings some time to catch up for the first time.
      timer.Simple(0.25, function()
        cable.send(player, id, unpack(args))
      end)

      return
    end

    if !istable(player) then
      if IsValid(player) then
        player = { player }
      else
        player = _player.GetAll()
      end
    end

    net.Start(id)
      write_sendable_args(...)
    net.Send(player)
  end
else
  function cable.send(id, ...)
    net.Start(id)
      write_sendable_args(...)
    net.SendToServer()
  end
end
