--- Database record of a progress multiplier of an attribute: its `value`, the time at which
-- it expires (`expires_at`, empty for a multiplier that stays until it is removed) and the
-- name it was given to be found by (`identifier`, empty for a multiplier without one).
-- Belongs to an `Attribute`.
-- @module [AttributeMultiplier]

class 'AttributeMultiplier' extends 'ActiveRecord::Base'

AttributeMultiplier:belongs_to 'Attribute'
