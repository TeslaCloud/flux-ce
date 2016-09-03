--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local PANEL = {};

local lerpDuration = 0.3;
local closeDuration = 0.1;

local colorBlack = Color(0, 0, 0, 255);
local colorWhite = Color(255, 255, 255, 100);

function PANEL:Init()
	RestoreCursorPosition();

	local scrW, scrH = ScrW(), ScrH();

	self.offset = 0;

	self:SetSize(scrW, scrH);
	self:SetPos(0, 0);

	self.playerLabel = vgui.Create("rwTabPlayerLabel", self);
	self.charPanel = vgui.Create("rwTabCharacter", self);
	self.dock = vgui.Create("rwTabDock", self);

	self.dateTime = vgui.Create("rwTabDate", self);
	self.dateTime:SetSize(self.charPanel:GetWide(), scrH * 0.075);
	self.dateTime:SetPos(self.charPanel.x, scrH * 0.01);

	self.viewPort = vgui.Create("DButton", self);

	self.viewPort:SetSize(scrW, scrH);
	self.viewPort:SetPos(0, 0);

	self.viewPort.Paint = function(viewPort, w, h)
		local x, y = viewPort:GetPos();

		render.RenderView({
			x = x,
			y = y,
			w = w,
			h = h,
			drawhud = true,
			dopostprocess = true
		});

		return true;
	end;

	self.viewPort.DoClick = function(viewPort)
		self:CloseMenu();
	end;

	self.lerpStart = CurTime();
end;

function PANEL:CloseMenu(bForce)
	if (bForce) then
		rw.tabMenu:Remove();
		rw.tabMenu = nil;

		if (timer.Exists("rwCloseTabMenu")) then
			timer.Remove("rwCloseTabMenu");
		end;

		return;
	end;

	self.reverseStart = CurTime();

	timer.Create("rwCloseTabMenu", lerpDuration * 0.25, 1, function()
		RememberCursorPosition();

		self:CloseMenu(true);
	end);
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorBlack);
end;

function PANEL:Think(w, h)
	if (self.lerpStart) then
		local scrW, scrH = ScrW(), ScrH();
		local fraction = (CurTime() - self.lerpStart) / lerpDuration;
		local targetW, targetH = scrW * 0.6, scrH * 0.6;
		local targetX, targetY = scrW * 0.115, scrH * 0.1;

		self.viewPort:SetSize(Lerp(fraction, scrW, targetW), Lerp(fraction, scrH, targetH));
		self.viewPort:SetPos(Lerp(fraction, 0, targetX), Lerp(fraction, 0, targetY));

		if (fraction >= 1) then
			self.lerpStart = nil;

			self.viewPort:SetSize(targetW, targetH);
			self.viewPort:SetPos(targetX, targetY);
		end;
	elseif (self.reverseStart) then
		if (!self.startX) then
			self.startX = self.viewPort.x;
			self.startY = self.viewPort.y;	
			self.startW = self.viewPort:GetWide();
			self.startH = self.viewPort:GetTall();
		end;

		local scrW, scrH = ScrW(), ScrH();
		local fraction = (CurTime() - self.reverseStart) / closeDuration;
	//	local oldW, oldH = scrW * 0.6, scrH * 0.6;
	//	local oldX, oldY = scrW * 0.1, scrH * 0.1;

		self.viewPort:SetSize(Lerp(fraction, self.startW, scrW), Lerp(fraction, self.startH, scrH));
		self.viewPort:SetPos(Lerp(fraction, self.startX, 0), Lerp(fraction, self.startY, 0));
	end;
end;

local function GetClassName(panel)
	return panel:GetTable().ClassName;
end;

function PANEL:OpenChildMenu(menu)
	local class = nil;

	if (self.menu) then
		class = GetClassName(self.menu);
		self:CloseChildMenu();
	end;
	
	if (!class or (class and class != menu)) then
		self.menu = vgui.Create(menu, self);
		self.menu:SetPos(self:GetWide() * 0.5, self:GetTall() * 0.5);
		self.menu:SetSize(1, 1);

		self.menu.OpenAnim = function(panel)
			local scrW, scrH = ScrW(), ScrH();

			local x = scrW * 0.25 + self.offset;

		//	if (self.bExpanded == true) then
	//			x = x + ScrW() * 0.1;
		//	end;

			panel:SetSize(scrW * 0.5, scrH * 0.5);
			panel:SetPos(x, scrH * 0.1);
		//	panel:SizeTo(scrW * 0.5, scrH * 0.5);
		//	panel:MoveTo(scrW * 0.5 - panel:GetWide() * 0.5, scrH * 0.5 - panel:GetTall() * 0.5);
		end;

		self.menu:OpenAnim();

		self.dock:ToggleMenuExpand();
	end;
