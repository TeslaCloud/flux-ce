local COMMAND = Command.new('textremove')
COMMAND.name = 'TextRemove'
COMMAND.description = 'Removes a 3D text.'
COMMAND.category = 'misc'

function COMMAND:on_run(player)
  SurfaceText:Remove(player)
end

COMMAND:register()
