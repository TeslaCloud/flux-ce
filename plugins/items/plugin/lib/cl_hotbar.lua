--- Client side of the Hotbar library: which slots the local player is shown, which of them is
-- selected, what the selected slot puts in their hands, and the panels that show the bar.
--
-- `Hotbar.refresh` works out the state of every slot that the local player is shown (see
-- `Hotbar.build_layout`): the item it shows, the kind of its entry, the weapon it puts in
-- the hands and, for a pinned item, how many of it the player carries. It runs when the
-- entries, the inventories of the storage of the player, their permissions or the
-- `items_hotbar_slots` config change, and when the inventories of the player are cleared, and
-- updates the hotbar panels, so that painting the bar and watching the attack key look
-- nothing up.
--
-- `Hotbar.select` selects a slot and puts its weapon in the hands: the weapon of a weapon
-- entry, the physgun of slot 9 and the tool gun of slot 0, and the hands weapon for slot 8,
-- an empty slot and any other entry, which the player then holds. The mouse wheel steps
-- through the slots with `Hotbar.cycle` and the number keys pick them with
-- `Hotbar.select_key`. When the active weapon changes by other means, the selection follows
-- it (`Hotbar.follow_active_weapon`); a player without a valid active weapon holds nothing.
-- While the selected slot holds an item that is not a weapon and the player is alive and out
-- of a vehicle, primary attack does not reach the hands weapon and runs the hotbar action of
-- the item instead (`Hotbar.filter_attack`, `ItemBase:on_hotbar_use`), unless a handler of
-- `PlayerCanUseHotbarItem` refuses, as the Pickup Objects plugin does while the player holds
-- an object. While the weapon selector is open (`Hotbar.is_selector_open`), the number keys,
-- the mouse wheel and primary attack belong to it: the hotbar changes no selection and runs
-- no action, and only keeps primary attack from the hands weapon while an item is held, so
-- that a click that reaches the command while the selector is open does not punch. What the
-- keys and the drags of the interfaces that show items do with the hotbar is in
-- `cl_hotbar_input.lua`.
--
-- The internal state of the library is kept across a code refresh: `Hotbar.selected` (the
-- selected slot, whose item or weapon the local player holds; nil until the first
-- `Hotbar.refresh`, which selects the hands), `Hotbar.slot_states` and `Hotbar.slot_classes`
-- (the state of every shown slot and the weapon it puts in the hands), `Hotbar.active_weapon`
-- and `Hotbar.active_class` (the valid active weapon of the local player and its class, nil
-- without one), `Hotbar.switch_class` and `Hotbar.switch_until` (the weapon that
-- `Hotbar.select` has asked for and until when the selection waits for it),
-- `Hotbar.layout_key` (what the layout has been built from) and `Hotbar.popup_panel` (the bar
-- that a key press or the context menu shows).

local IsValid = IsValid
local CurTime = CurTime
local isnumber = isnumber
local isstring = isstring
local IN_ATTACK = IN_ATTACK

mod 'Hotbar'

const key_delay = 0.2
const use_delay = 0.3
const switch_timeout = 0.5
const popup_step = 0.05

--- The slots that the local player is shown, in the order of the bar (see
-- `Hotbar.build_layout`). The list is reused by every update of the layout.
Hotbar.layout = Hotbar.layout or {}

--- How many slots `Hotbar.layout` holds.
Hotbar.layout_count = Hotbar.layout_count or 0

--- The hotbar panels that exist, as keys; `Hotbar.refresh` updates each of them.
Hotbar.panels = Hotbar.panels or setmetatable({}, { __mode = 'k' })

Hotbar.slot_states = Hotbar.slot_states or {}
Hotbar.slot_classes = Hotbar.slot_classes or {}

local layout = Hotbar.layout
local slot_states = Hotbar.slot_states
local slot_classes = Hotbar.slot_classes
local next_key_press = 0
local next_use = 0
local attack_was_down = false

