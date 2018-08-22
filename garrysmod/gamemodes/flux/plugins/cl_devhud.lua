PLUGIN:SetName("Flux Dev HUD")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds developer HUD.")

function PLUGIN:HUDPaint()
  if (fl.Devmode) then
    if (hook.Run("HUDPaintDeveloper") == nil) then
      draw.SimpleText("Flux version "..(GAMEMODE.Version or "UNKNOWN")..", developer mode on.", "default", 8, ScrH() - 18, Color(200, 200, 200, 200))
    end
  end
end
