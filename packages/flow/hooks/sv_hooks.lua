--- Server side of the gamemode hooks: the `GM` handlers that set players up when they join
-- and spawn, decide their model, fall damage and respawn time, check the sandbox spawn
-- menu and physics gun against the Flux permissions, save the data periodically and when
-- the server shuts down, pass chat commands to the command interpreter and write the files
-- that are sent to clients.
-- Most of Flux's server-side hooks are run from here, including `PostPlayerSpawn`,
-- `PlayerThink`, `PlayerOneSecond`, `FLSaveData`, `PostSaveData` and the
-- `FLPlayerSpawn...` checks.

local IsValid = IsValid
local CurTime = CurTime
local config_get = Config.get
local player_iterator = player.Iterator

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

  --- Called once the map's entities have been created, for plugins to load their saved
  -- data. Runs on both realms, from the server-side and from the client-side
  -- `InitPostEntity` handler of the gamemode. The counterpart of `SaveData`, which only
  -- runs on the server.
  hook.Run('LoadData')
  --- Called at the end of the gamemode's `InitPostEntity` handler, right after `LoadData`,
  -- on both realms. The Flux tools have been registered with the tool gun by then, and on
  -- the client the `PLAYER` global has been set. Gamemode (`GM`) handlers are not called.
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

  --- GMod's `PlayerSetModel` hook, run by Flux on the server every time a player spawns,
  -- before the rest of their state is reset. The gamemode's handler applies the model
  -- (see `PrePlayerSetModel` for changing it). A plugin or schema handler that returns a
  -- value replaces the gamemode's handler and has to set the model itself.
  -- @param actor [Player The player who is spawning]
  hook.Run('PlayerSetModel', actor)

  actor:SetCollisionGroup(COLLISION_GROUP_PLAYER)
  actor:SetMaterial('')
  actor:SetMoveType(MOVETYPE_WALK)
  actor:Extinguish()
  actor:UnSpectate()
  actor:GodDisable()

  local walk_speed = config_get('walk_speed')

  actor:SetCrouchedWalkSpeed(config_get('crouched_speed') / walk_speed)
  actor:SetWalkSpeed(walk_speed)
  actor:SetJumpPower(config_get('jump_power'))
  actor:SetRunSpeed(config_get('run_speed'))

  actor:SetNoDraw(false)
  actor:UnLock()
  actor:SetNotSolid(false)
  actor:SetCanZoom(false)

  --- Called on the server every time a player spawns, after their model, collisions,
  -- visibility and movement speeds have been reset and before their hands model is
  -- created. This is the place to set up whatever the player should spawn with.
  -- The gamemode's handler gives the loadout, plus the tool gun and the physics gun to
  -- players with the permissions for them, then runs the hook on the player's own client,
  -- where it is called without arguments.
  -- @param actor [Player The player who has spawned; nil on the client]
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
  --- Lets plugins choose the model a player gets when the gamemode sets it, which happens
  -- on the server every time the player spawns.
  -- @param actor [Player The player whose model is being set]
  -- @return [String/Boolean Path of the model to use, or false to let the base gamemode
  --   pick the model. When nothing is returned, bots and initialized players get the model
  --   from their `model` networked variable and everyone else is left to the base gamemode]
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
  victim:set_nv('respawn_time', CurTime() + config_get('respawn_delay'))
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
  --- Lets plugins set the damage a player takes from a fall. Called on the server from the
  -- gamemode's `GetFallDamage` handler.
  -- @param actor [Player The player who has hit the ground]
  -- @param speed [Number Speed at which the player hit the ground]
  -- @return [Number Damage to deal; when nothing or false is returned, the damage is
  --   calculated from the speed]
  local fall_damage = hook.Run('FLGetFallDamage', actor, speed)

  if speed < 660 then
    speed = speed - 250
  end

  if !fall_damage then
    fall_damage = 100 * ((speed) / 850) * 0.75
  end

  return fall_damage
end

