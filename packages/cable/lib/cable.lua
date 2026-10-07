--[[
  Cable - A simple Garry's Mod net wrapper.
  2018 TeslaCloud Studios

  Flux edition. Won't work outside of Flux due to dependencies.
--]]

local cable = {}
local net_cache = {}

--- Sets the function that handles an incoming Cable message.
-- On the server the callback receives the sending player followed by the sent values,
-- on the client it receives the sent values only.
-- ```
-- -- Server:
-- Cable.receive('fl_config_change', function(actor, key, value)
--   if !actor:can('manage_configuration') then return end
--
--   Config.set(key, value)
-- end)
--
-- -- Client:
-- Cable.receive('fl_config_set_var', function(key, value)
--   print(key, value)
-- end)
-- ```
-- @param id [String message name]
-- @param callback [Function message handler]
function cable.receive(id, callback)
  if SERVER then cable.check_networked_string(id) end

  return net.Receive(id, function(length, sender)
    local c_len = net.ReadUInt(8)
    local c_tables = table.map(string.split(net.ReadString(), ';'), function(v) return tonumber(v) end)
    local tables = {}
    local args = {}

    if c_tables then
      for k, v in ipairs(c_tables) do
        tables[v] = true
      end
    end

    if c_len > 0 then
      for i = 1, c_len do
        if tables[i] then
          local value, err = sfs.decode(net.ReadData(net.ReadUInt(16)))

          if err then
            error('cable.receive - failed to decode value #'..i..' of "'..id..'" ('..err..')\n')
          end

          args[i] = value
        else
          args[i] = net.ReadType()
        end
      end
    end

    if IsValid(sender) then
      callback(sender, unpack(args))
    else
      callback(unpack(args))
    end
  end)
end

local function write_sendable_args(...)
  local args = { ... }
  local length = 0
  local table_header = ''
  local send = {}
  local tables = {}

  for k, v in ipairs(args) do
    length = length + 1

    if !istable(v) then
      table.insert(send, v != nil and v or false)
    else
      local data, err = sfs.encode(v)

      if err then
        error('cable.send - failed to encode value #'..length..' ('..err..')\n')
      end

      table.insert(send, data)
      tables[length] = true
      table_header = table_header..tostring(length)..';'
    end
  end

  net.WriteUInt(length, 8)
  net.WriteString(table_header)

  for k, v in ipairs(send) do
    if tables[k] then
      -- SFS data is binary, so it has to be written along with its length.
      net.WriteUInt(#v, 16)
      net.WriteData(v, #v)
    else
      net.WriteType(v)
    end
  end
end

if SERVER then
  --- Makes sure that a message name is a networked string, adding it if necessary.
  -- Serverside only.
  -- @param id [String message name]
  -- @return [Boolean true if the name was already known, false if it has just been added]
  function cable.check_networked_string(id)
    if !net_cache[id] then
      net_cache[id] = util.AddNetworkString(id)
      return false
    end

    return true
  end

  --- Sends a Cable message to one, several or all players. Serverside variant.
  -- Tables are serialized with SFS. The first message under a new name is delayed by 0.1
  -- seconds to let the networked string reach the clients.
  -- ```
  -- Cable.send(target, 'fl_bind_pressed', key)
  -- Cable.send(nil, 'fl_player_disconnected', actor:EntIndex()) -- to everyone
  -- ```
  -- @param target [Player/List<Player> who to send the message to; everyone if nil]
  -- @param id [String message name]
  -- @param ... [Vararg values to send]
  function cable.send(target, id, ...)
    if isstring(target) then
      error('cable.send - bad argument #1 (must not be a string)\n')
    end

    if !cable.check_networked_string(id) then
      local args = { ... }

      -- Allow networked strings some time to catch up for the first time.
      timer.Simple(0.1, function()
        cable.send(target, id, unpack(args))
      end)

      return
    end

    if !istable(target) then
      if IsValid(target) then
        target = { target }
      else
        target = player.GetAll()
      end
    end

    net.Start(id)
      write_sendable_args(...)
    net.Send(target)
  end
else
  --- Sends a Cable message to the server. Clientside variant.
  -- Tables are serialized with SFS.
  -- ```
  -- Cable.send('fl_config_change', key, value)
  -- ```
  -- @param id [String message name]
  -- @param ... [Vararg values to send]
  function cable.send(id, ...)
    net.Start(id)
      write_sendable_args(...)
    net.SendToServer()
  end
end

return cable
