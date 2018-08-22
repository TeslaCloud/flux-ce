--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]PLUGIN:SetName("Auto Walk")
PLUGIN:SetAuthor("NightAngel")
PLUGIN:SetDescription("Allows users to press a button to automatically walk forward.")

if (SERVER) then
  local check = {
    [IN_FORWARD] = true,
    [IN_BACK] = true,
    [IN_MOVELEFT] = true,
    [IN_MOVERIGHT] = true
  }

  function PLUGIN:SetupMove(player, moveData, cmdData)
    if (!player:GetNetVar("flAutoWalk")) then return end

    moveData:SetForwardSpeed(moveData:GetMaxSpeed())

    -- If they try to move, break the autowalk.
    for k, v in pairs(check) do
      if (cmdData:KeyDown(k)) then
        player:SetNetVar("flAutoWalk", false)

        break
      end
    end
  end

  -- So clients can bind this as they want.
  concommand.Add("toggleautowalk", function(player)
    local oldValue = player:GetNetVar("flAutoWalk")

    if (!oldValue) then
      oldValue = false
    end

    player:SetNetVar("flAutoWalk", !oldValue)
  end)
else
--  fl.hint:Add("Autowalk", "Press 'B' to toggle auto walking.")

  -- We do this so there's no need to do an unnecessary check for if client or server in the hook itself.
  function PLUGIN:SetupMove(player, moveData, cmdData)
    if (!player:GetNetVar("flAutoWalk")) then return end

    moveData:SetForwardSpeed(moveData:GetMaxSpeed())
  end

  fl.binds:AddBind("ToggleAutoWalk", "toggleautowalk", KEY_B)
end
