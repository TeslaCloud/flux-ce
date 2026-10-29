--- Client-side receiver of the button presses that the server reports, which runs the Flux
-- bind of the button.

Cable.receive('fl_bind_pressed', function(key)
  local bind = Flux.Binds:get_bind(key)

  if bind then
    RunConsoleCommand(bind)
  end
end)
