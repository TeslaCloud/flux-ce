ITEM.print_name = 'item.key_molding_kit.print_name'
ITEM.description = 'item.key_molding_kit.description'
ITEM.category = 'item.category.keys'
ITEM.model = 'models/props_junk/cardboard_box004a.mdl'
ITEM.weight = 0.2

ITEM:add_button('create_key_copy', {
  name = 'item.option.create_key_copy',
  icon = 'icon16/key_add.png',
  callback = 'on_create_key_copy',
  on_show = function(item_table)
    if PLAYER:has_item('key_blank') then
      return true
    end
  end
})

--- Asks the player which of their keys to copy with this kit.
-- @param actor [Player player using the kit]
function ITEM:on_create_key_copy(actor)
  Cable.send(actor, 'fl_key_copy', self.instance_id)
end
