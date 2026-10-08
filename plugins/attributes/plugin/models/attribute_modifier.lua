--- Database record of a temporary progress multiplier of an attribute: its value and the
-- time at which it expires. Belongs to an `Attribute`.
-- @module [AttributeMultiplier]

class 'AttributeMultiplier' extends 'ActiveRecord::Base'

AttributeMultiplier:belongs_to 'Attribute'
