local player_meta = FindMetaTable('Player')

function player_meta:save_player()
  if self:IsBot() then return end
  if hook.run('PreSavePlayerData', self) == true then return end

  if self.record then
    self.record:save()
  end

  hook.run('PostSavePlayerData', self)
end

function player_meta:set_data(data)
  self:set_nv('fl_data', data or {})
end

function player_meta:set_player_data(key, value)
  local data = self:get_data()

  data[key] = value

  self:set_data(data)
end

function player_meta:get_player_data(key, default)
  return self:get_data()[key] or default
end

function player_meta:set_initialized(initialized)
  if initialized == nil then initialized = true end

  self:SetDTBool(BOOL_INITIALIZED, initialized)
end

function player_meta:notify(message, arguments, color)
  Flux.Player:notify(self, message, arguments, color)
end

function player_meta:notify_admin(message, arguments)
  Flux.Player:notify(self, message, arguments, Color(255, 128, 128))
end

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

function player_meta:restore_player()
  if self:IsBot() then
    self.record = User.new()
    return hook.run('PlayerRestored', self, self.record)
  end

  User:where('steam_id', self:SteamID()):expect(function(obj)
    obj.player = self
    self.record = obj

    hook.run('PlayerRestored', self, obj)
  end):rescue(function(obj)
    ServerLog(self:name()..' has joined for the first time!')

    obj.player = self
    obj.steam_id = self:SteamID()
    obj.name = self:name()
    obj.role = 'user'
    self.record = obj

    hook.run('PlayerCreated', self, obj)

    obj:save()

    hook.run('PlayerRestored', self, obj)
  end)
end

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

function player_meta:give_weapons(weapons_table, no_ammo)
  for k, v in pairs(weapons_table) do
    self:Give(v, no_ammo)
  end
end
