local player_meta = FindMetaTable('Player')

function player_meta:save_player()
  hook.run('SavePlayerData', self)

  if self.record then self.record:save() end
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

function player_meta:notify(message, arguments)
  fl.player:notify(self, message, arguments)
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
