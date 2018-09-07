-- Serverside hooks would go here.

-- Kill a random player every minute.
function Schema:OneMinute()
  self:kill_random_player()
end
