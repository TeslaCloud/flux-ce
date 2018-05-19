--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

library.New("player", fl)

function fl.player:Notify(player, message)
  if (!IsValid(player)) then
    ServerLog(message)

    return
  end

  netstream.Start(player, "flNotification", message)
end

function fl.player:NotifyAll(message)
  ServerLog("[Notification] "..message)

  netstream.Start(nil, "flNotification", message)
end
