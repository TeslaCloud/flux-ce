--- A fight of the turn based combat: its members in turn order, the member whose turn it is,
-- the round, and the timers of the turns.

class 'Combat'

local IsValid = IsValid
local pairs = pairs
local timer_create = timer.Create
local timer_remove = timer.Remove
local cable_send = Cable.send

--- Registers the combat with the combat system and sets up its initial state.
function Combat:init()
  self.id = CombatSystem:add(self)
  self.round = 1
  self.current_member = 1
  self.started = false
  self.finished = false
  self.members = {}
end

--- Freezes all members, rolls the turn order and gives the first member their turn.
function Combat:start()
  self.started = true
  self:freeze_members()
  self:calculate_turn_order()

  self:turn(self:get_acting_member(), true)
end

--- Ends the combat, notifies the players and releases all members.
function Combat:finish()
  self.finished = true
  self:notify_finish()
  timer_remove('combat_action_'..self.id)
  self:remove_members()

  CombatSystem:remove(self.id)
end

--- Returns the reflexes of a combat member used to break initiative ties.
-- @param target [Entity the combat member]
-- @return [Number reflexes modifier, 0 when the member has no attributes]
local function get_reflexes(target)
  if target.get_attribute_modifier then
    return target:get_attribute_modifier('reflexes') or 0
  elseif target.get_attribute then
    return target:get_attribute('reflexes') or 0
  end

  return 0
end

