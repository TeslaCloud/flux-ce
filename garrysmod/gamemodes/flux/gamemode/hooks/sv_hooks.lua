DEFINE_BASECLASS("gamemode_base")

function GM:DoPlayerDeath(player, attacker, damageInfo) end

function GM:Initialize()
  local config_file = fileio.Read("gamemodes/flux/flux.yml")

  if config_file then
    config.Import(config_file, CONFIG_FLUX)
  end

  local db_config = fl.db.config

  fl.db:connect(db_config.host, db_config.user, db_config.password, db_config.database, db_config.port, db_config.socket, db_config.flags)
end

function GM:InitPostEntity()
  local toolGun = weapons.GetStored("gmod_tool")

  for k, v in pairs(fl.tool:GetAll()) do
    toolGun.Tool[v.Mode] = v
  end

  hook.Run("LoadData")
  plugin.call("FLInitPostEntity")
end

function GM:PlayerInitialSpawn(player)
  player_manager.SetPlayerClass(player, "flPlayer")
  player_manager.RunClass(player, "Spawn")

  player:SetUserGroup("user")
  player:RestorePlayer()

  if (player:IsBot()) then
    player:SetInitialized(true)

    return
  end

  netstream.Start(nil, "PlayerInitialSpawn", player:EntIndex())
end

function GM:PlayerSpawn(player)
  player_manager.SetPlayerClass(player, "flPlayer")

  hook.Run("PlayerSetModel", player)

  player:SetCollisionGroup(COLLISION_GROUP_PLAYER)
  player:SetMaterial("")
  player:SetMoveType(MOVETYPE_WALK)
  player:Extinguish()
  player:UnSpectate()
  player:GodDisable()

  player:SetCrouchedWalkSpeed(config.Get("crouched_speed") / config.Get("walk_speed"))
  player:SetWalkSpeed(config.Get("walk_speed"))
  player:SetJumpPower(config.Get("jump_power"))
  player:SetRunSpeed(config.Get("run_speed"))

  hook.Run("PostPlayerSpawn", player)

  local oldHands = player:GetHands()

  if (IsValid(oldHands)) then
    oldHands:Remove()
  end

  local handsEntity = ents.Create("gmod_hands")

  if (IsValid(handsEntity)) then
    player:SetHands(handsEntity)
    handsEntity:SetOwner(player)

    local info = player_manager.RunClass(player, "GetHandsModel")

    if (info) then
      handsEntity:SetModel(info.model)
      handsEntity:SetSkin(info.skin)
      handsEntity:SetBodyGroups(info.body)
    end

    local viewModel = player:GetViewModel(0)
    handsEntity:AttachToViewmodel(viewModel)

    viewModel:DeleteOnRemove(handsEntity)
    player:DeleteOnRemove(handsEntity)

    handsEntity:Spawn()
  end
end

function GM:PostPlayerSpawn(player)
  player:SetNoDraw(false)
  player:UnLock()
  player:SetNotSolid(false)

  player_manager.RunClass(player, "Loadout")

  if (player:HasPermission("toolgun")) then
    player:Give("gmod_tool")
  end

  if (player:HasPermission("physgun")) then
    player:Give("weapon_physgun")
  end

  hook.RunClient(player, "PostPlayerSpawn")
end

function GM:PlayerSetModel(player)
  local override = hook.Run("PrePlayerSetModel", player)

  if (isstring(override)) then
    player:SetModel(override)
  elseif (isbool(override) and override == false and self.BaseClass.PlayerSetModel) then
    self.BaseClass:PlayerSetModel(player)
  elseif (player:IsBot()) then
    player:SetModel(player:GetNetVar("model", "models/humans/group01/male_0"..math.random(1, 9)..".mdl"))
  elseif (player:HasInitialized()) then
    player:SetModel(player:GetNetVar("model", "models/humans/group01/male_02.mdl"))
  elseif (self.BaseClass.PlayerSetModel) then
    self.BaseClass:PlayerSetModel(player)
  end
end

function GM:PlayerInitialized(player)
  player:SetInitialized(true)

  hook.RunClient(player, "PlayerInitialized")
end

function GM:PlayerDeath(player, inflictor, attacker)
  player:SetNetVar("RespawnTime", CurTime() + config.Get("respawn_delay"))
end

function GM:PlayerDeathThink(player)
  local respawnTime = player:GetNetVar("RespawnTime", 0)

  if (respawnTime <= CurTime()) then
    player:Spawn()
  end

  return false
end

function GM:PlayerDisconnected(player)
  player:SavePlayer()
  netstream.Start(nil, "PlayerDisconnected", player:EntIndex())
end

function GM:EntityRemoved(entity)
  entity:ClearNetVars()

  self.BaseClass:EntityRemoved(entity)
end

function GM:OnPluginFileChange(file_name)
  plugin.OnPluginChanged(file_name)
end

function GM:GetFallDamage(player, speed)
  local fallDamage = hook.Run("FLGetFallDamage", player, speed)

  if (speed < 660) then
    speed = speed - 250
  end

  if (!fallDamage) then
    fallDamage = 100 * ((speed) / 850) * 0.75
  end

  return fallDamage
end

