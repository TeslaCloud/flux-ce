local COMMAND = Command.new('charsetattribute')
COMMAND.name = 'CharSetAttribute'
COMMAND.description = t'char_set_attribute.description'
COMMAND.syntax = t'char_set_attribute.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 3
COMMAND.player_arg = 1
COMMAND.aliases = { 'setatt', 'setattribute', 'charsetatt' }

function COMMAND:on_run(player, targets, attr_id, value)
  local target = targets[1]
  local attribute = attributes.find_by_id(attr_id)

  if attribute then
    Flux.Player:broadcast('char_set_attribute.message', { get_player_name(player), target:name(), attribute.name, value })

    target:set_attribute(attr_id:to_id(), tonumber(value))
  else
    player:notify('err.attribute_not_valid', attr_id)
  end
end

COMMAND:register()
