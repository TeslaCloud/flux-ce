--- Server hooks of the Ragdoll plugin: ragdolls players when they die, resets them when they
-- spawn or leave, passes the damage a ragdoll takes on to its player, keeps the get up
-- timers running, pauses them while the player does something else, makes players fall
-- over from hard falls and heavy hits and knocks them out from melee hits when the config
-- says so, and keeps knocked out players from being heard and from switching characters.

local IsValid = IsValid
local config_get = Config.get

--- Checks whether a hit knocks a player out: the ragdoll_knockout_on_damage config is on,
-- the damage is of the DMG_CLUB type (a stunstick, a crowbar) and the player is left alive
-- at or below the ragdoll_knockout_health config, while they are not knocked out already.
-- @param victim [Player]
-- @param damage_info [CTakeDamageInfo]
-- @return [Boolean]
local function knocks_out(victim, damage_info)
  if !config_get('ragdoll_knockout_on_damage') or victim:is_knocked_out() then return false end
  if !damage_info:IsDamageType(DMG_CLUB) then return false end

  local health = victim:Health()

  return health > 0 and health <= config_get('ragdoll_knockout_health', 20)
end

--- Cancels the player's current action and puts them into the RAGDOLL_DUMMY state, which
-- leaves a corpse ragdoll. The ragdoll of a player who died lying on the ground becomes
-- their corpse.
-- @param victim [Player]
function Ragdoll:PlayerDeath(victim)
  victim:reset_action()
  victim:set_ragdoll_state(RAGDOLL_DUMMY)
end

--- Clears the player's ragdoll state when they spawn. Their corpse stays for its decay time.
-- @param actor [Player]
function Ragdoll:PlayerSpawn(actor)
  actor:reset_ragdoll_state()
end

--- Lets go of the ragdoll of a player who is leaving, so that it is removed once the decay
-- time has passed rather than staying on the map.
-- @param actor [Player]
function Ragdoll:PlayerDisconnected(actor)
  local ragdoll = actor:get_ragdoll_entity()

  if IsValid(ragdoll) then
    ragdoll.decay = ragdoll.decay or config_get('ragdoll_decay_time', 120)
  end

  actor:reset_ragdoll_state()
end

--- Runs the PlayerDeathThink hook for dead players that are ragdolled.
-- @param actor [Player]
function Ragdoll:PlayerThink(actor)
  if !actor:Alive() and actor:is_ragdolled() then
    --- GMod's `PlayerDeathThink` hook, run again by the Ragdoll plugin.
    -- Besides the engine's own calls, the plugin runs it on the server from its `PlayerThink`
    -- handler for every dead player who is ragdolled. This call ignores what the handlers
    -- return.
    -- @param actor [Player The dead player]
    hook.Run('PlayerDeathThink', actor)
  end
end

--- Makes sure that a get up timer does what it promised even if its timed action was
-- canceled or could not start: the action is started again, and the player gets up once
-- the time is up. Nothing is done while the player does any timed action, so that none is
-- cut short; a timer that runs while another action starts is paused for it instead.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Ragdoll:PlayerOneSecond(actor, cur_time)
  local data = actor.ragdoll_data

  if !data or !data.getup_end or !actor:Alive() then return end
  if Flux.TimedAction:get(actor) then return end

  local remaining = data.getup_end - cur_time

  if remaining > 0 then
    actor:set_getup_time(remaining)
  else
    data.getup_end = nil

    actor:set_ragdoll_state(RAGDOLL_NONE)
  end
end

--- Pauses the get up timer of a player who starts another timed action, which has canceled
-- the get up action; the timer goes on once that action has ended.
-- @param actor [Player]
-- @param action [Map the timed action that has started]
function Ragdoll:PlayerTimedActionStarted(actor, action)
  if action.id == 'getup' then return end

  local data = actor.ragdoll_data

  if data and data.getup_end and actor:pause_getup_time() then
    data.getup_held = true
  end
end

--- Resumes the get up timer that was paused for a timed action once that action has ended,
-- unless its callback has started yet another one, in which case the timer waits for that
-- one as well.
-- @param actor [Player]
-- @param action [Map the timed action that has ended]
-- @param _success [Boolean whether it ran for its whole duration]
function Ragdoll:PlayerTimedActionFinished(actor, action, _success)
  if action.id == 'getup' or !IsValid(actor) then return end

  local data = actor.ragdoll_data

  if !data or !data.getup_held or Flux.TimedAction:get(actor) then return end

  data.getup_held = nil

  actor:resume_getup_time()
end

--- Mutes knocked out players: nobody hears them over voice chat. Nothing is returned for
-- everyone else, so that the other handlers may still mute them.
-- @param _listener [Player]
-- @param talker [Player]
-- @return [Boolean false if the talker is knocked out, nothing otherwise]
function Ragdoll:PlayerCanHearPlayersVoice(_listener, talker)
  if talker:is_knocked_out() then
    return false
  end
end

--- Keeps knocked out players from switching characters.
-- @param actor [Player]
-- @param _character [Character the character the player wants to load]
-- @param _current [Character their active character]
-- @return [Boolean false and String the reason if the player is knocked out, nothing
--   otherwise]
function Ragdoll:PlayerCanSwitchCharacter(actor, _character, _current)
  if actor:is_knocked_out() then
    return false, 'error.ragdoll.knocked_out_switch'
  end
end

