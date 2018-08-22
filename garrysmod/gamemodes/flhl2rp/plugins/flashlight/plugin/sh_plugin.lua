--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]if (SERVER) then
  function PLUGIN:PlayerSwitchFlashlight(player, bIsOn)
    if (bIsOn and !player:HasItemEquipped("flashlight")) then
      return false
    end

    return true
  end

  function PLUGIN:OnItemTaken(player, instanceID, slotID)
    if (player:FlashlightIsOn() and !player:HasItemEquipped("flashlight")) then
      player:Flashlight(false)
    end
  end
end
