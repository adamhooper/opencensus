#!/usr/bin/env ruby
# encoding: utf-8

require "#{File.dirname(__FILE__)}/scrape"

require 'csv'
require 'logger'

module PopulationRecords
  def records
    @records ||= doc.xpath('//table[@border = "1"]/tr[not(@bgcolor)]').collect do |tr|
      next unless [5, 6].include?(tr.css('td').count)
      next if tr.css('strong').count != 0

      tds = tr.css('td')

      data_c = tr.css('td').count == 6 ? 2 : 1

      td0_a = tds[0].css('a')[0]
      td1_a = tds[data_c].css('a')[0]
      td2_a = tds[data_c + 1].css('a')[0]
      td4_a = tds[data_c + 3].css('a')[0]

      region = tds[0].text().gsub(/\s+/m, ' ').strip
      region_type = data_c == 2 ? tds[1].text().strip : ''
      pop_2001 = tds[data_c].text().gsub(/[^\d]*/, '').to_i
      pop_1996 = tds[data_c + 1].text().gsub(/[^\d]*/, '').to_i
      dwellings_2001 = tds[data_c + 3].text().gsub(/[^\d]*/, '').to_i
      notes_region = td0_a && td0_a.attribute('title')
      notes_2001 = td1_a && td1_a.attribute('title') || notes_region
      notes_1996 = td2_a && td2_a.attribute('title') || notes_region
      notes_dwellings = td4_a && td4_a.attribute('title') || notes_region

      [ region, region_type, pop_2001, notes_2001, pop_1996, notes_1996, dwellings_2001, notes_dwellings ]
    end.compact
  end
end

module DensityRecords
  def records
    @records ||= doc.xpath('//table[@border = "1"]/tr[not(@bgcolor)]').collect do |tr|
      next unless [4, 5, 6].include?(tr.css('td').count)
      next if tr.css('strong').count != 0

      tds = tr.css('td')

      data_c = tr.css('td').count == 6 ? 2 : 1

      td0_a = tds[0].css('a')[0]
      td1_a = tds[data_c].css('a')[0]
      td3_a = tds[data_c + 2].css('a')[0]

      region = tds[0].text().gsub(/\s+/m, ' ').strip
      region_type = data_c == 2 ? tds[1].text().strip : ''
      pop_2001 = tds[data_c].text().gsub(/[^\d]*/, '').to_i
      area_2001 = tds[data_c + 1].text().gsub(/[^\d\.]*/, '').to_f
      density_2001 = tds[data_c + 2].text().gsub(/[^\d\.]*/, '').to_f
      region_notes = td0_a && td0_a.attribute('title')
      pop_notes = td1_a && td1_a.attribute('title') || region_notes
      density_notes = td3_a && td3_a.attribute('title') || region_notes

      [ region, region_type, area_2001, density_2001, density_notes ]
    end.compact
  end
end

module PopulationHasUrlList
  def url_list
    return @url_list if @url_list

    html =~ /Page 1 of ([\d,]+)/
    n_pages = $1.to_i
    per_page = 25

    @url_list = (1..n_pages).collect { |page| page_url.sub('#{start}', (page * per_page - per_page + 1).to_s) }
  end
end

module PopulationHasOneUrl
  def url_list
    [ page_url ]
  end
end

def build_parser_class(region_type, url, has_density)
  Class.new(Parser) do
    const_set('PageUrl', url)
    const_set('Url', url.sub('#{start}', '1'))

    define_method(:page_url) do
      url
    end

    define_singleton_method(:csv_filename) do
      "2001-#{region_type}-#{has_density ? 'density' : 'population'}.csv"
    end

    if has_density
      include DensityRecords
    else
      include PopulationRecords
    end

    if url.include?('#{start}')
      include PopulationHasUrlList
    else
      include PopulationHasOneUrl
    end
  end
end

tasks = [
  [ 'Subdivision', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CSD-N.cfm?T=1&SR=#{start}&S=20&O=A', false ],
  [ 'Subdivision', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CSD-N.cfm?T=2&SR=#{start}&S=20&O=A', true ],
  [ 'Division', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CD-N.cfm?T=1&SR=#{start}&S=1&O=A', false ],
  [ 'Division', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CD-N.cfm?T=2&SR=#{start}&S=1&O=A', true ],
  [ 'Province', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-PR.cfm?T=1&S=1&O=A', false ],
  [ 'Province', 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-PR.cfm?T=2&S=1&O=A', true ]
]

tasks.each do |task|
  parser = build_parser_class(*task)

  filename = "#{File.dirname(__FILE__)}/../../db/scraped/#{parser.csv_filename}"

  fetcher = Fetcher.new(parser.const_get('Url'), parser)
  fetcher.logger = Logger.new(STDERR)
  fetcher.logger.info("Writing to #{filename}...")

  CSV.open(filename, 'wb') do |csv|
    fetcher.write_records_to_csv(csv)
  end

  fetcher.logger.info("Done writing to #{filename}")
end
