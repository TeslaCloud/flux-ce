--- Migration that adds the `identifier` column to the `attribute_boosts` and
-- `attribute_multipliers` tables.
-- The column holds the name that the code which gave a boost or a multiplier can find it by
-- again, to replace or remove it; it is empty for the ones that were given without a name.

local AddIdentifierToAttributeBoosts = ActiveRecord.Migration.new()

--- Adds the identifier column to attribute_boosts and attribute_multipliers.
function AddIdentifierToAttributeBoosts:change()
  add_column('attribute_boosts', 'identifier', 'string', { null = true })
  add_column('attribute_multipliers', 'identifier', 'string', { null = true })
end

return AddIdentifierToAttributeBoosts
