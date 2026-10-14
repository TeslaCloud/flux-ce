--- Migration that adds the `level` and `experience` columns to the `characters` table.
-- `level` holds the level of a character, starting at 1, and `experience` the experience the
-- character has gathered toward its next level, starting at 0.

local AddLevelsToCharacters = ActiveRecord.Migration.new()

--- Adds the level and experience columns to characters.
function AddLevelsToCharacters:change()
  add_column('characters', 'level', 'integer', { default = 1 })
  add_column('characters', 'experience', 'integer', { default = 0 })
end

return AddLevelsToCharacters
