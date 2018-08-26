local player_meta = FindMetaTable("Player")

function player_meta:SavePlayer()
  local saveData = {
    steam_id = self:SteamID(),
    name = self:Name(),
    joinTime = self.flJoinTime or os.time(),
    lastPlayTime = os.time(),
    data = fl.serialize(self:get_data())
  }

  hook.Run("SavePlayerData", self, saveData)

  if self.record then self.record:save() end
end

function player_meta:set_data(data)
  self:SetNetVar("flData", data or {})
end

function player_meta:SetPlayerData(key, value)
  local data = self:get_data()

  data[key] = value

  self:set_data(data)
end

function player_meta:GetPlayerData(key, default)
  local data = self:get_data()

  return data[key] or default
end

function player_meta:SetInitialized(bIsInitialized)
  if (bIsInitialized == nil) then bIsInitialized = true end

  self:SetDTBool(BOOL_INITIALIZED, bIsInitialized)
end

function player_meta:Notify(message)
  fl.player:Notify(self, message)
end

function player_meta:GetAmmoTable()
  local ammoTable = {}

  for k, v in pairs(game.GetAmmoList()) do
    local ammoCount = self:GetAmmoCount(k)

    if (ammoCount > 0) then
      ammoTable[k] = ammoCount
    end
  end

  return ammoTable
end

function player_meta:RestorePlayer()
  if self:IsBot() then
    return hook.Run('player_restored', self, Player.new())
  end

  Player:where('steam_id', self:SteamID()):expect(function(obj)
    obj.player = self
    self.record = obj
    hook.Run('player_restored', self, obj)
  end):rescue(function(obj)
    ServerLog(self:Name()..' has joined for the first time!')
    obj.player = self
    obj.steam_id = self:SteamID()
    obj.name = self:Name()
    obj.role = 'user'
    self.record = obj
    hook.Run('player_created', self, obj)
    obj:save()
    hook.Run('player_restored', self, obj)
  end)
end
