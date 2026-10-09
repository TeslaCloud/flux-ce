--- Migration that adds the `char_class` column to the `characters` table.
-- The column holds the ID of the class that the character holds within its faction.

local AddCharClassToCharacters = ActiveRecord.Migration.new()

--- Adds the char_class column to characters.
function AddCharClassToCharacters:change()
  add_column('characters', 'char_class', 'string', { null = true })
end

return AddCharClassToCharacters
