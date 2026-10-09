--- Shared hooks of the Limbs plugin: the movement penalties of hurt legs. They are applied to
-- the movement data of every command rather than to the run speed and the jump power of the
-- player, so they stack with whatever other plugins set those to, and they run on the server
-- and in the prediction of the owner, who is the only client that knows their limbs.

--- Slows a player with hurt legs down while they run: the speed limit of the command is
-- lowered from the run speed towards the walk speed, down to half of the run speed for a
-- crippled leg, but never below the walk speed. Also notes whether the command starts a jump
-- for the FinishMove handler.
-- @param actor [Player]
-- @param move_data [CMoveData]
function Limbs:Move(actor, move_data)
  actor.limb_jump = nil

  if actor:GetMoveType() != MOVETYPE_WALK or !actor:Alive() then return end

  if actor:OnGround() and move_data:KeyPressed(IN_JUMP) then
    actor.limb_jump = true
  end

  local fraction = self:get_effect(actor, 'run')

  if fraction <= 0 then return end

  local limit = math.max(actor:GetRunSpeed() / (1 + fraction), actor:GetWalkSpeed())

  if move_data:GetMaxClientSpeed() > limit then
    move_data:SetMaxClientSpeed(limit)
  end

  if move_data:GetMaxSpeed() > limit then
    move_data:SetMaxSpeed(limit)
  end
end

--- Lowers the jump of a player with hurt legs: when the command has taken the player off
-- the ground with a jump, the upward speed they have gained is cut, down to half for a
-- crippled leg.
-- @param actor [Player]
-- @param move_data [CMoveData]
function Limbs:FinishMove(actor, move_data)
  if !actor.limb_jump then return end

  actor.limb_jump = nil

  if actor:OnGround() then return end

  local velocity = move_data:GetVelocity()

  if velocity.z <= 0 then return end

  local fraction = self:get_effect(actor, 'jump')

  if fraction <= 0 then return end

  velocity.z = velocity.z / (1 + fraction)

  move_data:SetVelocity(velocity)
end
