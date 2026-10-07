CMD.name = 'CharSetAttribute'
CMD.description = 'command.charsetattribute.description'
CMD.syntax = 'command.charsetattribute.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 3
CMD.player_arg = 1
CMD.aliases = { 'setatt', 'setattribute', 'charsetatt' }

--- Returns the translated command description with every registered attribute ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.GetKeys(Attributes.get_stored()), ', ') })
end

--- Sets the level of an attribute for every target, then notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_id [String attribute to set, normalized with to_id]
-- @param value [String new level, parsed with tonumber]
function CMD:on_run(actor, targets, attribute_id, value)
  attribute_id = attribute_id:to_id()

  local attribute = Attributes.find(attribute_id)
  value = tonumber(value)

  if !value then
    actor:notify('error.invalid_value')

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
      player = get_player_name(actor),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value
    })
  else
    actor:notify('error.attribute_not_valid', { attribute = attribute_id })
  end
end
