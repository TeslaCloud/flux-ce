--- Keys and drops of the hotbar in the interfaces that show the items of the local player: the
-- inventory tab of the tab menu, the bar of the context menu and the container view.
--
-- While the cursor is over an item of the storage of the local player or over an entry of the
-- bar, the number keys and the drop key (`Hotbar.drop_key`) act on it. A number key puts the
-- item on the slot of that number, the same request as dragging it there (`fl_hotbar_place`),
-- or moves the entry there (`fl_hotbar_move`); the key of the slot of the hovered entry, keys
-- 8, 9 and 0 and those of slots past the item slots of the player do nothing. The drop key
-- drops one instance of the item into the world with the drop request of the inventory panels
-- (`fl_item_drop`): the hovered instance of a stack, the item of an equipped entry, or one
-- instance of a pinned item that the player carries, which leaves the pin on the bar.
--
-- The item slots note the cursor entering and leaving them (`Hotbar.hover`), and the keys are
-- read once a frame while one of them is hovered (`Hotbar.poll_hover_keys`): a panel that has
-- the keyboard gets the keys in place of the binds, and none may have it, as in the context
-- menu or after the menu of an item has been opened. Meanwhile the presses of the binds of
-- those keys, and the releases of the binds whose presses have been taken, do not reach the
-- hotbar, the weapon selector or the game (`Hotbar.take_hover_bind`). Nothing is read while
-- the cursor is over no item, while something is dragged, while a text field has the keyboard
-- or while the game menu or the console is open.
--
-- An entry dragged off the bar is taken off the hotbar when it is dropped onto an inventory
-- panel of the storage of the local player, and stays when it is dropped onto another one
-- (`Hotbar.receive_entry_on_inventory`). Dropped onto the world outside the card of its bar,
-- or onto the bare background of the inventory tab, its item is dropped as the drop key drops
-- it (`Hotbar.receive_entry_in_world`, `Hotbar.is_world_panel`, `Hotbar.is_cursor_on_card`).
-- Any other panel keeps the entry.
-- @module [Hotbar]

const IsValid = IsValid
const is_key_down = input.IsKeyDown
const lookup_key_binding = input.LookupKeyBinding
const is_game_ui_visible = gui.IsGameUIVisible
const is_console_visible = gui.IsConsoleVisible
const get_keyboard_focus = vgui.GetKeyboardFocus
const is_dragging = dragndrop.IsDragging

mod 'Hotbar'

--- The key that drops the hovered item into the world. A plugin or the schema may set another
-- `KEY_` code on the client.
Hotbar.drop_key = Hotbar.drop_key or KEY_Q

--- The slots of the number keys.
const key_slots = {
  [KEY_1] = 1, [KEY_2] = 2, [KEY_3] = 3, [KEY_4] = 4, [KEY_5] = 5,
  [KEY_6] = 6, [KEY_7] = 7, [KEY_8] = 8, [KEY_9] = 9, [KEY_0] = 0
}

local hovered_panel
local is_polling = false
local key_states = {}
local taken_binds = {}
local drop_ids = {}

--- Notes that the cursor has entered an item slot, which the keys act on while it is there.
-- @param panel [Panel the fl_inventory_item or fl_hotbar_slot]
function Hotbar.hover(panel)
  hovered_panel = panel
  is_polling = false
end

--- Notes that the cursor has left an item slot.
-- @param panel [Panel the fl_inventory_item or fl_hotbar_slot]
function Hotbar.unhover(panel)
  if hovered_panel == panel then
    hovered_panel = nil
    is_polling = false
  end
end

--- Returns what the keys act on while the cursor is over an item slot, as the slot tells it
-- (see `fl_inventory_item` and `fl_hotbar_slot`). Nothing is hovered while something is
-- dragged or the slot is hidden or gone.
-- @return [Item the item to put on a slot, Number the slot of the hovered entry of the bar, nil
--   for an item of an inventory, Item the instance that the drop key drops, nil if there is
--   none; nothing when no item is hovered]
function Hotbar.get_hover_target()
  local panel = hovered_panel

  if !IsValid(panel) or !panel:IsVisible() or is_dragging() then return end

  return panel:get_hover_target()
