# encoding: utf-8

class CsvImporter
  # Create a new CsvImporter for a specific file.
  #
  # Params:
  #   +file: path to CSV file
  #   +region_type: region type
  #   +region_description_column: column with region names
  #   +columns: String description of columns
  #             "2|Population|2001|3;4|Population|2006" would mean:
  #             [ column 2 (i.e., the third column) is the [integer] population,
  #               "Population" is the indicator (must be in "indicators" table),
  #               The year for column 2 is 2001,
  #               There are annotations for these values in column 3 ],
  #             [ column 3, "Population", 2006, and no annotations ]
  #   +options: optional hash...
  #     :region_subtype_column: integer column with subtypes (if applicable, e.g. for Subdivisions)
  def initialize(file, region_type, region_description_column, columns, options = {})
    @file = file
    @region_type = region_type
    @region_description_column = region_description_column
    @region_subtype_column = options[:region_subtype_column]
    @columns = parse_column_descriptions(columns)
  end

  def import
    num_successes = 0
    num_failures = 0

    open(@file) do |f|
      Region.transaction do
        CSV.new(f).each do |row|
          region_description = row[@region_description_column]
          region_subtype = row[@region_subtype_column] if @region_subtype_column
          region_id = find_region_id(region_description, region_subtype)

          if region_id.nil?
            num_failures += 1
          else
            num_successes += 1

            @columns.each do |column|
              indicator = column[:indicator]
              year = column[:year]

              value_string = row[column[:value_column]]
              note_string = row[column[:note_column]] if column[:note_column]
              note_string = nil if note_string && note_string.empty?

              value = indicator.cast_value(value_string)

              Region.connection.execute("INSERT INTO indicator_region_values (indicator_id, region_id, year, #{indicator.value_column}, note) SELECT #{indicator.id}, #{region_id}, #{year}, #{value_string}, #{Region.connection.quote(note_string)} WHERE ((#{region_id}, #{indicator.id}, #{year}) NOT IN (SELECT region_id, indicator_id, year FROM indicator_region_values))")
            end
          end
        end
      end
    end

    puts "Finished importing. #{num_successes} records imported, #{num_failures} records ignored."
  end

  def find_region_id(description, subtype)
    # XXX needs cleanup
    region_name = nil
    region_province_name = nil

    description_regex = /(?<region_name>.*) \((?<region_province_name>.*)\)/
    match = description_regex.match(description)

    if match.nil?
      match = /(?<region_name>.*) †/u.match(description)
      if match.nil?
        region_name = description
      else
        region_name = match[:region_name].strip
      end
      region_province_name = nil
      region_name = 'Yukon' if region_name == 'Yukon Territory'
    else
      region_name = match[:region_name].strip
      region_province_name = match[:region_province_name]
    end

    region_province_uid = case region_province_name
      when 'B.C.' then 59
      when 'Sask.' then 47
      when 'N.B.' then 13
      when 'Ont.' then 35
      when 'P.E.I.' then 11
      when 'Alta.' then 48
      when 'Nfld.Lab.' then 10
      when 'Que.' then 24
      when 'N.W.T.' then 61
      when 'Man.' then 46
      when 'Y.T.' then 60
      when 'N.S.' then 13
      when 'Nvt.' then 62
      when nil then nil
      else raise Exception.new("Couldn't find province: #{region_province_name.inspect}")
    end.to_s

    key = make_region_id_cache_key(subtype, region_province_uid, region_name)

    region_id = region_id_cache[key]

    if region_id.nil?
      puts "Couldn't find region from key #{key.inspect}. Ignoring."
    end

    region_id
  end

  protected

  # Returns [ { indicator:Indicator, year:int, value_column:int, note_column:(int|nil) }, ... ]
  def parse_column_descriptions(column_descriptions)
    column_descriptions.split(/;/).map do |d|
      value_column, indicator_name, year, note_column = d.split(/\|/)
      indicator = Indicator.where(:name => indicator_name).first
      raise "Indicator not found: #{indicator_name.inspect}" if indicator.nil?
      { indicator: indicator, year: year.to_i, value_column: value_column.to_i, note_column: (note_column.nil? ? nil : note_column.to_i) }
    end
  end

  def make_region_id_cache_key(subtype, province_uid, name)
    name = name.gsub(/[^\d\w]/, '_').upcase
    "#{@region_type}--#{subtype || ''}--#{province_uid || ''}--#{name}"
  end

  def region_id_cache
    return @region_cache if @region_cache

    ret = {}

    Region.connection.execute("SELECT id, type, subtype, name, province_uid FROM regions WHERE type = #{Region.connection.quote(@region_type)}").each do |row|
      id = row['id'].to_i
      region_type = row['type']
      region_name = row['name']
      region_subtype = row['subtype']
      region_province_uid = row['province_uid']

      region_province_uid = nil if region_type == 'Province' # XXX ugly

      key = make_region_id_cache_key(region_subtype, region_province_uid, region_name)

      # Sometimes there are two regions with the same type, subtype, province and name.
      # In 2001 we can't determine which is which (because statscan doesn't expose the UID
      # in its population data). Instead, let's use the heuristic that the second region
      # usually holds all-0 counts.
      #
      # So if ret[key] is already set, don't overwrite it.
      ret[key] ||= id
    end

    return @region_cache = ret
  end
end