--- Checks whether a slot is shown to the local player.
-- @param slot [Number]
-- @return [Boolean]
function Hotbar.is_displayed(slot)
  return Hotbar.find_position(layout, Hotbar.layout_count, slot) != nil
end

--- Returns the state of a slot that the local player is shown, as `Hotbar.refresh` has worked
-- it out. The table is reused by the next refresh.
-- @param slot [Number]
-- @return [Map item (Item the item the slot shows, an instance or the template of a pinned
--   item that the player has none of), instance (Item the equipped item or the first carried
--   instance of a pinned one), kind ('equip', 'pin' or nil for an empty slot), class (String
--   the weapon the slot puts in the hands), amount (Number how many of a pinned item the
--   player carries) and amount_text (String the same as text); nil for a slot that is not
--   shown]
function Hotbar.get_slot_state(slot)
  return Hotbar.is_displayed(slot) and slot_states[slot] or nil
end

--- Works out which slots the local player is shown: their item slots, the hands, and the
-- physgun and tool gun if they have the `physgun` and `toolgun` permissions.
-- @return [Boolean whether the slots have changed]
function Hotbar.update_layout()
  local client = PLAYER

  if !IsValid(client) then return false end

  local slot_count = Hotbar.has_item_slots(client) and Hotbar.get_slot_count() or 0
  local physgun = client:can('physgun') == true
  local toolgun = client:can('toolgun') == true
  local key = slot_count * 4 + (physgun ? 1 : 0) + (toolgun ? 2 : 0)

  if key == Hotbar.layout_key then return false end

  Hotbar.layout_key = key
  Hotbar.layout_count = Hotbar.build_layout(layout, slot_count, physgun, toolgun)

  return true
end

--- Fills the state of one slot, see `Hotbar.get_slot_state`.
-- @param client [Player the local player]
-- @param slot [Number]
-- @param entry [Number/String/Nil the entry of the slot]
local function fill_state(client, slot, entry)
  local state = slot_states[slot] or {}
  local hands_weapon = Hotbar.hands_weapon

  slot_states[slot] = state
  state.item, state.instance, state.kind, state.amount, state.amount_text = nil, nil, nil, nil, nil
  state.class = hands_weapon

  if slot == Hotbar.physgun_slot then
    state.class = Hotbar.physgun_weapon
  elseif slot == Hotbar.toolgun_slot then
    state.class = Hotbar.toolgun_weapon
  elseif isnumber(entry) then
    local item_obj = Item.find_instance_by_id(entry)

    if item_obj then
      state.item, state.instance, state.kind = item_obj, item_obj, 'equip'
      state.class = item_obj.weapon_class or hands_weapon
    end
  elseif isstring(entry) then
    local template = Item.find_by_id(entry)

    if template then
      local amount, first = Hotbar.count_items(client, entry)

      state.item, state.instance, state.kind = first or template, first, 'pin'
      state.amount, state.amount_text = amount, tostring(amount)
    end
  end

  slot_classes[slot] = state.class
end

--- Works out the state of every slot that the local player is shown, keeps the selection on a
-- shown slot, makes the selection follow the active weapon and updates the hotbar panels.
function Hotbar.refresh()
  local client = PLAYER

  if !IsValid(client) then return end

  Hotbar.update_layout()

  local entries = Hotbar.get_entries(client)

  for i = 1, Hotbar.layout_count do
    local slot = layout[i]

    fill_state(client, slot, slot <= Hotbar.max_slots and entries[slot] or nil)
  end

  if !Hotbar.is_displayed(Hotbar.selected) then
    Hotbar.selected = Hotbar.hands_slot
  end

  Hotbar.sync_selection()
  Hotbar.rebuild_panels()
end

--- Updates every hotbar panel that exists.
function Hotbar.rebuild_panels()
  for panel in pairs(Hotbar.panels) do
    if IsValid(panel) then
      panel:rebuild()
    end
  end
end

