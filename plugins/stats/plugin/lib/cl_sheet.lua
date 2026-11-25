--- Client helpers of the Stats plugin that the character sheet, the staff attribute viewer and
-- the stats stage of character creation share: how the icon of a stat or a skill is drawn,
-- how a modifier is written, the order in which stats and skills are listed and the grouping
-- of skills under their key stats.
--
-- This file is included before sh_plugin.lua, which is why it makes the plugin available as
-- the `Stats` global if no other file has done so yet.

local huge = math.huge

if !Stats then
  PLUGIN:set_global('Stats')
end

--- Returns how the icon of a stat or a skill is drawn: a name that starts with 'fa-' is a
-- FontAwesome icon, anything else the path of an image.
-- @param icon [String FontAwesome icon name or path of an image]
-- @return [String 'fontawesome' or 'image'; nil if there is no icon]
function Stats:get_icon_kind(icon)
  if !isstring(icon) or icon == '' then return end

  return icon:start_with('fa-') ? 'fontawesome' : 'image'
end

--- Writes a modifier with its sign, rounded to two decimals: '+2', '-1', '+0'.
-- @param value [Number]
-- @return [String]
function Stats:format_modifier(value)
  value = math.Round(tonumber(value) or 0, 2)

  if value < 0 then
    return tostring(value)
  end

  return '+'..value
end

--- Collects the translated names of definitions.
-- @param list [List<AttributeBase/SkillBase>]
-- @return [Map translated names keyed by definition]
local function translate_names(list)
  local names = {}

  for _, definition in ipairs(list) do
    names[definition] = t(definition.name)
  end

  return names
end

--- Compares two definitions by their translated names, and by their IDs when the names are
-- the same.
-- @param names [Map translated names keyed by definition]
-- @param a [AttributeBase/SkillBase]
-- @param b [AttributeBase/SkillBase]
-- @return [Boolean whether a comes first]
local function by_name(names, a, b)
  if names[a] != names[b] then
    return names[a] < names[b]
  end

  return tostring(a.attribute_id or a.skill_id) < tostring(b.attribute_id or b.skill_id)
end

--- Sorts stat or skill definitions by their translated names, and by their IDs when the
-- names are the same.
-- @param list [List<AttributeBase/SkillBase> sorted in place]
-- @return [List<AttributeBase/SkillBase> the same list]
function Stats:sort_by_name(list)
  local names = translate_names(list)

  table.sort(list, |a, b| -> by_name(names, a, b))

  return list
end

--- Sorts stats by their `order` field, lowest first, and puts the stats without one after
-- them; stats of the same order are sorted by name.
-- @param list [List<AttributeBase> sorted in place]
-- @return [List<AttributeBase> the same list]
function Stats:sort_stats(list)
  local names = translate_names(list)

  table.sort(list, function(a, b)
    local order_a = isnumber(a.order) ? a.order : huge
    local order_b = isnumber(b.order) ? b.order : huge

    if order_a != order_b then
      return order_a < order_b
    end

    return by_name(names, a, b)
  end)

  return list
end

--- Groups the registered skills under the key stats they name.
-- @param filter [Function called with each skill definition; a false or nil result leaves
--   the skill out]
-- @return [Map List<SkillBase> skills keyed by the ID of their key stat, List<SkillBase>
--   skills whose key stat is not registered; neither is sorted]
function Stats:group_skills(filter)
  local by_stat, other = {}, {}

  for _, skill in pairs(Skills.get_stored()) do
    if filter(skill) then
      local stat_id = skill.attribute

      if isstring(stat_id) and Attributes.find(stat_id) then
        local skills = by_stat[stat_id] or {}

        skills[#skills + 1] = skill
        by_stat[stat_id] = skills
      else
        other[#other + 1] = skill
      end
    end
  end

  return by_stat, other
end
