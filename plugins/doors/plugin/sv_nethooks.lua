--- Server-side network receivers of the Doors plugin: applies what the door menu and the
-- door management menu of a player send, once the request has been checked.

--- Checks a request that the door menu of a player has sent: the entity has to be a door
-- within `Doors.use_distance` of the living player, and a player may send a request only
-- every 0.3 seconds. The player is told what is wrong.
-- @param actor [Player]
-- @param entity [Any what the client sent as the door]
-- @return [Boolean whether the request may be handled]
local function accept_request(actor, entity)
  if !isentity(entity) or !IsValid(entity) or !entity:is_door() then return false end

  if !actor:Alive() then
    actor:notify('error.cant_now')

    return false
  end

  local cur_time = CurTime()

  if actor.next_door_request and actor.next_door_request > cur_time then
    actor:notify('error.wait')

    return false
  end

  if !Doors:is_in_reach(actor, entity) then
    actor:notify('error.door.too_far')

    return false
  end

  actor.next_door_request = cur_time + 0.3

  return true
end

Cable.receive('fl_send_door_data', function(actor, entity, id, data)
  if actor:can('manage_doors') and isentity(entity) and IsValid(entity) and entity:is_door()
  and Doors:is_in_reach(actor, entity) then
    local property = Doors.properties[id]

    if property and property.on_load then
      property.on_load(entity, data)
    end
  end
end)

Cable.receive('fl_lock_door', function(actor, entity, lock)
  if isentity(entity) and IsValid(entity) and entity:is_door() and Doors:is_in_reach(actor, entity)
  and hook.Run('PlayerCanLockDoor', actor, entity) then
    if !Doors:player_lock_door(actor, entity, tobool(lock)) then
      actor:notify('error.cant_now')
    end
  end
end)

Cable.receive('fl_send_door_conditions', function(actor, entity, conditions)
  if actor:can('manage_doors') and isentity(entity) and IsValid(entity) and entity:is_door()
  and istable(conditions) and Doors:is_in_reach(actor, entity) then
    entity.conditions = conditions
  end
end)

Cable.receive('fl_door_buy', function(actor, entity)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:buy(actor, entity)

  if !success then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_door_sell', function(actor, entity)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:sell(actor, entity)

  if !success then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_door_set_text', function(actor, entity, text)
  if !accept_request(actor, entity) then return end

  local success, reason = Doors:change_text(actor, entity, text)

  if success then
    actor:notify('notification.door.text_set')
  else
    actor:notify(reason)
  end

  Doors:send_info(actor, entity)
end)

Cable.receive('fl_door_set_access', function(actor, entity, character_id, level)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:change_access(actor, entity, character_id, level)

  if !success then
    actor:notify(reason, arguments)
  end

  Doors:send_info(actor, entity)
end)

Cable.receive('fl_door_evict', function(actor, entity)
  if !actor:can('manage_doors') or !accept_request(actor, entity) then return end

  if Doors:evict(entity) then
    actor:notify('notification.door.evict_done')

    Doors:save()
  else
    actor:notify('error.door.not_owned')
  end
end)
