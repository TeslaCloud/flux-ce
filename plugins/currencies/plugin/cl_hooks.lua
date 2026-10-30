--- Client side of the Currencies plugin: attaches money panels to the inventory of the player
-- and to opened containers, and adds the options to give money to the player interaction menu.

local IsValid = IsValid
local t = t
local scale = math.scale

--- Creates or refreshes the money panel that sits next to the 'pockets' inventory panel.
-- @param panel [Panel the inventory panel that was rebuilt]
function Currencies:InventoryRebuilt(panel)
  if panel:get_inventory_type() == 'pockets' then
    local parent = panel:GetParent()

    if !IsValid(panel.money) then
      local owner = Inventories.find(panel:get_inventory_id()).owner

      panel.money = self:create_panel(owner, parent)
    else
      panel.money:rebuild()
    end

    local text = t(panel.money.title)
    local font = Theme.get_font('main_menu_normal_large')
    local _text_w, text_h = util.text_size(text, font)

    if IsValid(panel.main_inventory) then
      panel:SetWide(math.min(panel:GetWide(), panel.main_inventory:GetWide() - panel.money:GetWide() - scale(16)))
    end

    panel.money:SetPos(
      panel.x + panel:GetWide() + scale(8),
      panel.y + math.max(panel:GetTall() - panel.money:GetTall(), text_h)
    )
  end
end

--- Creates or refreshes the money panel below an opened container's inventory. Inventories
-- that have an instance_id are skipped.
-- @param panel [Panel the container panel]
-- @param inventory_id [Number]
function Currencies:ContainerOpened(panel, inventory_id)
  local inventory = Inventories.find(inventory_id)
  local inv_panel = panel.inventory

  if inventory.instance_id then return end

  if !IsValid(panel.container_money) then
    panel.container_money = self:create_panel(inventory.owner, panel)
  else
    panel.container_money:rebuild()
  end

  local text = t(panel.container_money.title)
  local font = Theme.get_font('main_menu_normal_large')
  local _text_w, text_h = util.text_size(text, font)

  panel.container_money:SetPos(inv_panel.x, inv_panel.y + inv_panel:GetTall() + text_h + scale(8))
end

--- Adds a money submenu to the player interactions with a 'give' option for every currency
-- that is not hidden or that the local player owns.
-- @param options [List<Map> options of the interaction menu, changed in place]
-- @param target [Player the player being interacted with]
function Currencies:AdjustPlayerInteractions(options, target)
  local money_options = {}
  local client = PLAYER

  for currency_id, currency_data in pairs(Currencies.all()) do
    local amount = client:get_money(currency_id) or 0

    if !currency_data.hidden or currency_data.hidden and amount > 0 then
      money_options[#money_options + 1] = {
        id = 'give_'..currency_id,
        text = t'ui.currency.menu.give'..' '..t(currency_data.name),
        callback = function()
          Derma_StringRequest(
            t'ui.currency.give.title',
            t('ui.currency.give.message', { currency = t(currency_data.name) }),
            '',
            function(text)
              local value = tonumber(text)

              if value and value > 0 then
                Cable.send('fl_currency_give', value, currency_id, target)
              else
                client:notify('error.invalid_amount')
              end
            end
          )
        end
      }
    end
  end

  options[#options + 1] = {
    id = 'money',
    text = t'ui.currency.title',
    icon = 'icon16/money.png',
    options = money_options
  }
end

--- Creates a panel that lists the money of an entity and keeps track of it so that it is
-- rebuilt when the server reports a change. Client only.
-- @param entity [Entity entity whose money is shown]
-- @param parent [Panel]
-- @return [Panel the created fl_currencies panel]
function Currencies:create_panel(entity, parent)
  local money_panel = vgui.Create('fl_currencies', parent)
  money_panel:set_entity(entity)
  money_panel:rebuild()
  money_panel.OnRemove = function(pnl)
    if IsValid(pnl) then
      table.RemoveByValue(Flux.money_panels, pnl)
    end
  end

  Flux.money_panels = Flux.money_panels or {}
  table.insert(Flux.money_panels, money_panel)

  return money_panel
end
