--- Attributes gives characters numeric stats and skills that can level up.
-- An attribute is defined once, as an `AttributeBase` in a file of a plugin's `attributes`
-- folder or through `Attributes.register`, with a level range, a type (`ATTRIBUTE_STAT` or
-- `ATTRIBUTE_SKILL`) and a progression curve. Every character has a level and a progress
-- value for each attribute, stored in the database and read and changed through player
-- methods such as `Player:get_attribute`, `Player:set_attribute` and
-- `Player:progress_attribute`. A boost adds levels to an attribute and a multiplier scales
-- the progress gained in it, either for a limited time or until it is removed; one that is
-- given an identifier can be replaced and removed by it.
--
-- Players see their attributes in the Attributes tab of the tab menu, except for the ones
-- that are hidden. Staff set, boost and inspect attributes with the plugin's commands, and
-- the `attribute` condition compares a player's attribute level with a value. The
-- `attribute_progress_scale` config scales all progress. The `AdjustAttributeProgress` hook
-- changes progress before it is applied, `PlayerAttributeChanged` reports a changed level or
-- progress, and `IsAttributeVisible` hides attributes from the tab.

PLUGIN:set_global('AttributesPlugin')

Plugin.add_extra('attributes')

require_relative 'sh_enums'
require_relative 'cl_hooks'
require_relative 'sv_hooks'

--- Includes a plugin's attributes folder when the 'attributes' extra is being loaded.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function AttributesPlugin:PluginIncludeFolder(extra, folder)
  if extra == 'attributes' then
    Attributes.include_attributes(folder..'/attributes')

    return true
  end
end

--- Registers the 'attribute' condition, which compares a player's attribute level to a value.
function AttributesPlugin:RegisterConditions()
  Conditions:register_condition('attribute', {
    name = 'condition.attribute.name',
    text = 'condition.attribute.text',
    get_args = function(panel, data)
      local attribute_name = ''
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local attribute_value = panel.data.attribute_value or ''

      if panel.data.attribute then
        attribute_name = Attributes.find(panel.data.attribute).name
      end

      return { operator = operator, attribute = attribute_name, value = attribute_value }
    end,
    icon = 'icon16/chart_bar.png',
    check = function(target, data)
      if !data.operator or !data.attribute or !data.attribute_value then return false end

      return util.process_operator(data.operator, target:get_attribute(data.attribute), tonumber(data.attribute_value))
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'condition.attribute.message1', 'condition.attributes', Attributes.get_stored(),
      function(selector, value)
        selector:add_choice(t(value.name), function()
          panel.data.attribute = value.attribute_id

          panel.update()

          Derma_StringRequest(
            t(data.name),
            t'condition.attribute.message2',
            '',
            function(text)
              panel.data.attribute_value = text

              panel.update()
            end)
        end)
      end)
    end,
    set_operator = 'relational'
  })
end
