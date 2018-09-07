-- Clientside hooks would go here.
function Schema:HUDPaint()
  draw.SimpleText(t'reborn.welcome_text', 'DermaLarge', 16, 16, theme.Hook('TestHook'))
end
