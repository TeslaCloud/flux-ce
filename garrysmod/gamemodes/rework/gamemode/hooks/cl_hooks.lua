--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

timer.Remove("HintSystem_OpeningMenu")
timer.Remove("HintSystem_Annoy1")
timer.Remove("HintSystem_Annoy2")

-- Called when the client connects and spawns.
function GM:InitPostEntity()
	rw.client = rw.client or LocalPlayer()

	if (!rw.client:GetCharacter()) then
		rw.IntroPanel = theme.CreatePanel("MainMenu")
		rw.IntroPanel:MakePopup()
	end

 	for k, v in ipairs(player.GetAll()) do
 		local model = v:GetModel()

 		hook.Run("PlayerModelChanged", v, model, model)
 	end

 	local toolGun = weapons.GetStored("gmod_tool")

	for k, v in pairs(rw.tool:GetAll()) do
		toolGun.Tool[v.Mode] = v
	end

 	plugin.Call("RWInitPostEntity")
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
				rw.core:Print("Resolution changed from "..scrW.."x"..scrH.." to "..newW.."x"..newH..".")

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

function GM:OneMinute()
	local curTime = CurTime()

	if (curTime >= (rw.client.nextHint or 0)) then
		rw.hint:DisplayRandom()

		rw.client.nextHint = curTime + 300
	end
end

-- Called when the resolution has been changed and fonts need to be resized to fit the client's res.
function GM:OnResolutionChanged(oldW, oldH, newW, newH)
	rw.fonts:CreateFonts()
end

-- Called when the scoreboard should be shown.
function GM:ScoreboardShow()
	if (rw.client:HasInitialized()) then
		if (rw.tabMenu and rw.tabMenu.CloseMenu) then
			rw.tabMenu:CloseMenu(true)
		end

		rw.tabMenu = theme.CreatePanel("TabMenu", nil, "rwTabMenu")
		rw.tabMenu:MakePopup()
		rw.tabMenu.heldTime = CurTime() + 0.3
	end
end

-- Called when the scoreboard should be hidden.
function GM:ScoreboardHide()
	if (rw.client:HasInitialized()) then
		if (rw.tabMenu and rw.tabMenu.heldTime and CurTime() >= rw.tabMenu.heldTime) then
			rw.tabMenu:CloseMenu()
		end
	end
end

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
	if (!IsValid(rw.IntroPanel)) then
		local curTime = CurTime()

		if (rw.client.lastDamage and rw.client.lastDamage > (curTime - 0.3)) then
			local alpha = 255 - 255 * (curTime - rw.client.lastDamage) * 3.75
			draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(255, 255, 255, alpha))
		end

		if (!rw.client:Alive()) then
			local respawnTime = rw.client:GetNetVar("RespawnTime")

			draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(0, 0, 0, 230))
		end

		if (!hook.Run("RWHUDPaint") and rw.settings:GetBool("DrawBars")) then
			rw.bars:DrawTopBars()

			self.BaseClass:HUDPaint()
		end
	end
end

