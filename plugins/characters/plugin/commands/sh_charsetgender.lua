COMMAND.name = 'CharSetGender'
COMMAND.description = 'command.charsetgender.description'
COMMAND.syntax = 'command.charsetgender.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.alias = 'setgender'

function COMMAND:on_run(player, targets, new_gender)
  new_gender = new_gender:utf8lower()

  local valid_genders = {
    ['male'] = CHAR_GENDER_MALE,
    ['female'] = CHAR_GENDER_FEMALE,
    ['no_gender'] = CHAR_GENDER_NONE
  }

  if valid_genders[new_gender] then
    for k, v in ipairs(targets) do
      Characters.set_gender(v, valid_genders[new_gender])
      v:notify('notification.gender_changed', { gender = 'ui.gender.'..new_gender })
    end

    self:notify_staff('command.charsetgender.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      gender = 'ui.gender.'..new_gender
    })
  else
    player:notify('error.invalid_gender', { gender = 'ui.gender.'..new_gender })
  end
end
