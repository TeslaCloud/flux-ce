--- Placeholder of a chat moderation panel (`fl_chat_moderation`) that has no behavior yet.

local PANEL = {}

--- Currently does nothing.
function PANEL:Init()
end

--- Currently draws nothing.
-- @param _w [Number]
-- @param _h [Number]
function PANEL:Paint(_w, _h)
end

vgui.Register('fl_chat_moderation', PANEL, 'fl_base_panel')
