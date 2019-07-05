local COMMAND = Command.new('tp')
COMMAND.name = 'Tp'
COMMAND.description = 'command.tp.description'
COMMAND.syntax = 'command.tp.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.administration'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'teleport', 'plytp', 'bring' }

function COMMAND:on_run(player, targets)
  local pos = player:GetEyeTraceNoCursor().HitPos

  for k, v in pairs(targets) do
    if IsValid(v) then
      v:teleport(pos)
      v:notify('notification.tp')
    end
  end

  self:notify_staff('command.tp.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end

COMMAND:register()
