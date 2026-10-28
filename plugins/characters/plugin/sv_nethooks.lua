--- Server-side network handlers of the Characters plugin, behind the character menus:
-- creating, loading and deleting characters and changing the physical description. A request
-- of a player to load or delete a character is checked first with `Characters.can_use` and
-- `Characters.can_delete`, and a refused request is answered with a reason that the menu
-- shows.

local request_delay = 1

--- Checks whether the player has sent a character request less than a second ago, and
-- starts the wait for the next one when they have not.
-- @param actor [Player]
-- @return [Boolean true when the request has to be refused]
local function is_throttled(actor)
  local cur_time = CurTime()

  if actor.next_character_request and actor.next_character_request > cur_time then
    return true
  end

  actor.next_character_request = cur_time + request_delay

  return false
end

local function refuse_request(actor, action, reason, arguments)
  Cable.send(actor, 'fl_character_request_failed', action, reason, arguments)
end

MVC.handler('fl_create_character', function(actor, data)
  if !istable(data) then
    respond_to { success = false, status = CHAR_ERR_UNKNOWN }

    return
  end

  local cur_time = CurTime()

  if actor.next_character_creation and actor.next_character_creation > cur_time then
    respond_to { success = false, status = CHAR_ERR_UNKNOWN }

    return
  end

  if isstring(data.name) then
    data.name = string.Trim((data.name:gsub('%c', ' '):gsub('%s+', ' ')))
  end

  if isstring(data.description) then
    data.description = string.Trim((data.description:gsub('\r', ''):gsub('[%z\1-\9\11-\31\127]', ' ')))
  end

  local requested_name = data.name
  local requested_description = data.description

  --- Called on the server when the request of a client to create a character arrives, before
  -- the data is converted and passed to `Characters.create`. Handlers can fill in or change
  -- the data in place. A name that a handler has replaced counts as generated and may
  -- repeat the name of another character; a description that a handler has replaced
  -- counts as generated and may be of any length.
  -- @param actor [Player the player who sent the request]
  -- @param data [Map data collected by the creation menu: name, description, gender ('male',
  --   'female' or 'universal'), model, skin and the fields that other stages add]
  hook.Run('PreCreateCharacter', actor, data)

  data.name_generated = data.name != requested_name
  data.description_generated = data.description != requested_description
  data.gender = (data.gender == 'female' and CHAR_GENDER_FEMALE) or
    (data.gender == 'universal' and CHAR_GENDER_NONE) or CHAR_GENDER_MALE
  data.phys_desc = data.description

  local status = Characters.create(actor, data)

  Flux.dev_print('Creating character. Status: '..status)

  if status == CHAR_SUCCESS then
    actor.next_character_creation = cur_time + request_delay

    respond_to { success = true, status = status }

    Flux.dev_print('Success')
  else
    respond_to { success = false, status = status }

    Flux.dev_print('Error')
  end
end)

Cable.receive('fl_player_delete_character', function(actor, id)
  if !isnumber(id) or !istable(actor.record) then return end

  if is_throttled(actor) then
    refuse_request(actor, 'delete', 'error.wait')

    return
  end

  local character = actor:get_character_by_id(id)
  local allowed, reason, arguments = Characters.can_delete(actor, character)

  if !allowed then
    refuse_request(actor, 'delete', reason, arguments)

    return
  end

  Flux.dev_print(actor:name()..' has deleted character #'..id)

  --- Called on the server when a player has asked to delete one of their characters, right
  -- before it is deleted. The request has passed `Characters.can_delete` by then.
  -- @param actor [Player]
  -- @param id [Number ID of the character]
  -- @param character [Character the character that is about to be deleted]
  hook.Run('OnCharacterDelete', actor, id, character)

  Characters.delete(actor, id)
end)

Cable.receive('fl_player_select_character', function(actor, id)
  if !isnumber(id) or !istable(actor.record) then return end

  if is_throttled(actor) then
    refuse_request(actor, 'select', 'error.wait')

    return
  end

  local allowed, reason, arguments = Characters.can_use(actor, actor:get_character_by_id(id))

  if !allowed then
    refuse_request(actor, 'select', reason, arguments)

    return
  end

  Flux.dev_print(actor:name()..' has loaded character #'..id)

  actor:set_active_character(id)
end)

Cable.receive('fl_character_physdesc', function(actor, text)
  Characters.change_desc(actor, text)
end)
