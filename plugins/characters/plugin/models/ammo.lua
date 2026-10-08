--- Ammunition of a `Character`, stored in the `ammunitions` table as an ammo type and an
-- amount. The plugin declares the model and its relation but does not create or read these
-- records yet.

class 'Ammunition' extends 'ActiveRecord::Base'

Ammunition:belongs_to 'Character'
