--- Database record of a boost to an attribute: the levels it adds (`value`), the time at
-- which it expires (`expires_at`, empty for a boost that stays until it is removed) and the
-- name it was given to be found by (`identifier`, empty for a boost without one). Belongs to
-- an `Attribute`.
-- @module [AttributeBoost]

class 'AttributeBoost' extends 'ActiveRecord::Base'

AttributeBoost:belongs_to 'Attribute'
