--- Server side of the Animations plugin: checking whether a player may start an animation,
-- playing its sequences one after another and ending it.
-- What a player is playing is kept in `actor.animation_data`: the ID of the animation, its
-- phase ('enter', 'main' or 'exit'), the sequences picked for the player's model, where the
-- player stood when it started and whether the plugin has turned third person on for them.
-- Every sequence is set with `Player:set_animation` and a finish callback, which is how the
-- plugin learns that a sequence has played out or that the framework has dropped it.

local wall_reach = 24
local fallback_time = 2

--- Returns how long a sequence of a player's model lasts.
-- @param target [Player]
-- @param sequence [String name of the sequence]
-- @return [Number seconds, a fallback of two seconds if the sequence reports no length]
local function sequence_length(target, sequence)
  local _, length = target:LookupSequence(sequence)

  if length and length > 0 then
    return length
  end

  return fallback_time
end

--- Clears everything the plugin keeps for a player who was playing an animation: the state,
-- the networked variables that lock the player and the third person view, if the plugin has
-- turned it on. Does not touch the sequence the player is playing.
-- @param target [Player]
-- @param state [Map animation state of the player]
local function release(target, state)
  if target.animation_data == state then
    target.animation_data = nil
  end

  target:set_nv('fl_animation', nil)
  target:set_nv('fl_animation_angle', nil)

  if state.third_person then
    target:set_nv('fl_third_person', false)
  end
end

local phase_ended

--- Makes a player play the sequence of the next phase of their animation. The phase is
-- switched before the sequence is set, so that the finish callback of the previous phase,
-- which the new sequence replaces, is ignored.
-- @param target [Player]
-- @param state [Map animation state of the player]
-- @param phase [String 'enter', 'main' or 'exit']
-- @param sequence [String name of the sequence]
-- @param duration [Number seconds to keep the sequence for, 0 keeps it until it is stopped]
-- @return [Boolean false if the model of the player has no such sequence]
local function start_phase(target, state, phase, sequence, duration)
  state.phase = phase

  return target:set_animation(sequence, duration, function(owner, completed)
    phase_ended(owner, state, phase, completed)
  end)
end

--- Makes a player play the main sequence of their animation.
-- @param target [Player]
-- @param state [Map animation state of the player]
-- @return [Boolean false if the model of the player has no such sequence]
local function start_main(target, state)
  return start_phase(target, state, 'main', state.anim, state.duration)
end

--- Makes a player play the exit sequence of their animation.
-- @param target [Player]
-- @param state [Map animation state of the player]
-- @return [Boolean false if the animation has no exit sequence or the model lacks it]
local function start_exit(target, state)
  if !state.exit then return false end

  return start_phase(target, state, 'exit', state.exit, sequence_length(target, state.exit))
end

--- Handles the end of a sequence that the plugin has set for a player. A sequence that
-- has played out is followed by the one of the next phase, or the animation is over. A
-- sequence that was stopped or replaced by something else (the framework stops it when the
-- player dies, spawns or gets another model) ends the animation at once, without touching
-- whatever the player plays now. Callbacks of phases the animation has moved on from are
-- ignored.
-- @param target [Player]
-- @param state [Map animation state the sequence belonged to]
-- @param phase [String phase the sequence belonged to]
-- @param completed [Boolean whether the sequence was kept for its whole duration]
function phase_ended(target, state, phase, completed)
  if target.animation_data != state or state.phase != phase then return end

  if completed then
    if phase == 'enter' and start_main(target, state) then return end
    if phase == 'main' and start_exit(target, state) then return end
  end

  release(target, state)
end

--- Looks for a wall next to a player, as an animation that is played against one needs.
-- A wall is anything solid and upright within reach that is not a player or an NPC.
-- @param actor [Player]
-- @param data [Map animation data with the wall and wall_height fields]
-- @param facing [Angle direction the player is facing, yaw only]
-- @return [Angle direction the player has to face: away from the wall if it has to be behind
--   them, towards it otherwise; nil if there is no wall]
local function find_wall(actor, data, facing)
  local start = actor:EyePos()
  local reach = wall_reach

  if data.wall_height then
    start = actor:GetPos() + Vector(0, 0, data.wall_height)
  end

  if data.wall != 'front' then
    reach = -reach
  end

  local trace = util.TraceLine({
    start = start,
    endpos = start + facing:Forward() * reach,
    filter = actor
  })
  local entity = trace.Entity

  if !trace.Hit or trace.StartSolid or math.abs(trace.HitNormal.z) > 0.5 then return end
  if IsValid(entity) and (entity:IsPlayer() or entity:IsNPC()) then return end

  local yaw = trace.HitNormal:Angle().y

  if data.wall == 'front' then
    yaw = yaw + 180
  end

  return Angle(0, math.NormalizeAngle(yaw), 0)
end

