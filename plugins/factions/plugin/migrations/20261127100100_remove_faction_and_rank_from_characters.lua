--- Migration that removes the `faction` and `rank` columns from the `characters` table: the
-- faction of a character is worked out from its items and its species, and its rank is kept
-- in the data of the item that grants the faction or in the record of the character.

local RemoveFactionAndRankFromCharacters = ActiveRecord.Migration.new()

--- Removes the faction and rank columns from characters.
function RemoveFactionAndRankFromCharacters:change()
  remove_column('characters', 'faction', 'string', { default = '\'player\'' })
  remove_column('characters', 'rank', 'integer', { null = true })
end

return RemoveFactionAndRankFromCharacters