--- Asks the FLPlayerShouldTakeDamage hook whether a player can be damaged. The damage is
-- only blocked when the hook returns false.
-- @param victim [Player]
-- @param attacker [Entity]
-- @return [Boolean false if the hook has returned false, true otherwise]
function GM:PlayerShouldTakeDamage(victim, attacker)
  --- Called on the server from the gamemode's `PlayerShouldTakeDamage` handler, when a
  -- player is about to take damage from an attacker.
  -- @param victim [Player The player about to take damage]
  -- @param attacker [Entity The entity dealing the damage]
  -- @return [Boolean Return false to prevent the damage. The player takes the damage when
  --   anything else or nothing is returned]
  return hook.Run('FLPlayerShouldTakeDamage', victim, attacker) != false
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

  --- Called on the server when a player tries to spawn a prop, after the gamemode has
  -- checked that they have the `spawn_props` permission.
  -- @param actor [Player The player spawning the prop]
  -- @param model [String Model of the prop]
  -- @return [Boolean Return false to prevent the prop from being spawned]
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

  --- Called on the server when a player tries to spawn a prop, a ragdoll or an effect,
  -- after the gamemode has checked that they have the `spawn_entities` permission.
  -- @param actor [Player The player spawning the object]
  -- @param model [String Model of the object]
  -- @param skin [Number Skin of the object]
  -- @return [Boolean Return false to prevent the object from being spawned]
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

  --- Called on the server when a player tries to spawn an NPC, after the gamemode has
  -- checked that they have the `spawn_npcs` permission.
  -- @param actor [Player The player spawning the NPC]
  -- @param npc [String Type of the NPC]
  -- @param weapon [String Class of the weapon given to the NPC]
  -- @return [Boolean Return false to prevent the NPC from being spawned]
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

  --- Called on the server when a player tries to spawn an effect, after the gamemode has
  -- checked that they have the `spawn_entities` permission.
  -- @param actor [Player The player spawning the effect]
  -- @param model [String Model of the effect]
  -- @return [Boolean Return false to prevent the effect from being spawned]
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

  --- Called on the server when a player tries to spawn a vehicle, after the gamemode has
  -- checked that they have the `spawn_vehicles` permission.
  -- @param actor [Player The player spawning the vehicle]
  -- @param model [String Model of the vehicle]
  -- @param name [String Name of the vehicle in the vehicle list]
  -- @param tab [Map Vehicle table from the vehicle list]
  -- @return [Boolean Return false to prevent the vehicle from being spawned]
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

  --- Called on the server when a player tries to spawn a weapon, after the gamemode has
  -- checked that they have the `spawn_sweps` permission.
  -- @param actor [Player The player spawning the weapon]
  -- @param weapon [String Class of the weapon]
  -- @param swep [Map Information about the weapon from the weapon list]
  -- @return [Boolean Return false to prevent the weapon from being spawned]
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

  --- Called on the server when a player tries to spawn a scripted entity, after the
  -- gamemode has checked that they have the `spawn_entities` permission.
  -- @param actor [Player The player spawning the entity]
  -- @param class [String Class of the entity]
  -- @return [Boolean Return false to prevent the entity from being spawned]
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

  --- Called on the server when a player tries to spawn a ragdoll, after the gamemode has
  -- checked that they have the `spawn_ragdolls` permission.
  -- @param actor [Player The player spawning the ragdoll]
  -- @param model [String Model of the ragdoll]
  -- @return [Boolean Return false to prevent the ragdoll from being spawned]
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

  --- Called on the server when a player tries to give themselves a weapon from the spawn
  -- menu, after the gamemode has checked that they have the `spawn_sweps` permission.
  -- @param actor [Player The player taking the weapon]
  -- @param weapon [String Class of the weapon]
  -- @param swep [Map Information about the weapon from the weapon list]
  -- @return [Boolean Return false to prevent the weapon from being given]
  if hook.Run('FLPlayerGiveSWEP', actor, weapon, swep) == false then
    return false
  end

  return true
end

--- Lets the base gamemode freeze the entity if the player has the physgun_freeze permission
-- or a PlayerCanPhysgunFreeze handler allows it. Plugins that want to refuse a freeze return
-- false from OnPhysgunFreeze before this handler runs.
-- @param weapon [Weapon the physics gun]
-- @param phys_obj [PhysObj the physics object being frozen]
-- @param entity [Entity the entity the physics object belongs to]
-- @param actor [Player the player trying to freeze it]
-- @return [Boolean false if the entity has been frozen, nil otherwise]
function GM:OnPhysgunFreeze(weapon, phys_obj, entity, actor)
  --- Asks whether a player who lacks the physgun_freeze permission may freeze an entity
  -- with the physics gun all the same, for instance because they own it. Called on the
  -- server after every OnPhysgunFreeze handler has had the chance to refuse.
  -- @param actor [Player The player holding the physics gun]
  -- @param entity [Entity The entity being frozen]
  -- @return [Boolean Return true to allow the freeze]
  if actor:can('physgun_freeze') or hook.Run('PlayerCanPhysgunFreeze', actor, entity) == true then
    BaseClass.OnPhysgunFreeze(self, weapon, phys_obj, entity, actor)

    return false
  end
