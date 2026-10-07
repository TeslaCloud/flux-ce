CMD.name = 'CharAttributeBoost'
CMD.description = 'command.charattributeboost.description'
CMD.syntax = 'command.charattributeboost.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 4
CMD.player_arg = 1
CMD.aliases = { 'attboost', 'attboost', 'attributeboost', 'attributeboost', 'charattboost' }

--- Returns the translated command description with every registered attribute ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.get_keys(Attributes.get_stored()), ', ') })
end

--- Gives every target a temporary boost to an attribute, then notifies the targets and staff.
-- Rejects invalid values, durations and attributes that are not boostable.
-- @param player [Player the player who ran the command]
-- @param targets [Array<Player> players matched by the first command argument]
-- @param attribute_id [String attribute to boost, normalized with to_id]
-- @param value [String number of levels to add, parsed with tonumber]
-- @param duration [String boost length, e.g. '30' (minutes) or '2 hours']
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

  if attribute and attribute.boostable != false then
    for k, v in ipairs(targets) do
      v:notify('notification.attribute.boost', {
        attribute = attribute.name,
        value = value,
        time = Flux.Lang:nice_time(duration)
      })
      v:boost_attribute(attribute_id, value, duration)
    end

    self:notify_staff('command.charattributeboost.message', {
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
