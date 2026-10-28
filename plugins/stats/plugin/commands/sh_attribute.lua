--- The `attribute` staff command works with the attributes of the targeted players'
-- characters: `/attribute set <player> <attribute> <value>` sets the level of an attribute,
-- `/attribute boost <player> <attribute> <value> <duration>` gives a boost of that many levels
-- for a duration such as `30` (minutes) or `2 hours`, or until it is removed with a duration
-- such as `perma`, `/attribute clearboosts <player> [attribute]` removes the boosts of one
-- attribute or of all of them, and `/attribute list <player>` shows the caller every
-- attribute, with its level and boosts, and every skill, with its rank, hidden ones included:
-- a player gets them in a window, the server console as lines of text. The attribute is typed
-- as its ID. Listing needs the 'attribute_list' permission, the other subcommands the
-- 'attribute' one.

CMD.name = 'Attribute'
CMD.description = 'command.attribute.description'
CMD.category = 'permission.categories.character_management'
CMD.aliases = { 'attributes', 'att' }

local function describe_with_attributes(phrase)
  return t(phrase, { attributes = table.concat(table.GetKeys(Attributes.get_stored()), ', ') })
end

--- Finds the attribute an argument names by its ID, ignoring the case.
-- @param text [String the argument]
-- @return [String the attribute ID as typed, normalized with to_id; AttributeBase the attribute,
--   or nil if there is none with this ID]
local function find_attribute(text)
  local attribute_id = text:to_id()

  return attribute_id, Attributes.find(attribute_id)
end

local set = CMD:subcommand('set')
set.description = 'command.attribute.set.description'
set.syntax = 'command.attribute.set.syntax'
set.arguments = 3
set.arg_types = { 'player', 'attribute', 'number' }

--- Returns the translated description with every registered attribute ID listed.
-- @return [String]
function set:get_description()
  return describe_with_attributes(self.description)
end

--- Sets the level of an attribute for every target, then notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_text [String ID of the attribute to set]
-- @param value [String new level, parsed with tonumber]
function set:on_run(actor, targets, attribute_text, value)
  local attribute_id, attribute = find_attribute(attribute_text)
  value = tonumber(value)

  if !value then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  if !attribute then
    Flux.Player:notify(actor, 'error.attribute_not_valid', { attribute = attribute_id })

    return
  end

  for _, target in ipairs(targets) do
    target:notify('notification.attribute.set', {
      attribute = attribute.name,
      value = value
    })
    target:set_attribute(attribute_id, value)
  end

  self:notify_staff('command.attribute.set.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    attribute = attribute.name,
    value = value
  })
end

local boost = CMD:subcommand('boost')
boost.description = 'command.attribute.boost.description'
boost.syntax = 'command.attribute.boost.syntax'
boost.arguments = 4
boost.arg_types = { 'player', 'attribute', 'number', 'duration' }

--- Returns the translated description with every registered attribute ID listed.
-- @return [String]
function boost:get_description()
  return describe_with_attributes(self.description)
end

--- Gives every target a boost to an attribute, then notifies the targets and staff. A
-- duration of 0 gives a boost that does not expire. Rejects invalid values, durations and
-- attributes that are not boostable.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_text [String ID of the attribute to boost]
-- @param value [String number of levels to add, parsed with tonumber]
-- @param duration [String boost length as read by Bolt:interpret_ban_time, e.g. '30'
--   (minutes), '2 hours' or 'perma']
function boost:on_run(actor, targets, attribute_text, value, duration)
  local attribute_id, attribute = find_attribute(attribute_text)
  duration = Bolt:interpret_ban_time(duration)
  value = tonumber(value)

  if !isnumber(duration) then
    Flux.Player:notify(actor, 'error.invalid_time', {
      time = tostring(duration)
    })

    return
  end

  if !value then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  if !attribute or attribute.boostable == false then
    Flux.Player:notify(actor, 'error.attribute_not_valid', { attribute = attribute_id })

    return
  end

  local permanent = duration <= 0

  for _, target in ipairs(targets) do
    target:notify(permanent and 'notification.attribute.boost_permanent' or 'notification.attribute.boost', {
      attribute = attribute.name,
      value = value,
      time = Flux.Lang:duration(duration)
    })
    target:boost_attribute(attribute_id, value, duration)
  end

  self:notify_staff('command.attribute.boost.'..(permanent and 'message_permanent' or 'message'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    attribute = attribute.name,
    value = value,
    time = Flux.Lang:duration(duration)
  })
end

local clearboosts = CMD:subcommand('clearboosts')
clearboosts.description = 'command.attribute.clearboosts.description'
clearboosts.syntax = 'command.attribute.clearboosts.syntax'
clearboosts.arguments = 1
clearboosts.arg_types = { 'player', 'attribute' }

--- Returns the translated description with every registered attribute ID listed.
-- @return [String]
function clearboosts:get_description()
  return describe_with_attributes(self.description)
end

--- Removes the boosts of one attribute, or of every attribute, from every target, then
-- notifies staff and the targets that lost any.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_text=nil [String ID of the attribute to clear; every attribute if omitted]
function clearboosts:on_run(actor, targets, attribute_text)
  local attribute_id, attribute

  if attribute_text then
    attribute_id, attribute = find_attribute(attribute_text)

    if !attribute then
      Flux.Player:notify(actor, 'error.attribute_not_valid', { attribute = attribute_id })

      return
    end
  end

  for _, target in ipairs(targets) do
    local removed = target:remove_attribute_boosts(attribute_id)

    if removed > 0 then
      target:notify(attribute and 'notification.attribute.boosts_cleared'
        or 'notification.attribute.boosts_cleared_all', {
        attribute = attribute and attribute.name
      })
    end
  end

  self:notify_staff('command.attribute.clearboosts.'..(attribute and 'message' or 'message_all'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    attribute = attribute and attribute.name
  })
end

local list_cmd = CMD:subcommand('list')
list_cmd.description = 'command.attribute.list.description'
list_cmd.syntax = 'command.attribute.list.syntax'
list_cmd.permission_id = 'attribute_list'
list_cmd.arguments = 1
list_cmd.arg_types = { 'player' }

--- Sends the attributes and skills of the target's character to the caller, or prints them
-- when the command is run from the server console.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> matched players; only the first one is used]
function list_cmd:on_run(actor, targets)
  local target = targets[1]

  if !IsValid(target) then return end

  local target_name = target:name()

  if !target:is_character_loaded() then
    Flux.Player:notify(actor, 'error.attribute_no_character', { target = target_name })

    return
  end

  if IsValid(actor) then
    Cable.send(actor, 'fl_attributes_view', target, target:get_attributes(), target:get_skills())

    return
  end

  Flux.Player:notify(actor, 'command.attribute.list.header', { target = target_name })

  for attribute_id, attribute_table in SortedPairs(Attributes.get_stored()) do
    local level = target:get_attribute(attribute_id)
    local attribute_name = t(attribute_table.name)

    Flux.Player:notify(actor, 'command.attribute.list.line', {
      attribute = attribute_name,
      id = attribute_id,
      level = tostring(level),
      boost = tostring(target:get_attribute_boost(attribute_id))
    })
  end

  Flux.Player:notify(actor, 'command.attribute.list.skills_header', { target = target_name })

  for skill_id, skill_table in SortedPairs(Skills.get_stored()) do
    Flux.Player:notify(actor, 'command.attribute.list.skill_line', {
      skill = t(skill_table.name),
      id = skill_id,
      rank = tostring(target:get_skill(skill_id))
    })
  end
end
