PLUGIN:set_name('Hook Profiler')
PLUGIN:set_author('Mr. Meow')
PLUGIN:set_description('Profile any hooks.')

if !fl.development then return end
if DBugR then return end

hook._profiler_old_call = hook._profiler_old_call or hook.Call

local metrics = {}

function hook.Call(name, gm, ...)
  local start_time = os.clock()
  local total_time = metrics[name] or 0

  local a, b, c, d, e, f = hook._profiler_old_call(name, gm, ...)

  metrics[name] = total_time + (os.clock() - start_time)

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

  netstream.Hook('profiler_update', function(metrics_data)
    metrics_sv = metrics_data
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

    metrics = {}
  end)

  function PLUGIN:HUDPaint()
    local pos = ScrH() - 30

    draw.SimpleText('SV: '..tostring(math.Round(total_sv * 1000, 2))..'ms', 'default', 8, pos - 36, Color(200, 100, 100, 200))
    draw.SimpleText(largest_sv..' ('..tostring(math.Round(largest_sv_n * 1000, 2))..'ms)', 'default', 8, pos - 24, Color(200, 100, 100, 200))
    draw.SimpleText('CL: '..tostring(math.Round(total_cl * 1000, 2))..'ms', 'default', 8, pos - 12, Color(200, 100, 100, 200))
    draw.SimpleText(largest_cl..' ('..tostring(math.Round(largest_cl_n * 1000, 2))..'ms)', 'default', 8, pos, Color(200, 100, 100, 200))
  end
else
  timer.Create('profiler_update', 1, 0, function()
    netstream.Start(nil, 'profiler_update', metrics)
    metrics = {}
  end)
end
