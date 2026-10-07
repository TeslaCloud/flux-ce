CMD.name = 'CharAttributeMultiplier'
CMD.description = 'command.charattributemultiplier.description'
CMD.syntax = 'command.charattributemultiplier.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 4
CMD.player_arg = 1
CMD.aliases = { 'multiplierattribute', 'attmultiplier', 'attributemult', 'attributemultiplier', 'charattmult' }

--- Returns the translated command description with every registered attribute ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.get_keys(Attributes.get_stored()), ', ') })
end

--- Applies a timed value to a multipliable attribute of every target, then notifies the targets
-- and staff. The value is currently applied through Player#boost_attribute.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_id [String attribute to affect, normalized with to_id]
-- @param value [String multiplier value, parsed with tonumber]
-- @param duration [String effect length, e.g. '30' (minutes) or '2 hours']
function CMD:on_run(actor, targets, attribute_id, value, duration)
  attribute_id = attribute_id:to_id()

  local attribute = Attributes.find(attribute_id)
  duration = Bolt:interpret_ban_time(duration)
  value = tonumber(value)

  if !isnumber(duration) then
    actor:notify('error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  if !value then
    actor:notify('error.invalid_value')

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
      player = get_player_name(actor),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value,
      time = Flux.Lang:nice_time(duration)
    })
  else
    actor:notify('error.attribute_not_valid', { attribute = attribute_id })
  end
end
