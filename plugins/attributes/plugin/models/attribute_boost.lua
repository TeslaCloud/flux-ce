--- Database record of a temporary boost to an attribute: the levels it adds and the time at
-- which it expires. Belongs to an `Attribute`.
-- @module [AttributeBoost]

class 'AttributeBoost' extends 'ActiveRecord::Base'

AttributeBoost:belongs_to 'Attribute'
