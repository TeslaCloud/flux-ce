CMD.name = 'CharSetGender'
CMD.description = 'command.charsetgender.description'
CMD.syntax = 'command.charsetgender.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.alias = 'setgender'

function CMD:on_run(player, targets, new_gender)
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