--- Makes the selection follow the weapon in the hands of the local player, see
-- `Hotbar.follow_weapon`. While a weapon that `Hotbar.select` has asked for is on its way, it
-- waits for that weapon, half a second at most; once the weapon has arrived or the time is up,
-- it forgets the request and follows the active weapon. Does nothing more while the player
-- has no valid active weapon or no slot is selected.
function Hotbar.sync_selection()
  local active_class = Hotbar.active_class
  local switch_class = Hotbar.switch_class

  if switch_class then
    if active_class != switch_class and CurTime() < Hotbar.switch_until then return end

    Hotbar.switch_class = nil
  end

  local selected = Hotbar.selected

  if !active_class or !selected then return end

  local selected_class = slot_classes[selected]
  local owned = selected_class != nil and IsValid(PLAYER:GetWeapon(selected_class))
  local slot = Hotbar.follow_weapon(layout, Hotbar.layout_count, selected, slot_classes, active_class, owned)

  if slot != selected then
    Hotbar.selected = slot

    Hotbar.popup()
  end
end

--- Notes the weapon in the hands of the local player and makes the selection follow it when it
-- has changed, or when a weapon that `Hotbar.select` has asked for has not arrived in time.
-- A weapon that is not valid, such as one that has been removed, counts as none, whatever the
-- engine answers when it is compared with the NULL entity, so `Hotbar.active_class` is nil
-- while the player has no valid active weapon. Called every frame; allocates nothing.
function Hotbar.follow_active_weapon()
  local client = PLAYER

  if !IsValid(client) then return end

  local weapon = client:GetActiveWeapon()

  if !IsValid(weapon) then
    weapon = nil
  end

  if weapon == Hotbar.active_weapon then
    if Hotbar.switch_class and CurTime() >= Hotbar.switch_until then
      Hotbar.sync_selection()
    end

    return
  end

  Hotbar.active_weapon = weapon
  Hotbar.active_class = weapon and weapon:GetClass()

  Hotbar.sync_selection()
end

--- Returns the class of the weapon that is on its way to the hands of the local player, the one
-- `Hotbar.select` has asked for, or else of the weapon in their hands.
-- @param client [Player the local player]
-- @return [String the class, nil when nothing is on its way and the player has no valid
--   active weapon]
local function get_pending_class(client)
  local switch_class = Hotbar.switch_class

  if switch_class then
    return switch_class
  end

  local weapon = client:GetActiveWeapon()

  if IsValid(weapon) then
    return weapon:GetClass()
  end
end

--- Selects a slot that the local player is shown and puts its weapon in their hands, with the
-- selection sound, and pops the bar up. The weapon is asked for whenever the one that is on
-- its way to the hands, or else the one in them, is another, so that the last selection wins
-- over a switch that has not arrived yet. Does nothing for a slot that is not shown.
-- @param slot [Number]
-- @return [Boolean whether the slot is shown]
function Hotbar.select(slot)
  local client = PLAYER

  if !IsValid(client) or !Hotbar.is_displayed(slot) then return false end

  local weapon_class = slot_classes[slot]
  local weapon = client:GetWeapon(weapon_class)
  local changed = slot != Hotbar.selected

  if IsValid(weapon) and get_pending_class(client) != weapon_class then
    input.SelectWeapon(weapon)

    Hotbar.switch_class = weapon_class
    Hotbar.switch_until = CurTime() + switch_timeout
    changed = true
  end

  if changed then
    surface.PlaySound(weapon_class == Hotbar.hands_weapon ? 'common/wpn_hudoff.wav' : 'common/wpn_select.wav')
  end

  Hotbar.selected = slot

  Hotbar.popup()

  return true
end

--- Selects the slot of a number key, at most once every fifth of a second. The keys of the
-- slots that are not shown do nothing, though the slots that are shown are checked again
-- first, in case the permissions of the player have changed.
-- @param slot [Number 1 to 9, or 0]
function Hotbar.select_key(slot)
  local cur_time = CurTime()

  if next_key_press > cur_time then return end

  next_key_press = cur_time + key_delay

  if Hotbar.update_layout() then
    Hotbar.refresh()
  end

  Hotbar.select(slot)
