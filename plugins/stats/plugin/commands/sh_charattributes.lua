--- The CharAttributes command shows the caller the attributes and skills of the targeted
-- player's character: every attribute, hidden ones included, with its level and boosts, and
-- every skill, hidden ones included, with its rank. A player gets them in a window, the
-- server console as lines of text.
-- Allowed for assistants by default.

CMD.name = 'CharAttributes'
CMD.description = 'command.charattributes.description'
CMD.syntax = 'command.charattributes.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'charcheckatts', 'checkatts', 'checkattributes' }

--- Sends the attributes and skills of the target's character to the caller, or prints them
-- when the command is run from the server console.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> matched players; only the first one is used]
function CMD:on_run(actor, targets)
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

  Flux.Player:notify(actor, 'command.charattributes.header', { target = target_name })

  for k, v in SortedPairs(Attributes.get_stored()) do
    local level = target:get_attribute(k)
    local attribute_name = t(v.name)

    Flux.Player:notify(actor, 'command.charattributes.line', {
      attribute = attribute_name,
      id = k,
      level = tostring(level),
      boost = tostring(target:get_attribute_boost(k))
    })
  end

  Flux.Player:notify(actor, 'command.charattributes.skills_header', { target = target_name })

  for k, v in SortedPairs(Skills.get_stored()) do
    Flux.Player:notify(actor, 'command.charattributes.skill_line', {
      skill = t(v.name),
      id = k,
      rank = tostring(target:get_skill(k))
    })
  end
end