end

--- Runs the PlayerTakeDamage hook when the damaged entity is a player.
-- @param ent [Entity the entity taking damage]
-- @param damage_info [CTakeDamageInfo]
function GM:EntityTakeDamage(ent, damage_info)
  if IsValid(ent) and ent:IsPlayer() then
    --- Called on the server whenever a player takes damage, from the gamemode's
    -- `EntityTakeDamage` handler. The return value is ignored, so the damage cannot be
    -- blocked from here. The gamemode's handler tells the victim's client to show the
    -- damage flash.
    -- @param victim [Player The player taking the damage]
    -- @param damage_info [CTakeDamageInfo The damage being dealt]
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
    --- Asks whether the periodic data save may happen now. Called on the server every
    -- `data_save_interval` seconds (360 unless configured), for the first time about ten
    -- seconds after the server has started.
    -- @return [Boolean Return false to skip this save]
    if hook.Run('FLShouldSaveData') != false then
      --- Called on the server when all persistent data has to be saved: every
      -- `data_save_interval` seconds unless `FLShouldSaveData` returns false, when the
      -- server shuts down or changes the map, and by the restart command of the admin
      -- plugin. The gamemode's handler saves the config and runs `SaveData`, which is the
      -- hook that plugins normally implement, followed by `PostSaveData`.
      hook.Run('FLSaveData')
    end

    Flux.next_save_data = cur_time + config_get('data_save_interval', 360)
  end

  if !Flux.next_player_count_check then
    Flux.next_player_count_check = sys_time + 1800
  elseif Flux.next_player_count_check <= sys_time then
    Flux.next_player_count_check = sys_time + 1800

    if player.GetCount() == 0 then
      --- Asks whether the empty server may reload the current map. Called on the server every
      -- half an hour, if no players are connected at that moment.
      -- @return [Boolean Return false to prevent the map from being reloaded]
      if hook.Run('ShouldServerAutoRestart') != false then
        Flux.dev_print('Server is empty, restarting...')
        RunConsoleCommand('changelevel', game.GetMap())
      end
    end
  end
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

  -- Garry's Mod does not send a Lua file to clients if it is larger than 64 KB once it is
  -- compressed, clients get an empty file instead. Serialized tables are hex digits, which
  -- compress to half their size at worst, so pieces of this length always stay below that.
  local chunk_size = 100000

  -- Writes a table for the client, split over as many files as it takes. The pieces are put
  -- back together by Flux.receive_chunk, 'assign' is the code that runs once 'data' is whole.
  local function write_client_table(name, tab, assign)
    local contents = table.serialize(tab)
    local count = math.max(math.ceil(#contents / chunk_size), 1)

    for i = 1, count do
      write_client_file(
        string.format('%s_%02d.lua', name, i),
        "local data = Flux.receive_chunk('"..name.."', "..i..', '..count..', [['
          ..contents:sub((i - 1) * chunk_size + 1, i * chunk_size)..']])\n'
          ..'if data then '..assign..' end\n'
      )
    end
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

    write_client_table('0_shared', Flux.shared, 'Flux.shared = data')
    write_client_table('1_settings', settings_copy, 'Settings = data')
    write_client_table('2_lang', Flux.Lang.stored, "mod'Flux::Lang' Flux.Lang.stored = data")

    if IS_DEVELOPMENT then
      write_html()
    else
      print 'Compiling clientside assets...'

      local contents = (Flux.HTML:generate_html_file() or '')..' '
      contents = contents..(Flux.HTML:generate_css_file() or '')..' '
      contents = contents..(Flux.HTML:generate_js_file() or '')

      write_client_file('3_production.lua', contents)
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

--- Saves the config and runs the SaveData hook, then the PostSaveData hook.
function GM:FLSaveData()
  Config.save()
  --- Called on the server for plugins to save their persistent data, from the gamemode's
  -- `FLSaveData` handler after the config has been saved. The counterpart of `LoadData`.
  hook.Run('SaveData')
  --- Called on the server after a data save, when the config has been saved and every
  -- `SaveData` handler has run. This is the place for work that depends on the saved
  -- state, such as a backup or a log entry. Database queries that the handlers have
  -- started may still be running.
  hook.Run('PostSaveData')
end

--- Saves everything when the server shuts down or changes the map: runs the FLSaveData
-- hook and saves the data of every player. Afterwards Flux.shutting_down is true, so that
-- code which runs while the map unloads (an entity's OnRemove, for example) can tell.
function GM:ShutDown()
  hook.Run('FLSaveData')

  for k, v in player_iterator() do
    v:save_player()
  end

  Flux.shutting_down = true
end

--- Runs the PlayerPositionChanged hook if the player has moved since the previous check.
-- @param actor [Player]
-- @param cur_time [Number current CurTime()]
function GM:PlayerOneSecond(actor, cur_time)
  local pos = actor:GetPos()
  local last_pos = actor.last_pos

  if last_pos != pos then
    --- Called on the server when a player is not where they were a second ago. The gamemode
    -- checks this once a second for every player, from its `PlayerOneSecond` handler.
    -- @param actor [Player The player who has moved]
    -- @param old_pos [Vector Position at the previous check; nil at the player's first check]
    -- @param new_pos [Vector Current position]
    -- @param cur_time [Number CurTime() of the check]
    hook.Run('PlayerPositionChanged', actor, last_pos, pos, cur_time)
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
  for k, v in player_iterator() do
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

--- Lets the PlayerSwitchedFlashlight hook decide whether a player may toggle their flashlight,
-- and leaves the decision to the base gamemode when no handler returns anything. Plugin and
-- schema handlers of PlayerSwitchFlashlight run before this one and replace it when they
-- return a value.
-- @param actor [Player]
-- @param on [Boolean whether the flashlight is being turned on]
-- @return [Boolean whether the flashlight may be toggled]
function GM:PlayerSwitchFlashlight(actor, on)
  --- Called on the server when a player toggles their flashlight, before the engine does
  -- it. The Shared Flashlight plugin handles it by toggling a light that other players can
  -- see and returning false.
  -- @param actor [Player The player who toggles the flashlight]
  -- @param on [Boolean Whether the flashlight is being turned on]
  -- @return [Boolean Return false to keep the engine flashlight from toggling, true to allow
  --   it; the base gamemode decides when nothing is returned]
  local result = hook.Run('PlayerSwitchedFlashlight', actor, on)

  if result != nil then
    return result
  end

  return BaseClass.PlayerSwitchFlashlight(self, actor, on)
end

--- Applies changes of the walk_speed, run_speed, crouched_speed and jump_power configs to
-- every player.
-- @param key [String key of the config that has changed]
-- @param old_value [Any]
-- @param new_value [Any]
function GM:OnConfigSet(key, old_value, new_value)
  if key == 'walk_speed' then
    for k, v in player_iterator() do
      v:SetWalkSpeed(new_value)
    end
  elseif key == 'run_speed' then
    for k, v in player_iterator() do
      v:SetRunSpeed(new_value)
    end
  elseif key == 'crouched_speed' then
    local crouched_speed = new_value / config_get('walk_speed')

    for k, v in player_iterator() do
      v:SetCrouchedWalkSpeed(crouched_speed)
    end
  elseif key == 'jump_power' then
    for k, v in player_iterator() do
      v:SetJumpPower(new_value)
    end
  end
end

--- Strips the weapons of the player, gives them the default loadout and selects the first
-- weapon of it, then runs the PlayerLoadoutGiven hook for the weapons that plugins add.
-- @param actor [Player]
-- @param default_loadout [List<String> weapon classes to give]
function GM:PostPlayerLoadout(actor, default_loadout)
  actor:StripWeapons()

  for k, v in pairs(default_loadout) do
    actor:Give(v)
  end

  actor:SelectWeapon(default_loadout[1])

  --- Called on the server once a spawning player holds the default loadout, after the
  -- gamemode has stripped their weapons and given the default ones. This is where a plugin
  -- or schema gives the player the weapons of their faction, rank or job: a weapon given
  -- from `PostPlayerLoadout` would be stripped right after. Runs inside `Player:Spawn`, so
  -- whatever happens after the spawn, such as restoring saved ammo, sees these weapons.
  -- @param actor [Player the player who has spawned]
  -- @param default_loadout [List<String> weapon classes the player has been given]
  hook.Run('PlayerLoadoutGiven', actor, default_loadout)
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

      for k, v in player_iterator() do
        --- Called on the server eight times a second for every player, including players who
        -- are dead or not initialized yet. Prefer `PlayerOneSecond` when once a second is
        -- often enough. The gamemode's handler runs the player's current action.
        -- @param actor [Player The player to process]
        -- @param cur_time [Number CurTime() of the call]
        hook.Call('PlayerThink', self, v, cur_time)

        if one_second_tick then
          --- Called on the server once a second for every player, right after that player's
          -- `PlayerThink`. The gamemode's handler uses it to detect movement (see
          -- `PlayerPositionChanged`).
          -- @param actor [Player The player to process]
          -- @param cur_time [Number CurTime() of the call]
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
