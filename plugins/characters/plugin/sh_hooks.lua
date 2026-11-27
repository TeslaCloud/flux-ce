--- Shared hooks of the Characters plugin: the name a character is shown under, which is also
-- the public name commands accept a player by.

--- Shows a player under the display name of their character while it has one (see
-- `Characters.refresh_display_name`), which takes precedence over every other name.
-- @param target [Player]
-- @return [String the display name, nil when the character is shown under its real name]
function Characters:GetPlayerName(target)
  return target:get_display_name()
end

--- Makes the display name of the character of a player their public name, the name commands
-- accept them by besides the character name (see `Player:get_public_name`). It is networked
-- to everyone, so both realms give the same answer.
-- @param target [Player]
-- @return [String the display name, nil when the character is shown under its real name]
function Characters:GetPlayerPublicName(target)
  return target:get_display_name()
end