end

--- Selects the slot a step away from the selected one, wrapping around at either end of the
-- bar.
-- @param step [Number 1 for the next slot, -1 for the previous one]
function Hotbar.cycle(step)
  Hotbar.select(Hotbar.step_slot(layout, Hotbar.layout_count, Hotbar.selected, step))
end

--- Returns the state of the selected slot if the local player holds its item: the slot holds
-- an entry that is not a weapon and the hands weapon is the valid active weapon of the player.
-- Nothing is held while the player has no valid active weapon.
-- @return [Map the state of the slot (see `Hotbar.get_slot_state`), nil if no item is held]
function Hotbar.get_held_state()
  local hands_weapon = Hotbar.hands_weapon

  if Hotbar.active_class != hands_weapon then return end

  local state = slot_states[Hotbar.selected]

  if state and state.kind and state.class == hands_weapon and Hotbar.is_displayed(Hotbar.selected) then
    return state
  end
end

--- Checks whether the weapon selector of the Weapon Selector plugin is open, which owns the
-- number keys, the mouse wheel and primary attack for as long as it is. False without the
-- plugin.
-- @return [Boolean]
function Hotbar.is_selector_open()
  return WeaponSelect != nil and WeaponSelect:is_open()
end

--- Takes primary attack from a command while the local player holds an item of the hotbar, and
-- runs the hotbar action of the item when the key has just gone down, unless a handler of
-- `PlayerCanUseHotbarItem` refuses.
-- @param user_cmd [CUserCmd]
-- @param client [Player the local player]
-- @param state [Map the state of the held slot (see `Hotbar.get_held_state`)]
local function use_held_item(user_cmd, client, state)
  --- Called on the client for every command that is built while the local player holds
  -- primary attack down with an item of the hotbar in their hands, before the hotbar takes
  -- the key from the command. The Pickup Objects plugin refuses while the player carries or
  -- drags an object, so that the click throws it. It is not run while the player is dead or
  -- in a vehicle, nor while the weapon selector is open, when the hotbar takes the key without
  -- asking and runs no action.
  -- @param client [Player The local player]
  -- @param item_obj [Item The item in the hands: the equipped item, the first carried
  --   instance of a pinned item, or the item of a pin that the player has none of]
  -- @return [Boolean Return false to leave primary attack to the hands weapon and run no
  --   hotbar action]
  -- @realm [client]
  if hook.Run('PlayerCanUseHotbarItem', client, state.item) == false then return end

  user_cmd:RemoveKey(IN_ATTACK)

  local cur_time = CurTime()
  local item_obj = state.instance

  if !attack_was_down and next_use <= cur_time and item_obj then
    next_use = cur_time + use_delay

    item_obj:on_hotbar_use(client)
  end
end

--- Keeps primary attack from reaching the hands weapon while the local player holds an item of
-- the hotbar, and runs the hotbar action of the item (`ItemBase:on_hotbar_use`) when the key
-- goes down, at most every 0.3 seconds. An item whose pinned instances have run out does
-- nothing. A player who is dead or in a vehicle keeps primary attack, which the vehicle uses,
-- and runs no action, and so does a player whom a handler of `PlayerCanUseHotbarItem` refuses;
-- that is checked only once the key is down and an item is held. While the weapon selector is
-- open, a held item still keeps the key from the command, so that the hands weapon does not
-- punch, but no action runs and `PlayerCanUseHotbarItem` is not asked. An action runs only
-- when the key goes down, so a press that began while the selector was open or a handler
-- refused runs none for as long as the key stays down. Called for every command that is built;
-- allocates nothing.
-- @param user_cmd [CUserCmd]
function Hotbar.filter_attack(user_cmd)
  if !user_cmd:KeyDown(IN_ATTACK) then
    attack_was_down = false

    return
  end

  local state = Hotbar.get_held_state()

  if state then
    local client = PLAYER

    if client:Alive() and !client:InVehicle() then
      if Hotbar.is_selector_open() then
        user_cmd:RemoveKey(IN_ATTACK)
      else
        use_held_item(user_cmd, client, state)
      end
    end
  end

  attack_was_down = true
