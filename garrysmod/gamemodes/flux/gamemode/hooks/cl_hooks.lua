timer.Remove('HintSystem_OpeningMenu')
timer.Remove('HintSystem_Annoy1')
timer.Remove('HintSystem_Annoy2')

-- Called when the client connects and spawns.
function GM:InitPostEntity()
  fl.client = fl.client or LocalPlayer()

  cable.send('fl_player_set_lang', GetConVar('gmod_language'):GetString())

  timer.Simple(0.4, function()
    cable.send('fl_player_created', true)
    fl.localPlayerCreated = true
  end)

  for k, v in ipairs(player.GetAll()) do
    local model = v:GetModel()

    hook.run('PlayerModelChanged', v, model, model)
  end

  hook.run('SynchronizeTools')
  hook.run('LoadData')

  plugin.call('FLInitPostEntity')
end

function GM:PlayerInitialized()
  RunConsoleCommand('spawnmenu_reload')
  hook.run('PopulateToolMenu')
end

function GM:FluxClientSchemaLoaded()
  font.create_fonts()
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
        fl.print('Resolution changed from '..scrw..'x'..scrh..' to '..new_w..'x'..new_h..'.')

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
  font.create_fonts()
end

-- Called when the scoreboard should be shown.
function GM:ScoreboardShow()
  if hook.run('ShouldScoreboardShow') != false then
    if fl.tab_menu and fl.tab_menu.close_menu then
      fl.tab_menu:close_menu(true)
    end

    fl.tab_menu = theme.create_panel('tab_menu', nil, 'fl_tab_menu')
    fl.tab_menu:MakePopup()
    fl.tab_menu.held_time = CurTime() + 0.3
  end
end

-- Called when the scoreboard should be hidden.
function GM:ScoreboardHide()
  if hook.run('ShouldScoreboardHide') != false then
    if fl.tab_menu and fl.tab_menu.held_time and CurTime() >= fl.tab_menu.held_time then
      fl.tab_menu:close_menu()
    end
  end
end

function GM:HUDDrawScoreBoard()
  self.BaseClass:HUDDrawScoreBoard()

  if !fl.client or !fl.client:has_initialized() or hook.run('ShouldDrawLoadingScreen') then
    local text = t'loading.schema'
    local percentage = 50

    if !fl.localPlayerCreated then
      text = t'loading.local_player'
      percentage = 0
    end

    local hooked, hooked_percentage = plugin.call('GetLoadingScreenMessage')

    if isstring(hooked) then
      text = hooked

      if isnumber(hooked_percentage) then
        percentage = hooked_percentage
      end
    end

    percentage = math.Clamp(percentage, 0, 100)

    local font = font.size('flRobotoCondensed', font.scale(24))
    local scrw, scrh = ScrW(), ScrH()
    local w, h = util.text_size(text, font)

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0))
    draw.SimpleText(text, font, scrw * 0.5 - w * 0.5, scrh - 128, Color(255, 255, 255))

    local bar_w, bar_h = scrw / 3.5, 6
    local bar_x, bar_y = scrw * 0.5 - bar_w * 0.5, scrh - 80
    local fill_w = math.Clamp(bar_w * (percentage / 100), 0, bar_w - 2)

    draw.RoundedBox(0, bar_x, bar_y, bar_w, bar_h, Color(22, 22, 22))
    draw.RoundedBox(0, bar_x + 1, bar_y + 1, fill_w, bar_h - 2, Color(245, 245, 245))

    plugin.call('PostDrawLoadingScreen')
  end
end

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
  if fl.client:has_initialized() and hook.run('ShouldHUDPaint') != false then
    local cur_time = CurTime()
    local scrw, scrh = ScrW(), ScrH()

    if fl.client.last_damage and fl.client.last_damage > (cur_time - 0.3) then
      local alpha = math.Clamp(255 - 255 * (cur_time - fl.client.last_damage) * 3.75, 0, 200)
      draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, scrw, scrh, Color(255, 0, 0, alpha))
      draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 210, 210, alpha))
    end

    if !fl.client:Alive() then
      hook.run('HUDPaintDeathBackground', cur_time, scrw, scrh)
        theme.call('PaintDeathScreen', cur_time, scrw, scrh)
      hook.run('HUDPaintDeathForeground', cur_time, scrw, scrh)
    else
      fl.client.respawn_alpha = 0

      if isnumber(fl.client.white_alpha) and fl.client.white_alpha > 0.5 then
        fl.client.white_alpha = Lerp(0.04, fl.client.white_alpha, 0)
      end

      if !hook.run('FLHUDPaint', cur_time, scrw, scrh) then
        InfoDisplay:draw_all()
      end
    end

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 255, 255, fl.client.white_alpha or 0))

    self.BaseClass:HUDPaint()
  end
end

function GM:FLHUDPaint(cur_time, scrw, scrh)
  local percentage = fl.client.circle_action_percentage

  if percentage and percentage > -1 then
    local x, y = ScrC()

    surface.SetDrawColor(0, 0, 0, 180)
    surface.draw_circle_outline(x, y, 65, 5, 64)

    surface.SetDrawColor(theme.get_color('text'))
    surface.draw_circle_outline_partial(math.Clamp(percentage, 0, 100), x, y, 64, 3, 64)

    fl.client.circle_action_percentage = nil
  end
end

function GM:HUDPaintDeathBackground(cur_time, w, h)
  draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, w, h, Color(255, 0, 0, 200))
end

