local COMMAND = Command("getup")
COMMAND.Name = "GetUp"
COMMAND.Description = "Get up if you are currently fallen."
COMMAND.Syntax = "[number GetUpTime]"
COMMAND.Category = "roleplay"
COMMAND.Aliases = {"chargetup", "unfall", "unfallover"}
COMMAND.noConsole = true

function COMMAND:OnRun(player, delay)
  delay = math.Clamp(tonumber(delay) or 4, 2, 60)

  if (player:Alive() and player:IsRagdolled()) then
    player:SetNetVar("GetupEnd", CurTime() + delay)
    player:SetNetVar("GetupTime", delay)
    player:SetAction("getup", true)

    timer.Simple(delay, function()
      player:SetRagdollState(RAGDOLL_NONE)

      player:ResetAction()
    end)
  else
    player:Notify("You cannot do this right now!")
  end
end

COMMAND:Register()
