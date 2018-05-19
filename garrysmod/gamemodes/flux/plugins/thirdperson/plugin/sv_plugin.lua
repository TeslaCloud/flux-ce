--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

concommand.Add("flThirdPerson", function(player)
  local oldValue = player:GetNetVar("flThirdPerson")

  if (oldValue == nil) then
    oldValue = false
  end

  player:SetNetVar("flThirdPerson", !oldValue)
end)
