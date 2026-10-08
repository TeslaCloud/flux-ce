--- Placeholder of a chat moderation panel (`fl_chat_moderation`) that has no behavior yet.

local PANEL = {}

--- Currently does nothing.
function PANEL:Init()
end

--- Currently draws nothing.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
end

vgui.Register('fl_chat_moderation', PANEL, 'fl_base_panel')
