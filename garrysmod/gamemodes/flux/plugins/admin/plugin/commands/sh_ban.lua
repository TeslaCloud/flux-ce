local COMMAND = Command.new("ban")
COMMAND.name = "Ban"
COMMAND.description = t"bancmd.description"
COMMAND.syntax = t"bancmd.syntax"
COMMAND.category = "administration"
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = {"plyban"}

function COMMAND:on_run(player, targets, duration, ...)
  local pieces = {...}
  local reason = "You have been banned."

  duration = fl.admin:InterpretBanTime(duration)

  if (!isnumber(duration)) then
    fl.player:Notify(player, "'"..tostring(duration).."' could not be interpreted as duration!")

    return
  end

  if (#pieces > 0) then
    reason = string.Implode(" ", pieces)
  end

  for k, v in ipairs(targets) do
    fl.admin:Ban(v, duration, reason)
  end

  for k, v in ipairs(_player.GetAll()) do
    local time = t("time.for", fl.lang:nice_time_full(v:get_nv("language"), duration))

    if (duration <= 0) then time = t"time.permanently" end

    v:Notify('ban_message', {
      admin = (IsValid(player) and player:Name()) or "Console",
      target = util.PlayerListToString(targets),
      time = time,
      reason = reason
    })
  end
end

COMMAND:register()