end

--- Handles an item of an inventory that is dragged over a hotbar panel or dropped onto it:
-- takes the hover highlight off the inventory slot that was hovered last and, once the item
-- is dropped, forgets the slot that it was dragged from and shows the item in its inventory
-- again. It is the receiver for items of the bar and of the window that shows an inventory
-- opened over the tab menu or the container view, and the receivers of the slots of the bar
-- and of a background (`Inventories.receive_item_on_background`) call it.
-- @param _receiver [Panel the fl_hotbar or fl_hotbar_slot panel, the window of an inventory or
--   a background]
-- @param dropped [List<Panel> the dragged fl_inventory_item panels]
-- @param is_dropped [Boolean]
-- @return [Item the dropped item, nil while it is dragged or when the panel shows no item]
function Hotbar.receive_inventory_item(_receiver, dropped, is_dropped)
  local drop_slot = Flux.inventory_drop_slot

  if IsValid(drop_slot) then
    drop_slot.is_hovered = false
    Flux.inventory_drop_slot = nil
  end

  if !is_dropped then return end

  local item_panel = dropped[1]
  local item_obj = IsValid(item_panel) and item_panel.item_data

  if !item_obj then return end

  Flux.inventory_drag_slot = nil

  local inventory = Inventories.find(item_panel:get_inventory_id())

  if inventory and IsValid(inventory.panel) then
    inventory.panel:rebuild()
  end

  return item_obj
end

--- Creates a hotbar panel at the bottom center of the screen. A bar created for a parent
-- panel, such as the one of the tab menu, removes the bar that a key press or the context menu
-- has shown (`Hotbar.close_popup`).
-- @param parent=nil [Panel]
-- @return [Panel the fl_hotbar panel]
function Hotbar.create_panel(parent)
  if parent then
    Hotbar.close_popup()
  end

  local panel = vgui.Create('fl_hotbar', parent)

  panel:rebuild()

  return panel
end

--- Shows the hotbar for a short time, fading it out gradually. Makes the hotbar fully opaque
-- again if it is on the screen already, and leaves it alone while another panel, such as the
-- one of the tab menu, shows it.
function Hotbar.popup()
  local panel = Hotbar.popup_panel

  if IsValid(panel) then
    panel:SetAlpha(255)

    return
  end

  if !IsValid(PLAYER) or !PLAYER:Alive() then return end

  for other in pairs(Hotbar.panels) do
    if IsValid(other) then return end
  end

  Hotbar.popup_panel = Hotbar.create_panel()

  timer.Create('fl_hotbar_popup', popup_step, 0, function()
    local hotbar = Hotbar.popup_panel

    if !IsValid(hotbar) then
      timer.Remove('fl_hotbar_popup')

      return
    end

    local alpha = hotbar:GetAlpha()

    hotbar:SetAlpha(alpha - 5)

    if alpha <= 50 then
      hotbar:safe_remove()
    end
  end)
end

--- Shows the hotbar and makes it interactive, for as long as the context menu is open.
function Hotbar.open_interactive()
  if IsValid(Hotbar.popup_panel) then
    Hotbar.popup_panel:safe_remove()
  end

  timer.Remove('fl_hotbar_popup')

  local panel = Hotbar.create_panel()

  panel:SetAlpha(255)
  panel:MakePopup()
  panel:MoveToFront()
  panel:SetKeyboardInputEnabled(false)
  panel:SetMouseInputEnabled(true)

  Hotbar.popup_panel = panel
end

--- Removes the hotbar that the context menu or a key press has shown.
function Hotbar.close_popup()
  if IsValid(Hotbar.popup_panel) then
    Hotbar.popup_panel:safe_remove()
  end

  Hotbar.popup_panel = nil
end
