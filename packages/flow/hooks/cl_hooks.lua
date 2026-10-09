--- Client side of the gamemode hooks: the `GM` handlers that finish loading the local
-- player, draw the loading screen, the HUD, the death screen and the target IDs, open the
-- tab menu in place of the scoreboard, add the Flux tools to the spawn menu and hide the
-- parts of the sandbox HUD that Flux replaces.
-- Most of Flux's client-side drawing hooks are run from here, such as `FLHUDPaint`,
-- `ShouldHUDPaint`, `GetDrawPlayerInfo` and `DrawEntityTargetID`.

timer.Remove('HintSystem_OpeningMenu')
timer.Remove('HintSystem_Annoy1')
timer.Remove('HintSystem_Annoy2')

--- Stores the local player in the PLAYER global, sends the client's language to the server,
-- reports to the server that the player has been created and runs the client-side loading
-- hooks (PlayerModelChanged for every player, SynchronizeTools, LoadData, FLInitPostEntity).
function GM:InitPostEntity()
  PLAYER = LocalPlayer()

  Cable.send('fl_player_set_lang', Flux.Lang:get_preferred_language())

  timer.Simple(0.4, function()
    Cable.send('fl_player_created', true)
    Flux.local_player_created = true
  end)

  for k, v in player.Iterator() do
    local model = v:GetModel()

    hook.Run('PlayerModelChanged', v, model, model)
  end

  --- Called on the client when the tool gun has to learn about the Flux tools: once the
  -- map's entities have been created, and again whenever the tool menu has been populated.
  -- The gamemode's handler copies every registered Flux tool into the tool table of the
  -- tool gun.
  hook.Run('SynchronizeTools')
  hook.Run('LoadData')

  Plugin.call('FLInitPostEntity')

  timer.Create('flux_please_dont_screw_up', 0.1, 0, function()
    if !IsValid(PLAYER) then
      PLAYER = LocalPlayer()
    else
      timer.Remove('flux_please_dont_screw_up')
    end
  end)
end

--- Rebuilds the spawn menu and the tool menu once the server has initialized the local player.
function GM:PlayerInitialized()
  --- Called on the client once the server has initialized the local player, right before
  -- the spawn menu is rebuilt with the `spawnmenu_reload` console command. Plugins add
  -- their spawn menu tabs here.
  hook.Run('PopulateSpawnMenu')
  RunConsoleCommand('spawnmenu_reload')
  --- Sandbox's `PopulateToolMenu` hook, run once more by Flux on the client when the
  -- server has initialized the local player, after the spawn menu reload has been
  -- requested. The gamemode's handler adds every registered Flux tool to the tool menu
  -- and then runs `SynchronizeTools`.
  hook.Run('PopulateToolMenu')
end

--- Creates the fonts once the schema has been loaded on the client.
function GM:FluxClientSchemaLoaded()
  Font.create_fonts()
end

do
  local scrw, scrh = ScrW(), ScrH()
  local next_check = CurTime()

  --- Checks once a second whether the screen resolution has changed and runs the
  -- OnResolutionChanged hook if it has.
  function GM:Tick()
    local cur_time = CurTime()

    if cur_time >= next_check then
      local new_w, new_h = ScrW(), ScrH()

      if scrw != new_w or scrh != new_h then
        Flux.print('Resolution changed from '..scrw..'x'..scrh..' to '..new_w..'x'..new_h..'.')

        --- Called on the client when the screen resolution has changed. The gamemode checks
        -- the resolution once a second, and its handler recreates the fonts.
        -- @param new_w [Number New screen width]
        -- @param new_h [Number New screen height]
        -- @param old_w [Number Previous screen width]
        -- @param old_h [Number Previous screen height]
        hook.Run('OnResolutionChanged', new_w, new_h, scrw, scrh)

        scrw, scrh = new_w, new_h
      end

      next_check = cur_time + 1
    end
  end
end

