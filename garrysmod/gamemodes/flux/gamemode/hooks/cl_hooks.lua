timer.Remove("HintSystem_OpeningMenu")
timer.Remove("HintSystem_Annoy1")
timer.Remove("HintSystem_Annoy2")

-- Called when the client connects and spawns.
function GM:InitPostEntity()
  fl.client = fl.client or LocalPlayer()

  netstream.Start("player_set_lang", GetConVar("gmod_language"):GetString())

  timer.Simple(0.4, function()
    netstream.Start("player_created", true)
    fl.localPlayerCreated = true
  end)

   for k, v in ipairs(player.GetAll()) do
     local model = v:GetModel()

     hook.run("PlayerModelChanged", v, model, model)
   end

   hook.run("SynchronizeTools")
   hook.run("LoadData")

   plugin.call("FLInitPostEntity")
end

function GM:PlayerInitialized()
  RunConsoleCommand("spawnmenu_reload")
  hook.run("PopulateToolMenu")
end

function GM:FluxClientSchemaLoaded()
  font.CreateFonts()
end

do
  local scrW, scrH = ScrW(), ScrH()
  local nextCheck = CurTime()

  -- This will let us detect whether the resolution has been changed, then call a hook if it has.
  function GM:Tick()
    local curTime = CurTime()

    if (curTime >= nextCheck) then
      local newW, newH = ScrW(), ScrH()

      if (scrW != newW or scrH != newH) then
        fl.print("Resolution changed from "..scrW.."x"..scrH.." to "..newW.."x"..newH..".")

        hook.run("OnResolutionChanged", newW, newH, scrW, scrH)

        scrW, scrH = newW, newH
      end

      nextCheck = curTime + 1
    end
  end
end

-- Remove default death notices.
function GM:DrawDeathNotice() end
function GM:AddDeathNotice() end

-- Called when default GWEN skin is required.
function GM:ForceDermaSkin()
  return "Flux"
end

-- Called when the resolution has been changed and fonts need to be resized to fit the client's res.
function GM:OnResolutionChanged(oldW, oldH, newW, newH)
  font.CreateFonts()
end

-- Called when the scoreboard should be shown.
function GM:ScoreboardShow()
  if (hook.run("ShouldScoreboardShow") != false) then
    if (fl.tabMenu and fl.tabMenu.CloseMenu) then
      fl.tabMenu:CloseMenu(true)
    end

    fl.tabMenu = theme.CreatePanel("TabMenu", nil, "flTabMenu")
    fl.tabMenu:MakePopup()
    fl.tabMenu.heldTime = CurTime() + 0.3
  end
end

-- Called when the scoreboard should be hidden.
function GM:ScoreboardHide()
  if (hook.run("ShouldScoreboardHide") != false) then
    if (fl.tabMenu and fl.tabMenu.heldTime and CurTime() >= fl.tabMenu.heldTime) then
      fl.tabMenu:CloseMenu()
    end
  end
end

function GM:HUDDrawScoreBoard()
  self.BaseClass:HUDDrawScoreBoard()

  if (!fl.client or !fl.client:HasInitialized() or hook.run("ShouldDrawLoadingScreen")) then
    local text = t"loading.schema"
    local percentage = 80

    if (!fl.localPlayerCreated) then
      text = t"loading.local_player"
      percentage = 0
    elseif (!fl.shared_received) then
      text = t"loading.shared"
      percentage = 45
    end

    local hooked, hookedPercentage = plugin.call("GetLoadingScreenMessage")

    if (isstring(hooked)) then
      text = hooked

      if (isnumber(hookedPercentage)) then
        percentage = hookedPercentage
      end
    end

    percentage = math.Clamp(percentage, 0, 100)

    local font = font.GetSize("flRobotoCondensed", font.Scale(24))
    local scrW, scrH = ScrW(), ScrH()
    local w, h = util.text_size(text, font)

    draw.RoundedBox(0, 0, 0, scrW, scrH, Color(0, 0, 0))
    draw.SimpleText(text, font, scrW * 0.5 - w * 0.5, scrH - 128, Color(255, 255, 255))

    local barW, barH = scrW / 3.5, 6
    local barX, barY = scrW * 0.5 - barW * 0.5, scrH - 80
    local fillW = math.Clamp(barW * (percentage / 100), 0, barW - 2)

    draw.RoundedBox(0, barX, barY, barW, barH, Color(22, 22, 22))
    draw.RoundedBox(0, barX + 1, barY + 1, fillW, barH - 2, Color(245, 245, 245))

    plugin.call("PostDrawLoadingScreen")
  end
