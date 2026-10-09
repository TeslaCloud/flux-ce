--- Client side of the Ragdoll plugin: draws the screen overlay of a fallen or knocked out
-- player and sends the getup command when a fallen player presses jump. The get up timer
-- itself is a timed action called 'getup', whose progress bar is drawn by
-- `Flux.TimedAction`.

local next_getup_request = 0

--- Checks whether the get up timer of the local player is running.
-- @return [Boolean]
local function is_getting_up()
  local action = Flux.TimedAction:get(PLAYER)

  return action != nil and action.id == 'getup'
end

--- Sends the getup command when the player presses jump while fallen over, once a second at
-- most. Nothing is sent while they are knocked out or already getting up.
-- @param client [Player]
-- @param bind [String the bind's command]
-- @param pressed [Boolean whether the bind was pressed rather than released]
function Ragdoll:PlayerBindPress(client, bind, pressed)
  if pressed and bind:find('jump') and client:is_fallen_over() and !is_getting_up() then
    local cur_time = CurTime()

    if cur_time >= next_getup_request then
      next_getup_request = cur_time + 1

      Flux.Command:send('getup')
    end
  end
end

--- Darkens the screen while the local player is fallen over and blacks it out while they
-- are knocked out, and tells them what they can do about it: the 'press jump' prompt for a
-- fallen player who is not getting up yet, a notice for a knocked out one.
function Ragdoll:HUDPaint()
  if !IsValid(PLAYER) or !PLAYER:Alive() then return end

  local knocked_out = PLAYER:is_knocked_out()

  if !knocked_out and !PLAYER:is_fallen_over() then return end

  --- Asks whether the overlay of a fallen player should be drawn: the darkened screen with
  -- the 'press jump' prompt, or the blacked out screen of a knocked out player.
  -- Called on the client on every HUD paint while the local player is fallen over or
  -- knocked out. The get up progress bar is a timed action and is not affected.
  -- @return [Boolean Return false to hide the overlay]
  if Plugin.call('ShouldFallenHUDPaint') == false then return end

  local scrw, scrh = ScrW(), ScrH()
  local getting_up = is_getting_up()
  local text = nil

  draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0, knocked_out and 255 or 100))

  if knocked_out then
    text = t'ui.hud.knocked_out'
  elseif !getting_up then
    text = t'ui.hud.press_jump_to_getup'
  end

  if text then
    local text_font = Theme.get_font('text_normal')
    local w, h = util.text_size(text, text_font)
    local y = scrh * 0.5 - h * 0.5

    if getting_up then
      y = y - h - 24
    end

    draw.SimpleText(text, text_font, scrw * 0.5 - w * 0.5, y, Theme.get_color('text'))
  end
end
