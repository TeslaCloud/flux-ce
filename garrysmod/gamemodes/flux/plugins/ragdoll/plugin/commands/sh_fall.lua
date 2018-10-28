local COMMAND = Command.new('fall')
COMMAND.name = 'Fall'
COMMAND.description = t'fall.description'
COMMAND.syntax = t'fall.syntax'
COMMAND.category = 'roleplay'
COMMAND.aliases = { 'fallover', 'charfallover' }
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  if isnumber(delay) and delay > 0 then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  if player:Alive() and !player:IsRagdolled() then
    player:SetRagdollState(RAGDOLL_FALLENOVER)

    if delay and delay > 0 then
      player:RunCommand('getup '..tostring(delay))
    end
  else
    player:notify(t'cant_now')
  end
end

COMMAND:register()
