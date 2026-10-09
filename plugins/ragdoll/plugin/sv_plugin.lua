--- Player extensions of the Ragdoll plugin: changing the ragdoll state of a player, the
-- ragdoll entity that stands in for them and the timer that gets them back up.
-- Serverside only.
--
-- While a player has a ragdoll, `Player:get_ragdoll_data` returns the table that describes
-- it. Its fields are:
-- * `entity`: the ragdoll.
-- * `state`: the RAGDOLL_ state the ragdoll was last given.
-- * `fallen`: true if the ragdoll took over the body of a living player (they were frozen,
--   hidden and stripped of their weapons), false if it is only a corpse.
-- * `eye_angles`, `weapons` (their weapons with clips, as `Player:get_weapons_list` lists
--   them with ammo), `weapon` (class of the weapon they held), `no_draw` and `not_solid`:
--   what the player gets back when they get up.
-- * `immunity`: CurTime() until which the ragdoll ignores damage that no player has dealt.
-- * `getup_end`: CurTime() at which the player gets up by themselves, nil without a timer.
-- * `getup_paused`: seconds left on a paused timer, nil if it is not paused.
-- * `getup_held`: true while the timer is paused for another timed action of the player,
--   which the hooks of sv_hooks.lua resume once that action has ended.
--
-- The health and the armor of a fallen player stay on the player: damage dealt to the ragdoll
-- is passed on to them, so `Player:Health` and `Player:Armor` are right at all times. The
-- time at which a running get up timer ends is networked to everyone as the
-- 'ragdoll_getup_end' variable of the player, which `Player:get_knockout_remaining` reads.
--
-- Only the clips of the weapons of a fallen player are stored: `Player:StripWeapons` leaves
-- the reserve ammo on the player, so the weapons are given back without any.

local player_meta = FindMetaTable('Player')
local burn_time = 8
local max_force = 800

--- Shortens a force so that it does not throw a ragdoll across the map.
-- @param force [Vector]
-- @return [Vector the force, no longer than 800 units]
local function limit_force(force)
  local length = force:Length()

  if length > max_force then
    return force * (max_force / length)
  end

  return force
end

--- Removes a ragdoll that no longer belongs to a player, right away or once its decay time
-- has passed.
-- @param ragdoll [Entity]
-- @param owner [Player the player the ragdoll belonged to]
-- @param decay=nil [Number seconds the ragdoll remains; nil or 0 removes it right away]
local function decay_ragdoll(ragdoll, owner, decay)
  if !decay or decay <= 0 then
    ragdoll:Remove()

    return
  end

  --- Asks whether a ragdoll that its player has left behind may be removed once its decay
  -- time has passed. Called on the server when the player respawns, gets up or disconnects,
  -- for ragdolls that have a decay time; a ragdoll without one is removed right away and
  -- does not run the hook.
  -- @param owner [Player The player the ragdoll belonged to; they are leaving the server
  --   when the hook is run for a disconnect]
  -- @param ragdoll [Entity The ragdoll]
  -- @param decay [Number Seconds after which the ragdoll is removed]
  -- @return [Boolean Return false to keep the ragdoll; whoever does so becomes responsible
  --   for removing it]
  if hook.Run('PlayerCanRagdollDecay', owner, ragdoll, decay) == false then return end

  timer.Simple(decay, function()
    if IsValid(ragdoll) then
      --- Called on the server when the decay time of a ragdoll that its player has left
      -- behind is up, right before the ragdoll is removed. Not called for a ragdoll that
      -- is removed without a decay time, such as the one a player gets up from.
      -- @param owner [Player The player the ragdoll belonged to; no longer valid if they
      --   have left the server]
      -- @param ragdoll [Entity The ragdoll, still valid]
      hook.Run('PlayerRagdollDecayed', owner, ragdoll)

      ragdoll:Remove()
    end
  end)
end

