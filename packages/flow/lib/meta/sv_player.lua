--- Server side of the `Player` extensions: restoring and saving the database record of a
-- player (`User`), writing their data table and initialization state, sending
-- notifications and sounds, opening and closing their tab menu, and helpers for ammo,
-- weapons and moving a stuck player to a free spot.
--
-- The data table of a player (`Player:set_player_data`, `Player:get_player_data`) is
-- persistent: it is kept serialized in the `data` column of the player's `User` record,
-- loaded when the record is restored and saved with it. The server holds it in the
-- `fl_player_data` field of the player and networks it to that player alone, as the private
-- `fl_data` variable, so that nobody else's client learns what is stored about a player.

local player_meta = FindMetaTable('Player')
local IsValid = IsValid
local istable = istable

--- Reads the persistent data table out of the database record of a player.
-- @param record [User the database record]
-- @return [Map the stored data, an empty table if there is none or it cannot be read]
local function read_record_data(record)
  local raw = record.data

  if !isstring(raw) or raw == '' then return {} end

  local data = table.deserialize(raw)

  return istable(data) and data or {}
end

--- Saves the database record of the player, together with their data table. Does nothing for
-- bots. Can be prevented by returning true from the 'PreSavePlayerData' hook. Runs the
-- 'PostSavePlayerData' hook afterward. The data table is taken from the server's own copy
-- and never from the networked variables, which are gone once the entity of a leaving
-- player has been removed: without that copy the record keeps the data it already has.
function player_meta:save_player()
  if self:IsBot() then return end

  --- Called on the server before `Player:save_player` saves the database record of a
  -- player. Not called for bots.
  -- @param actor [Player The player about to be saved]
  -- @return [Boolean Return true to prevent the record from being saved; in that case
  --   `PostSavePlayerData` is not run either]
  if hook.Run('PreSavePlayerData', self) == true then return end

  if self.record then
    local data = self.fl_player_data

    if istable(data) then
      self.record.data = table.serialize(data)
    end

    self.record:save()
  end

  --- Called on the server after `Player:save_player` has saved the database record of a
  -- player. Not called for bots.
  -- @param actor [Player The player who has been saved]
  hook.Run('PostSavePlayerData', self)
end

--- Replaces the data table of the player. The table is networked to the player it belongs
-- to, and to nobody else, and written to the database record of the player, which stores
-- it the next time the record is saved.
-- @param data={} [Map values that `table.serialize` can store]
function player_meta:set_data(data)
  data = data or {}

  self.fl_player_data = data
  self:set_private_nv('fl_data', data)

  if self.record then
    self.record.data = table.serialize(data)
  end
end

--- Sets a value in the data table of the player. The value is networked to the player it
-- belongs to, and to nobody else, and persistent: it is saved with the database record of
-- the player (when they disconnect, when their character is saved and when the server
-- shuts down) and is there again the next time they join. Keep the values to what
-- `table.serialize` can store.
-- ```
-- target:set_player_data('tutorial_seen', true)
-- ```
-- @param key [String]
-- @param value [Any nil removes the value]
function player_meta:set_player_data(key, value)
  local data = self:get_data()

  data[key] = value

  self:set_data(data)
end

--- Returns a value from the data table of the player. Values that were saved during an
-- earlier session are available once the `PlayerRestored` hook has run for the player.
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

