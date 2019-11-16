timer.Remove('HintSystem_OpeningMenu')
timer.Remove('HintSystem_Annoy1')
timer.Remove('HintSystem_Annoy2')

-- Called when the client connects and spawns.
function GM:InitPostEntity()
  PLAYER = LocalPlayer()

  Cable.send('fl_player_set_lang', GetConVar('gmod_language'):GetString())

  timer.Simple(0.4, function()
    Cable.send('fl_player_created', true)
    Flux.local_player_created = true
  end)

  for k, v in ipairs(player.all()) do
    local model = v:GetModel()

    hook.run('PlayerModelChanged', v, model, model)
  end

  hook.run('SynchronizeTools')
  hook.run('LoadData')

  Plugin.call('FLInitPostEntity')

  timer.Create('flux_please_dont_screw_up', 0.1, 0, function()
    if !IsValid(PLAYER) then
      PLAYER = LocalPlayer()
    else
      timer.Remove('flux_please_dont_screw_up')
    end
  end)
end

function GM:PlayerInitialized()
  hook.run('PopulateSpawnMenu')
  RunConsoleCommand('spawnmenu_reload')
  hook.run('PopulateToolMenu')
end

function GM:FluxClientSchemaLoaded()
  Font.create_fonts()
end

do
  local scrw, scrh = ScrW(), ScrH()
  local next_check = CurTime()

  -- This will let us detect whether the resolution has been changed, then call a hook if it has.
  function GM:Tick()
    local cur_time = CurTime()

    if cur_time >= next_check then
      local new_w, new_h = ScrW(), ScrH()

      if scrw != new_w or scrh != new_h then
        Flux.print('Resolution changed from '..scrw..'x'..scrh..' to '..new_w..'x'..new_h..'.')

        hook.run('OnResolutionChanged', new_w, new_h, scrw, scrh)

        scrw, scrh = new_w, new_h
      end

      next_check = cur_time + 1
    end
  end
end

-- Remove default death notices.
function GM:DrawDeathNotice()
end

function GM:AddDeathNotice()
end

-- Called when default GWEN skin is required.
function GM:ForceDermaSkin()
  return 'Flux'
end

-- Called when the resolution has been changed and fonts need to be resized to fit the client's res.
function GM:OnResolutionChanged(old_w, old_h, new_w, new_h)
  Font.create_fonts()
end

-- Called when the scoreboard should be shown.
function GM:ScoreboardShow()
  if hook.run('ShouldScoreboardShow') != false then
    if Flux.tab_menu and Flux.tab_menu.close_menu then
      Flux.tab_menu:close_menu()
    end

    Flux.tab_menu = Theme.create_panel('tab_menu', nil, 'fl_tab_menu')
    Flux.tab_menu:MakePopup()
    Flux.tab_menu.held_time = CurTime() + 0.3
  end
end

-- Called when the scoreboard should be hidden.
function GM:ScoreboardHide()
  if hook.run('ShouldScoreboardHide') != false then
    if Flux.tab_menu and Flux.tab_menu.held_time and CurTime() >= Flux.tab_menu.held_time then
      Flux.tab_menu:close_menu()
    end
  end
end

function GM:HUDDrawScoreBoard()
  self.BaseClass:HUDDrawScoreBoard()

  if !IsValid(PLAYER) or !PLAYER:has_initialized() or hook.run('ShouldDrawLoadingScreen') then
    local text = t'ui.hud.loading.schema'
    local percentage = 80

    if !Flux.local_player_created then
      text = t'ui.hud.loading.local_player'
      percentage = 0
    elseif !IsValid(PLAYER) then
      text = t'ui.hud.loading.player_object'
      percentage = 20
    end

    local hooked, hooked_percentage = Plugin.call('GetLoadingScreenMessage')

    if isstring(hooked) then
      text = hooked

      if isnumber(hooked_percentage) then
        percentage = hooked_percentage
      end
    end

    percentage = math.Clamp(percentage, 0, 100)

    local font = Font.size('flRobotoCondensed', math.scale(24))
    local scrw, scrh = ScrW(), ScrH()
    local w, h = util.text_size(text, font)

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0))
    draw.SimpleText(text, font, scrw * 0.5 - w * 0.5, scrh - 128, Color(255, 255, 255))

    local bar_w, bar_h = scrw / 3.5, 6
    local bar_x, bar_y = scrw * 0.5 - bar_w * 0.5, scrh - 80
    local fill_w = math.Clamp(bar_w * (percentage / 100), 0, bar_w - 2)

    draw.RoundedBox(0, bar_x, bar_y, bar_w, bar_h, Color(22, 22, 22))
    draw.RoundedBox(0, bar_x + 1, bar_y + 1, fill_w, bar_h - 2, Color(245, 245, 245))

    Plugin.call('PostDrawLoadingScreen')
  end
