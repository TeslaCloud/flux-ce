--- Migration that adds the `data`, `ammo`, `armor` and `banned` columns to the `characters`
-- table and drops the `ammunitions` table.
-- `data` holds the generic data of a character and `ammo` its reserve ammo, both as serialized
-- tables; `armor` is saved next to the existing `health`, and `banned` marks a character that
-- may not be loaded. The `ammunitions` table was never written to and is replaced by `ammo`.

local AddPersistenceToCharacters = ActiveRecord.Migration.new()

--- Adds the data, ammo, armor and banned columns to characters and drops the ammunitions
-- table.
function AddPersistenceToCharacters:change()
  add_column('characters', 'data', 'text', { null = true })
  add_column('characters', 'ammo', 'text', { null = true })
  add_column('characters', 'armor', 'integer', { null = true })
  add_column('characters', 'banned', 'boolean', { default = false })

  drop_table('ammunitions', { if_exists = true }, function(t)
    t:string 'type'
    t:integer 'amount'
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:timestamps()
  end)
end

return AddPersistenceToCharacters
