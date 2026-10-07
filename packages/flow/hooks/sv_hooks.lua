DEFINE_BASECLASS('gamemode_base')

--- Does nothing, which disables the default handling of a player's death.
-- @param victim [Player the player who died]
-- @param attacker [Entity]
-- @param damage_info [CTakeDamageInfo]
function GM:DoPlayerDeath(victim, attacker, damage_info)
end

--- Mutes the default death sound.
-- @param victim [Player]
-- @return [Boolean always true]
function GM:PlayerDeathSound(victim)
  return true
end

--- Prevents players from killing themselves through the console.
-- @param actor [Player]
-- @return [Boolean always false]
function GM:CanPlayerSuicide(actor)
  return false
end

--- Registers the Flux tools with the tool gun and runs the LoadData and FLInitPostEntity hooks.
function GM:InitPostEntity()
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(Flux.Tool.stored) do
    toolgun.Tool[v.Mode] = v
  end

  hook.Run('LoadData')
  Plugin.call('FLInitPostEntity')
end

--- Sets up a newly connected player: assigns the flux_player class and the 'user' group,
-- restores their saved data and announces the spawn to all clients. Bots are marked as
-- initialized right away instead.
-- @param actor [Player]
function GM:PlayerInitialSpawn(actor)
  player_manager.SetPlayerClass(actor, 'flux_player')
  player_manager.RunClass(actor, 'Spawn')

  actor:SetUserGroup('user')
  actor:restore_player()

  if actor:IsBot() then
    actor:set_initialized(true)
    return
  end

  Cable.send(nil, 'fl_player_initial_spawn', actor:EntIndex())
end

--- Resets the state of a spawning player (model, collisions, visibility and the movement
-- speeds from the config), runs the PostPlayerSpawn hook and creates their hands model.
-- @param actor [Player]
function GM:PlayerSpawn(actor)
  player_manager.SetPlayerClass(actor, 'flux_player')

  hook.Run('PlayerSetModel', actor)

  actor:SetCollisionGroup(COLLISION_GROUP_PLAYER)
  actor:SetMaterial('')
  actor:SetMoveType(MOVETYPE_WALK)
  actor:Extinguish()
  actor:UnSpectate()
  actor:GodDisable()

  actor:SetCrouchedWalkSpeed(Config.get('crouched_speed') / Config.get('walk_speed'))
  actor:SetWalkSpeed(Config.get('walk_speed'))
  actor:SetJumpPower(Config.get('jump_power'))
  actor:SetRunSpeed(Config.get('run_speed'))

  actor:SetNoDraw(false)
  actor:UnLock()
  actor:SetNotSolid(false)
  actor:SetCanZoom(false)

  hook.Run('PostPlayerSpawn', actor)

  local old_hands = actor:GetHands()

  if IsValid(old_hands) then
    old_hands:Remove()
  end

  local hands_entity = ents.Create('gmod_hands')

  if IsValid(hands_entity) then
    actor:SetHands(hands_entity)
    hands_entity:SetOwner(actor)

    local info = player_manager.RunClass(actor, 'GetHandsModel')

    if info then
      hands_entity:SetModel(info.model)
      hands_entity:SetSkin(info.skin)
      hands_entity:SetBodyGroups(info.body)
    end

    local view_model = actor:GetViewModel(0)
    hands_entity:AttachToViewmodel(view_model)

    view_model:DeleteOnRemove(hands_entity)
    actor:DeleteOnRemove(hands_entity)

    hands_entity:Spawn()
  end
end

--- Gives the player their loadout, plus the tool gun and the physics gun if they have the
-- toolgun and physgun permissions, then runs PostPlayerSpawn on their client.
-- @param actor [Player]
function GM:PostPlayerSpawn(actor)
  player_manager.RunClass(actor, 'Loadout')

  if actor:can('toolgun') then
    actor:Give('gmod_tool')
  end

  if actor:can('physgun') then
    actor:Give('weapon_physgun')
  end

  hook.run_client(actor, 'PostPlayerSpawn')
end

