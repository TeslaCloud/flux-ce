CMD.name = 'CharSetAttribute'
CMD.description = 'command.charsetattribute.description'
CMD.syntax = 'command.charsetattribute.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 3
CMD.player_arg = 1
CMD.aliases = { 'setatt', 'setattribute', 'charsetatt' }

function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.get_keys(Attributes.get_stored()), ', ') })
end

function CMD:on_run(player, targets, attribute_id, value)
  attribute_id = attribute_id:to_id()

  local attribute = Attributes.find(attribute_id)
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
      v:set_attribute(attribute_id, value)
    end

    self:notify_staff('command.charsetattribute.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value
    })
  else
    player:notify('error.attribute_not_valid', { attribute = attribute_id })
  end
end
