--[[
  Simplistic base panel that has basic colors, fields and methods commonly used throughout Flux Framework.
  Do not use it directly, base your own panels off of it instead.
--]]

local PANEL = {}
PANEL.draw_background = true
PANEL.background_color = Color(0, 0, 0)
PANEL.text_color = Color(255, 255, 255)
PANEL.main_color = Color(255, 100, 100)
PANEL.accent_color = Color(200, 200, 200)
PANEL.title = 'Flux Base Panel'
PANEL.font = Theme.get_font('menu_titles') or 'flRoboto'

AccessorFunc(PANEL, 'draw_background', 'DrawBackground')
AccessorFunc(PANEL, 'background_color', 'BackgroundColor')
AccessorFunc(PANEL, 'text_color', 'TextColor')
AccessorFunc(PANEL, 'main_color', 'MainColor')
AccessorFunc(PANEL, 'accent_color', 'AccentColor')
AccessorFunc(PANEL, 'title', 'Title')
AccessorFunc(PANEL, 'font', 'Font')

--- Delegates drawing of the panel to the active theme's PaintPanel hook.
-- @param width [Number panel width]
-- @param height [Number panel height]
function PANEL:Paint(width, height)
  Theme.hook('PaintPanel', self, width, height)
end

--- Runs the active theme's PanelThink hook for this panel.
function PANEL:Think() Theme.hook('PanelThink', self)
end

-- MVC Functionality for all FL panels.

--- Sends an MVC request to the server-side handlers registered under the name.
-- @param name [String name of the MVC handler]
-- @param ... [Vararg data passed to the server-side handler]
-- @see [MVC.push]
function PANEL:push(name, ...)
  MVC.push(name, ...)
end

--- Registers a callback for data the server pushes to this client under the name.
-- The callback is removed after it has run once unless prevent_remove is set.
-- @param name [String name of the MVC response to wait for]
-- @param handler [Function called with the values sent by the server]
-- @param prevent_remove=false [Boolean keep the handler registered after it has run]
-- @see [MVC.pull]
function PANEL:pull(name, handler, prevent_remove)
  MVC.pull(name, handler, prevent_remove)
end

--- Sends an MVC request to the server and registers a one-time callback for its response.
-- ```
-- self:request('fl_create_character', function(response)
--   if response.success then
--     self:clear_data()
--   end
-- end, self.char_data)
-- ```
-- @param name [String name of the MVC handler]
-- @param handler [Function called once with the values the server responds with]
-- @param ... [Vararg data passed to the server-side handler]
-- @see [MVC.request]
function PANEL:request(name, handler, ...)
  self:pull(name, handler)
  self:push(name, ...)
end

PANEL.set_title = PANEL.SetTitle

vgui.Register('fl_base_panel', PANEL, 'EditablePanel')
