CMD.name = 'CharSetModel'
CMD.description = 'command.charsetmodel.description'
CMD.syntax = 'command.charsetmodel.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.alias = 'setmodel'

function CMD:on_run(player, targets, model)
  for k, v in ipairs(targets) do
    v:notify('notification.model_changed', { model = model })
    Characters.set_model(v, model)
  end

  self:notify_staff('command.charsetmodel.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    model = model
  })
end