end

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
  if PLAYER:has_initialized() and hook.run('ShouldHUDPaint') != false then
    local cur_time = CurTime()
    local scrw, scrh = ScrW(), ScrH()

    if PLAYER.last_damage and PLAYER.last_damage > (cur_time - 0.3) then
      local alpha = math.Clamp(255 - 255 * (cur_time - PLAYER.last_damage) * 3.75, 0, 200)
      draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, scrw, scrh, Color(255, 0, 0, alpha))
      draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 210, 210, alpha))
    end

    if !PLAYER:Alive() then
      hook.run('HUDPaintDeathBackground', cur_time, scrw, scrh)
        Theme.call('PaintDeathScreen', cur_time, scrw, scrh)
      hook.run('HUDPaintDeathForeground', cur_time, scrw, scrh)
    else
      PLAYER.respawn_alpha = 0

      if isnumber(PLAYER.white_alpha) and PLAYER.white_alpha > 0.5 then
        PLAYER.white_alpha = Lerp(0.04, PLAYER.white_alpha, 0)
      end

      if !hook.run('FLHUDPaint', cur_time, scrw, scrh) then
        InfoDisplay:draw_all()
      end
    end

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 255, 255, PLAYER.white_alpha or 0))

    self.BaseClass:HUDPaint()
  end
end

function GM:FLHUDPaint(cur_time, scrw, scrh)
  local percentage = PLAYER.circle_action_percentage

  if percentage and percentage > -1 then
    local alpha = PLAYER.circle_action_alpha
    local x, y = ScrC()

    surface.SetDrawColor(0, 0, 0, 180 * alpha / 255)
    surface.draw_circle_outline(x, y, 65, 5, 64)

    surface.SetDrawColor(Theme.get_color('text'):alpha(alpha))
    surface.draw_circle_outline_partial(math.Clamp(percentage, 0, 100), x, y, 64, 3, 64)

    PLAYER.circle_action_percentage = nil
  end
end

function GM:HUDPaintDeathBackground(cur_time, w, h)
  draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, w, h, Color(255, 0, 0, 200))
end

function GM:HUDDrawTargetID()
  if IsValid(PLAYER) and PLAYER:Alive() then
    local client_pos = EyePos()
    local trace = PLAYER:GetEyeTraceNoCursor()
    local trace_ent = trace.Entity
    local ent, dist, center_distance

    if IsValid(trace_ent) then
      dist = trace_ent:EyePos():Distance(client_pos)
      ent = trace_ent
    else
      local entities = ents.FindInCone(client_pos, trace.Normal, 512, 0.98) -- 0.98 gives approximately 10 degrees

      for k, v in ipairs(entities) do
        if !IsValid(v) then continue end

        local pos = v:EyePos()
        local screen_pos = pos:ToScreen()
        local x, y = screen_pos.x, screen_pos.y
        local to_center = math.distance(x, y, ScrC())

        if !center_distance or to_center < center_distance then
          center_distance = to_center
          dist = pos:Distance(client_pos)
          ent = v
        end
      end
    end

    if IsValid(ent) then
      local pos = ent:EyePos()

      if util.vector_obstructed(client_pos, pos, { ent, PLAYER }) then return end

      local screen_pos = (pos + Vector(0, 0, 10 + dist * 0.075)):ToScreen()
      local x, y = screen_pos.x, screen_pos.y

      if ent:IsPlayer() and ent:has_initialized() and ent:Alive() then
        hook.run('DrawPlayerTargetID', ent, x, y, dist)
      elseif ent.DrawTargetID then
        ent:DrawTargetID(x, y, dist)
      else
        hook.run('DrawEntityTargetID', ent, x, y, dist)
      end
    end
  end
end

function GM:GetDrawPlayerInfo(player, x, y, distance, lines)
  lines['name'] = {
    text = player:name(),
    font = Theme.get_font('tooltip_large'),
    color = Color('white'),
    priority = 100
  }
end

function GM:DrawPlayerTargetID(player, x, y, distance)
  local lines = {}

  hook.run('GetDrawPlayerInfo', player, x, y, distance, lines)

  if hook.run('PreDrawPlayerInfo', player, x, y, distance, lines) == false then return end

  local alpha = 255

  if distance < 640 then
    if distance > 500 then
      local d = distance - 500

      alpha = math.Clamp(255 * (140 - d) / 140, 0, 255)
    end
  else
    return
  end

  for k, v in SortedPairsByMemberValue(lines, 'priority') do
    local font = v.font or Theme.get_font('tooltip_small')
    local color = v.color:alpha(alpha) or Color(255, 255, 255, alpha)
    local text = v.text
    local wrapped = util.wrap_text(text, font, ScrW() * 0.33, 0)

    for k1, v1 in pairs(wrapped) do
      local w, h = util.text_size(v1, font)
      draw.SimpleTextOutlined(v1, font, x - w * 0.5 + (v.offset_x or 0), y + (v.offset_y or 0), color, nil, nil, 1, Color(0, 0, 0, alpha))

      y = y + h + 1
    end
  end
