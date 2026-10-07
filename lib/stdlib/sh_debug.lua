local is_development = ENV['FLUX_ENV'] == 'development'
local metrics = {}

if is_development then
  --- Registers an object under a debug metric.
  -- Metrics are only collected when FLUX_ENV is set to 'development'.
  -- @param id [String metric name]
  -- @param obj [Any object to register]
  -- @return [Number amount of objects registered under this metric so far]
  function add_debug_metric(id, obj)
    local count = 1

    if !metrics[id] then
      metrics[id] = { obj }
    else
      count = table.insert(metrics[id], obj)
    end

    return count
  end

  --- Returns all objects that were registered under a debug metric.
  -- @param id [String metric name]
  -- @return [List registered objects, or nil if nothing was registered under this metric]
  function get_debug_metric(id)
    return metrics[id]
  end

  --- Prints the amount of objects registered under a debug metric to the console.
  -- The metric has to exist.
  -- @param id [String metric name]
  -- @param format='{count} {id} were registered.' [String message, {count} and {id} are replaced]
  -- @see [string.fmt]
  function print_debug_metric(id, format)
    format = format or '{count} {id} were registered.'

    MsgC(
      Color(255, 255, 255),
      'Debug: ',
      Color(175, 175, 175),
      string.fmt(format, { id = tostring(id), count = tostring(#metrics[id]) }),
      '\n'
    )
  end

  --- Prints the amount of registered objects of every debug metric to the console.
  function print_debug_metrics()
    for id, objects in pairs(metrics) do
      print_debug_metric(id)
    end
  end
else
  --- Does nothing, since debug metrics are only collected in the development environment.
  -- @param id [String metric name]
  -- @param obj [Any object to register]
  function add_debug_metric(id, obj)
  end

  --- Does nothing, since debug metrics are only collected in the development environment.
  -- @param id [String metric name]
  function get_debug_metric(id)
  end

  --- Does nothing, since debug metrics are only collected in the development environment.
  -- @param id [String metric name]
  -- @param format=nil [String message]
  function print_debug_metric(id, format)
  end

  --- Does nothing, since debug metrics are only collected in the development environment.
  function print_debug_metrics()
  end
end