end

--- Tells what a number key does to the hovered item or entry.
-- @param hovered_slot [Number/Nil the slot of the hovered entry of the bar, nil for an item of
--   an inventory]
-- @param slot [Number the slot of the key]
-- @return [String 'move' to move the entry to the slot, 'place' to put the item on it; nil when
--   the key does nothing]
function Hotbar.get_key_action(hovered_slot, slot)
  if slot == hovered_slot or !Hotbar.is_item_slot(slot) then return end

  return hovered_slot != nil ? 'move' : 'place'
end

--- Asks the server to drop an item of the storage of the local player into the world, with the
-- drop request of the inventory panels.
-- @param item_obj [Item]
function Hotbar.drop_item(item_obj)
  drop_ids[1] = item_obj.instance_id

  Cable.send('fl_item_drop', drop_ids)
end

--- Drops the item of an entry of the hotbar into the world: the item of an equipped entry, or
-- one instance of a pinned item that the local player carries. Does nothing for a pin that the
-- player has none of, or a slot without an entry.
-- @param slot [Number]
function Hotbar.drop_entry(slot)
  local item_obj = Hotbar.get_slot_state(slot)?.instance

  if item_obj then
    Hotbar.drop_item(item_obj)
  end
end

--- Acts on the hovered item or entry for a key that has gone down, see the file description.
-- The drop key closes the menus of items, whose item may be gone after the drop.
-- @param key [Number KEY_ enumerator]
function Hotbar.press_hover_key(key)
  local item_obj, hovered_slot, drop_obj = Hotbar.get_hover_target()

  if !item_obj then return end

  if key == Hotbar.drop_key then
    CloseDermaMenus()

    if drop_obj then
      Hotbar.drop_item(drop_obj)
    end

    return
  end

  local slot = key_slots[key]
  local action = slot and Hotbar.get_key_action(hovered_slot, slot)

  if action == 'move' then
    Cable.send('fl_hotbar_move', hovered_slot, slot)
  elseif action == 'place' then
    Cable.send('fl_hotbar_place', slot, item_obj.instance_id)
  end
end

--- Checks whether the keys may be read: an item is hovered, no text field has the keyboard and
-- neither the game menu nor the console is open.
-- @return [Boolean]
local function can_read_keys()
  if !Hotbar.get_hover_target() or is_game_ui_visible() or is_console_visible() then return false end

  local focus = get_keyboard_focus()

  return !IsValid(focus) or focus:GetClassName() != 'TextEntry'
end

--- Notes whether a key is down and tells whether it has gone down since it was last read.
-- @param key [Number KEY_ enumerator]
-- @return [Boolean]
local function went_down(key)
  local down = is_key_down(key)
  local was_down = key_states[key]

  key_states[key] = down

  return down and !was_down
end

--- Reads the number keys and the drop key while an item is hovered and acts on the hovered item
-- for one key a frame: the drop key if it has gone down, otherwise one of the number keys that
-- have. The first read after the cursor has entered a slot, or after the keys could not be read,
-- only notes which keys are down, so that a key held before does not count; a key that goes
-- down in the very frame the cursor enters a slot counts as held before. A hovered slot that has
-- been removed without the cursor leaving it is forgotten. Called every frame; returns at once
-- while no item slot is hovered and allocates nothing.
function Hotbar.poll_hover_keys()
  if !hovered_panel then return end

  if !IsValid(hovered_panel) then
    Hotbar.unhover(hovered_panel)

    return
  end

  if !can_read_keys() then
    is_polling = false

    return
  end

  local fresh = !is_polling
  local pressed_key

  is_polling = true

  for key in pairs(key_slots) do
    if went_down(key) then
      pressed_key = key
    end
  end

  local drop_key = Hotbar.drop_key

  if went_down(drop_key) then
    pressed_key = drop_key
  end

  if pressed_key and !fresh then
    Hotbar.press_hover_key(pressed_key)
  end