--- Gives a player whose body was taken over by a ragdoll their own body back.
-- @param target [Player]
-- @param data [Map ragdoll data of the player]
-- @param ragdoll [Entity the ragdoll they get up from; may be invalid]
-- @param reset [Boolean the player is being respawned: only make them visible, solid and
--   able to move again]
local function stand_up(target, data, ragdoll, reset)
  target:Freeze(false)

  if reset then
    target:SetNoDraw(false)
    target:SetNotSolid(false)

    return
  end

  target:SetNoDraw(data.no_draw == true)
  target:SetNotSolid(data.not_solid == true)

  if IsValid(ragdoll) then
    target:SetPos(ragdoll:GetPos())

    if ragdoll:IsOnFire() then
      local remaining = (data.burning_until or 0) - CurTime()

      target:Ignite(remaining > 0 and math.max(remaining, 1) or burn_time, 0)
    end
  end

  if data.eye_angles then
    target:SetEyeAngles(data.eye_angles)
  end

  target:give_weapons(data.weapons or {}, true)

  if data.weapon and target:HasWeapon(data.weapon) then
    target:SelectWeapon(data.weapon)
  end

  if !data.not_solid and target:stuck() then
    target:DropToFloor()
    target:SetPos(target:GetPos() + Vector(0, 0, 16))

    if target:stuck() then
      target:unstuck(IsValid(ragdoll) and { ragdoll, target } or target)
    end
  end
end

--- Networks the end of the get up timer of a player, so that clients can show how long
-- they stay down.
-- @param target [Player]
-- @param data=nil [Map ragdoll data of the player; nil clears the variable]
local function sync_getup_end(target, data)
  target:set_nv('ragdoll_getup_end', data and data.getup_end or nil)
end

--- Takes a player out of their ragdoll state without asking any hook: stops their get up
-- timer, sets the state to RAGDOLL_NONE, lets go of the ragdoll and runs PlayerUnragdolled,
-- and PlayerWokeUp for a player who was knocked out.
-- @param target [Player]
-- @param reset [Boolean the player is being respawned rather than getting up]
local function unragdoll(target, reset)
  local data = target.ragdoll_data
  local state = target:get_ragdoll_state()

  if data then
    data.getup_end = nil
    data.getup_paused = nil
    data.getup_held = nil
  end

  sync_getup_end(target)
  Flux.TimedAction:cancel(target, 'getup')

  if target:is_doing_action('fallen') then
    target:reset_action()
  end

  target:SetDTInt(INT_RAGDOLL_STATE, RAGDOLL_NONE)
  target:reset_ragdoll_entity(reset)

  if state != RAGDOLL_NONE then
    --- Called on the server after a player has left a ragdoll state: they got back up,
    -- respawned after their death, or were reset while lying on the ground.
    -- @param target [Player The player]
    -- @param state [Number The RAGDOLL_ state they were in]
    -- @param data [Map The ragdoll data they had, see plugins/ragdoll/plugin/sv_plugin.lua;
    --   nil if they had no ragdoll]
    -- @param reset [Boolean True if the state was cleared because the player is respawning
    --   or leaving, false if they got up where their ragdoll was]
    hook.Run('PlayerUnragdolled', target, state, data, reset == true)
  end

  if state == RAGDOLL_KNOCKEDOUT then
    --- Called on the server after a knocked out player has come to: their knockout timer
    -- ran out, something got them up or made them merely fallen over, or their state was
    -- cleared because they respawn or leave. Not called when they die while knocked out.
    -- @param target [Player The player]
    -- @param reset [Boolean True if the state was cleared because the player is respawning
    --   or leaving, false if they came to where they lay]
    hook.Run('PlayerWokeUp', target, reset == true)
  end
end

--- Starts the timed action that shows the get up timer of a player and gets them up when it
-- completes.
-- @param target [Player]
-- @param data [Map ragdoll data of the player]
-- @param duration [Number seconds]
-- @return [Boolean true if the action has started]
local function start_getup_action(target, data, duration)
  return Flux.TimedAction:start(target, 'getup', duration, {
    text = data.state == RAGDOLL_KNOCKEDOUT and 'ui.hud.bar_text.wakeup' or 'ui.hud.bar_text.getup',
    force = true,
    callback = function(actor, success)
      if success and IsValid(actor) and actor.ragdoll_data == data and data.getup_end then
        data.getup_end = nil

        actor:set_ragdoll_state(RAGDOLL_NONE)
      end
    end
  })
end

