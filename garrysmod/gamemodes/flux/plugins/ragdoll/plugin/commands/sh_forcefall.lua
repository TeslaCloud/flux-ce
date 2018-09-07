local COMMAND = Command.new("forcefall")
COMMAND.name = "ForceFall"
COMMAND.description = "Forces a player to fall down on the ground."
COMMAND.syntax = "<target> [number GetUpTime]"
COMMAND.category = "roleplay"
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = {"forcefallover", "plyfall"}

function COMMAND:on_run(player, target, delay)
  if isnumber(delay) and delay > 0 then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  target = target[1]

  if IsValid(target) and target:Alive() and !target:IsRagdolled() then
    target:SetRagdollState(RAGDOLL_FALLENOVER)

    player:notify(target:Name().." has been ragdolled!")

    if delay and delay > 0 then
      target:Notify("Getting up...")

      timer.Simple(delay, function()
        target:SetRagdollState(RAGDOLL_NONE)
      end)
    end
  else
    player:notify("This player cannot be ragdolled right now!")
  end
end

COMMAND:register()