--- Checks whether a player can start an animation and works out what they would play.
-- @param actor [Player]
-- @param id [String ID of the animation]
-- @return [Map plan with the animation data, the sequences and the angle to face; or nil,
--   String phrase that says why not, Map arguments of the phrase]
local function prepare(actor, id)
  local data = Animations:get(id)

  if !data or !actor:has_initialized() or Animations:is_restricted(actor) then
    return nil, 'error.cant_now'
  end

  if actor.animation_data then
    return nil, 'error.animations.busy'
  end

  local remaining = (actor.next_animation or 0) - CurTime()

  if remaining > 0 then
    return nil, 'error.animations.cooldown', { time = math.ceil(remaining) }
  end

  if actor:Crouching() then
    return nil, 'error.animations.crouching'
  end

  if !actor:OnGround() then
    return nil, 'error.animations.not_on_ground'
  end

  local sequences = Animations:get_sequences(actor, data)

  if !sequences then
    return nil, 'error.animations.model'
  end

  local angle = Angle(0, actor:EyeAngles().y, 0)

  if data.wall then
    angle = find_wall(actor, data, angle)

    if !angle then
      if data.wall == 'front' then
        return nil, 'error.animations.wall_front'
      end

      return nil, 'error.animations.wall_behind'
    end
  end

  --- Asks whether a player may start an animation from the context menu or through
  -- `Animations:play`. Called on the server after the plugin's own checks have passed: the
  -- player is alive, on foot, on the ground, not crouching, not ragdolled, not in observer
  -- mode, not playing another animation, past the cooldown, and their model has the
  -- sequences.
  -- @param actor [Player The player who wants to play the animation]
  -- @param id [String ID of the animation]
  -- @param data [Map The registered animation data]
  -- @return [Boolean Return false to refuse. A second return value, a text or a language
  --   phrase, is shown to the player instead of the default refusal]
  local allowed, reason = hook.Run('PlayerCanPlayAnimation', actor, id, data)

  if allowed == false then
    return nil, reason or 'error.cant_now'
  end

  return {
    data = data,
    sequences = sequences,
    angle = angle
  }
end

--- Checks whether a player is in a state in which no animation can be played: dead, in a
-- vehicle, ragdolled, in observer mode, deep in water, or anything but on foot, which
-- covers noclipping, climbing a ladder and being frozen.
-- @param actor [Player]
-- @return [Boolean]
function Animations:is_restricted(actor)
  if !actor:Alive() or actor:InVehicle() or actor:GetMoveType() != MOVETYPE_WALK then
    return true
  end

  if actor:get_nv('observer') or actor:WaterLevel() >= 2 then
    return true
  end

  if isfunction(actor.is_ragdolled) and actor:is_ragdolled() then
    return true
  end

  return false
end

--- Checks whether a player may start an animation right now. Runs the
-- `PlayerCanPlayAnimation` hook once the plugin's own checks have passed.
-- @param actor [Player]
-- @param id [String ID of the animation]
-- @return [Boolean whether the animation can be started, String phrase that says why not,
--   Map arguments of the phrase or nil]
function Animations:can_play(actor, id)
  local plan, reason, arguments = prepare(actor, id)

  if !plan then
    return false, reason, arguments
  end

  return true
end

--- Makes a player play an animation: the enter sequence, if it has one, then the main
-- sequence. The player is turned to the wall if the animation needs one, locked in place
-- and, with the `animations_third_person` config on, switched to third person. Starts the
-- cooldown of the `animations_cooldown` config.
-- ```
-- local started, reason, arguments = Animations:play(actor, 'sit_ground')
--
-- if !started then
--   actor:notify(reason, arguments)
-- end
-- ```
-- @param actor [Player]
-- @param id [String ID of the animation]
-- @return [Boolean whether the animation has started, String phrase that says why not,
--   Map arguments of the phrase or nil]
function Animations:play(actor, id)
  local plan, reason, arguments = prepare(actor, id)

  if !plan then
    return false, reason, arguments
  end

  local data, sequences = plan.data, plan.sequences
  local variants = sequences.variants
  local anim = variants[math.random(#variants)]
  local duration = tonumber(data.duration) or 0
  local third_person = false

  if data.one_shot and duration <= 0 then
    duration = sequence_length(actor, anim)
  end

  if Config.get('animations_third_person', true) and !actor:get_nv('fl_third_person', false) then
    third_person = true
  end

  local state = {
    id = id,
    phase = 'enter',
    enter = sequences.enter,
    anim = anim,
    exit = sequences.exit,
    duration = duration,
    position = actor:GetPos(),
    third_person = third_person
  }

  if data.wall then
    actor:SetEyeAngles(plan.angle)
  end

  if actor:get_nv('auto_walk') then
    actor:set_nv('auto_walk', false)
  end

  actor.animation_data = state
  actor.next_animation = CurTime() + Config.get('animations_cooldown', 2)

  actor:set_nv('fl_animation', id)
  actor:set_nv('fl_animation_angle', plan.angle)

  if third_person then
    actor:set_nv('fl_third_person', true)
  end

  local enter = state.enter

  if enter and start_phase(actor, state, 'enter', enter, sequence_length(actor, enter)) then
    return true
  end

  if start_main(actor, state) then
    return true
  end

  release(actor, state)

  return false, 'error.animations.model'
end

--- Makes a player leave the animation they are playing the way they would by themselves:
-- with its exit sequence, after which they are free again. An animation without an exit
-- sequence ends at once.
-- @param actor [Player]
-- @return [Boolean false if the player is not playing an animation]
function Animations:leave(actor)
  local state = actor.animation_data

  if !state then return false end

  if state.phase != 'exit' and !start_exit(actor, state) then
    self:stop(actor)
  end

  return true
end

--- Ends the animation of a player at once, without its exit sequence: the sequence is
-- stopped, the player can move again, leaves third person if the plugin has put them into
-- it, and the plugin forgets the animation.
-- @param actor [Player]
-- @return [Boolean false if the player is not playing an animation]
function Animations:stop(actor)
  local state = actor.animation_data

  if !state then return false end

  state.phase = 'stopped'

  if Flux.Anim.forced[actor] then
    actor:stop_animation()
  end

  release(actor, state)

  return true
end