--- Runs the PlayerCanRagdoll hook.
-- @param target [Player]
-- @param state [Number RAGDOLL_ state the player is about to enter]
-- @param delay=nil [Number seconds after which they would get up by themselves]
-- @param data=nil [Map their ragdoll data if they are already lying on the ground]
-- @return [Boolean false if a handler has refused]
local function can_ragdoll(target, state, delay, data)
  --- Asks whether a player may be put into a ragdoll state. Called on the server before a
  -- living player falls over or is knocked out, before the state of a player who is already
  -- down is changed, and before a corpse is left for a player who died on their feet.
  -- @param target [Player The player]
  -- @param state [Number The RAGDOLL_ state they are about to enter]
  -- @param delay [Number Seconds after which they would get up by themselves; nil if they
  --   stay down]
  -- @param data [Map Their ragdoll data if they are already lying on the ground, nil
  --   otherwise]
  -- @return [Boolean Return false to prevent it. A dead player then leaves no corpse, but is
  --   still in the RAGDOLL_DUMMY state until they respawn]
  return hook.Run('PlayerCanRagdoll', target, state, delay, data) != false
end

--- Stores the state a ragdoll was given and runs the PlayerRagdolled hook.
-- @param target [Player]
-- @param state [Number RAGDOLL_ state the player has entered]
-- @param data [Map their ragdoll data]
local function ragdolled(target, state, data)
  data.state = state

  --- Called on the server after a player has entered a ragdoll state: they fell over, were
  -- knocked out, were switched between the two while lying on the ground, or died and left
  -- a corpse.
  -- @param target [Player The player]
  -- @param state [Number The RAGDOLL_ state they are in now]
  -- @param data [Map Their ragdoll data, see plugins/ragdoll/plugin/sv_plugin.lua]
  hook.Run('PlayerRagdolled', target, state, data)
end

--- Returns the table that describes the ragdoll of the player: what they get back when they
-- get up, the damage immunity and the get up timer. Its fields are listed at the top of
-- plugins/ragdoll/plugin/sv_plugin.lua. Serverside only.
-- @return [Map the ragdoll data, or nil if the player has no ragdoll]
function player_meta:get_ragdoll_data()
  return self.ragdoll_data
end

--- Sets the networked ragdoll entity of the player. Does not spawn or remove anything.
-- Serverside only.
-- @param entity [Entity]
function player_meta:set_ragdoll_entity(entity)
  self:SetDTEntity(ENT_RAGDOLL, entity)
end

