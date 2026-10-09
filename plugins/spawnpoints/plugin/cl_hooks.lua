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

  for k, v in ipairs(self.points) do
    local color = v.color or self.color_default
    local eye_pos = v.pos + eye_offset

    render.DrawWireframeBox(v.pos, self.box_angle, self.hull_mins, self.hull_maxs, color, true)
    render.DrawLine(eye_pos, eye_pos + v.ang:Forward() * direction_length, color, true)
  end
end

--- Draws the label of every spawn point above it: its number and the group it is for. Only
-- drawn while the Spawn Point Tool is held.
function SpawnPoints:HUDPaint()
  if !self.editing then return end

  local font = Theme.get_font('text_small')

  for k, v in ipairs(self.points) do
    local screen_pos = (v.pos + label_offset):ToScreen()

    if screen_pos.visible and v.label then
      draw.SimpleText(
        v.label,
        font,
        screen_pos.x,
        screen_pos.y,
        v.color or self.color_default,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
    end
  end
end