-- Remove default death notices.

--- Does nothing, which removes the default death notices from the HUD.
function GM:DrawDeathNotice()
end

--- Does nothing, so that the default death notices are never added.
function GM:AddDeathNotice()
end

--- Makes Derma use the Flux skin by default.
-- @return [String name of the skin]
function GM:ForceDermaSkin()
  return 'Flux'
end

--- Recreates the fonts so that they fit the new resolution.
-- @param new_w [Number new screen width]
-- @param new_h [Number new screen height]
-- @param old_w [Number previous screen width]
-- @param old_h [Number previous screen height]
function GM:OnResolutionChanged(new_w, new_h, old_w, old_h)
  Font.create_fonts()
end

--- Opens the tab menu in place of the default scoreboard, unless the ShouldScoreboardShow
-- hook returns false, and notes when the key was pressed.
function GM:ScoreboardShow()
  local menu = Flux.TabMenu:open()

  if menu then
    menu.held_time = CurTime() + 0.3
  end
end

--- Closes the tab menu when the scoreboard key is released after being held for longer
-- than 0.3 seconds, unless the ShouldScoreboardHide hook returns false. A short press
-- leaves the menu open, and so does a menu that was opened from code.
function GM:ScoreboardHide()
  --- Asks whether the tab menu may close. Called on the client when the scoreboard key is
  -- released.
  -- @return [Boolean Return false to keep the tab menu open]
  if hook.Run('ShouldScoreboardHide') != false then
    local menu = Flux.TabMenu:get_panel()

    if menu and menu.held_time and CurTime() >= menu.held_time then
      Flux.TabMenu:close()
    end
  end
end

--- Draws the loading screen with its status text and progress bar while the local player
-- is not initialized yet or the ShouldDrawLoadingScreen hook returns true.
function GM:HUDDrawScoreBoard()
  self.BaseClass:HUDDrawScoreBoard()

  --- Asks whether the loading screen should stay up. Called on the client every frame once
  -- the local player has been initialized; until then the loading screen is always drawn.
  -- @return [Boolean Return true to keep drawing the loading screen]
  if !IsValid(PLAYER) or !PLAYER:has_initialized() or hook.Run('ShouldDrawLoadingScreen') then
    local text = t'ui.hud.loading.schema'
    local percentage = 80

    if !Flux.local_player_created then
      text = t'ui.hud.loading.local_player'
      percentage = 0
    elseif !IsValid(PLAYER) then
      text = t'ui.hud.loading.player_object'
      percentage = 20
    end

    --- Lets plugins replace the status text and the progress shown on the loading screen.
    -- Called on the client every frame while the loading screen is drawn. Gamemode (`GM`)
    -- handlers are not called.
    -- @return [String Text to show instead of the default status,
    --   Number Progress of the bar from 0 to 100; optional and only used along with a text]
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

    --- Called on the client every frame right after the loading screen has been drawn, for
    -- drawing on top of it. Gamemode (`GM`) handlers are not called.
    Plugin.call('PostDrawLoadingScreen')
  end
end

