--- Player methods of the Recognize plugin: checking who a player recognizes and under
-- which name, and, on the server, making their character remember and forget others.
-- What the active character of a player has stored is networked as the 'fl_recognizes'
-- variable of the player, a Map of character IDs to the names they are known by.

do
  local player_meta = FindMetaTable('Player')

  --- Checks whether the player recognizes a target. Players always recognize themselves,
  -- bots and others while noclipping, everyone is recognized while the recognition system
  -- is off, and the PlayerRecognizeTarget hook can override the result.
  -- @param target [Player player to check]
  -- @return [Boolean whether the target is recognized, String name they are known by]
  function player_meta:recognizes(target)
    if !IsValid(target) then
      return true
    end

    if self == target or !Recognizes:is_enabled() or !self:get_character() or target:IsBot() or
    self:GetMoveType() == MOVETYPE_NOCLIP then
      return true, target:name(true)
    end

    --- Lets plugins make a player recognize another one regardless of what the character
    -- of the player has stored, for example because both belong to the same organization.
    -- Called on both realms whenever `Player:recognizes` is asked about two different
    -- players, unless the recognition system is off.
    -- @param viewer [Player the player who may recognize the target]
    -- @param target [Player the player who may be recognized]
    -- @return [Boolean return true to make the viewer recognize the target, String the
    --   name the viewer knows the target by; their real name when it is left out]
    local recognizes_override, name_override = hook.Run('PlayerRecognizeTarget', self, target)

    if recognizes_override then
      return true, name_override or target:name(true)
    end

    local known_name = self:get_recognize(target)

    if known_name then
      return true, known_name
    end

    return false
  end

  --- Checks whether the player knows a target by their real name.
  -- @param target [Player player to check]
  -- @return [Boolean whether the target is known by their real name]
  function player_meta:knows_real_name(target)
    local is_known, known_name = self:recognizes(target)

    return (is_known and known_name == target:name(true))
  end

  --- Returns the name the active character of the player has stored for the character of
  -- a target. Unlike `Player:recognizes` this only looks at what the character remembers,
  -- which is what `Player:remove_recognize` makes it forget.
  -- @param target [Player player to check]
  -- @return [String the stored name, nil if the character has not stored the target]
  function player_meta:get_recognize(target)
    if !IsValid(target) then return end

    local char_id = target:get_character_id()

    if !char_id then return end

    return self:get_nv('fl_recognizes', {})[char_id]
  end

  if SERVER then
    --- Makes the player recognize a target by a name, updating the stored and networked recognizes.
    -- @param target [Player player to recognize]
    -- @param name=nil [String name to know them by, the target's real name by default]
    function player_meta:add_recognize(target, name)
      if !IsValid(target) or self:IsBot() then return end

      local char_id = target:get_character_id()

      if !char_id or self == target then return end

      local is_known, known_name = self:recognizes(target)
      local real_name = target:name(true)

      if is_known and known_name == real_name then return end

      name = name or real_name

      local character = self:get_character()
      local record

      character.recognizes = character.recognizes or {}

      for k, v in ipairs(character.recognizes) do
        if v.target_id == char_id then
          record = v

          break
        end
      end

      if record then
        record.name = name
      else
        record = Recognize.new()
          record.target_id = char_id
          record.name = name
        table.insert(character.recognizes, record)
      end

      Recognizes:sync(self)
    end

    --- Makes the player forget a target, deleting the stored recognize.
    -- @param target [Player player to forget]
    -- @return [Boolean whether the character of the player had the target stored]
    function player_meta:remove_recognize(target)
      if !IsValid(target) or self == target or self:IsBot() or !self:is_character_loaded() then return false end

      local char_id = target:get_character_id()

      if !char_id then return false end

      if Recognizes:remove_records(self:get_character(), char_id) == 0 then return false end

      Recognizes:sync(self)

      return true
    end

    --- Makes the player forget everyone their active character has stored.
    -- @return [Number how many characters were forgotten]
    function player_meta:clear_recognizes()
      if self:IsBot() or !self:is_character_loaded() then return 0 end

      local count = Recognizes:clear_records(self:get_character())

      Recognizes:sync(self)

      return count
    end
  end
end
