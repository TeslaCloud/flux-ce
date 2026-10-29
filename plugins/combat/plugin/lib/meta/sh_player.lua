--- Player methods of the turn based combat: the attack and move turns of a player in combat.

local player_meta = FindMetaTable('Player')

--- Checks whether the player has asked to leave their combat.
-- @return [Boolean whether the player is leaving combat]
function player_meta:leaving_combat()
  return self.combat_leaving
end

--- Uses up turns of a type, freezing the matching ability once none are left and ending the turn when all are spent.
-- @param turn_type [Number TURN_ATTACK or TURN_MOVE]
-- @param amount=1 [Number turns to use up]
function player_meta:take_turn(turn_type, amount)
  amount = amount or 1

  local turns = self:get_nv('fl_combat_turns', {})

  if !turns[turn_type] then return end

  self.turn_done = true
  turns[turn_type] -= amount
  self:set_nv('fl_combat_turns', turns)

  if turns[TURN_ATTACK] <= 0 then
    self:freeze_gun()
  end

  if turns[TURN_MOVE] <= 0 then
    self:freeze_move()
  end

  for _k, v in pairs(turns) do
    if v > 0 then
      return
    end
  end

  local combat = self:get_combat()

  if combat and combat:get_acting_member() == self then
    combat:next_turn()
  end
end

--- Returns how many turns of a type the player has left.
-- @param turn_type [Number TURN_ATTACK or TURN_MOVE]
-- @return [Number turns left]
function player_meta:get_turns(turn_type)
  local turns = self:get_nv('fl_combat_turns', {})

  return turns and turns[turn_type] or 0
end

--- Checks whether the player has any turns of a type left.
-- @param turn_type [Number TURN_ATTACK or TURN_MOVE]
-- @return [Boolean whether the player has turns left]
function player_meta:has_turn(turn_type)
  return self:get_turns(turn_type) > 0
end

--- Resets the player's attack and move turns at the start of their turn, using the weapon's turns if it has any.
function player_meta:restore_turns()
  local turns = {
    [TURN_ATTACK] = 1,
    [TURN_MOVE] = 2
  }

  local weapon_item = self:get_active_weapon_item()

  if weapon_item and weapon_item.turns then
    turns[TURN_ATTACK] = weapon_item.turns
  end

  --- Lets plugins change how many attack and move turns a player gets at the start of their
  -- turn in combat. Called on the server. Every handler may change the table, so a handler
  -- should return nothing to let the others run.
  -- @param target [Player the player whose turn starts]
  -- @param turns [Map modified in place: TURN_ATTACK and TURN_MOVE to the number of turns of
  --   each, 1 attack turn (or the `turns` of the weapon item in their hands) and 2 move turns]
  hook.Run('AdjustPlayerTurns', self, turns)

  self:set_nv('fl_combat_turns', turns)

  self.shots_done = 0
  self.turn_done = false
end
