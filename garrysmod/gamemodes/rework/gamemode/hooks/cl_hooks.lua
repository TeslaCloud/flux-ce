--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

timer.Remove("HintSystem_OpeningMenu");
timer.Remove("HintSystem_Annoy1");
timer.Remove("HintSystem_Annoy2");

do
	local scrW, scrH = ScrW(), ScrH();

	-- This will let us detect whether the resolution has been changed, then call a hook if it has.
	function GM:Tick()
		local newW, newH = ScrW(), ScrH();

		if (scrW != newW or scrH != newH) then
			rw.core:Print("Resolution changed from "..scrW.."x"..scrH.." to "..newW.."x"..newH..".");

			plugin.Call("OnResolutionChanged", newW, newH, scrW, scrH);

			scrW, scrH = newW, newH;
		end;
	end;
end;

-- Called when the resolution has been changed and fonts need to be resized to fit the client's res.
function GM:OnResolutionChanged(oldW, oldH, newW, newH)
	rw.fonts:CreateFonts();
end;

-- Called when the client connects and spawns.
function GM:InitPostEntity()
	rw.client = rw.client or LocalPlayer();

	if (!rw.client:GetActiveCharacter()) then
		rw.IntroPanel = vgui.Create("rwIntro");
		rw.IntroPanel:MakePopup();
	end;

 	for k, v in ipairs(player.GetAll()) do
 		local model = v:GetModel();

 		plugin.Call("PlayerModelChanged", v, model, model);
 	end;
end;

function GM:RenderScreenspaceEffects()
	if (rw.client.colorModify) then
		DrawColorModify(rw.client.colorModifyTable);
	end;
end;

function GM:HUDDrawScoreBoard() end;

-- Called when the scoreboard should be shown.
function GM:ScoreboardShow()
	if (rw.client:HasInitialized()) then
		if (rw.tabMenu and rw.tabMenu.CloseMenu) then
			rw.tabMenu:CloseMenu(true);
		end;

		rw.tabMenu = theme.CreatePanel("TabMenu", nil, "rwTabMenu");
		rw.tabMenu:MakePopup();
		rw.tabMenu.heldTime = CurTime() + 0.3;
	end;
end;

-- Called when the scoreboard should be hidden.
function GM:ScoreboardHide()
	if (rw.client:HasInitialized()) then
		if (rw.tabMenu and rw.tabMenu.heldTime and CurTime() >= rw.tabMenu.heldTime) then
			rw.tabMenu:CloseMenu();
		end;
	end;
end;

-- Called when category icons are presented.
function GM:AdjustTabDockMenus(menus)
	menus["Inventory"] = {
		icon = "fa-suitcase"
	};
	menus["Settings"] = {
		icon = "fa-cog",
		menu = "rwSettings"
	};
	menus["MainMenu"] = {
		icon = "fa-home",
		callback = function(panel)
			panel:CloseMenu(true);

			rw.IntroPanel = theme.CreatePanel("MainMenu", nil, "reMainMenu");
			rw.IntroPanel:MakePopup();
		end
	};
	menus["Scoreboard"] = {
		menu = "rwScoreboard",
		icon = "fa-users"
	};
end;

local colorWhite = Color(255, 255, 255, 255);
local colorBlack = Color(0, 0, 0, 170);

local expandDuration = 0.15;

