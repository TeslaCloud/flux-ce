--- The Inventories library is the registry of all inventories, `Inventories.all` and
-- `Inventories.find`, along with `Inventories.place_items`, which puts the items loaded
-- from the database into the inventories that hold them. Every `Inventory` registers
-- itself here under its id when it is created.
-- @module [Inventories]

mod 'Inventories'

local stored = Inventories.stored or {}
Inventories.stored = stored

--- Returns all the inventory classes currently loaded on the server.
-- @return [Map inventories]
function Inventories.all()
  return stored
end

--- Finds a specific inventory by its id.
-- @param id [Number]
-- @return [Inventory]
function Inventories.find(id)
  return stored[id]
end

if SERVER then
  --- Puts items that have been loaded from the database where they belong: items inside
  -- of a container item into the inventory of the container item, which is created if
  -- needed, and items of a character into the inventory of the player of the type they
  -- were saved in, or into the default inventory if the player has no such inventory.
  -- Items that already are in an inventory and items that belong elsewhere are skipped.
  -- Server-side only.
  -- @param items [List<Item>]
  -- @param owner=nil [Player the player whose character the items belong to]
  -- @return [List<Item> the items that did not fit anywhere]
  function Inventories.place_items(items, owner)
    local unplaced = {}

    for _, item_obj in ipairs(items) do
      if !item_obj.inventory_id then
        if item_obj.parent_id then
          local container = Item.find_instance_by_id(item_obj.parent_id)

          if container and container.create_inventory then
            if !container.inventory then
              container:create_inventory()
            end

            if !container.inventory:add_item(item_obj, item_obj.x, item_obj.y) then
              unplaced[#unplaced + 1] = item_obj
            end
          else
            unplaced[#unplaced + 1] = item_obj
          end
        elseif item_obj.character_id and IsValid(owner) then
          local x, y = item_obj.x, item_obj.y
          local inventory = owner:get_inventories()[item_obj.inventory_type]

          if inventory and x and y then
            if inventory:is_width_infinite() and x > inventory:get_width() then
              inventory:set_width(x + 1)
            end

            if inventory:is_height_infinite() and y > inventory:get_height() then
              inventory:set_height(y + 1)
            end
          else
            inventory = owner:get_inventories()[owner.default_inventory or 'main_inventory']
            x, y = nil, nil
          end

          if !inventory or !inventory:add_item(item_obj, x, y) then
            unplaced[#unplaced + 1] = item_obj
          end
        end
      end
    end

    return unplaced
  end
end