--- Plays a sound once on the client of the player, at full volume and without a position.
-- Serverside variant.
-- @param path [String path of the sound file, relative to the sound/ folder]
-- @see [Flux.Player#play_sound]
function player_meta:play_sound(path)
  Flux.Player:play_sound(self, path)
end

--- Starts a named looping sound on the client of the player. Serverside variant.
-- @param id [String name to stop the sound by]
-- @param path [String path of a looping sound file, relative to the sound/ folder]
-- @param volume=0.75 [Number volume from 0 to 1]
-- @see [Flux.Player#start_sound]
function player_meta:start_sound(id, path, volume)
  Flux.Player:start_sound(self, id, path, volume)
end

--- Stops a named sound on the client of the player. Serverside variant.
-- @param id [String name the sound was started under]
-- @param fade_out=0 [Number seconds over which the sound fades out]
-- @see [Flux.Player#stop_sound]
function player_meta:stop_sound(id, fade_out)
  Flux.Player:stop_sound(self, id, fade_out)
end

--- Opens the tab menu of the player. Serverside variant.
-- @param panel_id=nil [String ID of the menu item to show; the item that was open the last
--   time if nil]
-- @see [Flux.Player#open_tab_menu]
function player_meta:open_tab_menu(panel_id)
  Flux.Player:open_tab_menu(self, panel_id)
end

--- Closes the tab menu of the player, if they have it open. Serverside variant.
-- @see [Flux.Player#close_tab_menu]
function player_meta:close_tab_menu()
  Flux.Player:close_tab_menu(self)
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
-- into self.record, the saved data table of the player is loaded from it (values set
-- during this session before the record arrived are kept) and the 'PlayerRestored' hook
-- is run once it has loaded. Nothing happens if the player has left by then. Bots get a
-- blank record that is never saved here.
function player_meta:restore_player()
  if self:IsBot() then
    self.record = User.new()
    return hook.Run('PlayerRestored', self, self.record)
  end

  User:where('steam_id', self:SteamID()):expect(function(obj)
    if !IsValid(self) then return end

    local data = read_record_data(obj)

    for k, v in pairs(self:get_data()) do
      data[k] = v
    end

    obj.player = self
    self.record = obj
    self:set_data(data)

    --- Called on the server once the database record of a player who has just joined is
    -- available as `actor.record`. For a player who joins for the first time it runs after
    -- `PlayerCreated`, when the new record has been saved. Bots get it right away with a
    -- blank record.
    -- @param actor [Player The player who has joined]
    -- @param record [User The database record of the player]
    hook.Run('PlayerRestored', self, obj)
  end):rescue(function(obj)
    if !IsValid(self) then return end

    ServerLog(self:name()..' has joined for the first time!')

    obj.player = self
    obj.steam_id = self:SteamID()
    obj.name = self:name()
    obj.role = 'user'
    self.record = obj
    self:set_data(self:get_data())

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
  local step = margin * 10
  local lift = margin * 1.25
  local first_start = min + Vector(0, 0, lift)
  local second_start = Vector(-max.x, -max.y, lift)
  local second_end = Vector(min.x, min.y, 32)
  local data = { filter = filter or self }
  local trace_line, is_in_world = util.TraceLine, util.IsInWorld

  for x = -margin, margin do
    for y = -margin, margin do
      local pick = pos + Vector(x * step, y * step, 0)

      if !is_in_world(pick) then continue end

      data.start = pick + first_start
      data.endpos = pick + max

      local trace = trace_line(data)

      if trace.StartSolid or trace.Hit then continue end

      data.start = pick + second_start
      data.endpos = pick + second_end

      local trace2 = trace_line(data)

      if trace2.StartSolid or trace2.Hit then continue end

      data.start = pos
      data.endpos = pick

      local trace3 = trace_line(data)

      if trace3.Hit then continue end

      positions[#positions + 1] = pick
    end
  end

  table.sort(positions, function(a, b)
    return a:DistToSqr(pos) < b:DistToSqr(pos)
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

--- Gives several weapons to the player: the classes that `Player:get_weapons_list` returns,
-- or its tables with clips, which the weapons are loaded with once they are given. The
-- weapons come with their default ammo unless the second argument says otherwise.
-- ```
-- actor:give_weapons({ 'weapon_pistol', 'weapon_crowbar' })
-- actor:give_weapons(weapons, true)
-- actor:give_weapons(weapons, ammo)
-- ```
-- @param weapons_table [List<String/Map> weapon classes, or tables with the class, clip1 and
--   clip2 fields as `Player:get_weapons_list` lists them with ammo; a clip that is nil is
--   left as the weapon spawns with it]
-- @param ammo=nil [Boolean/Map what reserve ammo comes with the weapons: nil for the default
--   ammo of every weapon, true for none, or counts by ammo type name as
--   `Player:get_weapons_list` returns them, which are set on the player once the weapons are
--   given and replace what they hold of those types]
function player_meta:give_weapons(weapons_table, ammo)
  local no_ammo = ammo != nil and ammo != false

  for k, v in pairs(weapons_table) do
    if istable(v) then
      local weapon = self:Give(v.class, no_ammo)

      if IsValid(weapon) then
        if isnumber(v.clip1) then
          weapon:SetClip1(v.clip1)
        end

        if isnumber(v.clip2) then
          weapon:SetClip2(v.clip2)
        end
      end
    else
      self:Give(v, no_ammo)
    end
  end

  if istable(ammo) then
    for ammo_name, amount in pairs(ammo) do
      self:SetAmmo(amount, ammo_name)
    end
  end
end
