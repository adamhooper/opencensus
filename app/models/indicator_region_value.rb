class IndicatorRegionValue < ActiveRecord::Base
  belongs_to(:indicator)
  belongs_to(:region)

  def value
    indicator.get_value(self)
  end

  def value=(new_value)
    indicator.set_value(self, new_value)
  end
end