--- Sorts the members by rolled initiative (see `CombatSystem:dice_initiative`), keeping the initiator first, and
-- sends the order with every initiative roll to the players. Higher initiative goes first. On a tie a player goes
-- before an NPC, then the member with higher reflexes goes first, and any remaining tie is settled by a random
-- number rolled once per member before sorting.
function Combat:calculate_turn_order()
  local order = self.members
  local initiator, victim = order[1], order[2]

  table.remove(order, 1)

  for k, v in pairs(order) do
    order[k] = {
      entity = v,
      initiative = CombatSystem:dice_initiative(v),
      tiebreak = math.random()
    }
  end

  table.sort(order, function(a, b)
    if a.initiative != b.initiative then
      return a.initiative > b.initiative
    end

    local a_player, b_player = a.entity:IsPlayer(), b.entity:IsPlayer()

    if a_player != b_player then
      return a_player and !b_player
    end

    local ref_a, ref_b = get_reflexes(a.entity), get_reflexes(b.entity)

    if ref_a != ref_b then
      return ref_a > ref_b
    end

    if a.tiebreak != b.tiebreak then
      return a.tiebreak > b.tiebreak
    end

    return false
  end)

  table.insert(order, 1, { entity = initiator, initiative = 'notification.combat.initiator' })

  --- Lets plugins change the turn order of a combat that is starting, after the initiative
  -- has been rolled and sorted and before it is sent to the players. Called on the server.
  -- Every handler may change the list, so a handler should return nothing to let the others
  -- run.
  -- @param order [List<Map> modified in place: one entry per member in turn order, with entity
  --   (Entity the member) and initiative (Number the rolled initiative, or the language
  --   phrase 'notification.combat.initiator' for the initiator, who goes first)]
  -- @param initiator [Entity the member who started the combat]
  -- @param victim [Entity the member who was attacked first]
  hook.Run('AdjustCombatTurnOrder', order, initiator, victim)

  local members = {}

  for _k, v in pairs(order) do
    members[#members + 1] = v.entity
  end

  self.members = members

  self:message_initiative(order)
end

--- Sends the turn order to every player in the combat.
-- @param order [List<Table> entries with entity and initiative fields]
function Combat:message_initiative(order)
  cable_send(self:get_players(), 'fl_combat_turn_order', order)
end

--- Returns the members of the combat that are valid players.
-- @return [List<Player> players in the combat]
function Combat:get_players()
  local players = {}

  for _k, v in pairs(self.members) do
    if IsValid(v) and v:IsPlayer() then
      players[#players + 1] = v
    end
  end

  return players
end

--- Returns the member whose turn it currently is.
-- @return [Entity acting member]
function Combat:get_acting_member()
  return self.members[self.current_member]
end

--- Returns all members of the combat in turn order.
-- @return [List<Entity> members]
function Combat:get_members()
  return self.members
end

--- Advances to the next member in the turn order, starting a new round after the last one.
-- @return [Entity member whose turn it is now]
function Combat:pop_member()
  local i = self.current_member

  i += 1

  if i > #self.members then
    i = 1

    self:round_end()
  end

  self.current_member = i

  return self.members[i]
end

--- Increments the round counter.
function Combat:round_end()
  self.round += 1
end

--- Adds a player or NPC to the combat, freezing them if the combat has already started.
-- @param entity [Entity player or NPC to add]
-- @param position=nil [Number position in the turn order, appended to the end by default]
function Combat:add_member(entity, position)
  if !IsValid(entity) or (!entity:IsNPC() and !entity:IsPlayer())
  or table.HasValue(self.members, entity) then return end

  entity:set_nv('combat_id', self.id)
  position = position or #self.members + 1

  table.insert(self.members, position, entity)

  if self.started then
    self:send_message('notification.combat.enter', { player = entity })
    entity:freeze()
  end
end

--- Removes a member from the combat, unfreezing them and ending their turn.
-- @param id [Entity member, or Number index of the member in the turn order]
-- @param all=nil [Boolean true to keep the member in the list, used when removing every member]
function Combat:remove_member(id, all)
  local entity

  if isentity(id) then
    entity = id
    id = table.KeyFromValue(self.members, entity)
  elseif isnumber(id) then
    entity = self.members[id]
  end

  if !id then return end

  if IsValid(entity) then
    entity:set_nv('combat_id', false)
    entity:unfreeze()

    if entity:IsPlayer() then
      timer_remove('combat_turn_'..entity:SteamID())

      cable_send(entity, 'fl_combat_end_turn')
    end
  end

  if !all then
    table.remove(self.members, id)

    if self.current_member >= id then
      self.current_member -= 1

      if self.current_member <= 0 then
        self.current_member = #self.members
      end
    end
  end
end

--- Releases every member and clears the member list.
function Combat:remove_members()
  for k, v in pairs(self:get_members()) do
    if IsValid(v) then
      self:remove_member(k, true)
    end
  end

  self.members = nil
end

--- Freezes every valid member of the combat.
function Combat:freeze_members()
  for _k, v in pairs(self:get_members()) do
    if IsValid(v) then
      v:freeze()
    end
  end
end

--- Finishes the combat if fewer than two members remain or no member is still hostile or willing to fight.
function Combat:check()
  if self.finished then return end

  if #self.members <= 1 then
    self:finish()

    return
  end

  for _k, v in pairs(self.members) do
    if IsValid(v) then
      if v:IsPlayer() and !v:leaving_combat() then
        return
      elseif v:IsNPC() then
        for _k1, v1 in pairs(self.members) do
          if IsValid(v1) and v != v1 and v:Disposition(v1) < D_LI then
            return
          end
        end
      end
    end
  end

  self:finish()
end

--- Starts an entity's turn. Players get 60 seconds and use up move turns as they walk, NPCs act for 4 seconds.
-- @param entity [Entity member whose turn it is]
-- @param first=nil [Boolean whether this is the first turn of the combat]
function Combat:turn(entity, first)
  if IsValid(entity) then
    local timer_name = 'combat_action_'..self.id
    entity:unfreeze()
    self:notify_turn()

    if entity:IsPlayer() then
      if entity:leaving_combat() then
        self:send_message('notification.combat.leave', { player = entity })
        self:remove_member(entity)
        entity.combat_leaving = false
        self:next_turn()
      else
        local last_pos = entity:GetPos()

        cable_send(entity, 'fl_combat_start_turn', last_pos)

        entity:restore_turns()
        timer_create('combat_turn_'..entity:SteamID(), 60, 1, function()
          if !self.finished and self:get_acting_member() == entity then
            self:next_turn()
          end
        end)

        timer_create(timer_name, 1, 0, function()
          if !IsValid(entity) or self.finished then
            timer_remove(timer_name)

            return
          end

          local pos = entity:GetPos()
          local max_step = entity:GetWalkSpeed() * 0.5

          if last_pos:DistToSqr(pos) > max_step * max_step then
            if entity:get_turns(TURN_MOVE) <= 1 then
              timer_remove(timer_name)
            end

            last_pos = pos
            entity:take_turn(TURN_MOVE)
            cable_send(entity, 'fl_combat_update_pos', last_pos)
          end
        end)
      end
    elseif entity:IsNPC() then
      if first or !IsValid(entity) then
        self:next_turn()
      else
        timer_create(timer_name, 4, 1, function()
          if !self.finished then
            self:next_turn()
          end
        end)
      end
    end
  end
end

--- Sends a combat chat message to every player in the combat.
-- @param text [String language phrase of the message]
-- @param arguments=nil [Table phrase arguments]
function Combat:send_message(text, arguments)
  cable_send(self:get_players(), 'fl_combat_message', text, arguments)
end

--- Notifies every player in the combat whose turn it is.
function Combat:notify_turn()
  cable_send(self:get_players(), 'fl_combat_notify_turn', self:get_acting_member())
end

--- Notifies every player in the combat that it has ended.
function Combat:notify_finish()
  cable_send(self:get_players(), 'fl_combat_notify_finish')
end

--- Ends the acting member's turn, gives the turn to the next member and checks whether the combat is over.
function Combat:next_turn()
  if self.finished then return end

  local member = self:get_acting_member()

  if IsValid(member) then
    member:freeze()

    if member:IsPlayer() then
      timer_remove('combat_turn_'..member:SteamID())

      cable_send(member, 'fl_combat_end_turn')
    end
  else
    self:remove_member(self.current_member)
  end

  member = self:pop_member()

  if IsValid(member) then
    self:turn(member)
  else
    self:remove_member(self.current_member)
  end

  self:check()
end
