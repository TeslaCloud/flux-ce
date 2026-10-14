--- Server side of the Radios plugin: finds the radios a player can use, sends what a player
-- says over the radio to the players who should receive it, and retunes radios.

Config.set('radio_chat_color', Color(100, 228, 100))

--- Returns the enabled radios a player has in their hotbar. A player who has no character
-- loaded has no inventories and therefore no radios.
-- @param owner [Player player to check]
-- @return [List<Item> enabled radios, empty if there are none]
function Communications.get_radios(owner)
  local radios = {}

  if !IsValid(owner) or !owner:IsPlayer() then return radios end

  local hotbar = owner:get_inventories().hotbar

  if !hotbar then return radios end

  local items = hotbar:get_items()

  for i = 1, #items do
    local item_obj = items[i]

    if item_obj:is('radio') and item_obj:is_enabled() then
      radios[#radios + 1] = item_obj
    end
  end

  return radios
end

--- Returns the first enabled radio in a player's hotbar.
-- @param owner [Player player to check]
-- @return [Item enabled radio, nil if there is none]
function Communications.get_active_radio(owner)
  return Communications.get_radios(owner)[1]
end

--- Checks whether a player has an enabled radio tuned to a frequency in their hotbar.
-- @param owner [Player player to check]
-- @param frequency [Number frequency to look for]
-- @return [Boolean]
function Communications.is_tuned_to(owner, frequency)
  local radios = Communications.get_radios(owner)

  for i = 1, #radios do
    if radios[i]:get_frequency() == frequency then
      return true
    end
  end

  return false
end

--- Checks whether a player may speak on the radio, by asking the PlayerCanRadio hook.
-- @param actor [Player player about to speak]
-- @param text [String message, without the radio prefix]
-- @param item_obj [Item the radio the player speaks into]
-- @return [Boolean false if a plugin has forbidden it, String phrase or text that says why,
--   if the plugin has given one]
function Communications.can_radio(actor, text, item_obj)
  --- Asks whether a player may speak on the radio. Called on the server when a player
  -- sends a chat message with a radio prefix and has an enabled radio in their hotbar,
  -- before anything is sent.
  -- @param actor [Player the player about to speak]
  -- @param text [String the message, without the radio prefix]
  -- @param item_obj [Item the radio the player speaks into; `item_obj:get_frequency()`
  --   is the frequency of the transmission]
  -- @return [Boolean return false to keep the player from speaking on the radio,
  --   String optional phrase or text to notify the player with]
  local allowed, reason = hook.Run('PlayerCanRadio', actor, text, item_obj)

  if allowed == false then
    return false, reason
  end

  return true
end

--- Makes a player say a text over the radio in their hotbar. The player is notified if
-- they have no enabled radio there, or if the PlayerCanRadio hook forbids them to speak
-- and says why. Nothing happens if there is nothing in the text but spaces.
-- @param actor [Player player who speaks]
-- @param text [String message, without the radio prefix]
-- @return [Boolean true if the message has been sent]
-- @see [Communications.speak_radio]
function Communications.say_radio(actor, text)
  if !IsValid(actor) or !actor:IsPlayer() or !isstring(text) then return false end

  text = text:strip()

  if text == '' then return false end

  local item_obj = Communications.get_active_radio(actor)

  if !item_obj then
    actor:notify('notification.no_active_radio')

    return false
  end

  local allowed, reason = Communications.can_radio(actor, text, item_obj)

  if !allowed then
    if isstring(reason) then
      actor:notify(reason)
    end

    return false
  end

  return Communications.speak_radio(actor, text, item_obj:get_frequency(), item_obj)
end

--- Sends a radio message on a frequency. It is received anywhere by the speaker and by
-- the players with an enabled radio tuned to the frequency in their hotbar, and overheard
-- by the players near the speaker. The PlayerAdjustRadioInfo hook can change who receives
-- it, and the PlayerRadioUsed hook is run once it has been sent. The PlayerCanRadio hook
-- is not asked here, see `Communications.say_radio` for that.
-- @param speaker [Player player talking]
-- @param text [String message]
-- @param frequency [Number frequency to talk on]
-- @param item_obj=nil [Item the radio the player speaks into, passed on to the hooks]
-- @return [Boolean true if the message has been sent, false if there was nothing to say,
--   the frequency is not a number or a plugin has cancelled the message]
function Communications.speak_radio(speaker, text, frequency, item_obj)
  if !IsValid(speaker) or !speaker:IsPlayer() then return false end
  if !isstring(text) or !isnumber(frequency) then return false end

  local default_radius = Config.get('talk_radius') * 0.5
  local info = {
    text = text:strip(),
    frequency = frequency,
    item = item_obj,
    listeners = {},
    eavesdrop = true,
    radius = default_radius
  }

  if info.text == '' then return false end

  local tuned_in = info.listeners
  local is_tuned_to = Communications.is_tuned_to

  for k, v in player.Iterator() do
    if v == speaker or is_tuned_to(v, frequency) then
      tuned_in[#tuned_in + 1] = v
    end
  end

  --- Lets plugins change a radio transmission before it is sent: what is said and who
  -- receives it. Called on the server by `Communications.speak_radio`.
  -- @param speaker [Player the player talking on the radio]
  -- @param info [Map the transmission, to be modified in place: text (String what is
  --   said), frequency (Number, changing it does not change the listeners), item (Item the
  --   radio spoken into, or nil), listeners (List<Player> who receives the message over the
  --   radio wherever they are: at first the speaker and everyone with an enabled radio on
  --   the frequency in their hotbar; add or remove players to change that), eavesdrop
  --   (Boolean whether the players near the speaker overhear the message, true at first)
  --   and radius (Number how near they have to be, in units, before other plugins adjust it
  --   for each of them; 0 or less means that nobody overhears). A player who has been
  --   removed from the listeners still overhears the message when they are near the speaker,
  --   and the speaker always receives it]
  hook.Run('PlayerAdjustRadioInfo', speaker, info)

  if !isstring(info.text) or info.text == '' then return false end

  local transmission_listeners = { [speaker] = true }
  local transmission = {
    speaker = speaker,
    listeners = transmission_listeners
  }

  if istable(info.listeners) then
    for k, v in pairs(info.listeners) do
      if IsValid(v) and v:IsPlayer() then
        transmission_listeners[v] = true
      end
    end
  end

  local radius = tonumber(info.radius) or default_radius
  local targets

  if info.eavesdrop == false or radius <= 0 then
    targets = table.GetKeys(transmission_listeners)
    radius = -1
  end

  local message = {
    Config.get('radio_chat_color'),
    Config.get('default_font_size'),
    speaker, ' ', t'ui.chat.radio', ': "', info.text:spelling(), '"',
    {
      sender = speaker,
      position = speaker:EyePos(),
      radius = radius,
      ic = true,
      frequency = isnumber(info.frequency) and info.frequency or frequency
    }
  }

  local previous = Communications.transmission

  Communications.transmission = transmission

  Chatbox.add_text(targets, unpack(message))

  Communications.transmission = previous

  if !transmission.receivers then return false end

  local receivers = transmission.receivers
  local over_radio = transmission.listeners
  local listeners, eavesdroppers = {}, {}

  for i = 1, #receivers do
    local receiver = receivers[i]
    local group = over_radio[receiver] and listeners or eavesdroppers

    group[#group + 1] = receiver
  end

  Log:print(Chatbox.message_to_string(message), 'player_ic')

  --- Called on the server after a radio message has been sent. Not called for a message
  -- that the ChatboxShouldSendMessage hook has cancelled.
  -- @param speaker [Player the player who talked on the radio]
  -- @param info [Map the transmission as it was sent: text (String), frequency (Number)
  --   and item (Item the radio spoken into, or nil)]
  -- @param listeners [List<Player> the players who received the message over the radio,
  --   the speaker among them]
  -- @param eavesdroppers [List<Player> the players who overheard the message because they
  --   were near the speaker]
  hook.Run('PlayerRadioUsed', speaker, info, listeners, eavesdroppers)

  return true
end

--- Checks whether a player may retune a radio right now: it has to be a radio that still
-- exists and is turned on, and the player has to have it at hand, which means that it is in
-- one of their inventories or, if it lies in the world, within their reach.
--
-- The `PlayerCanUseItem` hook is not asked here. The item menu has asked it by the time
-- the frequency button reaches the radio, and asking it again when the answer to the
-- frequency prompt arrives would refuse players for what pressing the button has done,
-- such as spending their last move turn in combat. This check only makes sure that the
-- radio has not left the player in the meantime.
-- @param actor [Player player who retunes the radio]
-- @param item_obj [Item the radio]
-- @return [Boolean]
function Communications.can_tune(actor, item_obj)
  if !IsValid(actor) or !actor:IsPlayer() then return false end
  if !istable(item_obj) or !isfunction(item_obj.is) or !item_obj:is('radio') then return false end
  if Item.find_instance_by_id(item_obj.instance_id) != item_obj then return false end
  if !item_obj:is_enabled() then return false end

  local item_entity = item_obj.entity

  if IsValid(item_entity) then
    return Inventories.is_in_reach(actor, item_entity)
  end

  return actor:has_item_by_id(item_obj.instance_id) == true
end

--- Tunes a radio to the frequency a player has entered, if the text is a valid frequency
-- and the player may retune the radio. The player is notified of the outcome.
-- @param actor [Player player who retunes the radio]
-- @param item_obj [Item the radio]
-- @param value [String the frequency as the player typed it, such as '100.1']
-- @return [Boolean true if the radio has been retuned]
-- @see [Communications.parse_frequency]
function Communications.tune_radio(actor, item_obj, value)
  if !Communications.can_tune(actor, item_obj) then
    if IsValid(actor) then
      actor:notify('error.radio.unavailable')
    end

    return false
  end

  local frequency = Communications.parse_frequency(value)

  if !frequency then
    actor:notify('error.frequency')

    return false
  end

  item_obj:set_frequency(frequency)

  actor:notify('notification.radio.frequency_set', { frequency = Communications.format_frequency(frequency) })

  return true
end

--- Asks a player for the new frequency of a radio and retunes the radio to the answer.
-- A prompt that the player has not answered yet is closed when a new one is opened.
-- @param actor [Player player to ask]
-- @param item_obj [Item the radio]
-- @return [Boolean true if the player has been asked]
function Communications.request_frequency(actor, item_obj)
  if !Communications.can_tune(actor, item_obj) then return false end

  if actor.fl_radio_prompt then
    Flux.Prompt:cancel(actor.fl_radio_prompt)
  end

  local instance_id = item_obj.instance_id
  local options = { default = Communications.format_frequency(item_obj:get_frequency()), max_length = 16 }
  local prompt_id

  prompt_id = actor:request_string('ui.radio.frequency', 'ui.radio.frequency_message', function(target, answer)
    if !IsValid(target) then return end

    if target.fl_radio_prompt == prompt_id then
      target.fl_radio_prompt = nil
    end

    if !answer then return end

    Communications.tune_radio(target, Item.find_instance_by_id(instance_id), answer)
  end, options)

  actor.fl_radio_prompt = prompt_id

  return prompt_id != nil
end
