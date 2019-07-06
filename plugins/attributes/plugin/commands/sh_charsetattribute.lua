COMMAND.name = 'CharSetAttribute'
COMMAND.description = 'command.charsetattribute.description'
COMMAND.syntax = 'command.charsetattribute.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 3
COMMAND.player_arg = 1
COMMAND.aliases = { 'setatt', 'setattribute', 'charsetatt' }

function COMMAND:get_description()
  return t(self.description, { attributes = table.concat(Attributes.get_id_list(), ', ') })
end

function COMMAND:on_run(player, targets, attr_id, value)
  attr_id = attr_id:to_id()

  local attribute = Attributes.find_by_id(attr_id)
  value = tonumber(value)

  if !value then
    player:notify('error.invalid_value')

    return
  end

  if attribute then
    for k, v in ipairs(targets) do
      v:notify('notification.attribute.set', {
        attribute = attribute.name,
        value = value
      })
      v:set_attribute(attr_id, value)
    end

    self:notify_staff('command.charsetattribute.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value
    })
  else
    player:notify('error.attribute_not_valid', attr_id)
  end
end
