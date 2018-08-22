concommand.Add("flThirdPerson", function(player)
  local oldValue = player:GetNetVar("flThirdPerson")

  if (oldValue == nil) then
    oldValue = false
  end

  player:SetNetVar("flThirdPerson", !oldValue)
end)