--- Sets the model of a player. A string returned by the PrePlayerSetModel hook is used as
-- the model, and false defers to the base gamemode. Otherwise bots and initialized players
-- get the model from their 'model' networked variable (a citizen model if it is not set),
-- and anyone else is left to the base gamemode.
-- @param actor [Player]
function GM:PlayerSetModel(actor)
  local override = hook.Run('PrePlayerSetModel', actor)

  if isstring(override) then
    actor:SetModel(override)
  elseif isbool(override) and override == false and self.BaseClass.PlayerSetModel then
    self.BaseClass:PlayerSetModel(actor)
  elseif actor:IsBot() then
    actor:SetModel(actor:get_nv('model', 'models/humans/group01/male_0'..math.random(1, 9)..'.mdl'))
  elseif actor:has_initialized() then
    actor:SetModel(actor:get_nv('model', 'models/humans/group01/male_02.mdl'))
  elseif self.BaseClass.PlayerSetModel then
    self.BaseClass:PlayerSetModel(actor)
  end
end

--- Marks the player as initialized and, shortly after, runs PlayerInitialized on their client.
-- @param actor [Player]
function GM:PlayerInitialized(actor)
  actor:set_initialized(true)

  timer.Simple(0.25, function()
    hook.run_client(actor, 'PlayerInitialized')
  end)
end

--- Stores the time at which the player may respawn, based on the respawn_delay config.
-- @param victim [Player the player who died]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function GM:PlayerDeath(victim, inflictor, attacker)
  victim:set_nv('respawn_time', CurTime() + Config.get('respawn_delay'))
end

--- Respawns a dead player once their respawn time has passed.
-- @param actor [Player]
-- @return [Boolean always false]
function GM:PlayerDeathThink(actor)
  local respawn_time = actor:get_nv('respawn_time', 0)

  if respawn_time <= CurTime() then
    actor:Spawn()
  end

  return false
end

--- Saves the data of the player unless their should_save_data field is false, tells all
-- clients about the disconnect and logs it.
-- @param actor [Player]
function GM:PlayerDisconnected(actor)
  if actor.should_save_data != false then
    actor:save_player()
  end

  Cable.send(nil, 'fl_player_disconnected', actor:EntIndex())

  Log:notify(actor:name()..' has disconnected from the server.', { action = 'player_events' })
end

--- Clears the networked variables of the removed entity before passing the event on to the
-- base gamemode.
-- @param entity [Entity]
function GM:EntityRemoved(entity)
  entity:clear_net_vars()

  self.BaseClass:EntityRemoved(entity)
end

--- Returns the fall damage of a player: the result of the FLGetFallDamage hook if it
-- returns one, otherwise a value calculated from the fall speed.
-- @param actor [Player]
-- @param speed [Number fall speed]
-- @return [Number damage to deal]
function GM:GetFallDamage(actor, speed)
  local fall_damage = hook.Run('FLGetFallDamage', actor, speed)

  if speed < 660 then
    speed = speed - 250
  end

  if !fall_damage then
    fall_damage = 100 * ((speed) / 850) * 0.75
  end

  return fall_damage
end

--- Asks the FLPlayerShouldTakeDamage hook whether a player can be damaged. Note that a
-- false or nil result of the hook is turned into true, so damage is never blocked here.
-- @param victim [Player]
-- @param attacker [Entity]
-- @return [Boolean true, or the truthy value returned by the hook]
function GM:PlayerShouldTakeDamage(victim, attacker)
  return hook.Run('FLPlayerShouldTakeDamage', victim, attacker) or true
end

--- Decides whether a player may spawn a prop.
-- Requires the spawn_props permission and that the FLPlayerSpawnProp hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param model [String model of the prop]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnProp(actor, model)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_props') then
    return false
  end

  if hook.Run('FLPlayerSpawnProp', actor, model) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn a prop, ragdoll or effect.
-- Requires the spawn_entities permission and that the FLPlayerSpawnObject hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param model [String model of the object]
-- @param skin [Number skin of the object]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnObject(actor, model, skin)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_entities') then
    return false
  end

  if hook.Run('FLPlayerSpawnObject', actor, model, skin) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn an NPC.
