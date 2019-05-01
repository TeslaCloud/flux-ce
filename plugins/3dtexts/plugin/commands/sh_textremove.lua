local COMMAND = Command.new('textremove')
COMMAND.name = 'TextRemove'
COMMAND.description = '3d_text.text_remove_desc'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.level_design'

function COMMAND:on_run(player)
  SurfaceText:remove_text(player)
end

COMMAND:register()