end

--- Checks whether a bind is one that the number keys or the drop key trigger while an item is
-- hovered, which the keys act on instead.
-- @param bind [String]
-- @return [Boolean]
function Hotbar.is_hover_bind(bind)
  if !hovered_panel or !Hotbar.get_hover_target() then return false end

  if bind == lookup_key_binding(Hotbar.drop_key) then return true end

  for key in pairs(key_slots) do
    if bind == lookup_key_binding(key) then
      return true
    end
  end

  return false
end

--- Tells whether the hotbar takes a bind that has gone down or up, so that it does not reach
-- the game. A press is taken when it is a bind of the number keys or the drop key while an item
-- is hovered (see `Hotbar.is_hover_bind`), and marks the bind; a press that is not taken removes
-- the mark. A release is taken exactly when the bind is marked, whatever is hovered, and removes
-- the mark, so that the release of a bind always goes where its press went. Allocates nothing
-- but the first mark of a bind.
-- @param bind [String]
-- @param pressed [Boolean true when the bind has gone down, false when it has gone up]
-- @return [Boolean]
function Hotbar.take_hover_bind(bind, pressed)
  if !pressed then
    if !taken_binds[bind] then return false end

    taken_binds[bind] = false

    return true
  end

  if !Hotbar.is_hover_bind(bind) then
    if taken_binds[bind] then
      taken_binds[bind] = false
    end

    return false
  end

  taken_binds[bind] = true

  return true
end

--- Checks whether a panel under the cursor is the world rather than the interface: no panel,
-- the world panel, or a panel whose clicks go to the world, such as the context menu.
-- @param panel [Panel/Nil]
-- @return [Boolean]
function Hotbar.is_world_panel(panel)
  return !IsValid(panel) or panel == vgui.GetWorldPanel() or panel:IsWorldClicker()
end

--- Checks whether the cursor is within the card that the theme draws around a panel, which
-- reaches the `inventory_card_margin` theme option past its bounds on every side.
-- @param panel [Panel the fl_hotbar or another panel drawn with PaintInventoryBackground]
-- @return [Boolean]
function Hotbar.is_cursor_on_card(panel)
  if !IsValid(panel) then return false end

  local margin = Theme.get_option('inventory_card_margin', 0)
  local x, y = panel:LocalCursorPos()
  local w, h = panel:GetSize()

  return x >= -margin and y >= -margin and x < w + margin and y < h + margin
end

--- Handles an entry of the bar dropped onto an inventory panel: takes it off the hotbar if the
-- inventory is part of the storage of the local player, which unequips an equipped item where
-- it lies, and keeps it otherwise. It is the receiver of the inventory panels for entries.
-- @param receiver [Panel the fl_inventory]
-- @param dropped [List<Panel> the dragged fl_hotbar_slot panels]
-- @param is_dropped [Boolean]
function Hotbar.receive_entry_on_inventory(receiver, dropped, is_dropped)
  local source = dropped[1]

  if !is_dropped or !IsValid(source) then return end

  source.drop_handled = true

  if source.kind and Hotbar.is_storage(receiver:get_inventory(), PLAYER) then
    Cable.send('fl_hotbar_clear', source.slot)
  end
end

--- Handles an entry of the bar dropped onto the inventory tab of the tab menu, whose bare
-- background drops items into the world: drops its item when nothing but the background is
-- under the cursor, and keeps it when a panel on the background without a receiver of its own
-- is. It is the receiver of the `fl_inventory_menu` panel for entries.
-- @param receiver [Panel the fl_inventory_menu]
-- @param dropped [List<Panel> the dragged fl_hotbar_slot panels]
-- @param is_dropped [Boolean]
function Hotbar.receive_entry_in_world(receiver, dropped, is_dropped)
  local source = dropped[1]

  if !is_dropped or !IsValid(source) then return end

  source.drop_handled = true

  if source.kind and vgui.GetHoveredPanel() == receiver then
    Hotbar.drop_entry(source.slot)
  end
end
