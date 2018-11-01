PLUGIN:set_name('Hook Profiler')
PLUGIN:set_author('Mr. Meow')
PLUGIN:set_description('Profile any hooks.')
PLUGIN:set_global('Profiler')

if !fl.development then return end
if DBugR then return end

hook._profiler_old_call = hook._profiler_old_call or hook.Call

local metrics = {}
local counts = {}

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

  cable.receive('profiler_update', function(metrics_data, counts_data)
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

  function Profiler:get_metrics()
    return metrics, counts, metrics_sv, counts_sv
  end

  function Profiler:HUDPaint()
    local pos = ScrH() - 30

    draw.SimpleText('SV: '..tostring(math.Round(total_sv * 1000, 2))..'ms', 'default', 8, pos - 36, Color(200, 100, 100, 200))
    draw.SimpleText(largest_sv..' ('..tostring(math.Round(largest_sv_n * 1000, 2))..'ms)', 'default', 8, pos - 24, Color(200, 100, 100, 200))
    draw.SimpleText('CL: '..tostring(math.Round(total_cl * 1000, 2))..'ms', 'default', 8, pos - 12, Color(200, 100, 100, 200))
    draw.SimpleText(largest_cl..' ('..tostring(math.Round(largest_cl_n * 1000, 2))..'ms)', 'default', 8, pos, Color(200, 100, 100, 200))
  end

  local PANEL = {}

  PANEL.metrics = {}
  PANEL.counts = {}
  PANEL.metrics_sv = {}
  PANEL.counts_sv = {}
  PANEL.lines = {}

  function PANEL:Init()
    self:rebuild()
  end

  function PANEL:update_metrics(metrics, counts, metrics_sv, counts_sv)
    self.metrics, self.counts, self.metrics_sv, self.counts_sv = metrics, counts, metrics_sv, counts_sv
    self:rebuild()
  end

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
  timer.Create('profiler_update', 1, 0, function()
    cable.send(nil, 'profiler_update', metrics, counts)
    metrics = {}
    counts = {}
  end)
end