function GM:PlayerShouldTakeDamage(player, attacker)
  return hook.Run("FLPlayerShouldTakeDamage", player, attacker) or true
end

function GM:PlayerSpawnProp(player, model)
  if (!player:HasPermission("spawn_props")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnProp", player, model) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnObject(player, model, skin)
  if (!player:HasPermission("spawn_entities")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnObject", player, model, skin) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnNPC(player, npc, weapon)
  if (!player:HasPermission("spawn_npcs")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnNPC", player, npc, weapon) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnEffect(player, model)
  if (!player:HasPermission("spawn_entities")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnEffect", player, model) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnVehicle(player, model, name, tab)
  if (!player:HasPermission("spawn_vehicles")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnVehicle", player, model, name, tab) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnSWEP(player, weapon, swep)
  if (!player:HasPermission("spawn_sweps")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnSWEP", player, weapon, swep) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnSENT(player, class)
  if (!player:HasPermission("spawn_entities")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnSENT", player, class) == false) then
    return false
  end

  return true
end

function GM:PlayerSpawnRagdoll(player, model)
  if (!player:HasPermission("spawn_ragdolls")) then
    return false
  end

  if (hook.Run("FLPlayerSpawnRagdoll", player, model) == false) then
    return false
  end

  return true
end

function GM:PlayerGiveSWEP(player, weapon, swep)
  if (!player:HasPermission("spawn_sweps")) then
    return false
  end

  if (hook.Run("FLPlayerGiveSWEP", player, weapon, swep) == false) then
    return false
  end

  return true
end

function GM:OnPhysgunFreeze(weapon, physObj, entity, player)
  if (player:HasPermission("physgun_freeze")) then
    BaseClass.OnPhysgunFreeze(self, weapon, physObj, entity, player)

    return false
  end
end

function GM:EntityTakeDamage(ent, damageInfo)
  if (IsValid(ent) and ent:IsPlayer()) then
    hook.Run("PlayerTakeDamage", ent, damageInfo)
  end
end

function GM:PlayerTakeDamage(player, damageInfo)
  netstream.Start(player, "PlayerTakeDamage")
end

function GM:OneSecond()
  local curTime = CurTime()
  local sysTime = SysTime()

  if (!fl.nextSaveData) then
    fl.nextSaveData = curTime + 10
  elseif (fl.nextSaveData <= curTime) then
    if (hook.Run("FLShouldSaveData") != false) then
      fl.dev_print("Saving framework's data...")

      hook.Run("FLSaveData")
    end

    fl.nextSaveData = curTime + config.Get("data_save_interval")
  end

  if (!fl.NextPlayerCountCheck) then
    fl.NextPlayerCountCheck = sysTime + 1800
  elseif (fl.NextPlayerCountCheck <= sysTime) then
    fl.NextPlayerCountCheck = sysTime + 1800

    if (#player.GetAll() == 0) then
      if (hook.Run("ShouldServerAutoRestart") != false) then
        fl.dev_print("Server is empty, restarting...")
        RunConsoleCommand("changelevel", game.GetMap())
      end
    end
  end
end

function GM:PreLoadPlugins()
  fl.shared.disabledPlugins = data.Load("disabled_plugins", {})
end

function GM:FLSaveData()
  hook.Run("SaveData")
end

function GM:PlayerOneSecond(player, curTime)
  local pos = player:GetPos()

  if (player.lastPos != pos) then
    hook.Run("PlayerPositionChanged", player, player.lastPos, pos, curTime)
  end

  player.lastPos = pos
end

function GM:PlayerThink(player, curTime)
  local act = player:GetAction()

  if (act != "idle" and act != "spawning") then
    player:DoAction()
  end
end

function GM:PlayerSay(player, text, bTeamChat)
  local isCommand, length = string.IsCommand(tostring(text))

  if (isCommand) then
    fl.command:Interpret(player, text:utf8sub(1 + length, text:utf8len()))

    return ""
  end
end

function GM:activerecord_ready()
  create_table('fl_players', function(t)
    t:primary_key 'id'
    t:string { 'steam_id', null = false }
    t:string { 'name', null = false }
    t:string 'role'
    t:json 'secondary_roles'
    t:json 'permissions'
    t:json 'data'
    t:timestamp 'created_at'
    t:timestamp 'updated_at'
  end)

  create_table('fl_logs', function(t)
    t:text 'body'
    t:string 'action'
    t:string 'object'
    t:string 'subject'
    t:timestamp 'created_at'
    t:timestamp 'updated_at'
  end)
end

-- Awful awful awful code, but it's kinda necessary in some rare cases.
-- Avoid using PlayerThink whenever possible though.
do
  local thinkDelay = 1 * 0.125
  local secondDelay = 1
  local nextThink = 0
  local nextSecond = 0

  function GM:Tick()
    local curTime = CurTime()

    if (curTime >= nextThink) then
      local oneSecondTick = (curTime >= nextSecond)

      for k, v in ipairs(player.GetAll()) do
        hook.Call("PlayerThink", self, v, curTime)

        if (oneSecondTick) then
          hook.Call("PlayerOneSecond", self, v, curTime)
        end
      end

      nextThink = curTime + thinkDelay

      if (oneSecondTick) then
        nextSecond = curTime + 1
      end
    end
  end
end
