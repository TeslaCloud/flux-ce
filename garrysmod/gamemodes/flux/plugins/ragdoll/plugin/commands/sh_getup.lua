local COMMAND = Command.new("getup")
COMMAND.name = "GetUp"
COMMAND.description = "Get up if you are currently fallen."
COMMAND.syntax = "[number GetUpTime]"
COMMAND.category = "roleplay"
COMMAND.aliases = {"chargetup", "unfall", "unfallover"}
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  delay = math.Clamp(tonumber(delay) or 4, 2, 60)

  if (player:Alive() and player:IsRagdolled()) then
    player:set_nv("GetupEnd", CurTime() + delay)
    player:set_nv("GetupTime", delay)
    player:SetAction("getup", true)

    timer.Simple(delay, function()
      player:SetRagdollState(RAGDOLL_NONE)

      player:ResetAction()
    end)
  else
    player:notify("You cannot do this right now!")
  end
end

COMMAND:register()
