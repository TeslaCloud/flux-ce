local COMMAND = Command.new('textremove')
COMMAND.name = 'TextRemove'
COMMAND.description = 'Removes a 3D text.'
COMMAND.syntax = '[none]'
COMMAND.category = 'misc'

function COMMAND:on_run(player)
  fl3DText:Remove(player)
end

COMMAND:register()
