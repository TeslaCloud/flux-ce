--- The CharSetSkill command sets the rank of a skill of the targeted players' characters.
-- Allowed for gamemasters by default.

CMD.name = 'CharSetSkill'
CMD.description = 'command.charsetskill.description'
CMD.syntax = 'command.charsetskill.syntax'
CMD.permission = 'gamemaster'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 3
CMD.player_arg = 1
CMD.aliases = { 'setskill', 'charsetskill' }

--- Returns the translated command description with every registered skill ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { skills = table.concat(table.GetKeys(Skills.get_stored()), ', ') })
end

--- Sets the rank of a skill for every target, then notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param skill_id [String skill to set, normalized with to_id]
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
    for k, v in ipairs(targets) do
      v:notify('notification.skill.set', {
        skill = skill.name,
        value = value
      })
      v:set_skill(skill_id, value)
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
