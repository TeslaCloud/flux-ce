--- Server side of the Attributes plugin: gives new characters their attribute records,
-- networks a character's attributes when it becomes active, and starts and removes the
-- expiry timers of its boosts and multipliers as characters are loaded and unloaded.

--- Adds an Attribute record for every registered attribute to a new character, using the
-- level chosen during creation or the attribute's minimum. A chosen level is rounded down
-- and kept between the attribute's min and max, as the creation data comes from the client.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data; levels are read from its attributes field]
function AttributesPlugin:PostCreateCharacter(owner, char, char_data)
  if char.attributes then
    local levels = istable(char_data.attributes) and char_data.attributes or {}

    for k, v in pairs(Attributes.get_stored()) do
      local level = tonumber(levels[k])

      if !level or level != level then
        level = v.min
      end

      local attribute = Attribute.new()
        attribute.attribute_id = k
        attribute.level = math.clamp(math.floor(level), v.min, v.max)
        attribute.progress = 0
      table.insert(char.attributes, attribute)
    end
  end
end

--- Restarts the expiry timers of the character's boosts and multipliers, destroys the ones
-- that have already expired and networks the attributes to the player.
-- @param owner [Player]
-- @param char [Character]
function AttributesPlugin:OnActiveCharacterSet(owner, char)
  local cur_time = os.time()

  if char.attributes then
    for k, v in pairs(char.attributes) do
      for k1, v1 in pairs(v.attribute_boosts) do
        local expires_at = time_from_timestamp(v1.expires_at)

        if expires_at > cur_time then
          local timer_id = 'fl_boost_'..v.id..'_'..v1.expires_at

          timer.Create(timer_id, expires_at - cur_time, 1, function()
            v1:destroy()
            table.remove(v.attribute_boosts, k1)

            timer.Destroy(timer_id)
          end)
        else
          v1:destroy()
          table.remove(v.attribute_boosts, k1)
        end
      end

      for k1, v1 in pairs(v.attribute_multipliers) do
        local expires_at = time_from_timestamp(v1.expires_at)

        if expires_at > cur_time then
          local timer_id = 'fl_multiplier_'..v.id..'_'..v1.expires_at

          timer.Create(timer_id, expires_at - cur_time, 1, function()
            v1:destroy()
            table.remove(v.attribute_multipliers, k1)

            timer.Destroy(timer_id)
          end)
        else
          v1:destroy()
          table.remove(v.attribute_multipliers, k1)
        end
      end
    end

    owner:set_nv('attributes', owner:get_attributes())
  end
end

--- Removes the attribute timers of the character the player is switching away from.
-- @param owner [Player]
-- @param new_char [Character]
-- @param old_char [Character]
function AttributesPlugin:OnCharacterChange(owner, new_char, old_char)
  Attributes.destroy_timers(old_char)
end

--- Removes the attribute timers of the disconnecting player's character.
-- @param actor [Player]
function AttributesPlugin:PlayerDisconnected(actor)
  if actor:is_character_loaded() then
    Attributes.destroy_timers(actor:get_character())
  end
end
