--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

timer.Remove("HintSystem_OpeningMenu")
timer.Remove("HintSystem_Annoy1")
timer.Remove("HintSystem_Annoy2")

-- Called when the client connects and spawns.
function GM:InitPostEntity()
	fl.client = fl.client or LocalPlayer()

	netstream.Start("Flux::Player::Language", GetConVar("gmod_language"):GetString())

	timer.Simple(0.4, function()
		netstream.Start("LocalPlayerCreated", true)
		fl.localPlayerCreated = true
	end)

 	for k, v in ipairs(player.GetAll()) do
 		local model = v:GetModel()

 		hook.Run("PlayerModelChanged", v, model, model)
 	end

 	hook.Run("SynchronizeTools")
 	hook.Run("LoadData")

 	plugin.Call("FLInitPostEntity")
end

function GM:PlayerInitialized()
	RunConsoleCommand("spawnmenu_reload")
	hook.Run("PopulateToolMenu")
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
				fl.Print("Resolution changed from "..scfl.."x"..scrH.." to "..newW.."x"..newH..".")

				hook.Run("OnResolutionChanged", newW, newH, scrW, scrH)

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
	if (hook.Run("ShouldScoreboardShow") != false) then
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
	if (hook.Run("ShouldScoreboardHide") != false) then
		if (fl.tabMenu and fl.tabMenu.heldTime and CurTime() >= fl.tabMenu.heldTime) then
			fl.tabMenu:CloseMenu()
		end
	end
end

function GM:HUDDrawScoreBoard()
	self.BaseClass:HUDDrawScoreBoard()

	if (!fl.client or !fl.client:HasInitialized() or hook.Run("ShouldDrawLoadingScreen")) then
		local text = "Loading schema and plugins, please wait..."
		local percentage = 80

		if (!fl.localPlayerCreated) then
			text = "Preparing loading sequence, please wait..."
			percentage = 0
		elseif (!fl.sharedTableReceived) then
			text = "Receiving shared data, please wait..."
			percentage = 45
		end

		local hooked, hookedPercentage = plugin.Call("GetLoadingScreenMessage")

		if (isstring(hooked)) then
			text = hooked

			if (isnumber(hookedPercentage)) then
				percentage = hookedPercentage
			end
		end

		percentage = math.Clamp(percentage, 0, 100)

		local font = font.GetSize("flMainFont", font.Scale(24))
		local scrW, scrH = ScrW(), ScrH()
		local w, h = util.GetTextSize(text, font)

		draw.RoundedBox(0, 0, 0, scrW, scrH, Color(0, 0, 0))
		draw.SimpleText(text, font, scrW / 2 - w / 2, scrH - 128, Color(255, 255, 255))

		local barW, barH = scrW / 3.5, 6
		local barX, barY = scrW / 2 - barW * 0.5, scrH - 80
		local fillW = math.Clamp(barW * (percentage / 100), 0, barW - 2)

		draw.RoundedBox(0, barX, barY, barW, barH, Color(22, 22, 22))
		draw.RoundedBox(0, barX + 1, barY + 1, fillW, barH - 2, Color(245, 245, 245))

		plugin.Call("PostDrawLoadingScreen")
	end
end

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
	if (fl.client:HasInitialized() and hook.Run("ShouldHUDPaint") != false) then
		local curTime = CurTime()
		local scrW, scrH = ScrW(), ScrH()

		if (fl.client.lastDamage and fl.client.lastDamage > (curTime - 0.3)) then
			local alpha = math.Clamp(255 - 255 * (curTime - fl.client.lastDamage) * 3.75, 0, 200)
			draw.TexturedRect(0, 0, scrW, scrH, Material("materials/flux/hl2rp/blood.png"), Color(255, 0, 0, alpha))
			draw.RoundedBox(0, 0, 0, scrW, scrH, Color(255, 210, 210, alpha))
		end

		if (!fl.client:Alive()) then
			hook.Run("HUDPaintDeathBackground", curTime, scrW, scrH)
				theme.Call("PaintDeathScreen", curTime, scrW, scrH)
			hook.Run("HUDPaintDeathForeground", curTime, scrW, scrH)
		else
			fl.client.respawnAlpha = 0

			if (isnumber(fl.client.whiteAlpha) and fl.client.whiteAlpha > 0.5) then
				fl.client.whiteAlpha = Lerp(0.04, fl.client.whiteAlpha, 0)
			end

			if (!hook.Run("FLHUDPaint", curTime, scrW, scrH) and fl.settings:GetBool("DrawBars")) then
				fl.bars:DrawTopBars()

				self.BaseClass:HUDPaint()
			end
		end

		draw.RoundedBox(0, 0, 0, scrW, scrH, Color(255, 255, 255, fl.client.whiteAlpha or 0))
	end
