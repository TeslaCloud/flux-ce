DEFINE_BASECLASS('gamemode_base')

function GM:DoPlayerDeath(player, attacker, damage_info)
end

function GM:InitPostEntity()
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(fl.tool.stored) do
    toolgun.Tool[v.Mode] = v
  end

  hook.run('LoadData')
  plugin.call('FLInitPostEntity')
end

function GM:PlayerInitialSpawn(player)
  player_manager.SetPlayerClass(player, 'flPlayer')
  player_manager.RunClass(player, 'Spawn')

  player:SetUserGroup('user')
  player:restore_player()

  if player:IsBot() then
    player:set_initialized(true)
    return
  end

  cable.send(nil, 'PlayerInitialSpawn', player:EntIndex())
end

function GM:PlayerSpawn(player)
  player_manager.SetPlayerClass(player, 'flPlayer')

  hook.run('PlayerSetModel', player)

  player:SetCollisionGroup(COLLISION_GROUP_PLAYER)
  player:SetMaterial('')
  player:SetMoveType(MOVETYPE_WALK)
  player:Extinguish()
  player:UnSpectate()
  player:GodDisable()

  player:SetCrouchedWalkSpeed(config.get('crouched_speed') / config.get('walk_speed'))
  player:SetWalkSpeed(config.get('walk_speed'))
  player:SetJumpPower(config.get('jump_power'))
  player:SetRunSpeed(config.get('run_speed'))

  player:SetNoDraw(false)
  player:UnLock()
  player:SetNotSolid(false)

  hook.run('PostPlayerSpawn', player)

  local old_hands = player:GetHands()

  if IsValid(old_hands) then
    old_hands:Remove()
  end

  local hands_entity = ents.Create('gmod_hands')

  if IsValid(hands_entity) then
    player:SetHands(hands_entity)
    hands_entity:SetOwner(player)

    local info = player_manager.RunClass(player, 'GetHandsModel')

    if info then
      hands_entity:SetModel(info.model)
      hands_entity:SetSkin(info.skin)
      hands_entity:SetBodyGroups(info.body)
    end

    local view_model = player:GetViewModel(0)
    hands_entity:AttachToViewmodel(view_model)

    view_model:DeleteOnRemove(hands_entity)
    player:DeleteOnRemove(hands_entity)

    hands_entity:Spawn()
  end
end

function GM:PostPlayerSpawn(player)
  player_manager.RunClass(player, 'Loadout')

  if player:can('toolgun') then
    player:Give('gmod_tool')
  end

  if player:can('physgun') then
    player:Give('weapon_physgun')
  end

  hook.run_client(player, 'PostPlayerSpawn')
end

function GM:PlayerSetModel(player)
  local override = hook.run('PrePlayerSetModel', player)

  if isstring(override) then
    player:SetModel(override)
  elseif isbool(override) and override == false and self.BaseClass.PlayerSetModel then
    self.BaseClass:PlayerSetModel(player)
  elseif player:IsBot() then
    player:SetModel(player:get_nv('model', 'models/humans/group01/male_0'..math.random(1, 9)..'.mdl'))
  elseif player:has_initialized() then
    player:SetModel(player:get_nv('model', 'models/humans/group01/male_02.mdl'))
  elseif self.BaseClass.PlayerSetModel then
    self.BaseClass:PlayerSetModel(player)
  end
end

function GM:PlayerInitialized(player)
  player:set_initialized(true)

  hook.run_client(player, 'PlayerInitialized')
end

function GM:PlayerDeath(player, inflictor, attacker)
  player:set_nv('respawn_time', CurTime() + config.get('respawn_delay'))
end

function GM:PlayerDeathThink(player)
  local respawn_time = player:get_nv('respawn_time', 0)

  if respawn_time <= CurTime() then
    player:Spawn()
  end

  return false
end

function GM:PlayerDisconnected(player)
  player:save_player()
  cable.send(nil, 'PlayerDisconnected', player:EntIndex())

  Log:notify(player:name()..' ('..player:GetUserGroup()..') has disconnected from the server.', { action = 'player_events' })
end

function GM:EntityRemoved(entity)
  entity:clear_net_vars()

  self.BaseClass:EntityRemoved(entity)
end

function GM:OnPluginFileChange(file_name)
  plugin.OnPluginChanged(file_name)
end

function GM:GetFallDamage(player, speed)
  local fall_damage = hook.run('FLGetFallDamage', player, speed)

  if speed < 660 then
    speed = speed - 250
  end

  if !fall_damage then
    fall_damage = 100 * ((speed) / 850) * 0.75
  end

  return fall_damage
end

function GM:PlayerShouldTakeDamage(player, attacker)
  return hook.run('FLPlayerShouldTakeDamage', player, attacker) or true
end

function GM:PlayerSpawnProp(player, model)
  if !IsValid(player) then return true end

  if !player:can('spawn_props') then
    return false
  end

  if hook.run('FLPlayerSpawnProp', player, model) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnObject(player, model, skin)
  if !IsValid(player) then return true end

  if !player:can('spawn_entities') then
    return false
  end

  if hook.run('FLPlayerSpawnObject', player, model, skin) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnNPC(player, npc, weapon)
  if !IsValid(player) then return true end

  if !player:can('spawn_npcs') then
    return false
  end

  if hook.run('FLPlayerSpawnNPC', player, npc, weapon) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnEffect(player, model)
  if !IsValid(player) then return true end

  if !player:can('spawn_entities') then
    return false
  end

  if hook.run('FLPlayerSpawnEffect', player, model) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnVehicle(player, model, name, tab)
  if !IsValid(player) then return true end

  if !player:can('spawn_vehicles') then
    return false
  end

  if hook.run('FLPlayerSpawnVehicle', player, model, name, tab) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnSWEP(player, weapon, swep)
  if !IsValid(player) then return true end

  if !player:can('spawn_sweps') then
    return false
  end

  if hook.run('FLPlayerSpawnSWEP', player, weapon, swep) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnSENT(player, class)
  if !IsValid(player) then return true end

  if !player:can('spawn_entities') then
    return false
  end

  if hook.run('FLPlayerSpawnSENT', player, class) == false then
    return false
  end

  return true
