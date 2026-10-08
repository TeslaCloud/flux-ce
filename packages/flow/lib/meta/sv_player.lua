--- Server side of the `Player` extensions: restoring and saving the database record of a
-- player (`User`), writing their networked data table and initialization state, sending
-- notifications, and helpers for ammo, weapons and moving a stuck player to a free spot.

local player_meta = FindMetaTable('Player')

--- Saves the database record of the player. Does nothing for bots. Can be prevented by returning
-- true from the 'PreSavePlayerData' hook. Runs the 'PostSavePlayerData' hook afterward.
function player_meta:save_player()
  if self:IsBot() then return end

  --- Called on the server before `Player:save_player` saves the database record of a
  -- player. Not called for bots.
  -- @param actor [Player The player about to be saved]
  -- @return [Boolean Return true to prevent the record from being saved; in that case
  --   `PostSavePlayerData` is not run either]
  if hook.Run('PreSavePlayerData', self) == true then return end

  if self.record then
    self.record:save()
  end

  --- Called on the server after `Player:save_player` has saved the database record of a
  -- player. Not called for bots.
  -- @param actor [Player The player who has been saved]
  hook.Run('PostSavePlayerData', self)
end

--- Replaces the networked data table of the player.
-- @param data={} [Map]
function player_meta:set_data(data)
  self:set_nv('fl_data', data or {})
end

--- Sets a value in the networked data table of the player.
-- @param key [String]
-- @param value [Any]
function player_meta:set_player_data(key, value)
  local data = self:get_data()

  data[key] = value

  self:set_data(data)
end

--- Returns a value from the networked data table of the player.
-- @param key [String]
-- @param default=nil [Any returned if the value is not set or is false]
-- @return [Any]
function player_meta:get_player_data(key, default)
  return self:get_data()[key] or default
end

--- Sets whether the player has been initialized by Flux.
-- @param initialized=true [Boolean]
function player_meta:set_initialized(initialized)
  if initialized == nil then initialized = true end

  self:SetDTBool(BOOL_INITIALIZED, initialized)
end

--- Sends a notification to the player. Serverside variant.
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @param color=nil [Color]
function player_meta:notify(message, arguments, color)
  Flux.Player:notify(self, message, arguments, color)
end

--- Sends a light red notification to the player.
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
function player_meta:notify_admin(message, arguments)
  Flux.Player:notify(self, message, arguments, Color(255, 128, 128))
end

--- Returns the ammo the player has.
-- @return [Map amounts of ammo by ammo type ID, only for the types the player has]
function player_meta:get_ammo_table()
  local ammo_table = {}

  for k, v in pairs(game.get_ammo_list()) do
    local ammo_count = self:GetAmmoCount(k)

    if ammo_count > 0 then
      ammo_table[k] = ammo_count
    end
  end

  return ammo_table
end

--- Loads the database record of the player by their SteamID, creating and saving a new one
-- if they have joined for the first time. The query is asynchronous: the record is put
-- into self.record and the 'PlayerRestored' hook is run once it has loaded. Bots get
-- a blank record that is never saved here.
function player_meta:restore_player()
  if self:IsBot() then
    self.record = User.new()
    return hook.Run('PlayerRestored', self, self.record)
  end

  User:where('steam_id', self:SteamID()):expect(function(obj)
    obj.player = self
    self.record = obj

    --- Called on the server once the database record of a player who has just joined is
    -- available as `actor.record`. For a player who joins for the first time it runs after
    -- `PlayerCreated`, when the new record has been saved. Bots get it right away with a
    -- blank record.
    -- @param actor [Player The player who has joined]
    -- @param record [User The database record of the player]
    hook.Run('PlayerRestored', self, obj)
  end):rescue(function(obj)
    ServerLog(self:name()..' has joined for the first time!')

    obj.player = self
    obj.steam_id = self:SteamID()
    obj.name = self:name()
    obj.role = 'user'
    self.record = obj

    --- Called on the server when a player joins for the first time, after their new database
    -- record has been given the SteamID, the name and the `user` role and right before it
    -- is saved. Handlers can set further defaults on the record. `PlayerRestored` follows.
    -- @param actor [Player The player who has joined]
    -- @param record [User The new database record of the player]
    hook.Run('PlayerCreated', self, obj)

    obj:save()

    hook.Run('PlayerRestored', self, obj)
  end)
end

--- Looks for unobstructed spots around the player that the player can be moved to.
-- @param margin=3 [Number how far to search: spots are checked on a grid of this many steps
--   in every direction, margin * 10 units apart]
-- @param filter=nil [Entity/List<Entity>/Function trace filter, the player by default]
-- @return [List<Vector> free positions, closest first]
function player_meta:find_best_position(margin, filter)
  margin = margin or 3

  local pos = self:GetPos()
  local min, max = Vector(-16, -16, 0), Vector(16, 16, 32)
  local positions = {}

  for x = -margin, margin do
    for y = -margin, margin do
      local pick = pos + Vector(x * margin * 10, y * margin * 10, 0)

      if !util.IsInWorld(pick) then continue end

      local data = {}
        data.start = pick + min + Vector(0, 0, margin * 1.25)
        data.endpos = pick + max
        data.filter = filter or self
      local trace = util.TraceLine(data)

      if trace.StartSolid or trace.Hit then continue end

      data.start = pick + Vector(-max.x, -max.y, margin * 1.25)
      data.endpos = pick + Vector(min.x, min.y, 32)

      local trace2 = util.TraceLine(data)

      if trace2.StartSolid or trace2.Hit then continue end

      data.start = pos
      data.endpos = pick

      local trace3 = util.TraceLine(data)

      if trace3.Hit then continue end

      table.insert(positions, pick)
    end
  end

  table.sort(positions, function(a, b)
    return a:Distance(pos) < b:Distance(pos)
  end)

  return positions
end

--- Moves the player to the closest unobstructed spot nearby.
-- @param filter=nil [Entity/List<Entity>/Function trace filter, the player by default]
function player_meta:unstuck(filter)
  local positions = self:find_best_position(4, filter)

  for k, v in ipairs(positions) do
    self:SetPos(v)

    if !self:stuck() then
      return
    else
      self:DropToFloor()

      if !self:stuck() then return end
    end
  end
end

--- Gives several weapons to the player.
-- @param weapons_table [List<String> weapon classes]
-- @param no_ammo=false [Boolean do not give the default ammo with the weapons]
function player_meta:give_weapons(weapons_table, no_ammo)
  for k, v in pairs(weapons_table) do
    self:Give(v, no_ammo)
  end
end
