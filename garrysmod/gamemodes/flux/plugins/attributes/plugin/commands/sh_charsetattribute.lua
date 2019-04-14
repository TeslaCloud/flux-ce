local COMMAND = Command.new('charsetattribute')
COMMAND.name = 'CharSetAttribute'
COMMAND.description = 'char_set_attribute.description'
COMMAND.syntax = 'char_set_attribute.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 3
COMMAND.player_arg = 1
COMMAND.aliases = { 'setatt', 'setattribute', 'charsetatt' }

function COMMAND:get_description()
  return t(self.description, table.concat(Attributes.get_id_list(), ', '))
end

function COMMAND:on_run(player, targets, attr_id, value)
  local target = targets[1]
  local attribute = Attributes.find_by_id(attr_id)

  if attribute then
    Flux.Player:broadcast('char_set_attribute.message', { get_player_name(player), target:name(), attribute.name, value })

    target:set_attribute(attr_id:to_id(), tonumber(value))
  else
    player:notify('err.attribute_not_valid', attr_id)
  end
end

COMMAND:register()
