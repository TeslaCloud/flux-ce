ActiveRecord.define_model('Player', function(t)
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
end)

function Player:as_parent(child_obj, child_class)
  child_obj.player = self.player
end
