PLUGIN:set_global('Items')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
require_relative 'sh_enums'

function Items:OnPluginLoaded()
  Plugin.add_extra('items')
  Plugin.add_extra('items/bases')

  require_relative_folder(self:get_folder()..'/items/bases')
  Item.include_items(self:get_folder()..'/items/')
end

function Items:PluginIncludeFolder(extra, folder)
  if extra == 'items' then
    Item.include_items(folder..'/items/')

    return true
  end
end

function Items:RegisterConditions()
  Conditions:register_condition('has_item', {
    name = 'conditions.has_item.name',
    text = 'conditions.has_item.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local parameter = panel.data.item_id or ''

      return { operator, parameter }
    end,
    icon = 'icon16/brick.png',
    check = function(player, data)
      if !data.operator or !data.item_id then return false end

      return util.process_operator(data.operator, player:has_item(data.item_id), true)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      Derma_StringRequest(
        t(data.name),
        t'conditions.has_item.message',
        '',
        function(text)
          panel.data.item_id = text:lower()

          panel.update()
        end)
    end,
    set_operator = 'equal'
  })

  Conditions:register_condition('has_item_data', {
    name = 'conditions.has_item_data.name',
    text = 'conditions.has_item_data.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local item_id = panel.data.item_id or ''
      local key = panel.data.key or ''
      local value = panel.data.value or ''

      return { operator, item_id, key, value }
    end,
    icon = 'icon16/brick_add.png',
    check = function(player, data)
      if !data.operator or !data.item_id or !data.key or !data.value then return false end

      local items = player:find_instances(item_id, 1)

      if #items == 0 then
        return false
      end

      for k, v in pairs(items) do
        local value = v:get_data(data.key)

        if value then
          return util.process_operator(data.operator, value, data.value)
        end
      end

      return false
    end,
    set_parameters = function(id, data, panel, menu, parent)
      Derma_StringRequest(
        t(data.name),
        t'conditions.has_item_data.message1',
        '',
        function(text)
          panel.data.item_id = text:lower()

          panel.update()

          Derma_StringRequest(
            t(data.name),
            t'conditions.has_item_data.message2',
            '',
            function(text)
              panel.data.key = text

              panel.update()

              Derma_StringRequest(
                t(data.name),
                t'conditions.has_item_data.message3',
                '',
                function(text)
                  panel.data.value = text

                  panel.update()
                end)
            end)
        end)
    end,
    set_operator = 'equal'
  })
end