-- Requires the spawn_npcs permission and that the FLPlayerSpawnNPC hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param npc [String type of the NPC]
-- @param weapon [String class of the weapon given to the NPC]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnNPC(actor, npc, weapon)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_npcs') then
    return false
  end

  if hook.Run('FLPlayerSpawnNPC', actor, npc, weapon) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn an effect.
-- Requires the spawn_entities permission and that the FLPlayerSpawnEffect hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param model [String model of the effect]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnEffect(actor, model)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_entities') then
    return false
  end

  if hook.Run('FLPlayerSpawnEffect', actor, model) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn a vehicle.
-- Requires the spawn_vehicles permission and that the FLPlayerSpawnVehicle hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param model [String model of the vehicle]
-- @param name [String name of the vehicle in the vehicle list]
-- @param tab [Map vehicle table from the vehicle list]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnVehicle(actor, model, name, tab)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_vehicles') then
    return false
  end

  if hook.Run('FLPlayerSpawnVehicle', actor, model, name, tab) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn a weapon.
-- Requires the spawn_sweps permission and that the FLPlayerSpawnSWEP hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param weapon [String class of the weapon]
-- @param swep [Map information about the weapon from the weapon list]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnSWEP(actor, weapon, swep)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_sweps') then
    return false
  end

  if hook.Run('FLPlayerSpawnSWEP', actor, weapon, swep) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn a scripted entity.
-- Requires the spawn_entities permission and that the FLPlayerSpawnSENT hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param class [String class of the entity]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnSENT(actor, class)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_entities') then
    return false
  end

  if hook.Run('FLPlayerSpawnSENT', actor, class) == false then
    return false
  end

  return true
end

--- Decides whether a player may spawn a ragdoll.
-- Requires the spawn_ragdolls permission and that the FLPlayerSpawnRagdoll hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param model [String model of the ragdoll]
-- @return [Boolean whether spawning is allowed]
function GM:PlayerSpawnRagdoll(actor, model)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_ragdolls') then
    return false
  end

  if hook.Run('FLPlayerSpawnRagdoll', actor, model) == false then
    return false
  end

  return true
end

--- Decides whether a player may give themselves a weapon.
-- Requires the spawn_sweps permission and that the FLPlayerGiveSWEP hook does not
-- return false. Invalid players are always allowed.
-- @param actor [Player]
-- @param weapon [String class of the weapon]
-- @param swep [Map information about the weapon from the weapon list]
-- @return [Boolean whether giving the weapon is allowed]
function GM:PlayerGiveSWEP(actor, weapon, swep)
  if !IsValid(actor) then return true end

  if !actor:can('spawn_sweps') then
    return false
  end

  if hook.Run('FLPlayerGiveSWEP', actor, weapon, swep) == false then
    return false
  end

  return true
end

--- Lets the base gamemode freeze the entity if the player has the physgun_freeze permission.
-- @param weapon [Weapon the physics gun]
-- @param phys_obj [PhysObj the physics object being frozen]
-- @param entity [Entity the entity the physics object belongs to]
-- @param actor [Player the player trying to freeze it]
-- @return [Boolean false if the player has the permission, nil otherwise]
function GM:OnPhysgunFreeze(weapon, phys_obj, entity, actor)
  if actor:can('physgun_freeze') then
    BaseClass.OnPhysgunFreeze(self, weapon, phys_obj, entity, actor)

    return false
  end
end

--- Runs the PlayerTakeDamage hook when the damaged entity is a player.
-- @param ent [Entity the entity taking damage]
-- @param damage_info [CTakeDamageInfo]
function GM:EntityTakeDamage(ent, damage_info)
  if IsValid(ent) and ent:IsPlayer() then
    hook.Run('PlayerTakeDamage', ent, damage_info)
  end
end

--- Notifies the client of the damaged player, which shows the damage flash on their HUD.
-- @param victim [Player]
-- @param damage_info [CTakeDamageInfo]
function GM:PlayerTakeDamage(victim, damage_info)
  Cable.send(victim, 'fl_player_take_damage')
end

