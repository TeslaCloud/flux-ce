--- Client side of the Doors plugin: when the server sends it, opens the context menu of a door
-- with the options to lock or unlock it, to buy it, to manage it and to open its settings.
-- Also works out the status text that is drawn on ownable doors.

--- Formats a price for display.
-- @param price [Number the price]
-- @param currency [String ID of the currency of the price]
-- @return [String the amount followed by the name of the currency; nil if the price is not
--   above 0 or the currency is not known, which is when a door is free]
function Doors:format_price(price, currency)
  local currency_data = isstring(currency) and Currencies and Currencies:find_currency(currency)

  if !currency_data or !isnumber(price) or price <= 0 then return end

  local text = t('ui.door.price', { value = price, currency = t(currency_data.name) })

  return text
end

--- Returns the status line of a door, which title types draw below its name: the text of
-- the owner or a note that the door is owned, or for an ownable door without an owner that
-- it is for sale and for how much.
-- ```
-- Doors:register_title_type('plain', {
--   name = 'door.title_type.plain',
--   draw = function(entity, w, h, alpha)
--     local status = Doors:get_status_text(entity)
--
--     if status then
--       draw.SimpleText(status, Theme.get_font('text_3d2d'), 0, 0, color_white:alpha(alpha))
--     end
--   end
-- })
-- ```
-- @param entity [Entity the door]
-- @return [String the status, or nil if the door is neither owned nor ownable]
function Doors:get_status_text(entity)
  local text

  if self:is_owned(entity) then
    text = self:get_text(entity)

    if text == '' then
      text = t'ui.door.status.owned'
    end
  elseif self:is_ownable(entity) then
    local price_text = self:format_price(self:get_price(entity))

    if price_text then
      text = t('ui.door.status.for_sale', { price = price_text })
    else
      text = t'ui.door.status.free'
    end
  end

  return text
end

--- Opens the context menu of a door for the local player. What it offers depends on the
-- player: locking and unlocking for those who may lock the door, buying an ownable door
-- that has no owner, the management menu for the owner and those who manage the door, and
-- evicting the owner and the door settings for staff with the 'manage_doors' permission.
-- Nothing opens if there is nothing to offer.
-- @param entity [Entity the door]
-- @param can_lock [Boolean whether the player may lock and unlock the door]
-- @param conditions=nil [List condition nodes that are set on the door]
-- @param info=nil [Map what the server tells the player about the ownership of the door,
--   see `Doors:get_menu_info`]
function Doors:open_menu(entity, can_lock, conditions, info)
  if !IsValid(entity) then return end

  info = istable(info) and info or {}

  local staff = can('manage_doors')
  local menu = DermaMenu()
  local options = 0
  local yes, no = t'ui.yes', t'ui.no'

  if can_lock then
    local locked = entity:get_nv('fl_locked')

    menu:AddOption(locked and t'ui.door.unlock' or t'ui.door.lock', function()
      Cable.send('fl_lock_door', entity, !locked)
    end)

    options = options + 1
  end

  if info.ownable and !info.owned then
    local price_text = self:format_price(info.price, info.currency)
    local label = price_text and t('ui.door.buy', { price = price_text }) or t'ui.door.take'
    local message = price_text and t('ui.door.buy_message', { price = price_text }) or t'ui.door.take_message'

    menu:AddOption(label, function()
      Derma_Query(message, label, yes, function()
        Cable.send('fl_door_buy', entity)
      end, no)
    end)

    options = options + 1
  end

  if (info.level or DOOR_ACCESS_NONE) >= DOOR_ACCESS_MANAGE then
    menu:AddOption(t'ui.door.manage', function()
      local management = vgui.Create('fl_door_management')
      management:set_door(entity, info)
    end)

    options = options + 1
  end

  if staff and info.owned then
    local label = t('ui.door.evict', { name = string.gsub(info.owner_name or '', '%%', '%%%%') })
    local message = t'ui.door.evict_message'

    menu:AddOption(label, function()
      Derma_Query(message, label, yes, function()
        Cable.send('fl_door_evict', entity)
      end, no)
    end)

    options = options + 1
  end

  if staff then
    menu:AddOption(t'ui.door.settings', function()
      local door_menu = vgui.Create('fl_door_menu')
      door_menu:set_door(entity, conditions)
    end)

    options = options + 1
  end

  if options < 1 then
    menu:Remove()

    return
  end

  menu:Open()
  menu:Center()

  menu:MakePopup()
  menu:DoModal()
end

Cable.receive('fl_door_menu', function(entity, can_lock, conditions, info)
  Doors:open_menu(entity, can_lock, conditions, info)
end)

Cable.receive('fl_door_info', function(entity, info)
  local management = Doors.management

  if IsValid(management) and management:get_door() == entity and istable(info) then
    management:set_info(info)
  end
end)