--- Spawns a ragdoll copy of the player (model, skin, bodygroups, material and color) and
-- stores it as their ragdoll entity. Does nothing if they already have a valid one. A fallen
-- player first leaves the vehicle they are in; they are then frozen, hidden and stripped of
-- their weapons, and a fire they are burning with moves over to the ragdoll. They get
-- everything back once the ragdoll is let go of or removed. Serverside only.
-- @param decay=nil [Number seconds the ragdoll remains after the ragdoll entity is reset;
--   nil removes it right away]
-- @param fallen=false [Boolean whether the player has fallen over rather than died]
-- @param force=nil [Vector push to give to every bone of the ragdoll]
-- @return [Entity the ragdoll, or nil if it could not be created]
-- @see [Player#set_ragdoll_state]
function player_meta:create_ragdoll_entity(decay, fallen, force)
  local existing = self:GetDTEntity(ENT_RAGDOLL)

  if IsValid(existing) then return existing end

  fallen = fallen and true or false

  local in_vehicle = fallen and self:InVehicle()

  if in_vehicle then
    self:ExitVehicle()
  end

  local ragdoll = ents.Create('prop_ragdoll')

  if !IsValid(ragdoll) then return end

  ragdoll:SetModel(self:GetModel())
  ragdoll:SetPos(self:GetPos())
  ragdoll:SetAngles(self:GetAngles())
  ragdoll:SetSkin(self:GetSkin())
  ragdoll:SetMaterial(self:GetMaterial())
  ragdoll:SetColor(self:GetColor())

  for k, v in ipairs(self:GetBodyGroups()) do
    ragdoll:SetBodygroup(v.id, self:GetBodygroup(v.id))
  end

  ragdoll.player = self
  ragdoll.decay = decay
  ragdoll:Spawn()

  if !IsValid(ragdoll) or ragdoll:IsMarkedForDeletion() then return end

  ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)

  local velocity = self:GetVelocity()

  if force then
    force = limit_force(force)
  end

  for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
    local phys_obj = ragdoll:GetPhysicsObjectNum(i)
    local position, angle = self:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))

    if IsValid(phys_obj) and position then
      phys_obj:SetPos(position)
      phys_obj:SetAngles(angle)
      phys_obj:SetVelocity(velocity)

      if force then
        phys_obj:ApplyForceCenter(force)
      end
    end
  end

  local data = { entity = ragdoll, fallen = fallen }

  if fallen then
    local active = self:GetActiveWeapon()
    local grounded = in_vehicle or self:IsOnGround()

    data.eye_angles = self:EyeAngles()
    data.weapons = self:get_weapons_list(true)
    data.weapon = IsValid(active) and active:GetClass() or nil
    data.no_draw = self:GetNoDraw()
    data.not_solid = !self:IsSolid()
    data.immunity = grounded and CurTime() + Config.get('ragdoll_immunity_time', 0.5) or 0

    if self:IsOnFire() then
      data.burning_until = CurTime() + burn_time

      ragdoll:Ignite(burn_time, 0)
      self:Extinguish()
    end

    self:StripWeapons()
    self:Freeze(true)
    self:SetNoDraw(true)
    self:SetNotSolid(true)
  end

  ragdoll:CallOnRemove('fl_ragdoll', function()
    if !IsValid(self) or self.ragdoll_data != data then return end

    data.removed = true

    if data.fallen and self:Alive() then
      unragdoll(self, false)
    else
      self.ragdoll_data = nil
      self:SetDTEntity(ENT_RAGDOLL, NULL)
    end
  end)

  self.ragdoll_data = data
  self:SetDTEntity(ENT_RAGDOLL, ragdoll)

  return ragdoll
end

--- Lets go of the player's ragdoll and removes it, right away or after its decay time
-- (unless PlayerCanRagdollDecay keeps it). A player whose body the ragdoll had taken over
-- gets it back: unless they are dead or being reset, they are moved to the ragdoll, given
-- their weapons and view back and keep burning if the ragdoll was. Serverside only.
-- @param reset=false [Boolean the player is being respawned: only make them visible, solid
--   and able to move again]
function player_meta:reset_ragdoll_entity(reset)
  local data = self.ragdoll_data
  local ragdoll = self:GetDTEntity(ENT_RAGDOLL)

  self.ragdoll_data = nil
  self:SetDTEntity(ENT_RAGDOLL, NULL)

  if data and data.fallen then
    stand_up(self, data, ragdoll, reset or !self:Alive())
  end

  if IsValid(ragdoll) then
    ragdoll.player = nil

    if !data or !data.removed then
      ragdoll:RemoveCallOnRemove('fl_ragdoll')

      decay_ragdoll(ragdoll, self, ragdoll.decay)
    end
  end
end

--- Sets how long the ragdoll of the player ignores damage that was not dealt by a player,
-- such as hitting the ground. Does nothing if the player has no ragdoll. Serverside only.
-- @param delay=nil [Number seconds of immunity from now on; nil ends it]
function player_meta:set_ragdoll_immunity(delay)
  local data = self.ragdoll_data

  if data then
    data.immunity = delay and CurTime() + delay or 0
  end
end

