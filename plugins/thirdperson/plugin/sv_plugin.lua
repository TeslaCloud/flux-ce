--- Server side of the Third Person plugin: the `fl_third_person` console command, which
-- toggles the view of the player who runs it.

concommand.Add('fl_third_person', function(actor)
  actor:set_nv('fl_third_person', !actor:get_nv('fl_third_person', false))
end)
