--- The balance of a `Character` in one currency, stored in the `currencies` table as the
-- currency ID and the amount.

class 'Currency' extends 'ActiveRecord::Base'

Currency:belongs_to 'Character'
