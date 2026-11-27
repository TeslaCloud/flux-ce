--- Migration that adds the `species` column to the `characters` table: the ID of the species
-- of a character, 'human' for the characters that exist already.

local AddSpeciesToCharacters = ActiveRecord.Migration.new()

--- Adds the species column to characters.
function AddSpeciesToCharacters:change()
  add_column('characters', 'species', 'string', { default = '\'human\'' })
end

return AddSpeciesToCharacters
