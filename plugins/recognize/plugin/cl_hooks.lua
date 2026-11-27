--- Client-side hooks of the Recognize plugin: opens the recognize menu, shows strangers as
-- strangers on the target ID, in chat and on the scoreboard, and adds the options to
-- introduce yourself to a player and to forget them to the player menus. A player whose
-- character has a display name is shown under it everywhere, recognized or not.

--- Opens the recognize menu when the show team key is pressed, unless the recognition
-- system is off.
-- @param _client [Player local player]
-- @param bind [String bind that was pressed]
-- @param _pressed [Boolean whether the key was pressed or released]
function Recognition:PlayerBindPress(_client, bind, _pressed)
  if bind:find('gm_showteam') and self:is_enabled() then
    local recognize_menu = vgui.Create('fl_recognize')
    recognize_menu:MakePopup()
    recognize_menu:SetPos(ScrW() * 0.5 - recognize_menu:GetWide() * 0.5, ScrH() * 0.6)
  end
end

--- Replaces the name above players the local player does not recognize with a stranger label,
-- unless their character has a display name.
-- @param target [Player player whose info is drawn]
-- @param _x [Number x position of the info]
-- @param _y [Number y position of the info]
-- @param _distance [Number distance to the player]
-- @param lines [Table info lines to draw, keyed by line ID]
function Recognition:PreDrawPlayerInfo(target, _x, _y, _distance, lines)
  if lines['name'] and !target:get_display_name() and !PLAYER:recognizes(target) then
    lines['name'].text = target:get_gender() == 'female' and t'ui.hud.stranger_female' or t'ui.hud.stranger_male'
  end
end

--- Returns the name the local player knows a player by, or the start of their physical
-- description, when it is not the real name of the player. Returns nothing for a real name,
-- for a player whose character has a display name, which is shown to everyone instead (see
-- `Characters.refresh_display_name`), and while the recognition system is off, which leaves
-- the name to other handlers.
-- @param target [Player player to get the name of]
-- @return [String displayed name, nil when it is the real name]
function Recognition:GetPlayerName(target)
  if !IsValid(PLAYER) or !IsValid(target) or !self:is_enabled() or target:get_display_name() then return end

  local name = self:get_known_name(PLAYER, target)

  if name != target:name(true) then
    return name
  end
end

--- Shows real names in out of character messages, and the display name of a player whose
-- character has one.
-- @param target [Player player whose name is processed]
-- @param message_data [Table chat message data]
-- @return [Boolean false for non-IC messages of players without a display name, nil
--   otherwise]
function Recognition:ShouldProcessChatPlayerName(target, message_data)
  if !message_data.ic and !target:get_display_name() then
    return false
  end
end

--- Hides the character card of players the local player does not recognize, unless their
-- character has a display name.
-- @param _card [Panel character card]
-- @param target [Player player the card belongs to]
-- @return [Boolean false if the player is not recognized, nil otherwise]
function Recognition:ShouldShowCharacterCard(_card, target)
  if !target:get_display_name() and !PLAYER:recognizes(target) then
    return false
  end
end

--- Adds a recognize submenu to introduce yourself to a player by real name, a new fake name or a recent one,
-- and to forget the player if the character of the local player has them stored. Nothing
-- is added while the recognition system is off.
-- @param options [List<Map> options of the interaction menu, changed in place]
-- @param target [Player player the menu was opened for]
function Recognition:AdjustPlayerInteractions(options, target)
  if !self:is_enabled() then return end

  local history = self:get_name_history()
  local fake_name_options = {
    {
      id = 'enter_fake_name',
      text = t'ui.recognize.enter_fake_name',
      callback = function()
        Derma_StringRequest(t'ui.recognize.enter_fake_name', t'ui.recognize.message', PLAYER:name(), function(text)
          surface.PlaySound('buttons/blip1.wav')

          if text and text != '' then
            Cable.send('fl_recognize', 'target', text, target)

            self:remember_false_name(text)
          end
        end)
      end
    }
  }

  for index, name in pairs(history) do
    fake_name_options[#fake_name_options + 1] = {
      id = 'recent_name_'..index,
      text = name,
      callback = function()
        Cable.send('fl_recognize', 'target', name, target)
      end
    }
  end

  local recognize_options = {
    {
      id = 'character_name',
      text = t'ui.recognize.character_name',
      icon = 'icon16/emoticon_grin.png',
      callback = function()
        surface.PlaySound('buttons/blip1.wav')

        Cable.send('fl_recognize', 'target', false, target)
      end
    },
    {
      id = 'fake_name',
      text = t'ui.recognize.fake_name',
      icon = 'icon16/emoticon_evilgrin.png',
      options = fake_name_options
    }
  }

  if PLAYER:get_recognize(target) then
    recognize_options[#recognize_options + 1] = {
      id = 'forget',
      text = t'ui.recognize.forget',
      icon = 'icon16/user_delete.png',
      callback = function()
        surface.PlaySound('buttons/blip1.wav')

        if IsValid(target) then
          Cable.send('fl_recognize_forget', target)
        end
      end
    }
  end

  options[#options + 1] = {
    id = 'recognize',
    text = t'ui.recognize.title',
    icon = 'icon16/user_comment.png',
    options = recognize_options
  }
end

--- Adds the option to forget a player to the menu of their scoreboard card, if the
-- character of the local player has them stored.
-- @param options [List<Map> options of the card's menu, changed in place]
-- @param target [Player the player the card shows]
-- @param _card [Panel the fl_scoreboard_player card that was clicked]
function Recognition:AdjustScoreboardPlayerMenu(options, target, _card)
  if !self:is_enabled() or target == PLAYER or !PLAYER:get_recognize(target) then return end

  options[#options + 1] = {
    id = 'forget',
    text = t'ui.recognize.forget',
    icon = 'icon16/user_delete.png',
    callback = function()
      if IsValid(target) then
        Cable.send('fl_recognize_forget', target)
      end
    end
  }
end

--- Moves players the local player does not recognize out of their faction into a players
-- online category; players whose character has a display name stay in their faction.
-- @param players_table [Table lists of players keyed by faction category]
function Recognition:PreRebuildFactionCategories(players_table)
  local client = PLAYER
  local players_online = {}

  for _, group in pairs(players_table) do
    for index, member in pairs(group) do
      if !member:get_display_name() and !client:recognizes(member) then
        players_online[#players_online + 1] = member
        group[index] = nil
      end
    end
  end

  players_table['players_online'] = players_online
end