end

function GM:HUDItemPickedUp(item_name)
end

function GM:HUDAmmoPickedUp(item_name, amount)
end

function GM:HUDDrawPickupHistory()
end

function GM:PopulateToolMenu()
  for tool_name, TOOL in pairs(Flux.Tool.stored) do
    if TOOL.AddToMenu != false then
      spawnmenu.AddToolMenuOption(
        TOOL.Tab or 'Main',
        TOOL.Category or 'New Category',
        tool_name,
        TOOL.Name or t(tool_name),
        TOOL.Command or 'gmod_tool '..tool_name,
        TOOL.ConfigName or tool_name,
        TOOL.BuildCPanel
      )
    end
  end

  hook.run('SynchronizeTools')
end

function GM:SynchronizeTools()
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(Flux.Tool.stored) do
    toolgun.Tool[v.Mode] = v
  end
end

local last_render = 0
local blur_render_time = 1 / Flux.blur_update_fps

function GM:RenderScreenspaceEffects()
  if Flux.should_render_blur then
    local cur_time = CurTime()

    if Flux.blur_update_fps == 0 or (cur_time - last_render > blur_render_time) then
      render.PushRenderTarget(Flux.rt_texture)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(Flux.blur_material)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        render.BlurRenderTarget(Flux.rt_texture, Flux.blur_size or 12, Flux.blur_size or 12, Flux.blur_passes or 8)
      render.PopRenderTarget()

      last_render = cur_time
    end

    Flux.blur_mat:SetTexture('$basetexture', Flux.rt_texture)
    Flux.should_render_blur = false
  else
    Flux.should_render_blur = nil
  end
end

-- Called when category icons are presented.
function GM:AddTabMenuItems(menu)
  menu:add_menu_item('scoreboard', {
    title = t'ui.tab_menu.scoreboard',
    panel = 'fl_scoreboard',
    icon = 'fa-users',
    priority = 20
  })

  menu:add_menu_item('help', {
    title = t'ui.tab_menu.help',
    icon = 'fa-info-circle',
    panel = 'fl_help',
    priority = 50
  })
end

function GM:OnMenuPanelOpen(menu_panel, active_panel)
  active_panel:SetPos(menu_panel:GetWide() * 0.5 - active_panel:GetWide() * 0.5, menu_panel:GetTall() * 0.5 - active_panel:GetTall() * 0.5)
end

function GM:PlayerBindPress(player, bind, pressed)
  if bind:find('gmod_undo') and pressed then
    if hook.run('SoftUndo', player) != nil then
      return true
    end
  end
end

function GM:ContextMenuOpen()
  if PLAYER:can('context_menu') then
    if !IsValid(g_ContextMenu) then
      CreateContextMenu()
    end
  else
    if IsValid(g_ContextMenu) then
      g_ContextMenu:safe_remove()
    end
  end

  return true
end

function GM:SpawnMenuOpen()
  timer.Remove('HintSystem_OpeningContext')
  timer.Remove('HintSystem_EditingSpawnlists')

  return true
end

function GM:SpawnlistContentChanged()
  timer.Remove('HintSystem_EditingSpawnlistsSave')
end

function GM:SoftUndo(player)
  Cable.send('fl_undo_soft')

  if #Flux.Undo:get_player(PLAYER) > 0 then return true end
end

function GM:OnIntroPanelCreated()
  system.FlashWindow()
end

do
  local prev_angles = nil

  function GM:Think()
    if IsValid(PLAYER) and !PLAYER:IsFlagSet(FL_FROZEN) then
      local lerp_step = FrameTime() * 6
      local angles = PLAYER:EyeAngles()

      if !prev_angles then prev_angles = angles end

      local x, y = Flux.global_ui_offset()
      local pitch, yaw = (prev_angles.pitch - angles.pitch), (prev_angles.yaw - angles.yaw)
      pitch = (pitch + 180) % 360 - 180
      yaw = (yaw + 180) % 360 - 180

      x = Lerp(lerp_step, x - yaw, 0)
      y = Lerp(lerp_step, y + pitch, 0)

      Flux.__set_global_offset__(x, y)

      prev_angles = angles
    end
  end
end

do
  local hidden_elements = { -- Hide default HUD elements.
    CHudAmmo = true,
    CHudBattery = true,
    CHudHealth = true,
    CHudCrosshair = true,
    CHudDamageIndicator = true,
    CHudSecondaryAmmo = true,
    CHudHistoryResource = true,
    CHudPoisonDamageIndicator = true
  }

  function GM:HUDShouldDraw(element)
    if hidden_elements[element] then
      return false
    end

    return true
  end
end