end;

function PANEL:CloseChildMenu()
	if (self.menu) then
		self.menu:Remove();
		self.menu = nil;
	end;
end;

derma.DefineControl("rwTabMenu", "", PANEL, "DPanel");

hook.Add("RenderScene", "rwTabMenu", function()
	if (rw.tabMenu) then
		return true;
	end;
end);

local PANEL = {};

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetPos(scrW * -0.2, scrH * 0.1);
	self:SetSize(scrW * 0.31, scrH * 0.6);

	self.alpha = 0;
	
	local size = scrW * 0.02;
	local x = self:GetWide() - size;
	local y = self:GetTall() * 0.15;

	self.expand = vgui.Create("rwTabDockButton", self);

	self.expand:SetSize(size, size);
	self.expand:SetPos(x * 1, 0);
	self.expand.icon = "fa-bars";
	self.expand.size = size;

	self.expand:SetCallback(function(panel)
		self:ToggleExpand();
	end);

	self.menus = {};

	plugin.Call("AdjustTabDockMenus", self.menus);

	for k, v in pairs(self.menus) do
		local button = vgui.Create("rwTabDockButton", self);

		button:SetSize(size, size);
		button:SetPos(x, y);
		button.size = size;
		button.icon = v.icon;
		button.menu = v.menu;

		button.DoClick = function(panel)
			if (panel.menu) then
				self:GetParent():OpenChildMenu(panel.menu);
			end;
		end;

		v.button = button;

		y = y + (size * 1.75);
	end;
end;

local expandDuration = 0.3;

function PANEL:ToggleExpand()
	local offset = ScrW() * 0.1;
	local parent = self:GetParent();

	if (self.bExpanded == nil) then
		self.bExpanded = true;
	end;

	if (self.bExpanded) then
		self.target = colorWhite.a;
	else
		self.target = 0;
	end;

	for k, v in pairs(parent:GetChildren()) do
		if (v == parent.playerLabel or v == parent.dateTime or (self.bMenuExpanded == false and v == parent.viewPort)) then
			continue;
		end;

		if (self.bExpanded) then
			v:MoveTo(v.x + offset, v.y, expandDuration);

			parent.offset = parent.offset + offset;
		else
			v:MoveTo(v.x - offset, v.y, expandDuration);

			parent.offset = parent.offset - offset;
		end;
	end;

	self.bExpanded = !self.bExpanded;
	self.expandStart = CurTime();
	self.origin = self.alpha;
end;

function PANEL:ToggleMenuExpand()
	local offset = ScrW() * 0.71;
	local parent = self:GetParent();

	if (self.bMenuExpanded == nil) then
		self.bMenuExpanded = true;
	end;

	for k, v in pairs(parent:GetChildren()) do
		if (v == parent.playerLabel or v == parent.dateTime or v == self or v == parent.menu) then
			continue;
		end;

		if (v == parent.viewPort and self.bExpanded == false) then
			offset = offset - ScrW() * 0.1;
		end;

		if (self.bMenuExpanded) then
			v:MoveTo(v.x + offset, v.y, expandDuration);

			self.lerpStart = CurTime();

		//	parent.offset = parent.offset + offset;
		else
			v:MoveTo(v.x - offset, v.y, expandDuration);

			self.reverseStart = CurTime();

		//	parent.offset = parent.offset - offset;
		end;

		if (v == parent.viewPort and self.bExpanded == false) then
			offset = offset + ScrW() * 0.1;
		end;
	end;

	self.bMenuExpanded = !self.bMenuExpanded;
end;

