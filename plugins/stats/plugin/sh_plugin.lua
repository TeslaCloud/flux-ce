--- Stats gives every character seven stats: strength, reflexes, endurance, perception,
-- intelligence, determination and charisma. A stat goes from -3 (terrible) through 3
-- (superb) to 5 (legendary), and its level is the modifier it adds to a twenty-sided roll.
-- A new character spreads the points of the `stats_creation_points` config over them in a
-- stage of character creation, raising no stat above its `creation_max` (3), and the server
-- checks the result. The faction of a character adds the bonuses it lists in
-- `FACTION.stats`, as attribute boosts that carry the `Stats.faction_boost_id` identifier and
-- last for as long as the character is in the faction; the `stats_faction_bonuses` config
-- turns them off.
--
-- Stats and skills are attributes, defined as `AttributeBase` objects by the files of the
-- plugin's `attributes` folder; any plugin or schema that loads after this one can add more
-- in an `attributes` folder of its own or with `Attributes.register`. Every character keeps
-- an `Attribute` record with the level of each attribute, created with the character from
-- the levels picked at creation or the defaults and added for the attributes registered
-- later when the character is loaded. A level changes only when it is set: by staff, by a
-- plugin through `Player:set_attribute` and the methods built on it, or by a point spent
-- through the Levels plugin; `PlayerAttributeChanged` reports every change. A boost
-- (`Player:boost_attribute`) adds levels on top for a limited time or until it is removed,
-- and one that is given an identifier can be replaced and removed by it; expired boosts are
-- removed every second. The server networks the levels and boosts of a character to its
-- owner alone. The `attribute` condition compares the level of an attribute, boosts
-- included, with a value. Staff set levels with the CharSetAttribute command, give and
-- remove boosts with CharAttributeBoost and CharAttributeBoostClear, and look at the
-- attributes of a character, hidden ones included, with CharAttributes, which opens a
-- window that lists them. `IsAttributeVisible` hides an attribute from the character
-- sheet.
--
-- Every level of a stat changes something in play by the share its config sets, and a
-- level below zero changes it the other way:
-- * perception: the range at which in-character speech is heard
--   (`stats_perception_hearing`, 1.5 meters);
-- * endurance: slower stamina drain and faster stamina regeneration
--   (`stats_endurance_stamina`, 10%), faster health regeneration and recovery of hurt limbs
--   (`stats_endurance_recovery`, 10%);
-- * strength: heavier objects can be picked up and are thrown harder
--   (`stats_strength_lifting`, 10%);
-- * reflexes: less fall damage (`stats_reflexes_fall`, 10%);
-- * charisma: lower prices when buying from vendors (`stats_charisma_prices`, 5%);
-- * determination: weaker slowdown and aim drift from hurt limbs
--   (`stats_determination_pain`, 10%).
--
-- Intelligence changes nothing in play by itself; it is the key stat of medicine, crafting,
-- technology and lore. The effects run through the hooks of the Chatbox, Stamina, Pickup
-- Objects, Damage, Limb Damage and Vendors plugins, so an effect whose plugin is not loaded
-- simply does nothing. Each stat lists its effects in the `effects` field of its definition, which the
-- creation stage and the staff attribute viewer show.
--
-- The plugin also adds twenty skills, each tied to a key stat by its `attribute` field and
-- ranked from untrained (0) through trained, expert and master to legendary (4):
-- * strength: athletics, close combat;
-- * reflexes: acrobatics, stealth, larceny, marksmanship;
-- * endurance: survival, fortitude;
-- * perception: observation, scavenging;
-- * intelligence: medicine, crafting, technology, lore;
-- * charisma: persuasion, deception, intimidation, streetwise;
-- * determination: composure, focus.
-- A roll of a skill adds the level of its key stat and the proficiency of the character:
-- nothing while the skill is untrained, else its rank times the `stats_rank_bonus` config
-- (2) plus the level of the character. `Player:roll_attribute` and `Player:roll_skill` roll
-- them with the `Dice` library after the `AdjustAttributeRoll` hook, and a client asks the
-- server to roll one and show the result in the chat with the 'fl_stats_roll' message.
--
-- The character sheet (`fl_character_sheet`, the 'character_sheet' Lumen template) is the
-- first and default page of the tab menu while the local player has a character. It shows
-- the name and the faction of the character, its level with the experience toward the next
-- one, its health and its unspent skill and attribute points, then every visible stat with
-- its level name and modifier and every visible skill under its key stat with its rank, its
-- total modifier and the parts that make it up. Each of them has a button that rolls it
-- through the 'fl_stats_roll' message, and while points are left a button that spends one on
-- it through the Levels plugin. The sheet follows changes that arrive from the server while
-- it is open.
-- @module [Stats]

