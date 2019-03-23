function Doors:ShowSpare1(player)
  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() and player:GetPos():Distance(entity:GetPos()) < 115 then
    local can_lock = hook.run('PlayerCanLockDoor', player, entity)

    Cable.send(player, 'fl_door_menu', entity, can_lock, entity.conditions)
  end
end

function Doors:PlayerUse(player, entity)
  local cur_time = CurTime()

  if (!entity.next_use or entity.next_use <= cur_time) and IsValid(entity) and entity:is_door() and
  player:GetPos():Distance(entity:GetPos()) < 115 and
  hook.run('PlayerCanLockDoor', player, entity) and player:IsSprinting() then
    local locked = entity:get_nv('fl_locked')

    self:lock_door(entity, !locked)
    entity:Fire(locked and 'Open' or 'Close')

    entity.next_use = cur_time + 2

    if !locked then
      return false
    end
  end
end

function Doors:PlayerCanLockDoor(player, entity)
  local conditions = entity.conditions

  if conditions and Conditions:check(player, conditions) then
    return true
  end
end
