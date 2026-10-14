--- Gives the `Character` model its `recognizes` association: the `Recognize` records of the
-- characters that the character recognizes.

Character:has_many 'recognizes'
