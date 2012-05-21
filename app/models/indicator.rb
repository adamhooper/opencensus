class Indicator < ActiveRecord::Base
  has_many(:indicator_region_values, :dependent => :delete_all)

  # Casts a value to the type this Indicator uses (integer or float)
  def cast_value(value)
    case value_type
    when 'integer' then value.to_i
    when 'float' then value.to_f
    when 'string' then value.to_s
    else raise_invalid_type
    end
  end

  # Returns the value from the given IndicatorRegionValue object
  def get_value(object)
    case value_type
    when 'integer' then object.value_integer
    when 'float' then object.value_float
    when 'string' then object.value_string
    else raise_invalid_type
    end
  end

  # Sets the value on the given IndicatorRegionValue object
  def set_value(object, value)
    value = cast_value(value)

    case value_type
    when 'integer' then object.value_integer = value
    when 'float' then object.value_float = value
    when 'string' then object.value_string = value
    else raise_invalid_type
    end
  end

  # Returns the value column to use in the region_indicator_values table.
  #
  # Will be 'value_integer' or 'value_float'
  def value_column
    case value_type
    when 'integer' then 'value_integer'
    when 'float' then 'value_float'
    when 'string' then 'value_string'
    else raise_invalid_type
    end
  end

  protected

  def raise_invalid_type
    raise Exception.new("Invalid value_type #{value_type.inspect}")
  end
end
