local COMMAND = Command.new('textremove')
COMMAND.name = 'TextRemove'
COMMAND.description = 'Removes a 3D text.'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.level_design'

function COMMAND:on_run(player)
  SurfaceText:remove_text(player)
end

COMMAND:register()