function PANEL:Think()
	if (self.lerpStart) then
		local parent = self:GetParent();
		local scrW, scrH = ScrW(), ScrH();
		local fraction = (CurTime() - self.lerpStart) / expandDuration;
		local targetW, targetH = scrW * 0.15, scrH * 0.15;

		if (!self.startW) then
			self.startW = parent.viewPort:GetWide();
			self.startH = parent.viewPort:GetTall();	
		end;

		parent.viewPort:SetSize(Lerp(fraction, self.startW, targetW), Lerp(fraction, self.startH, targetH));

		if (fraction >= 1) then
			self.lerpStart = nil;
			self.startW = nil;
			self.startH = nil;

			parent.viewPort:SetSize(targetW, targetH);
		end;
	elseif (self.reverseStart) then
		local parent = self:GetParent();

		if (!self.startW) then
			self.startW = parent.viewPort:GetWide();
			self.startH = parent.viewPort:GetTall();	
		end;

		local scrW, scrH = ScrW(), ScrH();
		local fraction = (CurTime() - self.reverseStart) / expandDuration;
		local targetW, targetH = scrW * 0.6, scrH * 0.6;

		parent.viewPort:SetSize(Lerp(fraction, self.startW, targetW), Lerp(fraction, self.startH, targetH));

		if (fraction >= 1) then
			self.reverseStart = nil;
			self.startW = nil;
			self.startH = nil;

			parent.viewPort:SetSize(targetW, targetH);
		end;
	end;
end;

