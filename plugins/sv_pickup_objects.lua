PLUGIN:set_name('Pickup Objects')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows players to pickup objects.')

local max_dist = Unit:meters(2) ^ 2

function PLUGIN:pickup_at_trace(player)
  if !IsValid(player) then return end

  if IsValid(player.holding_object) then
    if hook.run('PlayerDropObject', player, player.holding_object) != false then
      player:DropObject()
      player.holding_object = nil
    end

    return false
  end

  local ent = player:GetEyeTraceNoCursor().Entity

  if IsValid(ent) then
    if ent:IsPlayerHolding() then return false end
    if ent:GetPos():DistToSqr(player:GetPos()) > max_dist then return false end

    if !player.holding_object then
      if hook.run('PlayerPickupObject', player, ent) != false then
        player:PickupObject(ent)
        player.holding_object = ent

        local timer_name = 'check_ent_hold_'..player:SteamID()

        timer.Create(timer_name, 0.1, 0, function()
          if !IsValid(player) then
            if IsValid(ent) then
              hook.run('PlayerDropObject', player, ent)
            end

            timer.Remove(timer_name)
            return
          end

          if IsValid(ent) and !ent:IsPlayerHolding() then
            hook.run('PlayerDropObject', player, ent)
            player.holding_object = nil
            timer.Remove(timer_name)
          elseif !IsValid(ent) then
            player.holding_object = nil
            timer.Remove(timer_name)
          end
        end)

        return true
      end
    end
  end

  return false
end

function PLUGIN:KeyRelease(player, key)
  if key == IN_ATTACK2 then
    local wep = player:GetActiveWeapon()

    if IsValid(wep) and wep:GetClass():include('fists') then
      self:pickup_at_trace(player)
    end
  end

  if key == IN_RELOAD and IsValid(player.holding_object) then
    self:pickup_at_trace(player)
  end
end

function PLUGIN:PlayerPickupObject(player, ent)
  if player.next_pickup and player.next_pickup > CurTime() then return false end

  local phys_obj = ent:GetPhysicsObject()

  if phys_obj:GetMass() > 25 then
    return false
  else
    ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
  end

  if IsValid(player) then
    player.next_pickup = CurTime() + 1
  end
end

function PLUGIN:PlayerDropObject(player, ent)
  ent:SetCollisionGroup(COLLISION_GROUP_NONE)

  if IsValid(player) then
    player.next_pickup = CurTime() + 1
  end
end
