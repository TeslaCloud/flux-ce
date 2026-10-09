--- Server side of the Attributes plugin: gives characters their attribute records, networks
-- a character's attributes when it becomes active, and removes its boosts and multipliers
-- as they expire. The 'fl_attributes_view' message, which the CharAttributes command sends
-- to show a character's attributes to a member of staff, is registered here.

Cable.check_networked_string('fl_attributes_view')

--- Adds an Attribute record for every registered attribute to a new character, using the
-- level chosen during creation or the attribute's default. A chosen level is rounded down
-- and kept between the attribute's min and max, as the creation data comes from the client.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data; levels are read from its attributes field]
function AttributesPlugin:PostCreateCharacter(owner, char, char_data)
  Attributes.create_records(char, char_data.attributes)
end

--- Prepares the attributes of the character that has become active: adds records for the
-- attributes that were registered after the character was created, removes the boosts and
-- multipliers that have expired or whose expiry time cannot be read, and networks the
-- attributes to the players.
-- @param owner [Player]
-- @param char [Character]
function AttributesPlugin:OnActiveCharacterSet(owner, char)
  Attributes.create_records(char)
  Attributes.remove_expired(owner)
  Attributes.sync(owner)
end

--- Removes the boosts and multipliers that have expired from the characters of the players
-- who have one due, and networks their attributes again so that the clients stop counting
-- them when the server does.
function AttributesPlugin:OneSecond()
  local unix_time = os.time()

  for k, v in player.Iterator() do
    local expiry = v.attribute_expiry

    if expiry and expiry <= unix_time then
      Attributes.remove_expired(v)
      Attributes.sync(v)
    end
  end
end