end

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
  if (fl.client:HasInitialized() and hook.run("ShouldHUDPaint") != false) then
    local curTime = CurTime()
    local scrW, scrH = ScrW(), ScrH()

    if (fl.client.lastDamage and fl.client.lastDamage > (curTime - 0.3)) then
      local alpha = math.Clamp(255 - 255 * (curTime - fl.client.lastDamage) * 3.75, 0, 200)
      draw.TexturedRect(util.GetMaterial("materials/flux/hl2rp/blood.png"), 0, 0, scrW, scrH, Color(255, 0, 0, alpha))
      draw.RoundedBox(0, 0, 0, scrW, scrH, Color(255, 210, 210, alpha))
    end

    if (!fl.client:Alive()) then
      hook.run("HUDPaintDeathBackground", curTime, scrW, scrH)
        theme.Call("PaintDeathScreen", curTime, scrW, scrH)
      hook.run("HUDPaintDeathForeground", curTime, scrW, scrH)
    else
      fl.client.respawnAlpha = 0

      if (isnumber(fl.client.whiteAlpha) and fl.client.whiteAlpha > 0.5) then
        fl.client.whiteAlpha = Lerp(0.04, fl.client.whiteAlpha, 0)
      end

      if (!hook.run("FLHUDPaint", curTime, scrW, scrH)) then
        fl.bars:DrawTopBars()

        self.BaseClass:HUDPaint()
      end
    end

    draw.RoundedBox(0, 0, 0, scrW, scrH, Color(255, 255, 255, fl.client.whiteAlpha or 0))
  end
end

function GM:FLHUDPaint(curTime, scrW, scrH)
  local percentage = fl.client.circleActionPercentage

  if (percentage and percentage > -1) then
    local x, y = ScrC()

    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawCircle(x, y, 41, 64)
    surface.DrawOutlinedCircle(x, y, 41, 10, 64)

    surface.SetDrawColor(theme.GetColor("Text"))
    surface.DrawPartialOutlinedCircle(math.Clamp(percentage, 0, 100), x, y, 40, 8  , 64)

    fl.client.circleActionPercentage = nil
  end
end

function GM:HUDPaintDeathBackground(curTime, w, h)
  draw.TexturedRect(util.GetMaterial("materials/flux/hl2rp/blood.png"), 0, 0, w, h, Color(255, 0, 0, 200))
end

function GM:HUDDrawTargetID()
  if (IsValid(fl.client) and fl.client:Alive()) then
    local trace = fl.client:GetEyeTraceNoCursor()
    local ent = trace.Entity

    if (IsValid(ent)) then
      local screenPos = (trace.HitPos + Vector(0, 0, 16)):ToScreen()
      local x, y = screenPos.x, screenPos.y
      local distance = fl.client:GetPos():Distance(trace.HitPos)

      if (ent:IsPlayer()) then
        hook.run("DrawPlayerTargetID", ent, x, y, distance)
      elseif (ent.DrawTargetID) then
        ent:DrawTargetID(x, y, distance)
      end
    end
  end
end

