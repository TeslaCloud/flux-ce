--- The CharSetSkill command sets the rank of a skill of the targeted players' characters:
-- `/charsetskill <player> <skill> <rank>`, with the skill typed as its ID.

CMD.name = 'CharSetSkill'
CMD.description = 'command.charsetskill.description'
CMD.syntax = 'command.charsetskill.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 3
CMD.arg_types = { 'player', 'skill', 'number' }
CMD.aliases = { 'setskill' }

--- Returns the translated command description with every registered skill ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { skills = table.concat(table.GetKeys(Skills.get_stored()), ', ') })
end

--- Sets the rank of a skill for every target, then notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param skill_id [String ID of the skill to set, in any case]
-- @param value [String new rank, parsed with tonumber]
function CMD:on_run(actor, targets, skill_id, value)
  skill_id = skill_id:to_id()

  local skill = Skills.find(skill_id)
  value = tonumber(value)

  if !value then
    actor:notify('error.invalid_value')

    return
  end

  if skill then
    for _, target in ipairs(targets) do
      target:notify('notification.skill.set', {
        skill = skill.name,
        value = value
      })
      target:set_skill(skill_id, value)
    end

    self:notify_staff('command.charsetskill.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(targets),
      skill = skill.name,
      value = value
    })
  else
    actor:notify('error.skill_not_valid', { skill = skill_id })
  end
end
