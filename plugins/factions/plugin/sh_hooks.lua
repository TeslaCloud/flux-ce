--- Shared hooks of the Factions plugin: random character names from the lists of a faction.

--- Picks a random name from the random_names lists of the faction of the character.
-- @param _actor [Player the player the name is for]
-- @param faction_id [String ID of the faction of the character, nil without one]
-- @param gender [Number CHAR_GENDER_* value of the character]
-- @return [String the name, nil when the faction has no lists for the gender]
function Factions:GetRandomCharacterName(_actor, faction_id, gender)
  return Factions.find_by_id(faction_id)?.:get_random_name(gender)
end
