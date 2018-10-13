local COMMAND = Command.new('charattributeboost')
COMMAND.name = 'CharAttributeBoost'
COMMAND.description = t'char_attribute_boost.description'
COMMAND.syntax = t'char_attribute_boost.syntax'
COMMAND.category = 'character_management'
COMMAND.arguments = 4
COMMAND.player_arg = 1
COMMAND.aliases = { 'attboost', 'attboost', 'attributeboost', 'attributeboost', 'charattboost' }

function COMMAND:on_run(player, targets, attr_id, value, duration)
  local target = targets[1]
  local attribute = attributes.find_by_id(attr_id)

  if attribute and attribute.boostable then
    fl.player:broadcast('char_attribute_boost.message', { get_player_name(player), target:Name(), attribute.name, value, duration })

    target:attribute_boost(attr_id:to_id(), tonumber(value), tonumber(duration))
  else
    player:notify('err.attribute_not_valid', attr_id)
  end
end

COMMAND:register()