--- Returns the ragdoll data of a living player who is lying on the ground after a fall and
-- has been stripped of their weapons, which they get back when they get up.
-- @param owner [Player]
-- @return [Map the ragdoll data, nil if the player is not in that state]
local function fallen_data(owner)
  if !IsValid(owner) or !owner:IsPlayer() or !owner:Alive() then return end

  local data = owner.ragdoll_data

  if data and data.fallen and istable(data.weapons) then
    return data
  end
end

--- Moves the weapon that a weapon item gives a player who is lying on the ground, and has
-- been stripped of their weapons, into the weapons they get back when they get up.
-- @param owner [Player]
-- @param item_obj [Item the equipped item]
function Ragdoll:OnItemEquipped(owner, item_obj)
  local weapon_class = item_obj.weapon_class
  local data = isstring(weapon_class) and fallen_data(owner)

  if !data then return end

  local weapon = owner:GetWeapon(weapon_class)

  if !IsValid(weapon) then return end

  local stored = false

  for _, entry in ipairs(data.weapons) do
    if entry.class == weapon_class then
      stored = true

      break
    end
  end

  if !stored then
    table.insert(data.weapons, { class = weapon_class, clip1 = weapon:Clip1(), clip2 = weapon:Clip2() })
  end

  owner:StripWeapon(weapon_class)
end

--- Takes the weapon of a weapon item that a player who is lying on the ground unequips out
-- of the weapons they get back when they get up, and stores its clips in the item, so that
-- the weapon does not come back without its item.
-- @param owner [Player]
-- @param item_obj [Item the unequipped item]
function Ragdoll:OnItemUnequipped(owner, item_obj)
  local weapon_class = item_obj.weapon_class
  local data = isstring(weapon_class) and fallen_data(owner)

  if !data then return end

  for index, entry in ipairs(data.weapons) do
    if entry.class == weapon_class then
      table.remove(data.weapons, index)

      if isfunction(item_obj.set_data) then
        item_obj:set_data('ammo', { entry.clip1 or 0, entry.clip2 or 0 })
      end

      break
    end
  end
end

--- Keeps the ragdoll of the player in what is networked to them, however far it ends up
-- from where they fell.
-- @param actor [Player]
-- @param _view_entity [Entity the entity the player sees through]
function Ragdoll:SetupPlayerVisibility(actor, _view_entity)
  local ragdoll = actor:GetDTEntity(ENT_RAGDOLL)

  if IsValid(ragdoll) then
    AddOriginToPVS(ragdoll:GetPos())
  end
end

--- Passes damage dealt to the ragdoll of a living player on to that player. Damage that was
-- not dealt by a player is ignored while the ragdoll is immune, which it is for a moment
-- after the player has fallen; PlayerRagdollCanTakeDamage can block the rest.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
function Ragdoll:EntityTakeDamage(entity, damage_info)
  if !entity:IsRagdoll() then return end

  local owner = entity.player

  if !IsValid(owner) or !owner:Alive() then return end

  local data = owner.ragdoll_data

  if data and data.entity == entity and (data.immunity or 0) > CurTime() then
    local attacker = damage_info:GetAttacker()

    if !IsValid(attacker) or !attacker:IsPlayer() then return end
  end

  --- Asks whether damage dealt to the ragdoll of a living player is passed on to them.
  -- Called on the server for every hit the ragdoll takes once its immunity is over, and
  -- during the immunity for hits dealt by players.
  -- @param owner [Player The player lying on the ground]
  -- @param ragdoll [Entity Their ragdoll]
  -- @param damage_info [CTakeDamageInfo The damage]
  -- @return [Boolean Return false to keep the player from taking the damage]
  if hook.Run('PlayerRagdollCanTakeDamage', owner, entity, damage_info) == false then return end

  owner:TakeDamageInfo(damage_info)
end

--- Knocks a player out when a melee hit leaves them at or below the ragdoll_knockout_health
-- config, for the ragdoll_knockout_time config, while ragdoll_knockout_on_damage is on; a
-- fallen player is knocked out where they lie. Otherwise makes a player fall over when they
-- take at least as much damage from a fall as the ragdoll_fall_damage config, or from
-- anything else as the ragdoll_hit_damage config. A fall leaves them down until they get up
-- by themselves; a hit throws them down for the ragdoll_hit_time config. Both are off while
-- their config is 0.
-- @param entity [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
-- @param took [Boolean whether the entity has actually taken the damage]
function Ragdoll:PostEntityTakeDamage(entity, damage_info, took)
  if !took or !entity:IsPlayer() or !entity:Alive() then return end

  if knocks_out(entity, damage_info) then
    local delay = config_get('ragdoll_knockout_time', 60)
    local attacker = damage_info:GetAttacker()
    local force = damage_info:GetDamageForce()

    timer.Simple(0, function()
      if IsValid(entity) and entity:Alive() and !entity:is_knocked_out() then
        entity:knock_out(delay, { attacker = IsValid(attacker) and attacker or nil, force = force })
      end
    end)

    return
  end

  if entity:InVehicle() or entity:is_ragdolled() then return end

  local fell = damage_info:IsFallDamage()
  local threshold = config_get(fell and 'ragdoll_fall_damage' or 'ragdoll_hit_damage', 0)

  if threshold <= 0 or damage_info:GetDamage() < threshold then return end

  local delay = !fell and config_get('ragdoll_hit_time', 8) or nil
  local force = !fell and damage_info:GetDamageForce() or nil

  timer.Simple(0, function()
    if IsValid(entity) and entity:Alive() and !entity:is_ragdolled() then
      entity:set_ragdoll_state(RAGDOLL_FALLENOVER, delay, { force = force })
    end
  end)
end
