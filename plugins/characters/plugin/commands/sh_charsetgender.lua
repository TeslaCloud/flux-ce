local COMMAND = Command.new('charsetgender')
COMMAND.name = 'CharSetGender'
COMMAND.description = 'char_set_gender.description'
COMMAND.syntax = 'char_set_gender.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'setgender' }

function COMMAND:on_run(player, targets, new_gender)
  new_gender = new_gender:utf8lower()

  local target = targets[1]
  local valid_genders = {
    ['male'] = CHAR_GENDER_MALE,
    ['female'] = CHAR_GENDER_FEMALE,
    ['no_gender'] = CHAR_GENDER_NONE
  }

  if valid_genders[new_gender] then
    Characters.set_gender(target, valid_genders[new_gender])
  end
end

COMMAND:register()
