CMD.name = 'CharAttributeMultiplier'
CMD.description = 'command.charattributemultiplier.description'
CMD.syntax = 'command.charattributemultiplier.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 4
CMD.player_arg = 1
CMD.aliases = { 'multiplierattribute', 'attmultiplier', 'attributemult', 'attributemultiplier', 'charattmult' }

function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.get_keys(Attributes.get_stored()), ', ') })
end

function CMD:on_run(player, targets, attribute_id, value, duration)
  attribute_id = attribute_id:to_id()

  local attribute = Attributes.find(attribute_id)
  duration = Bolt:interpret_ban_time(duration)
  value = tonumber(value)

  if !isnumber(duration) then
    player:notify('error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  if !value then
    player:notify('error.invalid_value')

    return
  end

  if attribute and attribute.multipliable then
    for k, v in ipairs(targets) do
      v:notify('notification.attribute.multiplier', {
        attribute = attribute.name,
        value = value,
        time = Flux.Lang:nice_time(duration)
      })
      v:boost_attribute(attribute_id, value, duration)
    end

    self:notify_staff('command.charattributemultiplier.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value,
      time = Flux.Lang:nice_time(duration)
    })
  else
    player:notify('error.attribute_not_valid', { attribute = attribute_id })
  end
end
