class IndicatorCalculator
  attr_reader(:indicator)

  def initialize(indicator)
    @indicator = indicator
  end

  def destroy_values
    IndicatorRegionValue.where(:indicator_id => indicator.id).delete_all
  end

  def create_values
    sql = indicator.sql.dup

    wheres = []

    keys = sql.scan(/{[^}]*?}/)
    keys.sort!
    keys.uniq!

    keys.each do |key_with_brackets|
      key = key_with_brackets[1...-1]
      other_indicator = Indicator.find_by_name(key)
      sql.gsub!(/{#{Regexp.quote(key)}}/) do |x|
        "(SELECT #{other_indicator.value_column} FROM indicator_region_values x WHERE x.indicator_id = #{other_indicator.id} AND x.year = indicator_region_values.year AND x.region_id = indicator_region_values.year)"
      end

      if wheres.empty?
        wheres << "indicator_region_values.indicator_id = #{other_indicator.id}"
      else
        wheres << "(indicator_region_values.region_id, indicator_region_values.year) IN (SELECT region_id, year FROM indicator_region_values WHERE indicator_id = #{other_indicator.id})"
      end
    end

    IndicatorRegionValue.connection.execute("INSERT INTO indicator_region_values (indicator_id, region_id, year, #{indicator.value_column}, note) SELECT #{indicator.id}, region_id, year, #{sql}, note FROM indicator_region_values WHERE #{wheres.join(' AND ')}")
  end
end
