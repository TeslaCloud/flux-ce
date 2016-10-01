local scrW, scrH = ScrW(), ScrH();
local gradient = surface.GetTextureID("vgui/gradient-r")

local PANEL = {};
 
function PANEL:Init()
 
self:SetSize(scrW, scrH);
self:SetPos(0, 0);
 
self.ph1 = vgui.Create("DPanel", self);
self.ph1:SetSize(scrW, scrH)
self.ph1:SetPos(0, 0)
 
self.ph1.Paint = function(panel, w, h)
surface.SetDrawColor(255, 255, 255, 2);
surface.SetTexture(gradient)
surface.DrawTexturedRect(0, 0, w, h);

self.tbb = vgui.Create("DButton", self);
self.tbb:SetSize(250, 35)
self.tbb:SetPos(scrW*0.025,scrH*0.5)
self.tbb:SetText("Settings")

self.tbb.Paint = function(panel, w, h)
draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 2))
end;
end;
end;
 
vgui.Register("rwTabBackground", PANEL, "EditablePanel");
 
if (CLIENT) then
    concommand.Add("opentestmenu", function()
        if (ph1) then ph1:Remove(); ph1 = nil return end;
		ph1 = vgui.Create("rwTabBackground");
        ph1:MakePopup();
    end);
end;