function GM:AdjustSettingCallbacks(callbacks)
	callbacks["DCheckBox"] = function(panel, parent, setting)
		local boxSize = parent:GetTall() * 0.4;

		panel:SetSize(boxSize, boxSize);
		panel:SetPos(parent:GetWide() * 0.99 - panel:GetWide(), parent:GetTall() * 0.5 - panel:GetTall() * 0.5);
		panel:SetConVar("RW_"..setting.id);

		function panel:Paint(w, h)
			local curTime = CurTime();

			if (self:IsHovered() and !self.hovered) then
				self.lerpTime = curTime;
				self.hovered = true;
			elseif (!self:IsHovered() and self.hovered) then
				self.lerpTime = curTime;
				self.hovered = false;
			end;

			if (self.lerpTime) then
				local fraction = (curTime - self.lerpTime) / expandDuration;

				if (self.hovered) then
					self.textAlpha = Lerp(fraction, colorWhite.a, 170);
				else
					self.textAlpha = Lerp(fraction, 170, colorWhite.a);
				end;
			end;

			draw.RoundedBox(5, 0, 0, w, h, ColorAlpha(rw.settings:GetColor("TextColor"), self.textAlpha));

			if (self:GetChecked() and self.checked) then
				self.checkTime = curTime;
				self.checked = false;
			elseif (!self:GetChecked() and !self.checked) then
				self.checkTime = curTime;
				self.checked = true;
			end;

			if (self.checkTime) then
				local fraction = (curTime - self.checkTime) / expandDuration;

				if (self.checked) then
					self.iconAlpha = Lerp(fraction, colorBlack.a, 0);
					self.size = Lerp(fraction, h * 0.95, 0);
				else
					self.iconAlpha = Lerp(fraction, 0, colorBlack.a);
					self.size = Lerp(fraction, 0, h * 0.95);
				end;
			end;

			rw.fa:Draw("fa-check", w * 0.5, h * 0.5, self.size or h * 0.95, ColorAlpha(colorBlack, self.iconAlpha or colorBlack.a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
		end;
	end;

	callbacks["DComboBox"] = function(panel, parent, setting)
		panel:SetSize(parent:GetWide() * 0.98, parent:GetTall() * 0.6);
		panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25);

		parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall());

		if (istable(setting.info)) then
			for k, v in pairs(setting.info) do
				panel:AddChoice(v, k);
			end;
		end;

		function panel:OnSelect(index, value, data)
			if (data) then
				value = data;
			end;

			rw.settings:SetValue(setting.id, value);
		end;

		panel:SetConVar("RW_"..setting.id);
	end;

	callbacks["DTextEntry"] = function(panel, parent, setting)
		panel:SetSize(parent:GetWide() * 0.98, parent:GetTall() * 0.6);
		panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25);
		panel:SetConVar("RW_"..setting.id);
		panel:SetFont("menu_light_tiny");
		panel:SetTextColor(rw.settings:GetColor("TextColor"));
		panel:SetDrawBackground(false);
		panel.oldThink = panel.Think;

		panel.Think = function(entry)
			entry:SetTextColor(rw.settings:GetColor("TextColor"));
			entry:oldThink();
		end;

		local back = vgui.Create("EditablePanel", parent);
		back:SetPos(panel.x, panel.y);
		back:SetSize(panel:GetWide(), panel:GetTall());
		back:MoveToBefore(panel);

		function back:Paint(w, h)
			surface.SetDrawColor(colorBlack);
			surface.DrawRect(0, 0, w, h);
		end;

		parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall());
	end;

	callbacks["DColorMixer"] = function(panel, parent, setting)
		panel:SetSize(parent:GetWide() * 0.98, ScrH() * 0.23);
		panel:SetPos(parent.label.x, parent.label.y + parent.label:GetTall() * 1.25);
		panel:SetConVarR("RW_"..setting.id.."_R");
		panel:SetConVarG("RW_"..setting.id.."_G");
		panel:SetConVarB("RW_"..setting.id.."_B");
		panel:SetConVarA("RW_"..setting.id.."_A");

		parent:SetSize(parent:GetWide(), parent:GetTall() + parent.label:GetTall() * 0.1 + panel:GetTall());		
	end;

	callbacks["DNumSlider"] = function(panel, parent, setting)	
		local w, h = parent:GetWide(), parent:GetTall();
		local offset = w * 0.77;
		local decimals = 0;

		if (setting.info) then
			if (setting.info.min) then
				panel:SetMin(setting.info.min);
			end;

			if (setting.info.max) then
				panel:SetMax(setting.info.max);
			end;

			if (setting.info.decimals) then
				panel:SetDecimals(setting.info.decimals);
			end;

			if (setting.info.decimals) then
				decimals = setting.info.decimals;
			end;
		end;

		panel:SetSize(w + offset, h * 0.8);
		panel:SetPos(w - panel:GetWide() * 0.98, parent.label.y + parent.label:GetTall() * 1.25);
		panel:SetConVar("RW_"..setting.id);
		panel:SetText("");

		panel.Slider.Paint = function(slider, w, h)
			local num = slider:GetNotches();

			surface.SetDrawColor(rw.settings:GetColor("TextColor"));
			surface.DrawRect(8, h / 2 - 1, w - 15, 1);

			if (!num) then return; end;

			local x, y = 8, h / 2 - 1;
			local space = w / num;

			for i = 0, num do	
				surface.DrawRect(x + i * space, y + 4, 1, 5);
			end;
		end;

		panel.TextArea.Paint = function(label, w, h)
		end;

		parent.numLabel = vgui.Create("DTextEntry", parent);
		parent.numLabel:SetFont("menu_thin_smaller");
		parent.numLabel:SetText(panel:GetValue());
		parent.numLabel:SetTextColor(rw.settings:GetColor("TextColor"));			
		parent.numLabel:SizeToContents();
		parent.numLabel:SetPos(parent:GetWide() * 0.01, panel.y + panel:GetTall() * 1.1);
		parent.numLabel:SetSize(parent:GetWide(), parent.numLabel:GetTall());
		parent.numLabel:SetConVar("RW_"..setting.id);
		parent.numLabel:SetDrawBackground(false);

		parent:SetSize(w, h + parent.label:GetTall() * 0.1 + panel:GetTall() * 1.1 + parent.numLabel:GetTall());
	end;
