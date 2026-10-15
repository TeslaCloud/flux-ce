--- Staff command that sets the gender of the characters of one or more players to male,
-- female or no_gender.

CMD.name = 'CharSetGender'
CMD.description = 'command.charsetgender.description'
CMD.syntax = 'command.charsetgender.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.arg_types = { 'player', { 'male', 'female', 'no_gender' } }
CMD.alias = 'setgender'

--- The gender values of the words the second argument can be.
local genders = {
  male = CHAR_GENDER_MALE,
  female = CHAR_GENDER_FEMALE,
  no_gender = CHAR_GENDER_NONE
}

--- Sets the gender of every target's character and notifies the targets and staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param new_gender [String 'male', 'female' or 'no_gender']
function CMD:on_run(actor, targets, new_gender)
  for _, client in ipairs(targets) do
    Characters.set_gender(client, genders[new_gender])
    client:notify('notification.gender_changed', { gender = 'ui.gender.'..new_gender })
  end

  self:notify_staff('command.charsetgender.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    gender = 'ui.gender.'..new_gender
  })
end
