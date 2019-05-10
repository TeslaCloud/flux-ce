local COMMAND = Command.new('tp')
COMMAND.name = 'Tp'
COMMAND.description = 'tpcmd.description'
COMMAND.syntax = 'tpcmd.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.administration'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'teleport', 'plytp', 'bring' }

function COMMAND:on_run(player, targets)
  local pos = player:GetEyeTraceNoCursor().HitPos

  for k, v in pairs(targets) do
    if IsValid(v) then
      v:teleport(pos)
    end
  end

  player:notify('tpcmd.notify', util.player_list_to_string(targets))
end

COMMAND:register()