--- Runs the FLSaveData hook every data_save_interval seconds, unless FLShouldSaveData
-- returns false. Also checks every half an hour whether the server is empty and reloads
-- the map if it is, unless ShouldServerAutoRestart returns false.
function GM:OneSecond()
  local cur_time = CurTime()
  local sys_time = SysTime()

  if !Flux.next_save_data then
    Flux.next_save_data = cur_time + 10
  elseif Flux.next_save_data <= cur_time then
    if hook.Run('FLShouldSaveData') != false then
      hook.Run('FLSaveData')
    end

    Flux.next_save_data = cur_time + Config.get('data_save_interval', 360)
  end

  if !Flux.next_player_count_check then
    Flux.next_player_count_check = sys_time + 1800
  elseif Flux.next_player_count_check <= sys_time then
    Flux.next_player_count_check = sys_time + 1800

    if #player.GetAll() == 0 then
      if hook.Run('ShouldServerAutoRestart') != false then
        Flux.dev_print('Server is empty, restarting...')
        RunConsoleCommand('changelevel', game.GetMap())
      end
    end
  end
end

--- Loads the list of disabled plugins into Flux.shared before the plugins are loaded.
function GM:PreLoadPlugins()
  Flux.shared.disabled_plugins = Data.load('disabled_plugins', {})
end

do
  local function purge_client_files()
    if file.Exists('lua/_flux/client', 'GAME') then
      local files, dirs = file.Find('lua/_flux/client/*', 'GAME')

      for k, v in ipairs(files) do
        File.delete('lua/_flux/client/'..v)
      end
    end
  end

  local function write_client_file(path, contents)
    File.mkdir 'lua/_flux'
    File.mkdir 'lua/_flux/client'

    File.write('lua/_flux/client/'..path, contents)
    AddCSLuaFile('_flux/client/'..path)
  end

  local function write_html()
    write_client_file('3_html.lua', Flux.HTML:generate_html_file() or '-- .keep')
    write_client_file('4_css.lua', Flux.HTML:generate_css_file() or '-- .keep')
    write_client_file('5_js.lua', Flux.HTML:generate_js_file() or '-- .keep')
  end

  local function write_client_files()
    -- Get rid of the old files (if any)
    purge_client_files()

    -- Do not send server-only settings to the client!
    local settings_copy = table.Copy(Settings)
    settings_copy.server = nil

    if IS_DEVELOPMENT then
      write_client_file('0_shared.lua', 'Flux.shared = table.deserialize([['..table.serialize(Flux.shared)..']])\n')
      write_client_file('1_settings.lua', 'Settings = table.deserialize([['..table.serialize(settings_copy)..']])\n')
      write_client_file('2_lang.lua', "mod'Flux::Lang'\nFlux.Lang.stored = table.deserialize([["..table.serialize(Flux.Lang.stored)..']])\n')
      write_html()
    else
      print 'Compiling clientside assets...'

      local contents = 'Flux.shared=table.deserialize([['..table.serialize(Flux.shared)..']])'
      contents = contents..'Settings=table.deserialize([['..table.serialize(settings_copy)..']])'
      contents = contents.."mod'Flux::Lang'Flux.Lang.stored=table.deserialize([["..table.serialize(Flux.Lang.stored)..']])'
      contents = contents..(Flux.HTML:generate_html_file() or '')..' '
      contents = contents..(Flux.HTML:generate_css_file() or '')..' '
      contents = contents..(Flux.HTML:generate_js_file() or '')

      write_client_file('0_production.lua', contents)
    end
  end

  concommand.Add('fl_reload_html', function(actor)
    if !IsValid(actor) then
      print('Reloading HTML...')

      local total = tostring(table.Count(Flux.HTML.file_paths))
      local len = total:len()
      local i = 0

      Msg('  -> 0 / '..total)

      for k, v in pairs(Flux.HTML.file_paths) do
        i = i + 1
        Msg('\r  -> '..i..' / '..total)
        Flux.HTML[v.pipe][v.file_name] = File.read(k)
      end

      write_html()

      Msg ' (done)\n'
    end
  end)

  --- Writes the files that get sent to clients (shared data, settings, language phrases and
  -- the HTML, CSS and JavaScript assets) into lua/_flux/client.
  function GM:FluxPackageLoaded()
    write_client_files()
  end

  --- Writes the files that get sent to clients again after a Lua refresh.
  function GM:OnReloaded()
    write_client_files()
  end
