PLUGIN:set_name("DBugR Hooks")
PLUGIN:set_author("NightAngel")
PLUGIN:set_description("Adds all plugin hooks to DBugR performance metrics monitor.")

if DBugR then
  function PLUGIN:OnSchemaLoaded()
    for hookName, hooks in pairs(plugin.get_cache()) do
      for k, v in ipairs(hooks) do
        local name = "N/A"
        local func = v[1]

        if v[2] and v[2].get_name then
          name = v[2]:get_name()
        elseif v.id then
          name = v.id
        end

        hooks[k][1] = DBugR.Util.Func.AttachProfiler(func, function(time)
          DBugR.Profilers.Hook:AddPerformanceData(name..":"..hookName, time, func)
        end)
      end
    end

    if fl.development then
      DBugR.Print("Flux plugin hooks detoured!")
    end
  end
end
