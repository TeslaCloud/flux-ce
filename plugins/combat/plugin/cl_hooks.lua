--- Client hooks of the turn based combat: the reach of the moves of the local player, the
-- turns they have left, and keeping their frozen weapon from firing and reloading.

local trace_offset = Vector(0, 0, -100)
local circle_offset = Vector(0, 0, 5)
local circle_angle = Angle(90, 0, 0)
local hud_color = Color('aqua'):alpha(200)
local hud_outline_color = color_black:alpha(200)
local draw_text_outlined = draw.SimpleTextOutlined
local text_size = util.text_size
const empty_turns = {}

--- Draws circles around the local player's turn start position showing how far they can walk and run this turn.
-- @param depth [Boolean whether the depth pass is being drawn]
-- @param skybox [Boolean whether the skybox is being drawn]
function CombatSystem:PostDrawTranslucentRenderables(depth, skybox)
  if depth or skybox then return end

  local client = PLAYER
  local pos = client.walk_pos

  if pos then
    local turns = client:get_turns(TURN_MOVE)
    local walk_speed, run_speed = client:GetWalkSpeed() * turns, client:GetRunSpeed() * turns
    local trace = util.TraceLine({
      start = pos,
      endpos = pos + trace_offset,
      filter = client
    })

    cam.Start3D2D(pos + circle_offset, trace.HitNormal:Angle() + circle_angle, 1)
      surface.SetDrawColor(35, 210, 250)
      surface.draw_circle_outline(0, 0, walk_speed, 3, 50)

      if run_speed > walk_speed then
        surface.SetDrawColor(255, 220, 75)
        surface.draw_circle_outline(0, 0, run_speed, 3, 50)
      end
    cam.End3D2D()
  end
end

--- Prevents the local player from attacking while their weapon is frozen.
-- @return [Boolean false if the weapon is frozen, nil otherwise]
function CombatSystem:PlayerCanAttack()
  local weapon = PLAYER:GetActiveWeapon()

  if IsValid(weapon) and weapon:is_frozen() then
    return false
  end
end

--- Strips the reload key from the command while the local player's weapon is frozen.
-- @param _actor [Player player the command belongs to]
-- @param user_cmd [CUserCmd command being processed]
function CombatSystem:StartCommand(_actor, user_cmd)
  local weapon = PLAYER:GetActiveWeapon()

  if IsValid(weapon) and weapon:is_frozen() then
    user_cmd:RemoveKey(IN_RELOAD)
  end
end

--- Draws the remaining attack and move turns, the turn timer and the skip hint during the local player's turn.
function CombatSystem:HUDPaint()
  local client = PLAYER

  if client:in_combat() and !client:is_frozen() then
    local turns = client:get_nv('fl_combat_turns', empty_turns)
    local scrw, scrh = ScrC()
    local x, y = scrw, scrh
    local gx, gy = Flux.global_ui_offset()
    local icon_size = 32
    local icon_w, icon_h = FontAwesome:get_icon_size('fa-crosshairs', icon_size)
    local text_offset = math.scale(4)

    x, y = x + gx, y + gy

    local icon_x, icon_y = x - icon_w * 8, y + icon_h * 6
    local icon_x_right = icon_x + icon_w * 15

    FontAwesome:draw('fa-crosshairs', icon_x, icon_y, icon_size, hud_color, nil, nil, 1, hud_outline_color)
    FontAwesome:draw('fa-shoe-prints', icon_x_right, icon_y, icon_size, hud_color, nil, nil, 1, hud_outline_color)

    local text = turns[TURN_ATTACK]
    local font = Theme.get_font('menu_large')
    local text_w, text_h = text_size(text, font)

    draw_text_outlined(
      text,
      font,
      icon_x + text_w * 0.5,
      icon_y + text_h + text_offset,
      hud_color,
      nil,
      nil,
      1,
      hud_outline_color
    )

    text = turns[TURN_MOVE]
    text_w, text_h = text_size(text, font)

    draw_text_outlined(
      text,
      font,
      icon_x_right + text_w * 0.5,
      icon_y + text_h + text_offset,
      hud_color,
      nil,
      nil,
      1,
      hud_outline_color
    )

    local cur_time = CurTime()
    local turn_end = client.turn_end

    if turn_end and turn_end > cur_time then
      text = math.round(turn_end - cur_time, 1)
      text_w, text_h = text_size(text, font)
      draw_text_outlined(
        text,
        font,
        gx + scrw - text_w * 0.5,
        icon_y + text_h + text_offset,
        hud_color,
        nil,
        nil,
        1,
        hud_outline_color
      )
    end

    font = Theme.get_font('menu_small')
    text = t'ui.combat.skip'
    text_w, text_h = text_size(text, font)
    draw_text_outlined(
      text,
      font,
      gx + scrw - text_w * 0.5,
      icon_y + text_h * 3,
      hud_color,
      nil,
      nil,
      1,
      hud_outline_color
    )
  end
end
