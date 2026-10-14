--- Server-side hooks and net messages of the Animations plugin: the requests of the context
-- menu panel, and everything that ends the animation of a player other than the player
-- leaving it.

local max_drift_sqr = 32 * 32

Cable.receive('fl_animations_play', function(actor, id)
  if !isstring(id) then return end

  if actor.animation_data then
    Animations:leave(actor)

    return
  end

  local started, reason, arguments = Animations:play(actor, id)

  if !started and reason then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_animations_leave', function(actor)
  Animations:leave(actor)
end)

--- Ends the animation of a player who can no longer play it: one who has died, entered a
-- vehicle, been ragdolled or frozen, started noclipping or gone under water, whose sequence
-- has been dropped, who has been off the ground for two checks in a row, or who has been
-- moved away from where they started it.
-- @param actor [Player]
-- @param cur_time [Number current CurTime()]
function Animations:PlayerThink(actor, cur_time)
  local state = actor.animation_data

  if !state then return end

  if self:is_restricted(actor) or !Flux.Anim.forced[actor] then
    self:stop(actor)

    return
  end

  if actor:OnGround() then
    state.airborne = nil
  elseif state.airborne then
    self:stop(actor)

    return
  else
    state.airborne = true
  end

  if actor:GetPos():DistToSqr(state.position) > max_drift_sqr then
    self:stop(actor)
  end
end

--- Ends the animation of a player who has died. The framework has dropped the sequence by
-- then, which ends the animation by itself; this makes sure nothing is left behind.
-- @param victim [Player]
function Animations:PostPlayerDeath(victim)
  self:stop(victim)
end

--- Ends the animation of a player who is spawning, so that they never spawn locked or in
-- the third person view of an animation.
-- @param actor [Player]
function Animations:PlayerSpawn(actor)
  self:stop(actor)
end

--- Ends the animation of a player who is leaving the server.
-- @param actor [Player]
function Animations:PlayerDisconnected(actor)
  self:stop(actor)
end

--- Ends the animation of a player who has switched characters and lets the new character
-- start one right away.
-- @param owner [Player player whose character was set]
-- @param character [Character newly active character]
function Animations:OnActiveCharacterSet(owner, character)
  self:stop(owner)

  owner.next_animation = nil
end