function PANEL:Paint(w, h)
	if (self.expandStart) then
		local fraction = (CurTime() - self.expandStart) / expandDuration;

		self.alpha = Lerp(fraction, self.origin, self.target);

		if (fraction >= 1) then
			if (!self.bExpanded) then
				self.alpha = colorWhite.a;
			else
				self.alpha = 0;
			end;

			self.origin = nil;
			self.expandStart = nil;
		end;
	end;

	if (self.alpha > 0) then
		draw.SimpleText("#TabMenu_Expand", "DermaLarge", self.expand.x * 0.97, self.expand.y + self.expand:GetTall() * 0.5, ColorAlpha(colorWhite, self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER);

		for k, v in pairs(self.menus) do
			draw.SimpleText("#TabMenu_"..k, "DermaLarge", v.button.x * 0.97, v.button.y + v.button:GetTall() * 0.5, ColorAlpha(colorWhite, self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER);
		end;
	end;
end;

derma.DefineControl("rwTabDock", "", PANEL, "DScrollPanel");

local PANEL = {};

function PANEL:Init()
	self:SetText("");
end;

function PANEL:SetCallback(callback)
	function self:DoClick()
		callback(self);
	end;
end;

function PANEL:Paint(w, h)
	local color = self.color or colorWhite;

	if (self:IsHovered()) then
		color = ColorAlpha(color, 255);
	end;

	rw.fa:Draw(self.icon or "fa-bars", w * 0.5, h * 0.5, self.size or 16, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
end;

derma.DefineControl("rwTabDockButton", "", PANEL, "DButton");

local PANEL = {};

function PANEL:Init()
end;

local days = {
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday"
};

function PANEL:Paint(w, h)
	local date = os.date("*t", os.time());
	local day = days[date.wday - 1];
	local month = date.month;
	local year = date.year;
	local hour = date.hour;

	local am = "AM";

	if (hour > 12) then
		am = "PM";
		hour = hour - 12;
	elseif (hour == 0) then
		hour = 12;
	end;

	local min = date.min;

	// or else it will look like 7:3 PM for 7:03 PM.
	if (min < 10) then
		min = "0"..min;
	end;

	// 24 Hour String
//	local timeText = hour..":"..date.min;
	local timeText = hour..":"..min.." "..am;
	local dateText = day.." "..date.day.."/"..month.."/"..year;

	draw.SimpleText(timeText, "DermaLarge", w, h * 0.5, colorWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP);
	draw.SimpleText(dateText, "DermaLarge", 0, h * 0.5, colorWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP);
end;

derma.DefineControl("rwTabDate", "", PANEL, "DPanel");

local PANEL = {};

--[[
	Credits to Willox on facepunch for the minimap code. BIG thank you!
	https://facepunch.com/member.php?u=257577
--]]
local function GenerateCircleVertices( x, y, radius, ang_start, ang_size )
    local vertices = {};
    local passes = 64; -- Seems to look pretty enough
    
    -- Ensure vertices resemble sector and not a chord
    vertices[ 1 ] = { 
        x = x,
        y = y
    };

    for i = 0, passes do
        local ang = math.rad(-90 + ang_start + ang_size * i / passes);

        vertices[ i + 2 ] = {
            x = x + math.cos( ang ) * radius,
            y = y + math.sin( ang ) * radius
        };
    end;

    return vertices;
end;

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.2, scrH * 0.075);
	self:SetPos(scrW * 0.115, scrH * 0.01);

	self.avatar = vgui.Create("AvatarImage", self);
	self.avatar:SetSize(self:GetTall() * 0.9, self:GetTall() * 0.9);
	self.avatar:SetPos(self:GetWide() * 0.025, self:GetTall() * 0.05);
	self.avatar:SetPlayer(rw.client, 64);
	self.avatar:SetPaintedManually(true);
	self.avatar:SetCursor("hand");

	self.avatar.OnMousePressed = function(self)
		gui.OpenURL("http://steamcommunity.com/profiles/"..rw.client:SteamID64());
	end;

	self.avatar.inner_vertices = GenerateCircleVertices(
		self.avatar.x + (self.avatar:GetWide() * 0.5), 
		self.avatar.y + (self.avatar:GetTall() * 0.5), 
		self.avatar:GetWide() * 0.5,
		0, 360
	);
end;

function PANEL:Paint(w, h)
	draw.SimpleText(rw.client:Name(), "DermaLarge", w * 0.25, h * 0.5, colorWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP);

	-- Circle Avatar
	render.PushFilterMag(TEXFILTER.ANISOTROPIC);
	render.PushFilterMin(TEXFILTER.ANISOTROPIC);

		render.SetStencilEnable(true);
			render.SetStencilReferenceValue(1);

			render.SetStencilWriteMask(1);
			render.SetStencilTestMask(1);

			render.SetStencilPassOperation(STENCIL_REPLACE);
			render.SetStencilFailOperation(STENCIL_KEEP);
			render.SetStencilZFailOperation(STENCIL_KEEP);

			render.ClearStencil();

			render.SetStencilCompareFunction(STENCIL_NOTEQUAL);
				surface.DrawPoly(self.avatar.inner_vertices);
			render.SetStencilCompareFunction(STENCIL_EQUAL);
				self.avatar:PaintManual();
			render.ClearStencil();
	render.SetStencilEnable(false);

	render.PopFilterMag();
	render.PopFilterMin();
end;

derma.DefineControl("rwTabPlayerLabel", "", PANEL, "DPanel");

local PANEL = {};

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.25, scrH * 0.6);
	self:SetPos(scrW * 0.725, scrH * 0.1);

	self.modelPanel = vgui.Create("DModelPanel", self);
	self.modelPanel:SetSize(self:GetWide(), self:GetTall());
	self.modelPanel:SetPos(0, 0);
	self.modelPanel:SetModel(rw.client:GetModel());
	self.modelPanel:SetCamPos(Vector(50, 10, 50));
	self.modelPanel:SetLookAt(Vector(0, 0, 35));

	function self.modelPanel:LayoutEntity(ent)
		self:RunAnimation();
	end;

	function self.modelPanel:Think()
		if (self.bDragging) then
			if (!input.IsMouseDown(MOUSE_LEFT)) then
				self.lastMouseX = nil;
				self.bDragging = false;

				return;
			end;

			local ent = self:GetEntity();

			if (IsValid(ent)) then
				local mouseX, mouseY = input.GetCursorPos();

				if (!self.lastMouseX) then
					self.lastMouseX = mouseX;
				end;

				local mouseXDiff = mouseX - self.lastMouseX;
				local entAngles = ent:GetAngles();

				ent:SetAngles(entAngles + Angle(0, mouseXDiff, 0));

				self.lastMouseX = mouseX;
			end;
		end;
	end;

	function self.modelPanel:OnMousePressed(key)
		if (key == MOUSE_LEFT) then
			self.bDragging = true;
		end;
	end;
end;

function PANEL:Think()
	self:SetAnimation(rw.client:GetSequence());
end;

function PANEL:SetAnimation(anim)
	if (!anim) then return; end;

	local ent = self.modelPanel:GetEntity();

	if (IsValid(ent)) then
		-- We do this check so our client doesn't crash if we supply an anim the model doesn't have.
		if (isnumber(anim) and anim >= 0) then
			ent:SetSequence(anim);
		end;
	end;
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorWhite);
end;

derma.DefineControl("rwTabCharacter", "", PANEL, "DPanel");

local PANEL = {};

function PANEL:Init()
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorWhite);
end;

derma.DefineControl("rwSettings", "", PANEL, "DPanel");