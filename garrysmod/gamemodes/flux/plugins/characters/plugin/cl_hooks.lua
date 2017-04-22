--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flCharacters:PlayerInitialized()
	if (!fl.client:GetCharacter()) then
		fl.IntroPanel = theme.CreatePanel("MainMenu")
		fl.IntroPanel:MakePopup()
	end
end

do
	local curVolume = 1

	function flCharacters:Tick()
		if (fl.menuMusic and !IsValid(fl.IntroPanel)) then
			if (curVolume > 0.05) then
				curVolume = Lerp(0.1, curVolume, 0)
				fl.menuMusic:SetVolume(curVolume)
			else
				curVolume = 1
				fl.menuMusic:Stop()
				fl.menuMusic = nil
			end
		end
	end
end

function flCharacters:OnThemeLoaded(activeTheme)
	activeTheme:AddPanel("MainMenu", function(id, parent, ...)
		return vgui.Create("flMainMenu", parent)
	end)

	activeTheme:AddPanel("CharacterCreation", function(id, parent, ...)
		return vgui.Create("flCharacterCreation", parent)
	end)

	activeTheme:AddPanel("CharCreation_General", function(id, parent, ...)
		return vgui.Create("flCharCreationGeneral", parent)
	end)

	activeTheme:AddPanel("CharCreation_Model", function(id, parent, ...)
		return vgui.Create("flCharCreationModel", parent)
	end)
end

function flCharacters:AddTabMenuItems(menu)
	menu:AddMenuItem("!mainmenu", {
		title = "Main Menu",
		icon = "fa-users",
		override = function(menuPanel, button)
			menuPanel:SafeRemove()
			fl.IntroPanel = theme.CreatePanel("MainMenu")
		end
	})
end

function flCharacters:OnIntroPanelCreated(panel)
	panel:CloseMenu()
end

function flCharacters:PostCharacterLoaded(nCharID)
	if (IsValid(fl.IntroPanel)) then
		fl.IntroPanel:SafeRemove()
	end
end

function flCharacters:ShouldDrawLoadingScreen()
	if (!fl.IntroPanel) then
		return true
	end
end

function flCharacters:ShouldHUDPaint()
	return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardHide()
	return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardShow()
	return fl.client:CharacterLoaded()
end

netstream.Hook("PlayerCreatedCharacter", function(success, status)
	if (IsValid(fl.IntroPanel) and IsValid(fl.IntroPanel.menu)) then
		if (success) then
			fl.IntroPanel:RecreateSidebar(true)

			if (fl.IntroPanel.menu.Close) then
				fl.IntroPanel.menu:Close()
			else
				fl.IntroPanel.menu:SafeRemove()
			end
		else
			local text = "We were unable to create a character! (unknown error)"
			local hookText = hook.Run("GetCharCreationErrorText", success, status)

			if (hookText) then
				text = hookText
			elseif (status == CHAR_ERR_NAME) then
				text = "Your character's name must be between "..config.Get("character_min_name_len").." and "..config.Get("character_max_name_len").." characters long!"
			elseif (status == CHAR_ERR_DESC) then
				text = "Your character's description must be between "..config.Get("character_min_desc_len").." and "..config.Get("character_max_desc_len").." characters long!"
			elseif (status == CHAR_ERR_GENDER) then
				text = "You must pick a gender for your character before continuing!"
			elseif (status == CHAR_ERR_MODEL) then
				text = "You have not chosen a model or the one you have chosen is invalid!"
			end

			local panel = vgui.Create("flNotification", fl.IntroPanel)
			panel:SetText(text)
			panel:SetLifetime(6)
			panel:SetTextColor(Color("red"))
			panel:SetBackgroundColor(Color(50, 50, 50, 220))

			local w, h = panel:GetSize()
			panel:SetPos(ScrW() / 2 - w / 2, ScrH() - 128)

			function panel:PostThink() self:MoveToFront() end
		end
	end
end)