--- Cable is a thin wrapper around the net library that sends any number of values in one call.
-- `Cable.send` writes its arguments one after another, serializing tables with SFS, and
-- `Cable.receive` sets the handler that gets them back as regular arguments, so that there is
-- no reading or writing of individual net types. A nil argument arrives as nil and does not
-- cut off the arguments after it. Message names become networked strings the first time
-- the server uses them.
--
-- A net message holds 64 KB at most. Values that do not fit are sent in chunks: the whole
-- argument list is serialized with SFS as one block, compressed, cut into pieces of
-- `Cable.chunk_size` bytes and sent one piece every `Cable.chunk_interval` seconds under the
-- `fl_cable_chunk` name. The other side puts the pieces back together and runs the handler
-- as if the message had arrived in one piece, so a table of any size goes through a single
-- `Cable.send` call. Values that SFS cannot serialize, such as functions, cannot be chunked.
-- The server accepts chunked messages from a client only for names that have a handler, up
-- to `Cable.max_transfer_size` bytes and `Cable.max_transfers_per_player` at a time, and
-- forgets a transfer that has not completed within `Cable.transfer_timeout` seconds.
-- ```
-- -- Any size, on either side:
-- Cable.send(target, 'fl_map_data', huge_table)
--
-- Cable.receive('fl_map_data', function(data)
--   print(table.Count(data))
-- end)
-- ```
-- Both realms run this file; the package installer sends it to clients.

--[[
  Cable - A simple Garry's Mod net wrapper.
  2018 TeslaCloud Studios

  Flux edition. Won't work outside of Flux due to dependencies.
--]]

local cable = {}
local net_cache = {}
local handlers = {}
local transfers = {}
local next_transfer_id = 0

local CHUNK_MESSAGE = 'fl_cable_chunk'
local DIRECT_LIMIT = 65535

cable.chunk_size = 60000
cable.chunk_interval = 0.1
cable.max_transfer_size = 4 * 1024 * 1024
cable.max_transfers_per_player = 4
cable.transfer_timeout = 60

--- Runs the handler of a message with the values that have arrived. On the server the
-- handler gets the sender first.
-- @param id [String message name]
-- @param sender [Player the sending player on the server; nil or NULL on the client]
-- @param args [List<Any> the values, which may have holes]
-- @param count [Number how many values there are]
local function dispatch(id, sender, args, count)
  local callback = handlers[id]

  if !callback then return end

  if IsValid(sender) then
    callback(sender, unpack(args, 1, count))
  else
    callback(unpack(args, 1, count))
  end
end

--- Reads the values of a message that has arrived in one piece.
-- @param id [String message name, for the error message]
-- @return [List<Any> the values, Number how many there are]
local function read_args(id)
  local count = net.ReadUInt(8)
  local table_indices = table.map(string.split(net.ReadString(), ';'), function(v) return tonumber(v) end)
  local tables = {}
  local args = {}

  if table_indices then
    for k, v in ipairs(table_indices) do
      tables[v] = true
    end
  end

  for i = 1, count do
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

  return args, count
end

