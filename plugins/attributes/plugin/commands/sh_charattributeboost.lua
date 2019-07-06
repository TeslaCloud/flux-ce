local COMMAND = Command.new('charattributeboost')
COMMAND.name = 'CharAttributeBoost'
COMMAND.description = 'command.charattributeboost.description'
COMMAND.syntax = 'command.charattributeboost.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 4
COMMAND.player_arg = 1
COMMAND.aliases = { 'attboost', 'attboost', 'attributeboost', 'attributeboost', 'charattboost' }

function COMMAND:get_description()
  return t(self.description, { attributes = table.concat(Attributes.get_id_list(), ', ') })
end

function COMMAND:on_run(player, targets, attr_id, value, duration)
  attr_id = attr_id:to_id()

  local attribute = Attributes.find_by_id(attr_id)
  duration = Bolt:interpret_ban_time(duration)

  if !isnumber(duration) then
    player:notify('error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  if !tonumber(value) then
    player:notify('error.invalid_value', { value = value })

    return
  else
    value = tonumber(value)
  end

  if attribute and attribute.boostable then
    for k, v in ipairs(targets) do
      v:notify('notification.attribute.boost', {
        attribute = attribute.name,
        value = value,
        time = Flux.Lang:nice_time(duration)
      })
      v:attribute_boost(attr_id, value, duration)
    end

    self:notify_staff('command.charattributeboost.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      attribute = attribute.name,
      value = value,
      time = Flux.Lang:nice_time(duration)
    })
  else
    player:notify('error.attribute_not_valid', attr_id)
  end
end

COMMAND:register()
