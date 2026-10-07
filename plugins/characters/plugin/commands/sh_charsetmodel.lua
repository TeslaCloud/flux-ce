CMD.name = 'CharSetModel'
CMD.description = 'command.charsetmodel.description'
CMD.syntax = 'command.charsetmodel.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.alias = 'setmodel'

--- Sets the model of every target's character and notifies staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param model [String model path]
function CMD:on_run(actor, targets, model)
  for k, v in ipairs(targets) do
    v:notify('notification.model_changed', { model = model })
    Characters.set_model(v, model)
  end

  self:notify_staff('command.charsetmodel.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    model = model
  })
end