--- Draws the Flux HUD once the local player is initialized: the damage flash, the death
-- screen while dead or the info displays and the top bars while alive (unless FLHUDPaint
-- returns a truthy value), and the white respawn fade. Skipped when the ShouldHUDPaint hook
-- returns false.
function GM:HUDPaint()
  --- Asks whether the HUD should be drawn. Called on the client every frame once the local
  -- player has been initialized, from the gamemode's `HUDPaint` handler. HUD elements
  -- that plugins draw on their own, such as the crosshair, can run it too.
  -- @return [Boolean Return false to hide the Flux HUD and the HUD of the base gamemode]
  if PLAYER:has_initialized() and hook.Run('ShouldHUDPaint') != false then
    local cur_time = CurTime()
    local scrw, scrh = ScrW(), ScrH()

    if PLAYER.last_damage and PLAYER.last_damage > (cur_time - 0.3) then
      local alpha = math.Clamp(255 - 255 * (cur_time - PLAYER.last_damage) * 3.75, 0, 200)
      draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, scrw, scrh, Color(255, 0, 0, alpha))
      draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 210, 210, alpha))
    end

    if !PLAYER:Alive() then
      --- Called on the client every frame while the local player is dead, before the theme
      -- paints the death screen, for drawing behind it. The gamemode's handler draws a red
      -- blood overlay.
      -- @param cur_time [Number CurTime() of the frame]
      -- @param scrw [Number Screen width]
      -- @param scrh [Number Screen height]
      hook.Run('HUDPaintDeathBackground', cur_time, scrw, scrh)
        Theme.call('PaintDeathScreen', cur_time, scrw, scrh)
      --- Called on the client every frame while the local player is dead, after the theme has
      -- painted the death screen, for drawing on top of it.
      -- @param cur_time [Number CurTime() of the frame]
      -- @param scrw [Number Screen width]
      -- @param scrh [Number Screen height]
      hook.Run('HUDPaintDeathForeground', cur_time, scrw, scrh)
    else
      PLAYER.respawn_alpha = 0

      if isnumber(PLAYER.white_alpha) and PLAYER.white_alpha > 0.5 then
        PLAYER.white_alpha = Lerp(0.04, PLAYER.white_alpha, 0)
      end

      --- Called on the client every frame while the local player is alive and the HUD is
      -- shown, for drawing HUD elements. Runs after the damage flash and before the info
      -- displays (`InfoDisplay`) and the top bars (`Flux.Bars`) are drawn. The gamemode's
      -- handler draws the circular action indicator.
      -- @param cur_time [Number CurTime() of the frame]
      -- @param scrw [Number Screen width]
      -- @param scrh [Number Screen height]
      -- @return [Boolean Return true to keep the info displays and the top bars from being
      --   drawn]
      if !hook.Run('FLHUDPaint', cur_time, scrw, scrh) then
        InfoDisplay:draw_all()
        Flux.Bars:DrawTopBars()
      end
    end

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(255, 255, 255, PLAYER.white_alpha or 0))

    self.BaseClass:HUDPaint()
  end
end

--- Draws the circular action progress indicator in the middle of the screen if a
-- percentage was set with Flux.set_circle_percent.
-- @param cur_time [Number current CurTime()]
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
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

--- Draws the red blood overlay behind the death screen.
-- @param cur_time [Number current CurTime()]
-- @param w [Number screen width]
-- @param h [Number screen height]
function GM:HUDPaintDeathBackground(cur_time, w, h)
  draw.textured_rect(util.get_material('materials/flux/hl2rp/blood.png'), 0, 0, w, h, Color(255, 0, 0, 200))
end

