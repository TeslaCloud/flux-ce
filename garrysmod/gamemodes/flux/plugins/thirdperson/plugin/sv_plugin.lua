concommand.Add("flThirdPerson", function(player)
  local oldValue = player:get_nv("flThirdPerson")

  if (oldValue == nil) then
    oldValue = false
  end

  player:set_nv("flThirdPerson", !oldValue)
end)
