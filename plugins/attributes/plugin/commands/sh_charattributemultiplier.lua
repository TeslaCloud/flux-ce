local COMMAND = Command.new('charattributemultiplier')
COMMAND.name = 'CharAttributeMultiplier'
COMMAND.description = 'command.char_attribute_multiplier.description'
COMMAND.syntax = 'command.char_attribute_multiplier.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'perm.categories.character_management'
COMMAND.arguments = 4
COMMAND.player_arg = 1
COMMAND.aliases = { 'attmult', 'attmultiplier', 'attributemult', 'attributemultiplier', 'charattmult' }

function COMMAND:get_description()
  return t(self.description, table.concat(Attributes.get_id_list(), ', '))
end

function COMMAND:on_run(player, targets, attr_id, value, duration)
  local target = targets[1]
  local attribute = Attributes.find_by_id(attr_id)

  if attribute and attribute.multipliable then
    Flux.Player:broadcast('char_attribute_multiplier.message', { get_player_name(player), target:name(), attribute.name, value, duration })

    target:attribute_multiplier(attr_id:to_id(), tonumber(value), tonumber(duration))
    target:increase_attribute(attr_id:to_id(), 1)
  else
    player:notify('error.attribute_not_valid', attr_id)
  end
end

COMMAND:register()