--- Finds the entity the local player is looking at, or the one closest to the crosshair
-- within a narrow cone, and draws its target ID through the DrawPlayerTargetID hook, the
-- entity's own DrawTargetID method or the DrawEntityTargetID hook.
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
        --- Called on the client every frame to draw the target ID of the player that the local
        -- player is looking at, or has closest to the crosshair. Only happens while the local
        -- player is alive and for targets that are alive, initialized and not obstructed. The
        -- gamemode's handler draws the lines collected with `GetDrawPlayerInfo`.
        -- @param target [Player The player being looked at]
        -- @param x [Number Screen x of the point above the target to center the text on]
        -- @param y [Number Screen y of that point]
        -- @param distance [Number Distance from the camera to the target's eyes in units]
        hook.Run('DrawPlayerTargetID', ent, x, y, dist)
      elseif ent.DrawTargetID then
        ent:DrawTargetID(x, y, dist)
      else
        --- Called on the client every frame to draw the target ID of the entity that the local
        -- player is looking at, or has closest to the crosshair, when `DrawPlayerTargetID`
        -- does not apply to it and it has no `DrawTargetID` method of its own. Nothing is
        -- drawn unless a handler does it.
        -- @param entity [Entity The entity being looked at]
        -- @param x [Number Screen x of the point above the entity to center the text on]
        -- @param y [Number Screen y of that point]
        -- @param distance [Number Distance from the camera to the entity in units]
        hook.Run('DrawEntityTargetID', ent, x, y, dist)
      end
    end
  end
end

--- Adds the name of the player to the lines shown in their target ID.
-- @param target [Player the player being looked at]
-- @param x [Number screen x of the target ID]
-- @param y [Number screen y of the target ID]
-- @param distance [Number distance to the player in units]
-- @param lines [Map lines to draw, keyed by ID. Each one is a table with the text and
--   priority fields, and optionally font, color, offset_x and offset_y]
function GM:GetDrawPlayerInfo(target, x, y, distance, lines)
  lines['name'] = {
    text = target:name(),
    font = Theme.get_font('tooltip_large'),
    color = Color('white'),
    priority = 100
  }
end

--- Collects the target ID lines of a player through the GetDrawPlayerInfo hook and draws
-- them in order of priority, fading out between 500 and 640 units of distance. Nothing is
-- drawn if the PreDrawPlayerInfo hook returns false.
-- @param target [Player the player being looked at]
-- @param x [Number screen x of the horizontal center of the text]
-- @param y [Number screen y of the first line]
-- @param distance [Number distance to the player in units]
function GM:DrawPlayerTargetID(target, x, y, distance)
  local lines = {}

  --- Collects the lines of text shown in the target ID of a player. Called on the client
  -- every frame the gamemode draws a player's target ID. Handlers add their entries to
  -- `lines` and should not return anything, so that the other handlers run too; the
  -- gamemode's handler adds the `name` line.
  -- @param target [Player The player being looked at]
  -- @param x [Number Screen x of the target ID]
  -- @param y [Number Screen y of the target ID]
  -- @param distance [Number Distance to the player in units]
  -- @param lines [Map Lines to draw by ID. Each one is a table with the `text` and
  --   `priority` fields (lines with a lower priority are drawn first) and optionally
  --   `color` (white by default), `font`, `offset_x` and `offset_y`]
  hook.Run('GetDrawPlayerInfo', target, x, y, distance, lines)

  --- Called on the client after the target ID lines of a player have been collected with
  -- `GetDrawPlayerInfo` and before they are drawn. Handlers can change or remove the
  -- entries of `lines`.
  -- @param target [Player The player being looked at]
  -- @param x [Number Screen x of the target ID]
  -- @param y [Number Screen y of the target ID]
  -- @param distance [Number Distance to the player in units]
  -- @param lines [Map Lines about to be drawn by ID, see `GetDrawPlayerInfo`]
  -- @return [Boolean Return false to draw nothing for this player]
  if hook.Run('PreDrawPlayerInfo', target, x, y, distance, lines) == false then return end

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
    local color = v.color and v.color:alpha(alpha) or Color(255, 255, 255, alpha)
    local text = v.text
    local wrapped = util.wrap_text(text, font, ScrW() * 0.33, 0)

    for k1, v1 in pairs(wrapped) do
      local w, h = util.text_size(v1, font)
      draw.SimpleTextOutlined(
        v1,
        font,
        x - w * 0.5 + (v.offset_x or 0),
        y + (v.offset_y or 0),
        color,
        nil,
        nil,
        1,
        Color(0, 0, 0, alpha)
      )

      y = y + h + 1
    end
  end
end

--- Does nothing, which disables the default item pickup notification.
-- @param item_name [String]
function GM:HUDItemPickedUp(item_name)
end

--- Does nothing, which disables the default ammo pickup notification.
-- @param item_name [String]
-- @param amount [Number]
function GM:HUDAmmoPickedUp(item_name, amount)
end

--- Does nothing, which disables the default pickup history on the HUD.
function GM:HUDDrawPickupHistory()
end

--- Adds every registered Flux tool to the tool list of the spawn menu, then runs the
-- SynchronizeTools hook.
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

  hook.Run('SynchronizeTools')
end

--- Copies every registered Flux tool into the tool table of the tool gun.
function GM:SynchronizeTools()
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(Flux.Tool.stored) do
    toolgun.Tool[v.Mode] = v
  end
end

local last_render = 0
local blur_render_time = 1 / Flux.blur_update_fps

--- Updates the blurred copy of the screen used by draw.blur_box and draw.blur_panel. Only
-- does so while something has requested the blur, and no more often than the blur update
-- interval unless Flux.blur_update_fps is 0.
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

--- Adds the scoreboard and help items to the tab menu.
-- @param menu [Panel the fl_tab_menu being built]
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

--- Adds the options that the scoreboard offers for every player to the menu of a player
-- card: opening their Steam profile and copying their SteamID. Bots have neither.
-- @param menu [Panel the DermaMenu being filled]
-- @param target [Player the player the card shows]
-- @param card [Panel the fl_scoreboard_player card that was clicked]
function GM:CreateScoreboardPlayerMenu(menu, target, card)
  if target:IsBot() then return end

  menu:AddOption(t'ui.scoreboard.menu.profile', function()
    if IsValid(target) then
      target:ShowProfile()
    end
  end):SetIcon('icon16/user.png')

  menu:AddOption(t'ui.scoreboard.menu.copy_steam_id', function()
    if IsValid(target) then
      SetClipboardText(target:SteamID())
    end
  end):SetIcon('icon16/page_copy.png')
end

--- Takes the players that are kept off the scoreboard out of the lists that the Factions
-- plugin builds its scoreboard categories from, so that PlayerShouldShowOnScoreboard also
-- applies when the players are grouped by faction. Handles the PreRebuildFactionCategories
-- hook of that plugin and runs after the plugins that regroup the players.
-- @param players_table [Map lists of players keyed by category]
function GM:PreRebuildFactionCategories(players_table)
  for id, players in pairs(players_table) do
    for k, v in pairs(players) do
      if IsValid(v) and v:has_initialized() and hook.Run('PlayerShouldShowOnScoreboard', v) == false then
        players[k] = nil
      end
    end
  end
end

--- Centers a newly opened panel within the tab menu.
-- @param menu_panel [Panel the tab menu]
-- @param active_panel [Panel the panel that has been opened]
function GM:OnMenuPanelOpen(menu_panel, active_panel)
  active_panel:SetPos(
    menu_panel:GetWide() * 0.5 - active_panel:GetWide() * 0.5,
    menu_panel:GetTall() * 0.5 - active_panel:GetTall() * 0.5
  )
end

do
  local following = false

  --- Makes the language setting show the language the player has actually picked, which
  -- is kept in the fl_language console variable and can be changed there directly. A
  -- language that this server has no phrases for is shown as following the game. The
  -- console variable is left alone.
  local function follow_language()
    if following or !ClientSettings or !ClientSettings:find('language') then return end

    local lang = Flux.Lang:get_language_override() or ''

    if ClientSettings:sanitize('language', lang) == nil then
      lang = ''
    end

    if ClientSettings:get('language') != lang then
      following = true
      ClientSettings:set('language', lang)
      following = false
    end
  end

  --- Switches the language of the client to the one the player has picked in the settings
  -- menu.
  -- @param value [String language code, or an empty string to follow the language of the
  --   game]
  local function language_picked(value)
    if following then return end

    following = true
    Flux.Lang:set_language(value)
    following = false
  end

  --- Registers the language setting with the Settings plugin: a choice between following
  -- the language of the game and every language the server has phrases for. Picking one
  -- goes through Flux.Lang:set_language. Handles the RegisterClientSettings hook, which
  -- only the Settings plugin runs, so nothing happens without that plugin.
  local function register_language_setting()
    if !ClientSettings then return end

    local choices = { { value = '', name = 'settings.language.auto' } }

    for k, v in ipairs(Flux.Lang:get_languages()) do
      table.insert(choices, { value = v, name = Flux.Lang:get_language_name(v) })
    end

    ClientSettings:register_setting('language', {
      type = 'choice',
      default = '',
      choices = choices,
      category = 'settings.categories.interface',
      name = 'settings.language.name',
      description = 'settings.language.desc',
      on_change = language_picked
    })

    follow_language()
  end

  --- Registers the language setting when the Settings plugin collects the settings, which
  -- it does while the schema is being included. On the first load the gamemode is not
  -- registered yet at that point and a `GM` method would not be called, which is why the
  -- handler is added with hook.Add instead.
  hook.Add('RegisterClientSettings', 'FLLanguageSetting', register_language_setting)

  --- Keeps the language setting in step when the language of the client changes for
  -- another reason than the setting itself, such as the fl_language console variable.
  -- @param new_lang [String new language code]
  -- @param old_lang [String previous language code]
  function GM:LanguageChanged(new_lang, old_lang)
    follow_language()
  end

  --- Keeps the language setting in step when the fl_language console variable changes
  -- without the language of the client changing with it, which is the case when it is
  -- cleared while the game is set to the same language.
  cvars.AddChangeCallback('fl_language', function(name, old_value, new_value)
    follow_language()
  end, 'FLLanguageSetting')
end

--- Intercepts the undo bind and blocks it when the SoftUndo hook returns a value.
-- @param client [Player]
-- @param bind [String the bind that was triggered]
-- @param pressed [Boolean whether the key was pressed rather than released]
-- @return [Boolean true to block the bind, nil otherwise]
function GM:PlayerBindPress(client, bind, pressed)
  if bind:find('gmod_undo') and pressed then
    --- Called on the client when the local player presses the undo key (a bind containing
    -- `gmod_undo`). The gamemode's handler asks the server to undo the last entry of the
    -- player's Flux undo queue and returns true if the queue is not empty.
    -- @param client [Player The local player]
    -- @return [Any Return any non-nil value to block the bind, which keeps sandbox's own
    --   undo from running as well]
    if hook.Run('SoftUndo', client) != nil then
      return true
    end
  end
end

--- Creates the context menu if the local player has the context_menu permission and
-- removes it if they do not.
-- @return [Boolean always true]
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

--- Removes the sandbox hint timers and allows the spawn menu to open.
-- @return [Boolean always true]
function GM:SpawnMenuOpen()
  timer.Remove('HintSystem_OpeningContext')
  timer.Remove('HintSystem_EditingSpawnlists')

  return true
end

--- Removes the sandbox hint timer about saving spawnlists.
function GM:SpawnlistContentChanged()
  timer.Remove('HintSystem_EditingSpawnlistsSave')
end

--- Asks the server to undo the last Flux undo entry of the local player.
-- @param client [Player unused, the local player is always used]
-- @return [Boolean true if the local player has entries in their undo queue, nil otherwise]
function GM:SoftUndo(client)
  Cable.send('fl_undo_soft')

  if #Flux.Undo:get_player(PLAYER) > 0 then return true end
end

--- Flashes the game window in the taskbar when the intro panel appears.
function GM:OnIntroPanelCreated()
  system.FlashWindow()
end

do
  local prev_angles = nil

  --- Updates the global UI offset from the rotation of the local player's view, so that HUD
  -- elements using it sway and settle back. Skipped while the player is frozen.
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

  --- Hides the default HUD elements that Flux replaces, such as health, armor, ammo, the
  -- crosshair and the damage indicators.
  -- @param element [String name of the HUD element]
  -- @return [Boolean false for the hidden elements, true for everything else]
  function GM:HUDShouldDraw(element)
    if hidden_elements[element] then
      return false
    end

    return true
  end
end
