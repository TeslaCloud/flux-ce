--- Migration that creates the `items` table, which holds every item instance, and the
-- `item_id_blocks` table, which the instance ids are reserved from.
-- A row of `items` names the item template of the instance, its serialized custom data
-- and overridden fields, and where the instance is: in an inventory of a character, inside
-- of a container item, in a container prop of a map or lying in the world of a map. Every
-- row of `item_id_blocks` stands for a block of 1000 instance ids. See the `sv_storage.lua`
-- file of the Items plugin.

local CreateItems = ActiveRecord.Migration.new()

--- Creates the items and item_id_blocks tables.
function CreateItems:change()
  create_table('items', function(t)
    t:string { 'template_id', null = false }
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:references('parent', { to_table = 'items', foreign_key = { on_delete = 'cascade' } })
    t:integer 'container_id'
    t:string  'map'
    t:string  'inventory_type'
    t:integer 'x'
    t:integer 'y'
    t:boolean { 'rotated', default = false }
    t:float   'pos_x'
    t:float   'pos_y'
    t:float   'pos_z'
    t:float   'pitch'
    t:float   'yaw'
    t:float   'roll'
    t:references('dropped_by_character', {
      to_table = 'characters',
      foreign_key = { on_delete = 'nullify' }
    })
    t:string  'dropped_by_steam_id'
    t:text    'data'
    t:text    'overrides'
    t:timestamps()
  end)

  add_index('items', 'map')

  create_table('item_id_blocks', function(t)
    t:timestamps()
  end)
end

return CreateItems