end

function GM:HUDPaintDeathBackground(curTime, w, h)
	draw.TexturedRect(0, 0, w, h, Material("materials/flux/hl2rp/blood.png"), Color(255, 0, 0, 200))
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
				hook.Run("DrawPlayerTargetID", ent, x, y, distance)
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

		local width, height = util.GetTextSize(player:Name(), tooltip_large)
		draw.SimpleText(player:Name(), tooltip_large, x - width * 0.5, y - 40, Color(255, 255, 255, alpha))

		local width, height = util.GetTextSize(player:GetPhysDesc(), tooltip_small)
		draw.SimpleText(player:GetPhysDesc(), tooltip_small, x - width * 0.5, y - 14, Color(255, 255, 255, alpha))

		if (distance < 125) then
			if (distance > 90) then
				local d = distance - 90
				alpha = math.Clamp((255 * (35 - d) / 35), 0, 255)
			end

			local smallerFont = font.GetSize(tooltip_small, 12)
			local width, height = util.GetTextSize("#TargetID_Information", smallerFont)
			draw.SimpleText("#TargetID_Information", smallerFont, x - width * 0.5, y + 5, Color(50, 255, 50, alpha))
		end
	end
end

function GM:PopulateToolMenu()
	for ToolName, TOOL in pairs(fl.tool:GetAll()) do
		if (TOOL.AddToMenu != false) then
			spawnmenu.AddToolMenuOption(
				TOOL.Tab or "Main",
				TOOL.Category or "New Category",
				ToolName,
				TOOL.Name or "#"..ToolName,
				TOOL.Command or "gmod_tool "..ToolName,
				TOOL.ConfigName or ToolName,
				TOOL.BuildCPanel
			)
		end
	end

	hook.Run("SynchronizeTools")
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

function GM:PlayerUseItemMenu(itemTable, bIsEntity)
	if (!itemTable) then return end

	local itemMenu = DermaMenu()

	if (!itemTable.Name) then
		local closeBtn = itemMenu:AddOption(itemTable.CancelText or "Cancel", function() end)
		closeBtn:SetIcon("icon16/cross.png")
	else
		if (itemTable.customButtons) then
			for k, v in pairs(itemTable.customButtons) do
				local button = itemMenu:AddOption(k, function()
					itemTable:DoMenuAction(v.callback)
				end)

				button:SetIcon(v.icon)
			end
		end

		if (itemTable.OnUse) then
			local useBtn = itemMenu:AddOption(itemTable.UseText or "Use", function()
				itemTable:DoMenuAction("OnUse")
			end)

			useBtn:SetIcon(itemTable.UseIcon or "icon16/wrench.png")
		end

		if (bIsEntity) then
			local takeBtn = itemMenu:AddOption(itemTable.TakeText or "Take", function()
				itemTable:DoMenuAction("OnTake")
			end)

			takeBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		else
			local dropBtn = itemMenu:AddOption(itemTable.TakeText or "Drop", function()
				itemTable:DoMenuAction("OnDrop")
			end)

			dropBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		end

		local closeBtn = itemMenu:AddOption(itemTable.CancelText or "Cancel", function() end)
		closeBtn:SetIcon(itemTable.CancelIcon or "icon16/cross.png")
	end

	itemMenu:Open()

	if (itemTable.entity) then
		itemMenu:SetPos(ScrW() / 2, ScrH() / 2)
	else
		itemMenu:SetPos(gui.MouseX(), gui.MouseY())
	end
