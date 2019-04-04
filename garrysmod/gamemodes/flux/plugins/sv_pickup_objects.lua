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

        timer.Create('check_ent_hold_'..player:SteamID(), 0.1, 0, function()
          if IsValid(ent) and !ent:IsPlayerHolding() then
            hook.run('PlayerDropObject', player, ent)
            player.holding_object = nil
            timer.Remove('check_ent_hold_'..player:SteamID())
          elseif !IsValid(ent) then
            player.holding_object = nil
            timer.Remove('check_ent_hold_'..player:SteamID())
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
end

function PLUGIN:PlayerPickupObject(player, ent)
  if player.next_pickup and player.next_pickup > CurTime() then return false end

  local phys_obj = ent:GetPhysicsObject()

  if phys_obj:GetMass() > 25 then
    return false
  else
    ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
  end

  player.next_pickup = CurTime() + 1
end

function PLUGIN:PlayerDropObject(player, ent)
  ent:SetCollisionGroup(COLLISION_GROUP_NONE)

  player.next_pickup = CurTime() + 1
end