PLUGIN:set_global('Stats')

Stats.faction_boost_id = 'faction'
Stats.roll_interval = 1
Stats.min_hearing_radius = 1

require_relative 'sh_hooks'
require_relative 'cl_hooks'
require_relative 'sv_hooks'

--- Returns the highest level a new character can pick for a stat: its `creation_max`
-- field, or its `max` if it has none, never above `max`.
-- @param attribute_table [AttributeBase definition of the stat]
-- @return [Number]
function Stats:get_creation_max(attribute_table)
  local creation_max = tonumber(attribute_table.creation_max)

  if !creation_max then
    return attribute_table.max
  end

  return math.min(creation_max, attribute_table.max)
end

--- Returns the points a new character has to spread over its stats: the
-- `stats_creation_points` config, never more than the stats can take at creation. The
-- levels a player picks have to add up to this number.
-- @return [Number attribute points]
-- @see [Stats:get_creation_max]
function Stats:default_attribute_points()
  local key = 'stats_creation_points'
  local points = tonumber(Config.get(key)) or tonumber(Config.get_default(key)) or 0
  local highest = 0

  for k, v in pairs(Attributes.get_by_type(ATTRIBUTE_STAT)) do
    highest = highest + self:get_creation_max(v)
  end

  return math.min(math.floor(points), highest)
end

--- Checks whether characters get the stat bonuses of their faction.
-- @return [Boolean the `stats_faction_bonuses` config; true while it has no value]
function Stats:faction_bonuses_enabled()
  return Config.get('stats_faction_bonuses') != false
end

--- Returns the stat bonuses that a faction lists in its `stats` field. Entries that do not
-- name a registered stat or do not hold a number other than zero are left out.
-- ```
-- -- factions/sh_cca.lua
-- FACTION.stats = {
--   ['strength'] = 1,
--   ['endurance'] = 1
-- }
-- ```
-- @param faction_table [Faction faction to read the bonuses of; anything else has none]
-- @return [Map bonus levels keyed by stat ID]
function Stats:get_faction_bonuses(faction_table)
  local bonuses = {}

  if !istable(faction_table) or !istable(faction_table.stats) then
    return bonuses
  end

  local stats = Attributes.get_by_type(ATTRIBUTE_STAT)

  for k, v in pairs(faction_table.stats) do
    local bonus = tonumber(v)

    if stats[k] and bonus and bonus == bonus and bonus != 0 then
      bonuses[k] = bonus
    end
  end

  return bonuses
end

--- Returns the bonus that the faction of a player currently adds to one of their stats:
-- the value of the boost that carries the `Stats.faction_boost_id` identifier.
-- @param target [Player]
-- @param attribute_id [String ID of the stat]
-- @return [Number bonus levels, or nil if the stat has no faction bonus]
function Stats:get_faction_boost(target, attribute_id)
  for k, v in ipairs(target:get_attribute_boosts(attribute_id)) do
    if v.id == self.faction_boost_id then
      return tonumber(v.value)
    end
  end
end

--- Registers the 'attribute' condition, which compares a player's attribute level to a value.
function Stats:RegisterConditions()
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
