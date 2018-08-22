--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]concommand.Add("flThirdPerson", function(player)
  local oldValue = player:GetNetVar("flThirdPerson")

  if (oldValue == nil) then
    oldValue = false
  end

  player:SetNetVar("flThirdPerson", !oldValue)
end)