end;

local colorRed = Color(200, 30, 30);
local colorDark = Color(40, 40, 40);
local colorBlue = Color(30, 100, 200);

rw.bars:Register("health", {
	text = "HEALTH",
	color = Color(200, 40, 40),
	maxValue = 100
}, true);

rw.bars:Register("armor", {
	text = "armor",
	color = Color(80, 80, 220),
	maxValue = 100
}, true);

-- Called when the player's HUD is drawn.
function GM:HUDPaint()
	if (!IsValid(rw.IntroPanel)) then
		if (!plugin.Call("RWHUDPaint") and rw.settings:GetBool("DrawBars")) then
			rw.bars:SetValue("health", rw.client:Health());
			rw.bars:SetValue("armor", rw.client:Armor());
			rw.bars:DrawTopBars();

			self.BaseClass:HUDPaint();
		end;
	end;
end;

function GM:HUDDrawTargetID()
	if (IsValid(rw.client) and rw.client:Alive()) then
		local trace = rw.client:GetEyeTraceNoCursor();
		local ent = trace.Entity;

		if (IsValid(ent)) then
			local screenPos = (trace.HitPos + Vector(0, 0, 16)):ToScreen();
			local x, y = screenPos.x, screenPos.y;
			local distance = rw.client:GetPos():Distance(trace.HitPos);

			if (ent:IsPlayer()) then
				plugin.Call("DrawPlayerTargetID", ent, x, y, distance);
			elseif (ent.DrawTargetID) then
				ent:DrawTargetID(x, y, distance);
			end;
		end;
	end;
end;

function GM:DrawPlayerTargetID(player, x, y, distance)
	if (distance < 640) then
		local alpha = 255;

		if (distance > 500) then
			local d = distance - 500;
			alpha = math.Clamp((255 * (140 - d) / 140), 0, 255);
		end;

		local width, height = util.GetTextSize(player:Name(), "tooltip_large");
		draw.SimpleText(player:Name(), "tooltip_large", x - width * 0.5, y - 40, Color(255, 255, 255, alpha));

		local width, height = util.GetTextSize(player:GetPhysDesc(), "tooltip_small");
		draw.SimpleText(player:GetPhysDesc(), "tooltip_small", x - width * 0.5, y - 14, Color(255, 255, 255, alpha));
		
		if (distance < 125) then
			if (distance > 90) then
				local d = distance - 90;
				alpha = math.Clamp((255 * (35 - d) / 35), 0, 255);
			end;

			local smallerFont = rw.fonts:GetSize("tooltip_small", 12);
			local width, height = util.GetTextSize("#TargetID_Information", smallerFont);
			draw.SimpleText("#TargetID_Information", smallerFont, x - width * 0.5, y + 5, Color(50, 255, 50, alpha));
		end;
	end;
end;

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
			return false;
		end

		return true;
	end
end;