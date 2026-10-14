--- Migration that drops the `attribute_multipliers` table.
-- The level of an attribute changes only when it is set, so there is no progress for a
-- multiplier to scale. The `progress` column of the `attributes` table is left in place,
-- because the SQLite of Garry's Mod cannot drop a column; nothing reads or writes it.

local DropAttributeMultipliers = ActiveRecord.Migration.new()

--- Drops the attribute_multipliers table.
function DropAttributeMultipliers:change()
  drop_table('attribute_multipliers', { if_exists = true }, function(t)
    t:references('attribute', { foreign_key = { on_delete = 'cascade' } })
    t:integer   'value'
    t:datetime  'expires_at'
    t:timestamps()
    t:string { 'identifier', null = true }
  end)
end

return DropAttributeMultipliers
