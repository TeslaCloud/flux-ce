--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local COMMAND = Command("forcefall")
COMMAND.Name = "ForceFall"
COMMAND.Description = "Forces a player to fall down on the ground."
COMMAND.Syntax = "<target> [number GetUpTime]"
COMMAND.Category = "roleplay"
COMMAND.Arguments = 1
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"forcefallover", "plyfall"}

function COMMAND:OnRun(player, target, delay)
  if (isnumber(delay) and delay > 0) then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  target = target[1]

  if (IsValid(target) and target:Alive() and !target:IsRagdolled()) then
    target:SetRagdollState(RAGDOLL_FALLENOVER)

    player:Notify(target:Name().." has been ragdolled!")

    if (delay and delay > 0) then
      target:Notify("Getting up...")

      timer.Simple(delay, function()
        target:SetRagdollState(RAGDOLL_NONE)
      end)
    end
  else
    player:Notify("This player cannot be ragdolled right now!")
  end
end

COMMAND:Register()