function GM:DrawPlayerTargetID(player, x, y, distance)
  if (distance < 640) then
    local alpha = 255
    local tooltip_small = theme.GetFont("Tooltip_Small")
    local tooltip_large = theme.GetFont("Tooltip_Large")

    if (distance > 500) then
      local d = distance - 500
      alpha = math.Clamp((255 * (140 - d) / 140), 0, 255)
    end

    local width, height = util.text_size(player:Name(), tooltip_large)
    draw.SimpleText(player:Name(), tooltip_large, x - width * 0.5, y - 40, Color(255, 255, 255, alpha))

    local width, height = util.text_size(player:GetPhysDesc(), tooltip_small)
    draw.SimpleText(player:GetPhysDesc(), tooltip_small, x - width * 0.5, y - 14, Color(255, 255, 255, alpha))

    if (distance < 125) then
      if (distance > 90) then
        local d = distance - 90
        alpha = math.Clamp((255 * (35 - d) / 35), 0, 255)
      end

      local smallerFont = font.GetSize(tooltip_small, 12)
      local text = t'target_id.information'
      local width, height = util.text_size(text, smallerFont)
      draw.SimpleText(text, smallerFont, x - width * 0.5, y + 5, Color(50, 255, 50, alpha))
    end
  end
end

function GM:PopulateToolMenu()
  for ToolName, TOOL in pairs(fl.tool:GetAll()) do
    if (TOOL.AddToMenu != false) then
      spawnmenu.AddToolMenuOption(
        TOOL.Tab or "Main",
        TOOL.category or "New Category",
        ToolName,
        TOOL.name or t(ToolName),
        TOOL.Command or "gmod_tool "..ToolName,
        TOOL.ConfigName or ToolName,
        TOOL.BuildCPanel
      )
    end
  end

  hook.run("SynchronizeTools")
end

function GM:SynchronizeTools()
   local toolGun = weapons.GetStored("gmod_tool")

  for k, v in pairs(fl.tool:GetAll()) do
    toolGun.Tool[v.Mode] = v
  end
end

function GM:RenderScreenspaceEffects()
  if (fl.client.colorModify) then
    DrawColorModify(fl.client.colorModifyTable)
  end
end

-- Called when category icons are presented.
function GM:AddTabMenuItems(menu)
  menu:AddMenuItem("scoreboard", {
    title = t"tab_menu.scoreboard",
    panel = "flScoreboard",
    icon = "fa-list-alt"
  })

  menu:AddMenuItem("help", {
    title = "Help",
    icon = "fa-book",
    panel = "flHelp",
  })
end

function GM:OnMenuPanelOpen(menuPanel, activePanel)
  activePanel:SetPos(menuPanel:GetWide() * 0.5 - activePanel:GetWide() * 0.5 + font.Scale(200) + 6, menuPanel:GetTall() * 0.5 - activePanel:GetTall() * 0.5)
end

function GM:AddAdminMenuItems(panel, sidebar)
  sidebar:add_button("Manage Config")
  sidebar:add_button("Manage Players")
  sidebar:add_button("Manage Admins")
  sidebar:add_button("Group Editor")
  sidebar:add_button("Item Editor")
  panel:AddPanel("Admin_PermissionsEditor", "Permissions", "manage_permissions")
end

function GM:PlayerBindPress(player, bind, bPressed)
  if (bind:find("gmod_undo") and bPressed) then
    if (hook.run("SoftUndo", player) != nil) then
      return true
    end
  end
end

function GM:ContextMenuOpen()
  return true --fl.client:HasPermission("context_menu")
end

function GM:SoftUndo(player)
  netstream.Start("soft_undo")

  if (#fl.undo:get_player(fl.client) > 0) then return true end
end

do
  local hiddenElements = { -- Hide default HUD elements.
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudCrosshair = true,
    CHudHistoryResource = true,
    CHudDamageIndicator = true
  }

  function GM:HUDShouldDraw(element)
    if (hiddenElements[element]) then
      return false
    end

    return true
  end
end