--- Makes the fallen or knocked out player get up by themselves after a delay, replacing the
-- timer they have and resuming a paused one. The timer is a timed action called 'getup',
-- which shows the player a progress bar. Serverside only.
-- ```
-- target:set_getup_time(10) -- get up in ten seconds
-- target:set_getup_time() -- stay down until something else gets the player up
-- ```
-- @param delay=nil [Number seconds until the player gets up; nil or 0 only stops the timer]
-- @return [Boolean false if the player is not alive and lying on the ground]
-- @see [Player#pause_getup_time]
function player_meta:set_getup_time(delay)
  local data = self.ragdoll_data

  if !data or !data.fallen or !self:Alive() then return false end

  data.getup_end = nil
  data.getup_paused = nil
  data.getup_held = nil

  Flux.TimedAction:cancel(self, 'getup')

  delay = tonumber(delay)

  if delay and delay > 0 then
    data.getup_end = CurTime() + delay

    start_getup_action(self, data, delay)
  end

  sync_getup_end(self, data)

  return true
end

--- Returns when the player gets up by themselves. Serverside only.
-- @return [Number CurTime() at which they get up; nil if they have no get up timer or it
--   is paused]
function player_meta:get_getup_time()
  local data = self.ragdoll_data

  return data and data.getup_end or nil
end

--- Pauses the get up timer of the player, for example while someone is carrying them. The
-- player cannot start getting up by themselves while it is paused. Serverside only.
-- @return [Boolean true if a running timer was paused]
-- @see [Player#resume_getup_time]
function player_meta:pause_getup_time()
  local data = self.ragdoll_data

  if !data or !data.getup_end then return false end

  local remaining = math.max(data.getup_end - CurTime(), 0.1)

  data.getup_end = nil

  sync_getup_end(self)
  Flux.TimedAction:cancel(self, 'getup')

  data.getup_paused = remaining

  return true
end

--- Resumes the get up timer of the player with the time it had left when it was paused.
-- Serverside only.
-- @return [Boolean true if a paused timer was resumed]
-- @see [Player#pause_getup_time]
function player_meta:resume_getup_time()
  local data = self.ragdoll_data

  if !data or !data.getup_paused then return false end

  return self:set_getup_time(data.getup_paused)
end

--- Checks whether the get up timer of the player is paused. Serverside only.
-- @return [Boolean]
function player_meta:is_getup_paused()
  local data = self.ragdoll_data

  return data != nil and data.getup_paused != nil
end

--- Makes the fallen player start getting up by themselves, which is what the jump key and
-- the getup command do. Refused if they are not fallen over (a knocked out player has to
-- wait), if they already have a get up timer, running or paused, if someone is dragging
-- their ragdoll (`Player:get_dragger` of the Pickup Objects plugin), or if the
-- PlayerCanGetUp hook says no. Serverside only.
-- @param duration=nil [Number seconds it takes, never less than the ragdoll_getup_time
--   config, which is also the default, nor more than 60]
-- @return [Boolean true if the player has started getting up]
function player_meta:get_up(duration)
  local data = self.ragdoll_data

  if !data or !self:Alive() or self:get_ragdoll_state() != RAGDOLL_FALLENOVER then return false end
  if data.getup_end or data.getup_paused then return false end
  if isfunction(self.get_dragger) and IsValid(self:get_dragger()) then return false end

  --- Asks whether a fallen player may start getting up by themselves. Called on the server
  -- when they press the jump key or run the getup command (`Player:get_up`), not when a
  -- get up timer was given to them by something else.
  -- @param target [Player The player lying on the ground]
  -- @return [Boolean Return false to keep the player down]
  if hook.Run('PlayerCanGetUp', self) == false then return false end

  local minimum = Config.get('ragdoll_getup_time', 4)

  return self:set_getup_time(math.Clamp(tonumber(duration) or minimum, minimum, math.max(minimum, 60)))
end

--- Clears the ragdoll state of the player without getting them up: no hook is asked, the
-- player is not moved to their ragdoll and does not get their weapons back. This is what
-- happens when a player respawns or leaves; the corpse of a dead player then stays for its
-- decay time. Runs PlayerUnragdolled if the player was ragdolled. Serverside only.
function player_meta:reset_ragdoll_state()
  if self:get_ragdoll_state() == RAGDOLL_NONE and !self.ragdoll_data then return end

  unragdoll(self, true)
end

--- Makes a living player fall over or knocks them out, or changes which of the two a player
-- who is already down is. Runs the PlayerCanKnockOut, PlayerKnockedOut and PlayerWokeUp
-- hooks when the knocked out state is entered or left for the fallen over one.
-- @param target [Player]
-- @param state [Number RAGDOLL_FALLENOVER or RAGDOLL_KNOCKEDOUT]
-- @param delay=nil [Number seconds after which the player gets up by themselves]
-- @param options=nil [Map optional settings: force (Vector push given to the ragdoll) and
--   attacker (Entity whoever knocked the player out)]
-- @return [Boolean true if the player is now in the state]
local function fall_down(target, state, delay, options)
  if !target:Alive() then return false end

  delay = tonumber(delay)

  if delay and delay <= 0 then
    delay = nil
  end

  local data = target.ragdoll_data
  local current = target:get_ragdoll_state()
  local down = data != nil and data.fallen and IsValid(data.entity)
    and (current == RAGDOLL_FALLENOVER or current == RAGDOLL_KNOCKEDOUT)
  local attacker = options and options.attacker or nil
  local knocking_out = state == RAGDOLL_KNOCKEDOUT and current != RAGDOLL_KNOCKEDOUT

  if knocking_out then
    --- Asks whether a player may be knocked out. Called on the server before a player who
    -- is not knocked out already is, whether by `Player:knock_out`, the knockout command or
    -- a stunstick hit, and before the PlayerCanRagdoll hook.
    -- @param target [Player The player who is about to be knocked out]
    -- @param attacker [Entity Whoever is knocking them out; nil if nobody in particular]
    -- @param duration [Number Seconds after which they would come to; nil if they stay out
    --   until something wakes them]
    -- @return [Boolean Return false to keep the player conscious]
    if hook.Run('PlayerCanKnockOut', target, attacker, delay) == false then return false end
  end

  if !can_ragdoll(target, state, delay, down and data or nil) then return false end

  if !down then
    if current != RAGDOLL_NONE or data then
      unragdoll(target, true)
    end

    target:create_ragdoll_entity(nil, true, options and options.force)

    data = target.ragdoll_data

    if !data or !data.fallen then return false end

    target:set_action('fallen', true)
  end

  data.state = state

  target:SetDTInt(INT_RAGDOLL_STATE, state)
  target:set_getup_time(delay)

  ragdolled(target, state, data)

  if knocking_out then
    --- Called on the server after a player has been knocked out: they lie on the ground
    -- unable to get up, hear and are heard by nobody over voice chat and cannot switch
    -- characters until they come to.
    -- @param target [Player The player who was knocked out]
    -- @param duration [Number Seconds after which they come to by themselves; nil if they
    --   stay out until something wakes them]
    -- @param attacker [Entity Whoever knocked them out; nil if nobody in particular]
    hook.Run('PlayerKnockedOut', target, delay, attacker)
  elseif current == RAGDOLL_KNOCKEDOUT and state == RAGDOLL_FALLENOVER then
    hook.Run('PlayerWokeUp', target, false)
  end

  return true
end

--- Puts a player into the RAGDOLL_DUMMY state. The ragdoll of a player who was lying on the
-- ground becomes their corpse; anyone else gets a new one unless PlayerCanRagdoll refuses.
-- @param target [Player]
-- @return [Boolean true if the player has a corpse]
local function leave_corpse(target)
  local data = target.ragdoll_data
  local decay = Config.get('ragdoll_decay_time', 120)

  if data then
    data.getup_end = nil
    data.getup_paused = nil
    data.getup_held = nil
  end

  sync_getup_end(target)
  Flux.TimedAction:cancel(target, 'getup')

  if target:is_doing_action('fallen') then
    target:reset_action()
  end

  target:SetDTInt(INT_RAGDOLL_STATE, RAGDOLL_DUMMY)

  if data and IsValid(data.entity) then
    data.entity.decay = decay
  else
    if !can_ragdoll(target, RAGDOLL_DUMMY) then return false end

    target:create_ragdoll_entity(decay)

    data = target.ragdoll_data

    if !data then return false end
  end

  ragdolled(target, RAGDOLL_DUMMY, data)

  return true
end

--- Sets the player's ragdoll state and creates or removes their ragdoll to match it.
-- RAGDOLL_FALLENOVER and RAGDOLL_KNOCKEDOUT put a living player on the ground as a ragdoll,
-- with the 'fallen' action; a fallen player may get up by themselves, a knocked out one may
-- not. RAGDOLL_DUMMY leaves a corpse that stays for the ragdoll_decay_time config after the
-- player respawns. RAGDOLL_NONE gets a player who is lying on the ground back up where
-- their ragdoll is. The PlayerCanRagdoll and PlayerCanUnragdoll hooks can refuse the change;
-- PlayerRagdolled and PlayerUnragdolled run after it. Serverside only.
-- ```
-- target:set_ragdoll_state(RAGDOLL_FALLENOVER) -- fall over until they get up by themselves
-- target:set_ragdoll_state(RAGDOLL_KNOCKEDOUT, 30) -- knock out for half a minute
-- target:set_ragdoll_state(RAGDOLL_NONE) -- get back up
-- ```
-- @param state=RAGDOLL_NONE [Number one of the RAGDOLL_ enums]
-- @param delay=nil [Number seconds after which a fallen or knocked out player gets up by
--   themselves; nil leaves them down until something gets them up]
-- @param options=nil [Map optional settings for falling over: force (Vector push given to
--   the ragdoll, such as the force of the damage that knocked the player down) and
--   attacker (Entity whoever knocked the player out, passed to the knockout hooks)]
-- @return [Boolean true if the player is now in the state, false if a hook has refused or
--   the state does not apply to them]
-- @see [Player#set_getup_time]
-- @see [Player#reset_ragdoll_state]
-- @see [Player#knock_out]
function player_meta:set_ragdoll_state(state, delay, options)
  state = state or RAGDOLL_NONE

  if state == RAGDOLL_FALLENOVER or state == RAGDOLL_KNOCKEDOUT then
    return fall_down(self, state, delay, options)
  elseif state == RAGDOLL_DUMMY then
    return leave_corpse(self)
  elseif state != RAGDOLL_NONE then
    return false
  end

  local current = self:get_ragdoll_state()

  if current == RAGDOLL_NONE and !self.ragdoll_data then return true end

  if self:Alive() and (current == RAGDOLL_FALLENOVER or current == RAGDOLL_KNOCKEDOUT) then
    --- Asks whether a player who is lying on the ground may get back up. Called on the
    -- server when their get up timer runs out or something sets their state to
    -- RAGDOLL_NONE. Not called when the state is cleared because they respawn or leave, nor
    -- when their ragdoll has been removed.
    -- @param target [Player The player]
    -- @param state [Number The RAGDOLL_ state they are in]
    -- @param data [Map Their ragdoll data, see plugins/ragdoll/plugin/sv_plugin.lua]
    -- @return [Boolean Return false to keep the player down]
    if hook.Run('PlayerCanUnragdoll', self, current, self.ragdoll_data) == false then
      return false
    end

    unragdoll(self, false)
  else
    unragdoll(self, true)
  end

  return true
end

--- Knocks the player out: they fall over, or stay down if they are fallen over already, and
-- cannot get up by themselves until they come to. While they are out they are not heard
-- over voice chat and cannot switch characters. The PlayerCanKnockOut hook can refuse;
-- PlayerKnockedOut runs afterwards and PlayerWokeUp once they come to. Serverside only.
-- ```
-- target:knock_out(30, { attacker = actor }) -- out for half a minute
-- target:knock_out() -- out until something wakes them
-- ```
-- @param duration=nil [Number seconds after which the player comes to by themselves; nil
--   or 0 keeps them out until `Player:wake_up`, `Player:set_getup_time` or staff gets them
--   up]
-- @param options=nil [Map optional settings: attacker (Entity whoever knocks the player
--   out) and force (Vector push given to the ragdoll)]
-- @return [Boolean true if the player is knocked out now]
-- @see [Player#set_ragdoll_state]
function player_meta:knock_out(duration, options)
  return self:set_ragdoll_state(RAGDOLL_KNOCKEDOUT, duration, options)
end

--- Brings the knocked out player to: they get up where their ragdoll is, unless the
-- PlayerCanUnragdoll hook keeps them down. Serverside only.
-- @return [Boolean true if the player is up; false if they were not knocked out or a hook
--   has refused]
-- @see [Player#set_ragdoll_state]
function player_meta:wake_up()
  if self:get_ragdoll_state() != RAGDOLL_KNOCKEDOUT then return false end

  return self:set_ragdoll_state(RAGDOLL_NONE)
end