end

--- Saves the config and runs the SaveData hook.
function GM:FLSaveData()
  Config.save()
  hook.Run('SaveData')
end

--- Runs the PlayerPositionChanged hook if the player has moved since the previous check.
-- @param actor [Player]
-- @param cur_time [Number current CurTime()]
function GM:PlayerOneSecond(actor, cur_time)
  local pos = actor:GetPos()

  if actor.last_pos != pos then
    hook.Run('PlayerPositionChanged', actor, actor.last_pos, pos, cur_time)
  end

  actor.last_pos = pos
end

--- Runs the current action of the player, unless it is 'idle' or 'spawning'.
-- @param actor [Player]
-- @param cur_time [Number current CurTime()]
function GM:PlayerThink(actor, cur_time)
  local act = actor:get_action()

  if act != 'idle' and act != 'spawning' then
    actor:do_action()
  end
end

--- Passes chat messages that start with a command prefix to the command interpreter and
-- hides them from the chat.
-- @param actor [Player]
-- @param text [String the chat message]
-- @param team_chat [Boolean whether the message was sent to the team chat]
-- @return [String an empty string if the message was a command, nil otherwise]
function GM:PlayerSay(actor, text, team_chat)
  local is_command, length = string.is_command(tostring(text))

  if is_command then
    Flux.Command:interpret(actor, text:utf8sub(1 + length, utf8.len(text)))

    return ''
  end
end

--- Does nothing, which disables the default help menu.
-- @param actor [Player]
function GM:ShowHelp(actor)
end

--- Saves the data of every player before the server restarts.
function GM:ServerRestart()
  for k, v in ipairs(player.GetAll()) do
    v:save_player()
  end
end

--- Prevents players from picking entities up with the use key.
-- @param actor [Player]
-- @param entity [Entity]
-- @return [Boolean always false]
function GM:AllowPlayerPickup(actor, entity)
  return false
end

--- Applies changes of the walk_speed, run_speed, crouched_speed and jump_power configs to
-- every player.
-- @param key [String key of the config that has changed]
-- @param old_value [Any]
-- @param new_value [Any]
function GM:OnConfigSet(key, old_value, new_value)
  if key == 'walk_speed' then
    for k, v in ipairs(player.GetAll()) do
      v:SetWalkSpeed(new_value)
    end
  elseif key == 'run_speed' then
    for k, v in ipairs(player.GetAll()) do
      v:SetRunSpeed(new_value)
    end
  elseif key == 'crouched_speed' then
    for k, v in ipairs(player.GetAll()) do
      v:SetCrouchedWalkSpeed(new_value / Config.get('walk_speed'))
    end
  elseif key == 'jump_power' then
    for k, v in ipairs(player.GetAll()) do
      v:SetJumpPower(new_value)
    end
  end
end

--- Strips the weapons of the player, gives them the default loadout and selects the first
-- weapon of it.
-- @param actor [Player]
-- @param default_loadout [List<String> weapon classes to give]
function GM:PostPlayerLoadout(actor, default_loadout)
  actor:StripWeapons()

  for k, v in pairs(default_loadout) do
    actor:Give(v)
  end

  actor:SelectWeapon(default_loadout[1])
end

--- Tells the client of the player to open the interaction menu for the player or entity
-- they pressed the use key on, at most once a second.
-- @param activator [Player]
-- @param target [Entity the entity being used]
function GM:PlayerUse(activator, target)
  if IsValid(target) then
    local cur_time = CurTime()

    if !activator.next_use or activator.next_use < cur_time then
      if target:IsPlayer() then
        Cable.send(activator, 'fl_player_interact', target)
      else
        Cable.send(activator, 'fl_entity_interact', target)
      end

      activator.next_use = cur_time + 1
    end
  end
end

-- Awful awful awful code, but it's kinda necessary in some rare cases.
-- Avoid using PlayerThink whenever possible though.
do
  local think_delay = 1 * 0.125
  local next_think = 0
  local next_second = 0

  --- Runs the PlayerThink hook for every player eight times a second and the PlayerOneSecond
  -- hook once a second.
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
