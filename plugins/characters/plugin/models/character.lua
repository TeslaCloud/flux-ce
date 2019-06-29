class 'Character' extends 'ActiveRecord::Base'

Character:belongs_to 'User'
Character:has_one 'ammo'

Character:validates('user_id', { presence = true })
Character:validates('steam_id', { presence = true })
Character:validates('name', { presence = true, min_length = 4, max_length = 24 })
Character:validates('gender', { presence = true })
Character:validates('phys_desc', { presence = true, min_length = 16, max_length = 200 })
Character:validates('model', { presence = true })

function Character:restored()
  if self.user then
    hook.run('RestoreCharacter', self.user.player, self.id, self)
  end
end