end

function GM:PlayerDropItem(itemTable, panel, mouseX, mouseY)
	netstream.Start("PlayerDropItem", itemTable.instanceID)
end

-- Called when category icons are presented.
function GM:AddTabMenuItems(menu)
	menu:AddMenuItem("!inventory", {
		title = "Inventory",
		panel = "flInventory",
		icon = "fa-inbox",
		callback = function(menuPanel, button)
			local inv = menuPanel.activePanel
			inv:SetPlayer(fl.client)
			inv:SetTitle("Inventory")
		end
	})

	menu:AddMenuItem("scoreboard", {
		title = "Scoreboard",
		panel = "flScoreboard",
		icon = "fa-list-alt"
	})
end

function GM:OnMenuPanelOpen(menuPanel, activePanel)
	activePanel:SetPos(ScrW() / 2 - activePanel:GetWide() / 2 + 64, 256)
end

function GM:AddMainMenuItems(panel, sidebar)
	local scrW, scrH = ScrW(), ScrH()

	panel:AddButton("#MainMenu_New", function(btn)
		panel.menu = theme.CreatePanel("CharacterCreation", panel)

		if (panel.menu.AddSidebarItems) then
			panel:RecreateSidebar()
			panel.menu:AddSidebarItems(sidebar, panel)
		end
	end)

	local loadBtn = panel:AddButton("#MainMenu_Load", function(btn)
		panel.menu = vgui.Create("DFrame", panel)
		panel.menu:SetPos(scrW / 2 - 300, scrH / 4)
		panel.menu:SetSize(600, 600)
		panel.menu:SetTitle("LOAD CHARACTER")

		panel.menu.Paint = function(lp, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
			draw.SimpleText("Which one to load", "DermaLarge", 0, 24)

			if (#fl.client:GetAllCharacters() <= 0) then
				draw.SimpleText("wow you have none", "DermaLarge", 0, 64)
			end
		end

		panel.menu:MakePopup()

		panel.menu.buttons = {}

		local offY = 0

		for k, v in ipairs(fl.client:GetAllCharacters()) do
			panel.menu.buttons[k] = vgui.Create("DButton", panel.menu)
			panel.menu.buttons[k]:SetPos(8, 100 + offY)
			panel.menu.buttons[k]:SetSize(128, 24)
			panel.menu.buttons[k]:SetText(v.name)
			panel.menu.buttons[k].DoClick = function()
				netstream.Start("PlayerSelectCharacter", v.uniqueID)
				panel:Remove()
			end

			offY = offY + 28
		end
	end)

	if (#fl.client:GetAllCharacters() <= 0) then
		loadBtn:SetEnabled(false)
	end

	if (fl.client:GetCharacter()) then
		panel:AddButton("#MainMenu_Cancel", function(btn)
			panel:Remove()
		end)
	else
		panel:AddButton("Disconnect", function(btn)
			RunConsoleCommand("disconnect")
		end)
	end
end

function GM:AddAdminMenuItems(panel, sidebar)
	sidebar:AddButton("Manage Config")
	sidebar:AddButton("Manage Players")
	sidebar:AddButton("Manage Admins")
	sidebar:AddButton("Group Editor")
	sidebar:AddButton("Item Editor")
	panel:AddPanel("Admin_PermissionsEditor", "Permissions", "manage_permissions")
end

function GM:PlayerBindPress(player, bind, bPressed)
	if (bind:find("gmod_undo") and bPressed) then
		if (hook.Run("SoftUndo", player) != nil) then
			return true
		end
	end
end

function GM:ContextMenuOpen()
	return fl.client:HasPermission("context_menu")
end

function GM:SoftUndo(player)
	netstream.Start("SoftUndo")

	if (#fl.undo:GetPlayer(fl.client) > 0) then return true end
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