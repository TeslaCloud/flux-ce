--- Server side of the Characters plugin: making a character the active character of a
-- player.

--- Makes a character the active character of a player. Runs PreSwitchCharacter if another
-- character was active, networks the basic character data and runs ActiveCharacterSet, then
-- PostSwitchCharacter if another character was active. The character does not have to
-- belong to the player: one of another user record is sent to the player on its own, so
-- that their client knows the character it is playing. Nothing is
-- checked here: the requests of players go through `Characters.can_use` first, which is what
-- keeps banned characters from being loaded.
-- @param target [Player]
-- @param character [Character any character record; nothing happens when it is not a table]
function Characters.activate(target, character)
  if !istable(character) then return end

  local old_id = target:get_character_id()
  local old_char = target:get_character()

  if old_id then
    --- Called on the server when a player who already has an active character selects a
    -- character, before the selected character becomes the active one. The return value is
    -- ignored: `PlayerCanSwitchCharacter` decides whether the switch may happen.
    -- @param owner [Player]
    -- @param new_char [Character the character that is about to become active]
    -- @param old_char [Character the character that is still active]
    hook.Run('PreSwitchCharacter', target, character, old_char)
  end

  if !target:IsBot() then
    local user = character.user
    local borrowed = istable(user) and user != target.record and Characters.to_networkable(target, character) or nil

    Cable.send(target, 'fl_character_borrowed', borrowed)
  end

  target.vitals_restored = false
  target:set_nv('active_character', tonumber(character.id))
  target.current_character = character

  target:set_nv('name', character.name or target:steam_name())
  target:set_nv('gender', character.gender or CHAR_GENDER_MALE)
  target:set_nv('phys_desc', character.phys_desc or '')
  target:set_nv('model', character.model or Characters.default_model)

  --- Called on the server when a character has become the active character of a player, after
  -- its ID, name, gender, description and model have been networked. The Characters plugin
  -- spawns the player from its own handler of this hook; other plugins use it to apply what
  -- they keep on the character.
  -- @param owner [Player]
  -- @param character [Character the character that is now active]
  hook.Run('ActiveCharacterSet', target, target:get_character())

  if old_id then
    --- Called on the server when a player who had an active character has switched to
    -- another one, after `ActiveCharacterSet` has run for the character they have switched to.
    -- @param owner [Player]
    -- @param new_char [Character the active character]
    -- @param old_char [Character the character that was active before]
    hook.Run('PostSwitchCharacter', target, character, old_char)
  end
end
