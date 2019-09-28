function AttributesPlugin:PostCreateCharacter(player, char, char_data)
  if char.attributes then
    for k, v in pairs(Attributes.get_stored()) do
      local attribute = Attribute.new()
        attribute.attribute_id = k
        attribute.level = char_data.attributes[k] or v.min
        attribute.progress = 0
      table.insert(char.attributes, attribute)
    end
  end
end

function AttributesPlugin:OnActiveCharacterSet(player, char)
  local cur_time = os.time()

  if char.attributes then
    for k, v in pairs(char.attributes) do
      for k1, v1 in pairs(v.attribute_boosts) do
        local expires_at = time_from_timestamp(v1.expires_at)

        if expires_at > cur_time then
          local timer_id = 'fl_boost_'..v.id..'_'..v1.expires_at

          timer.create(timer_id, expires_at - cur_time, 1, function()
            v1:destroy()
            table.remove(v.attribute_boosts, k1)

            timer.destroy(timer_id)
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

          timer.create(timer_id, expires_at - cur_time, 1, function()
            v1:destroy()
            table.remove(v.attribute_multipliers, k1)

            timer.destroy(timer_id)
          end)
        else
          v1:destroy()
          table.remove(v.attribute_multipliers, k1)
        end
      end
    end

    player:set_nv('attributes', player:get_attributes())
  end
end

function AttributesPlugin:OnCharacterChange(player, new_char, old_char)
  Attributes.destroy_timers(old_char)
end

function AttributesPlugin:PlayerDisconnected(player)
  if player:is_character_loaded() then
    Attributes.destroy_timers(player:get_character())
  end
end
