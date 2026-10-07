PLUGIN:set_name('Hook Profiler')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Profile any hooks.')
PLUGIN:set_global('Profiler')

if !Flux.development then return end
if DBugR then return end

hook._profiler_old_call = hook._profiler_old_call or hook.Call

local metrics = {}
local counts = {}

--- Replaces hook.Call with a wrapper that measures the total run time and the number of
-- calls of every hook. Only installed in development mode and when DBugR is not present.
-- @param name [String hook name]
-- @param gm [Hash gamemode table, or nil]
-- @param ... [Vararg arguments of the hook]
-- @return [Any up to six values returned by the original hook.Call]
function hook.Call(name, gm, ...)
  local start_time = os.clock()
  local total_time = metrics[name] or 0

  local a, b, c, d, e, f = hook._profiler_old_call(name, gm, ...)

  metrics[name] = total_time + (os.clock() - start_time)
  counts[name] = (counts[name] or 0) + 1

  return a, b, c, d, e, f
end

if CLIENT then
  local total_cl = 0
  local total_sv = 0
  local largest_cl = 'not measured yet'
  local largest_sv = 'not measured yet'
  local largest_cl_n = 0
  local largest_sv_n = 0
  local metrics_sv = {}
  local counts_sv = {}
  local debug_color = Color(200, 100, 100, 200)

  Cable.receive('fl_profiler_update', function(metrics_data, counts_data)
    metrics_sv = metrics_data
    counts_sv = counts_data
    total_sv = 0
    total_cl = 0
    largest_cl_n = 0
    largest_sv_n = 0

    for k, v in pairs(metrics_sv) do
      total_sv = total_sv + v

      if v > largest_sv_n then
        largest_sv_n = v
        largest_sv = k
      end
    end

    for k, v in pairs(metrics) do
      total_cl = total_cl + v

      if v > largest_cl_n then
        largest_cl_n = v
        largest_cl = k
      end
    end

    if IsValid(Profiler.panel) then
      Profiler.panel:update_metrics(Profiler:get_metrics())
    end

    metrics = {}
    counts = {}
  end)

  --- Returns the profiler data: clientside data gathered since the last update from the
  -- server, and the serverside data received with that update. Clientside only.
  -- @return [Hash clientside run time in seconds by hook name, Hash clientside call counts
  --   by hook name, Hash serverside run time by hook name, Hash serverside call counts]
  function Profiler:get_metrics()
    return metrics, counts, metrics_sv, counts_sv
  end

  --- Draws the total hook run time and the slowest hook of the server and of the client.
  function Profiler:HUDPaint()
    local pos = ScrH() - 30

    draw.SimpleText('SV: '..tostring(math.Round(total_sv * 1000, 2))..'ms', 'default', 8, pos - 36, debug_color)
    draw.SimpleText(largest_sv..' ('..tostring(math.Round(largest_sv_n * 1000, 2))..'ms)', 'default', 8, pos - 24, debug_color)
    draw.SimpleText('CL: '..tostring(math.Round(total_cl * 1000, 2))..'ms', 'default', 8, pos - 12, debug_color)
    draw.SimpleText(largest_cl..' ('..tostring(math.Round(largest_cl_n * 1000, 2))..'ms)', 'default', 8, pos, debug_color)
  end

  local PANEL = {}

  PANEL.metrics = {}
  PANEL.counts = {}
  PANEL.metrics_sv = {}
  PANEL.counts_sv = {}
  PANEL.lines = {}

  --- Builds the hook list.
  function PANEL:Init()
    self:rebuild()
  end

  --- Stores new profiler data and refreshes the hook list.
  -- @param metrics [Hash clientside run time in seconds by hook name]
  -- @param counts [Hash clientside call counts by hook name]
  -- @param metrics_sv [Hash serverside run time in seconds by hook name]
  -- @param counts_sv [Hash serverside call counts by hook name]
  function PANEL:update_metrics(metrics, counts, metrics_sv, counts_sv)
    self.metrics, self.counts, self.metrics_sv, self.counts_sv = metrics, counts, metrics_sv, counts_sv
    self:rebuild()
  end

  --- Creates the list view if it is missing, then adds or updates one line per serverside
  -- hook with its load in milliseconds and its call count.
  function PANEL:rebuild()
    if !IsValid(self.sv_list) then
      self.sv_list = vgui.Create('DListView', self)
      self.sv_list:Dock(FILL)
      self.sv_list:AddColumn('Hook')
      self.sv_list:AddColumn('Load')
      self.sv_list:AddColumn('Calls')
    end

    for k, v in pairs(self.metrics_sv) do
      local line = PANEL.lines[k]

      if !line then
        PANEL.lines[k] = self.sv_list:AddLine(k, tostring(math.Round(v * 1000, 2))..'ms', self.counts_sv[k])
      else
        line:SetValue(1, k)
        line:SetValue(2, tostring(math.Round(v * 1000, 2))..'ms')
        line:SetValue(3, self.counts_sv[k])
      end
    end
  end

  vgui.Register('profiler_window', PANEL, 'fl_base_panel')

  concommand.Add('fl_profiler_toggle', function()
    if can('read', Profiler) then
      if !IsValid(Profiler.panel) then
        local scrw, scrh = ScrW(), ScrH()
        local pw, ph = scrw * 0.5, scrh * 0.5

        Profiler.panel = vgui.Create('profiler_window')
        Profiler.panel:SetSize(pw, ph)
        Profiler.panel:SetPos(scrw * 0.5 - pw * 0.5, scrh * 0.5 - ph * 0.5)
        Profiler.panel:SetVisible(false)
      end

      if Profiler.panel:IsVisible() then
        Profiler.panel:SetVisible(false)
        Profiler.panel:SetKeyboardInputEnabled(false)
        Profiler.panel:SetMouseInputEnabled(false)
      else
        Profiler.panel:SetVisible(true)
        Profiler.panel:MakePopup()
      end
    end
  end)
else
  timer.Create('fl_profiler_update', 1, 0, function()
    Cable.send(nil, 'fl_profiler_update', metrics, counts)
    metrics = {}
    counts = {}
  end)
end