function GM:HUDDrawTargetID()
  if IsValid(fl.client) and fl.client:Alive() then
    local entities = ents.FindInCone(EyePos(), EyeVector(), 256, 0.98) -- 0.98 gives approximately 40 degrees
    local ent
    local dist
    local client_pos = EyePos()

    for k, v in ipairs(entities) do
      if !IsValid(v) then continue end

      local ent_distance = v:GetPos():Distance(client_pos)

      if !dist then
        dist = ent_distance
        ent = v
      end

      if ent_distance < dist then
        dist = ent_distance
        ent = v
      end
    end

    if !IsValid(ent) then
      local trace = fl.client:GetEyeTraceNoCursor()
      local trace_ent = trace.Entity

      if IsValid(trace_ent) then
        dist = trace_ent:GetPos():Distance(client_pos)
        ent = trace_ent
      end
    end

    if IsValid(ent) then
      local pos

      if ent:IsPlayer() then
        pos = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Head1'))
      else
        pos = ent:GetPos()
      end

      if util.vector_obstructed(client_pos, pos, { ent, fl.client }) then return end

      local screen_pos = (pos + Vector(0, 0, 16)):ToScreen()
      local x, y = screen_pos.x, screen_pos.y

      if ent:IsPlayer() then
        hook.run('DrawPlayerTargetID', ent, x, y, dist)
      elseif ent.DrawTargetID then
        ent:DrawTargetID(x, y, dist)
      end
    end
  end
end

function GM:GetPlayerDrawInfo(player, x, y, distance, lines)
  if distance < 640 then
    local alpha = 255

    if distance > 500 then
      local d = distance - 500
      alpha = math.Clamp((255 * (140 - d) / 140), 0, 255)
    end

    lines['name'] = {
      text = player:name(),
      font = theme.get_font('tooltip_large'),
      color = Color(255, 255, 255, alpha),
      priority = 100
    }
  end
end

function GM:DrawPlayerTargetID(player, x, y, distance)
  local lines = {}

  hook.run('GetPlayerDrawInfo', player, x, y, distance, lines)
  hook.run('PrePlayerDrawInfo', player, x, y, distance, lines)

  for k, v in SortedPairsByMemberValue(lines, 'priority') do
    local font = v.font or theme.get_font('tooltip_small')
    local color = v.color or Color('white')
    local text = v.text

    if text then
      local w, h = util.text_size(text, font)
      draw.SimpleText(text, font, x - w * 0.5 + (v.offset_x or 0), y + (v.offset_y or 0), color)

      y = y + h + 2
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
  for ToolName, TOOL in pairs(fl.tool.stored) do
    if TOOL.AddToMenu != false then
      spawnmenu.AddToolMenuOption(
        TOOL.Tab or 'Main',
        TOOL.Category or 'New Category',
        ToolName,
        TOOL.Name or t(ToolName),
        TOOL.Command or 'gmod_tool '..ToolName,
        TOOL.ConfigName or ToolName,
        TOOL.BuildCPanel
      )
    end
  end

  hook.run('SynchronizeTools')
end

function GM:SynchronizeTools()
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(fl.tool.stored) do
    toolgun.Tool[v.Mode] = v
  end
end

local last_render = 0
local blur_render_time = 1 / fl.blur_update_fps

function GM:RenderScreenspaceEffects()
  if fl.should_render_blur then
    local cur_time = CurTime()

    if fl.blur_update_fps == 0 or (cur_time - last_render > blur_render_time) then
      render.PushRenderTarget(fl.rt_texture)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(fl.blur_material)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        render.BlurRenderTarget(fl.rt_texture, fl.blur_size or 12, fl.blur_size or 12, fl.blur_passes or 8)
      render.PopRenderTarget()

      last_render = cur_time
    end

    fl.blur_mat:SetTexture('$basetexture', fl.rt_texture)
    fl.should_render_blur = false
  else
    fl.should_render_blur = nil
  end
end

-- Called when category icons are presented.
function GM:AddTabMenuItems(menu)
  menu:add_menu_item('scoreboard', {
    title = t'tab_menu.scoreboard',
    panel = 'fl_scoreboard',
    icon = 'fa-list-alt'
  })

  menu:add_menu_item('help', {
    title = 'Help',
    icon = 'fa-book',
    panel = 'fl_help',
  })
end

function GM:OnMenuPanelOpen(menu_panel, active_panel)
  active_panel:SetPos(menu_panel:GetWide() * 0.5 - active_panel:GetWide() * 0.5 + font.scale(200) + 6, menu_panel:GetTall() * 0.5 - active_panel:GetTall() * 0.5)
end

function GM:AddAdminMenuItems(panel, sidebar)
  sidebar:add_button('Manage Config')
  sidebar:add_button('Manage Players')
  sidebar:add_button('Manage Admins')
  sidebar:add_button('Group Editor')
  sidebar:add_button('Item Editor')
  panel:AddPanel('admin_permissions_editor', 'Permissions', 'manage_permissions')
end

function GM:PlayerBindPress(player, bind, pressed)
  if bind:find('gmod_undo') and pressed then
    if hook.run('SoftUndo', player) != nil then
      return true
    end
  end
end

function GM:ContextMenuOpen()
  return true --fl.client:can('context_menu')
end

function GM:SoftUndo(player)
  cable.send('fl_undo_soft')

  if #fl.undo:get_player(fl.client) > 0 then return true end
end

function GM:OnIntroPanelCreated()
  system.FlashWindow()
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