--- Serializes the tables among the values of a message and measures the message.
-- @param ... [Vararg values to send]
-- @return [List<Any> values with tables replaced by their SFS data, Map<Number, Boolean>
--   which of them are tables, String table index header, Number how many values there are,
--   Number rough size of the message in bytes]
local function encode_args(...)
  local args = { ... }
  local length = select('#', ...)
  local table_header = ''
  local send = {}
  local tables = {}
  local size = 0

  for i = 1, length do
    local v = args[i]

    if istable(v) then
      local data, err = sfs.encode(v)

      if err then
        error('cable.send - failed to encode value #'..i..' ('..err..')\n')
      end

      send[i] = data
      tables[i] = true
      table_header = table_header..tostring(i)..';'
      size = size + #data + 2
    else
      send[i] = v
      size = size + (isstring(v) and #v or 0) + 16
    end
  end

  return send, tables, table_header, length, size
end

--- Writes the values of a message that fits into one piece.
-- @param send [List<Any> values as returned by encode_args]
-- @param tables [Map<Number, Boolean> which values are SFS data]
-- @param table_header [String table index header]
-- @param length [Number how many values there are]
local function write_args(send, tables, table_header, length)
  net.WriteUInt(length, 8)
  net.WriteString(table_header)

  for i = 1, length do
    local v = send[i]

    if tables[i] then
      net.WriteUInt(#v, 16)
      net.WriteData(v, #v)
    else
      net.WriteType(v)
    end
  end
end

--- Serializes the whole argument list of a message as one block for a chunked transfer and
-- compresses it when that makes it smaller.
-- @param ... [Vararg values to send]
-- @return [String the block, Boolean whether it is compressed]
local function encode_transfer(...)
  local count = select('#', ...)
  local packet = { n = count }

  for i = 1, count do
    packet[i] = (select(i, ...))
  end

  local data, err = sfs.encode(packet)

  if err then
    error('cable.send - failed to encode the values of a chunked message ('..err..')\n')
  end

  local compressed = util.Compress(data)

  if isstring(compressed) and #compressed > 0 and #compressed < #data then
    return compressed, true
  end

  return data, false
end

--- Turns the block of a completed chunked transfer back into the argument list.
-- @param data [String the block]
-- @param compressed [Boolean whether the block is compressed]
-- @return [List<Any> the values with their amount in the n field, or nil and an error
--   message]
local function decode_transfer(data, compressed)
  if compressed then
    data = util.Decompress(data)

    if !isstring(data) or data == '' then
      return nil, 'decompression failed'
    end
  end

  local packet, err = sfs.decode(data)

  if err then
    return nil, err
  end

  if !istable(packet) or !isnumber(packet.n) then
    return nil, 'malformed block'
  end

  return packet
end

--- Writes one piece of a chunked transfer into a started net message.
-- @param transfer_id [Number ID of the transfer on the sending side]
-- @param id [String name of the message being transferred]
-- @param index [Number index of the piece, from 1]
-- @param count [Number how many pieces the transfer has]
-- @param compressed [Boolean whether the block is compressed]
-- @param piece [String the piece]
local function write_chunk(transfer_id, id, index, count, compressed, piece)
  net.Start(CHUNK_MESSAGE)
  net.WriteUInt(transfer_id, 32)
  net.WriteString(id)
  net.WriteUInt(index, 16)
  net.WriteUInt(count, 16)
  net.WriteBool(compressed)
  net.WriteUInt(#piece, 16)
  net.WriteData(piece, #piece)
end

--- Lists the players of a receiver list who are still on the server.
-- @param receivers [List<Player>]
-- @return [List<Player>]
local function live_receivers(receivers)
  local alive = {}

  for k, v in ipairs(receivers) do
    if IsValid(v) then
      alive[#alive + 1] = v
    end
  end

  return alive
end

--- Sends a message in chunks: one piece at once and the others spaced by
-- `Cable.chunk_interval`, so that the reliable channel of the receivers is not flooded.
-- @param receivers [List<Player> who to send to on the server; ignored on the client]
-- @param id [String message name]
-- @param ... [Vararg values to send]
-- @return [Number ID of the transfer, Number how many pieces it has]
local function send_chunked(receivers, id, ...)
  local data, compressed = encode_transfer(...)
  local size = cable.chunk_size
  local count = math.max(1, math.ceil(#data / size))

  next_transfer_id = next_transfer_id % 4294967295 + 1

  local transfer_id = next_transfer_id

  for index = 1, count do
    local piece = string.sub(data, (index - 1) * size + 1, index * size)

    local deliver = function()
      if SERVER then
        local targets = live_receivers(receivers)

        if #targets == 0 then return end

        write_chunk(transfer_id, id, index, count, compressed, piece)
        net.Send(targets)
      else
        write_chunk(transfer_id, id, index, count, compressed, piece)
        net.SendToServer()
      end
    end

    if index == 1 then
      deliver()
    else
      timer.Simple((index - 1) * cable.chunk_interval, deliver)
    end
  end

  return transfer_id, count
end

--- Forgets the chunked transfers that have been waiting for their pieces for longer than
-- `Cable.transfer_timeout`, and every transfer of a sender who has left.
local function sweep_transfers()
  local now = SysTime()

  for owner, pending in pairs(transfers) do
    if isentity(owner) and !IsValid(owner) then
      transfers[owner] = nil
    else
      for transfer_id, transfer in pairs(pending) do
        if now - transfer.started > cable.transfer_timeout then
          pending[transfer_id] = nil
        end
      end

      if next(pending) == nil then
        transfers[owner] = nil
      end
    end
  end
end

--- Sets the function that handles an incoming Cable message, however it arrives.
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

  handlers[id] = callback

  return net.Receive(id, function(length, sender)
    local args, count = read_args(id)

    dispatch(id, sender, args, count)
  end)
end

--- Checks whether a message has a handler set with `Cable.receive`.
-- @param id [String message name]
-- @return [Boolean]
function cable.has_receiver(id)
  return handlers[id] != nil
end

--- Counts the chunked transfers that are still waiting for pieces on this side.
-- @return [Number]
function cable.pending_transfers()
  local count = 0

  for owner, pending in pairs(transfers) do
    count = count + table.Count(pending)
  end

  return count
end

net.Receive(CHUNK_MESSAGE, function(length, sender)
  local transfer_id = net.ReadUInt(32)
  local id = net.ReadString()
  local index = net.ReadUInt(16)
  local count = net.ReadUInt(16)
  local compressed = net.ReadBool()
  local size = net.ReadUInt(16)
  local piece = net.ReadData(size)

  if !handlers[id] or count < 1 or index < 1 or index > count or size > cable.chunk_size then return end

  if SERVER then
    if !IsValid(sender) or count * cable.chunk_size > cable.max_transfer_size then return end
  end

  local owner = SERVER and sender or true
  local pending = transfers[owner]

  if !pending then
    pending = {}
    transfers[owner] = pending
  end

  local transfer = pending[transfer_id]

  if !transfer then
    if SERVER and table.Count(pending) >= cable.max_transfers_per_player then return end

    transfer = {
      id = id,
      count = count,
      compressed = compressed,
      received = 0,
      pieces = {},
      started = SysTime()
    }

    pending[transfer_id] = transfer
  end

  if transfer.id != id or transfer.count != count or transfer.pieces[index] then return end

  transfer.pieces[index] = piece
  transfer.received = transfer.received + 1

  if transfer.received < count then return end

  pending[transfer_id] = nil

  if next(pending) == nil then
    transfers[owner] = nil
  end

  local packet, err = decode_transfer(table.concat(transfer.pieces, '', 1, count), transfer.compressed)

  if !packet then
    ErrorNoHalt('cable.receive - failed to decode a chunked "'..id..'" message ('..tostring(err)..')\n')

    return
  end

  dispatch(id, sender, packet, packet.n)
end)

timer.Create('fl_cable_transfers', 10, 0, sweep_transfers)

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

  cable.check_networked_string(CHUNK_MESSAGE)

  --- Sends a Cable message to one, several or all players. Serverside variant.
  -- Tables are serialized with SFS, and nil values are delivered as nil. The first message
  -- under a new name is delayed by 0.1 seconds to let the networked string reach the clients.
  -- Values that do not fit into one net message are sent in chunks (see the top of this
  -- file), which takes `Cable.chunk_interval` seconds per piece after the first.
  -- ```
  -- Cable.send(target, 'fl_bind_pressed', key)
  -- Cable.send(nil, 'fl_player_disconnected', actor:EntIndex()) -- to everyone
  -- ```
  -- A player who is not valid any more, such as one who has left, is nobody: a single invalid
  -- player gets no message and invalid players are left out of a list. A list without a valid
  -- player sends nothing. Only nil stands for everyone.
  -- @param target [Player/List<Player> who to send the message to; everyone if nil]
  -- @param id [String message name]
  -- @param ... [Vararg values to send]
  function cable.send(target, id, ...)
    if isstring(target) then
      error('cable.send - bad argument #1 (must not be a string)\n')
    end

    if !cable.check_networked_string(id) then
      local args, count = { ... }, select('#', ...)

      timer.Simple(0.1, function()
        cable.send(target, id, unpack(args, 1, count))
      end)

      return
    end

    if target == nil then
      target = player.GetAll()
    elseif !istable(target) then
      if !IsValid(target) or !target:IsPlayer() then return end

      target = { target }
    else
      local receivers = {}

      for k, v in pairs(target) do
        if isentity(v) and IsValid(v) and v:IsPlayer() then
          receivers[#receivers + 1] = v
        end
      end

      if #receivers == 0 then return end

      target = receivers
    end

    local send, tables, table_header, length, size = encode_args(...)

    if size > cable.chunk_size or size > DIRECT_LIMIT then
      send_chunked(target, id, ...)

      return
    end

    net.Start(id)
      write_args(send, tables, table_header, length)
    net.Send(target)
  end
else
  --- Sends a Cable message to the server. Clientside variant.
  -- Tables are serialized with SFS, and nil values are delivered as nil. Values that do not
  -- fit into one net message are sent in chunks (see the top of this file), which the server
  -- only accepts for a message that has a handler there.
  -- ```
  -- Cable.send('fl_config_change', key, value)
  -- ```
  -- @param id [String message name]
  -- @param ... [Vararg values to send]
  function cable.send(id, ...)
    local send, tables, table_header, length, size = encode_args(...)

    if size > cable.chunk_size or size > DIRECT_LIMIT then
      send_chunked(nil, id, ...)

      return
    end

    net.Start(id)
      write_args(send, tables, table_header, length)
    net.SendToServer()
  end
end

return cable