do
	local cache = nil
	local addedCache = nil
	local tempCache = nil
	local renderColor = Color(50, 255, 50)
	local renderColorRed = Color(255, 50, 50)
	local lastAmt = nil
	local render = render

	function GM:PostDrawOpaqueRenderables(bDrawDepth, bDrawSkybox)
		local weapon = rw.client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "area") then
			local tool = rw.client:GetTool()
			local verts = (tool and tool.area and tool.area.verts)

			if (istable(verts) and (!tempCache or #tempCache != #verts)) then
				tempCache = {}

				for k, v in ipairs(verts) do
					local n

					if (k == #verts) then
						n = verts[1]
					else
						n = verts[k + 1]
					end

					table.insert(tempCache, {v, n})
				end
			end

			if (!lastAmt) then lastAmt = areas.GetCount() end
	
			if (!cache or lastAmt != areas.GetCount()) then
				cache = {}
				addedCache = {}

				for k, v in pairs(areas.GetAll()) do
					for k2, v2 in ipairs(v.polys) do
						for idx, p in ipairs(v2) do
							local n

							if (idx == #v2) then
								n = v2[1]
							else
								n = v2[idx + 1]
							end

							local add = Vector(0, 0, v.maxH)

							table.insert(cache, {p, n})
							table.insert(addedCache, {p + add, n + add})
						end
					end
				end
			end

			if (cache) then
				for k, v in ipairs(cache) do
					local p, n, ap, an = v[1], v[2], addedCache[k][1], addedCache[k][2]

					render.DrawLine(p, n, renderColor)
					render.DrawLine(ap, an, renderColor)
					render.DrawLine(ap, p, renderColor)
				end
			end

			if (tempCache) then
				for k, v in ipairs(tempCache) do
					local p, n = v[1], v[2]

					render.DrawLine(p, n, renderColorRed)
				end
			end
		end
	end
end

function GM:HUDDrawTargetID()
	if (IsValid(rw.client) and rw.client:Alive()) then
		local trace = rw.client:GetEyeTraceNoCursor()
		local ent = trace.Entity

		if (IsValid(ent)) then
			local screenPos = (trace.HitPos + Vector(0, 0, 16)):ToScreen()
			local x, y = screenPos.x, screenPos.y
			local distance = rw.client:GetPos():Distance(trace.HitPos)

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

		if (distance > 500) then
			local d = distance - 500
			alpha = math.Clamp((255 * (140 - d) / 140), 0, 255)
		end

		local width, height = util.GetTextSize(player:Name(), "tooltip_large")
		draw.SimpleText(player:Name(), "tooltip_large", x - width * 0.5, y - 40, Color(255, 255, 255, alpha))

		local width, height = util.GetTextSize(player:GetPhysDesc(), "tooltip_small")
		draw.SimpleText(player:GetPhysDesc(), "tooltip_small", x - width * 0.5, y - 14, Color(255, 255, 255, alpha))

		if (distance < 125) then
			if (distance > 90) then
				local d = distance - 90
				alpha = math.Clamp((255 * (35 - d) / 35), 0, 255)
			end

			local smallerFont = rw.fonts:GetSize("tooltip_small", 12)
			local width, height = util.GetTextSize("#TargetID_Information", smallerFont)
			draw.SimpleText("#TargetID_Information", smallerFont, x - width * 0.5, y + 5, Color(50, 255, 50, alpha))
		end
	end
end

function GM:PopulateToolMenu()
	for ToolName, TOOL in pairs(rw.tool:GetAll()) do
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
end

function GM:RenderScreenspaceEffects()
	if (rw.client.colorModify) then
		DrawColorModify(rw.client.colorModifyTable)
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

function GM:HUDDrawScoreBoard() end

-- Called when category icons are presented.
function GM:AddTabMenuItems(menu)
	menu:AddMenuItem("!mainmenu", {
		title = "Main Menu",
		icon = "fa-users",
		override = function(menuPanel, button)
			menuPanel:SafeRemove()
			rw.IntroPanel = theme.CreatePanel("MainMenu")
		end
	})

	menu:AddMenuItem("!inventory", {
		title = "Inventory",
		panel = "reInventory",
		icon = "fa-inbox",
		callback = function(menuPanel, button)
			local inv = menuPanel.activePanel
			inv:SetPlayer(rw.client)
			inv:SetTitle("Inventory")
		end
	})

	menu:AddMenuItem("scoreboard", {
		title = "Scoreboard",
		panel = "rwScoreboard",
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

	panel:AddButton("#MainMenu_Load", function(btn)
		panel.menu = vgui.Create("DFrame", panel)
		panel.menu:SetPos(scrW / 2 - 300, scrH / 4)
		panel.menu:SetSize(600, 600)
		panel.menu:SetTitle("LOAD CHARACTER")

		panel.menu.Paint = function(lp, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
			draw.SimpleText("Which one to load", "DermaLarge", 0, 24)

			if (#rw.client:GetAllCharacters() <= 0) then
				draw.SimpleText("wow you have none", "DermaLarge", 0, 24)
			end
		end

		panel.menu:MakePopup()

		panel.menu.buttons = {}

		local offY = 0

		for k, v in ipairs(rw.client:GetAllCharacters()) do
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

	if (rw.client:GetCharacter()) then
		panel:AddButton("#MainMenu_Cancel", function(btn)
			panel:Remove()
		end)
	end
end

function GM:PlayerBindPress(player, bind, bPressed)
	if (bind:find("gmod_undo") and bPressed) then
		if (hook.Run("SoftUndo", player) != nil) then
			return true
		end
	end
end

function GM:SoftUndo(player)
	netstream.Start("SoftUndo")

	if (#rw.undo:GetPlayer(rw.client) > 0) then return true end
end

do
	local hiddenElements = { -- Hide default HUD elements.
		CHudHealth = true,
		CHudBattery = true,
		CHudAmmo = true,
		CHudSecondaryAmmo = true,
		CHudCrosshair = true,
		CHudHistoryResource = true
	}

	function GM:HUDShouldDraw(element)
		if (hiddenElements[element]) then
			return false
		end

		return true
	end
end