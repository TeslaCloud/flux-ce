--- Server side of the Classes plugin: validates and stores the class of new characters,
-- restores the class when a character is loaded, resets it when the faction changes, applies
-- the model and the loadout of the class, and pays wages on a timer.

--- Rejects character creation when the creation data names a class that is not registered
-- or does not belong to the chosen faction. Data without a class is accepted: the character
-- then gets the default class of its faction.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_CLASS when the data is rejected, otherwise nil]
function Classes:PlayerCreateCharacter(actor, data)
  if data.char_class == nil or data.char_class == '' then return end

  local class_table = isstring(data.char_class) and self.find_by_id(data.char_class)

  if !class_table or class_table.faction != data.faction then
    return CHAR_ERR_CLASS
  end
end

--- Stores the class of the new character: the one from the creation data, which the
-- Factions plugin has copied to the character, or else the default class of its faction.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Classes:PostCreateCharacter(owner, char, char_data)
  local class_table = self.get_character_class(char)

  char.char_class = class_table and class_table.class_id or ''
end

--- Restores the class of the newly active character: gives a character without a valid
-- class the default class of its faction, networks the class and applies its model. The
-- class is stored on the character, so it is saved with it.
-- @param owner [Player]
-- @param char [Character]
function Classes:OnActiveCharacterSet(owner, char)
  local class_table = self.get_character_class(char)

  owner:set_character_var('char_class', class_table and class_table.class_id or '')

  self.apply_model(owner)
end

--- Moves a player whose faction has changed into the default class of the new faction, or
-- takes their class away when that faction has none.
-- @param target [Player]
-- @param faction_table [Faction the faction the player is in now]
-- @param old_faction [Faction the faction the player was in before, nil if that was not a
--   registered faction]
function Classes:OnPlayerFactionChanged(target, faction_table, old_faction)
  if !target:is_character_loaded() then return end

  local char = target:get_character()
  local old_class = isstring(char.char_class) and self.find_by_id(char.char_class) or nil

  if old_faction and (!old_class or old_class.faction != old_faction.faction_id) then
    old_class = self.get_default(old_faction.faction_id)
  end

  target:reset_class(old_class)
end

--- Keeps the model of the class on a player whose character model has been changed.
-- @param owner [Player]
-- @param char [Character the active character, nil if the player has none]
-- @param model [String the new model of the character]
-- @param old_model [String the model that was networked before the change]
function Classes:CharacterModelChanged(owner, char, model, old_model)
  self.apply_model(owner)
end

--- Makes a spawning player use the model of their class, if the class has one.
-- @param actor [Player]
-- @return [String model path of the class, nil to leave the choice of the model to others]
function Classes:PrePlayerSetModel(actor)
  local class_table = actor:get_class()

  if class_table then
    return class_table:get_model(actor)
  end
end

--- Gives a spawning player the weapons of their class on top of the default loadout. This
-- is done on the next tick, because the gamemode strips the weapons of the player and gives
-- the default loadout after the plugin handlers of this hook have run. The record of the
-- weapons the class gave before is dropped, as none of them is left after that.
-- @param actor [Player]
-- @param default_loadout [List<String> weapon classes of the default loadout]
function Classes:PostPlayerLoadout(actor, default_loadout)
  actor.class_weapons = nil

  timer.Simple(0, function()
    if IsValid(actor) and actor:Alive() then
      self.give_loadout(actor)
    end
  end)
end

--- Pays the wages once the wages_interval config has passed since the last payment, or
-- since the interval was turned on. An interval of 0 turns the wages off.
function Classes:OneSecond()
  local interval = tonumber(Config.get('wages_interval')) or 0

  if interval <= 0 then
    self.next_wages = nil

    return
  end

  local cur_time = CurTime()

  if !self.next_wages or self.next_wages > cur_time + interval then
    self.next_wages = cur_time + interval
  elseif cur_time >= self.next_wages then
    self.next_wages = cur_time + interval

    self.distribute_wages()
  end
end