end

function GM:PlayerSpawnRagdoll(player, model)
  if !IsValid(player) then return true end

  if !player:can('spawn_ragdolls') then
    return false
  end

  if hook.run('FLPlayerSpawnRagdoll', player, model) == false then
    return false
  end

  return true
end

function GM:PlayerGiveSWEP(player, weapon, swep)
  if !IsValid(player) then return true end

  if !player:can('spawn_sweps') then
    return false
  end

  if hook.run('FLPlayerGiveSWEP', player, weapon, swep) == false then
    return false
  end

  return true
end

function GM:OnPhysgunFreeze(weapon, phys_obj, entity, player)
  if player:can('physgun_freeze') then
    BaseClass.OnPhysgunFreeze(self, weapon, phys_obj, entity, player)

    return false
  end
end

function GM:EntityTakeDamage(ent, damage_info)
  if IsValid(ent) and ent:IsPlayer() then
    hook.run('PlayerTakeDamage', ent, damage_info)
  end
end

function GM:PlayerTakeDamage(player, damage_info)
  cable.send(player, 'PlayerTakeDamage')
end

function GM:OneSecond()
  local cur_time = CurTime()
  local sys_time = SysTime()

  if !fl.next_save_data then
    fl.next_save_data = cur_time + 10
  elseif fl.next_save_data <= cur_time then
    if hook.run('FLShouldSaveData') != false then
      hook.run('FLSaveData')
    end

    fl.next_save_data = cur_time + config.get('data_save_interval')
  end

  if !fl.next_player_count_check then
    fl.next_player_count_check = sys_time + 1800
  elseif fl.next_player_count_check <= sys_time then
    fl.next_player_count_check = sys_time + 1800

    if #player.GetAll() == 0 then
      if hook.run('ShouldServerAutoRestart') != false then
        fl.dev_print('Server is empty, restarting...')
        RunConsoleCommand('changelevel', game.GetMap())
      end
    end
  end
end

function GM:PreLoadPlugins()
  fl.shared.disabled_plugins = data.load('disabled_plugins', {})
end

do
  local function write_client_file(path, contents)
    fileio.MakeDirectory 'lua/flux'
    fileio.MakeDirectory 'lua/flux/client'

    fileio.Write('lua/flux/client/'..path, contents)
    AddCSLuaFile('flux/client/'..path)
  end

  local function write_html()
    write_client_file('3_html.lua', fl.html:generate_html_file() or '-- .keep')
    write_client_file('4_css.lua', fl.html:generate_css_file() or '-- .keep')
    write_client_file('5_js.lua', fl.html:generate_js_file() or '-- .keep')
  end

  local function write_client_files()
    write_client_file('0_shared.lua', 'fl.shared = fl.deserialize([['..fl.serialize(fl.shared)..']])\n')
    write_client_file('1_settings.lua', 'Settings = fl.deserialize([['..fl.serialize(Settings)..']])\n')
    write_client_file('2_lang.lua', "library.new('lang', fl)\nfl.lang.stored = fl.deserialize([["..fl.serialize(fl.lang.stored).."]])\n")
    write_html()
  end

  concommand.Add('fl_reload_html', function(player)
    if !IsValid(player) then
      print('Rewriting HTML...')
      for k, v in pairs(fl.html.file_paths) do
        fl.html[v.pipe][v.file_name] = fileio.Read(k)
      end

      write_html()
    end
  end)

  function GM:OnSchemaLoaded()
    write_client_files()
  end

  function GM:OnReloaded()
    write_client_files()
  end
end

function GM:FLSaveData()
  config.save()
  hook.run('SaveData')
end

function GM:PlayerOneSecond(player, cur_time)
  local pos = player:GetPos()

  if player.last_pos != pos then
    hook.run('PlayerPositionChanged', player, player.last_pos, pos, cur_time)
  end

  player.last_pos = pos
end

function GM:PlayerThink(player, cur_time)
  local act = player:get_action()

  if act != 'idle' and act != 'spawning' then
    player:do_action()
  end
end

function GM:PlayerSay(player, text, team_chat)
  local is_command, length = string.is_command(tostring(text))

  if is_command then
    fl.command:interpret(player, text:utf8sub(1 + length, text:utf8len()))

    return ''
  end
end

function GM:ShowHelp(player) end

-- Awful awful awful code, but it's kinda necessary in some rare cases.
-- Avoid using PlayerThink whenever possible though.
do
  local think_delay = 1 * 0.125
  local next_think = 0
  local next_second = 0

  function GM:Tick()
    local cur_time = CurTime()

    if cur_time >= next_think then
      local one_second_tick = (cur_time >= next_second)

      for k, v in ipairs(player.GetAll()) do
        hook.Call('PlayerThink', self, v, cur_time)

        if one_second_tick then
          hook.Call('PlayerOneSecond', self, v, cur_time)
        end
      end

      next_think = cur_time + think_delay

      if one_second_tick then
        next_second = cur_time + 1
      end
    end
  end
end
