--- Client hooks of the Spawn Points plugin: ask the server for the spawn points when the
-- local player takes out the Spawn Point Tool, and draw the points while it is held.

local eye_offset = Vector(0, 0, 64)
local label_offset = Vector(0, 0, 80)
local direction_length = 32
local request_interval = 2

--- Keeps track of whether the local player is editing spawn points. The points are asked
-- for every time the tool is taken out, and again every couple of seconds until the server
-- has answered, so that the list is fresh and a permission given later is picked up.
function SpawnPoints:LazyTick()
  local editing = self:is_tool_held()

  if editing then
    local cur_time = CurTime()

    if !self.editing then
      self.received = false
      self.next_request = 0
    end

    if !self.received and cur_time >= (self.next_request or 0) then
      self.next_request = cur_time + request_interval

      Cable.send('fl_spawnpoints_request')
    end
  end

  self.editing = editing
end

--- Draws every spawn point as a box of the size of a player, with a line at eye height that
-- shows which way a player spawning there faces. Only drawn while the Spawn Point Tool is
-- held.
-- @param draw_depth [Boolean whether the depth pass is being drawn]
-- @param draw_skybox [Boolean whether the skybox is being drawn]
function SpawnPoints:PostDrawOpaqueRenderables(draw_depth, draw_skybox)
  if draw_depth or draw_skybox or !self.editing then return end

  local points = self.points
  local default_color = self.color_default
  local box_angle, hull_mins, hull_maxs = self.box_angle, self.hull_mins, self.hull_maxs

  for i = 1, #points do
    local v = points[i]
    local pos = v.pos
    local color = v.color or default_color
    local eye_pos = pos + eye_offset

    render.DrawWireframeBox(pos, box_angle, hull_mins, hull_maxs, color, true)
    render.DrawLine(eye_pos, eye_pos + v.ang:Forward() * direction_length, color, true)
  end
end

--- Draws the label of every spawn point above it: its number and the group it is for. Only
-- drawn while the Spawn Point Tool is held.
function SpawnPoints:HUDPaint()
  if !self.editing then return end

  local font = Theme.get_font('text_small')
  local points = self.points
  local default_color = self.color_default

  for i = 1, #points do
    local v = points[i]
    local label = v.label
    local screen_pos = (v.pos + label_offset):ToScreen()

    if screen_pos.visible and label then
      draw.SimpleText(
        label,
        font,
        screen_pos.x,
        screen_pos.y,
        v.color or default_color,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
    end
  end
end
