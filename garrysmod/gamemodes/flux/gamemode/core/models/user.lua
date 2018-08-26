ActiveRecord.define_model('User', function(t)
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
end)

function User:as_parent(child_obj, child_class)
  child_obj.player = self.player
end
