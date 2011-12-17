#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/scrape"

require 'csv'
require 'logger'

module PopulationRecordsSixColumns
  def records
    @records ||= doc.xpath('//table[@border = "1"]/tr[not(@bgcolor)]').collect do |tr|
      next if tr.css('td').count != 6
      next if tr.css('strong').count != 0

      tds = tr.css('td')

      td2_a = tds[2].css('a')[0]
      td3_a = tds[3].css('a')[0]

      region = tds[0].text().gsub(/\s+/m, ' ').strip
      region_type = tds[1].text().strip
      pop_2001 = tds[2].text().gsub(/[^\d]*/, '').to_i
      pop_1996 = tds[3].text().gsub(/[^\d]*/, '').to_i
      notes_2001 = td2_a && td2_a.attribute('title')
      notes_1996 = td3_a && td3_a.attribute('title')
      dwellings_2001 = tds[5].text().gsub(/[^\d]*/, '').to_i

      [ region, region_type, pop_2001, notes_2001, pop_1996, notes_1996, dwellings_2001 ]
    end.compact
  end
end

module PopulationRecordsFiveColumns
  def records
    @records ||= doc.xpath('//table[@border = "1"]/tr[not(@bgcolor)]').collect do |tr|
      next if tr.css('td').count != 6
      next if tr.css('strong').count != 0

      tds = tr.css('td')

      td2_a = tds[2].css('a')[0]
      td3_a = tds[3].css('a')[0]

      region = tds[0].text().gsub(/\s+/m, ' ').strip
      region_type = tds[1].text().strip
      pop_2001 = tds[2].text().gsub(/[^\d]*/, '').to_i
      area_2001 = tds[3].text().gsub(/[^\d\.]*/, '').to_f
      density_2001 = tds[4].text().gsub(/[^\d\.]*/, '').to_f

      [ region, region_type, pop_2001, area_2001, density_2001 ]
    end.compact
  end
end

class StatsCan2001PopulationAndDwellingCountsParser < Parser
  PageUrl = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CSD-N.cfm?T=1&SR=#{start}&S=20&O=A'
  Url = PageUrl.sub('#{start}', '1')

  include PopulationRecordsSixColumns

  def url_list
    return @url_list if @url_list

    html =~ /Page 1 of ([\d,]+)/
    n_pages = $1.to_i
    per_page = 25

    @url_list = (1..n_pages).collect { |page| PageUrl.sub('#{start}', (page * per_page - per_page + 1).to_s) }
  end
end

class StatsCan2001PopulationAndDwellingCountsAreaParser < StatsCan2001PopulationAndDwellingCountsParser
  PageUrl = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CSD-N.cfm?T=2&SR=#{start}&S=20&O=A'
  Url = PageUrl.sub('#{start}', '1')
end

class StatsCan2001PopulationAndDwellingCountsByDivisionParser < StatsCan2001PopulationAndDwellingCountsParser
  PageUrl = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CD-N.cfm?T=1&SR=#{start}&S=1&O=A'
  Url = PageUrl.sub('#{start}', '1')

  include PopulationRecordsFiveColumns
end

class StatsCan2001PopulationAndDwellingCountsAreaByDivisionParser < StatsCan2001PopulationAndDwellingCountsAreaParser
  PageUrl = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-CD-N.cfm?T=2&SR=#{start}&S=1&O=A'
  Url = PageUrl.sub('#{start}', '1')

  include PopulationRecordsFiveColumns
end

class StatsCan2001PopulationAndDwellingCountsByProvinceParser < StatsCan2001PopulationAndDwellingCountsByDivisionParser
  Url = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-PR.cfm'

  def url_list
    @url_list ||= [ Url ]
  end
end

class StatsCan2001PopulationAndDwellingCountsAreaByProvinceParser < StatsCan2001PopulationAndDwellingCountsAreaParser
  Url = 'http://www12.statcan.ca/english/census01/products/standard/popdwell/Table-PR.cfm?T=2&S=1&O=A'

  def url_list
    @url_list ||= [ Url ]
  end
end

fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsParser::Url, StatsCan2001PopulationAndDwellingCountsParser)
#fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsAreaParser::Url, StatsCan2001PopulationAndDwellingCountsAreaParser)
#fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsByDivisionParser::Url, StatsCan2001PopulationAndDwellingCountsByDivisionParser)
#fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsAreaByDivisionParser::Url, StatsCan2001PopulationAndDwellingCountsAreaByDivisionParser)
#fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsAreaParser::Url, StatsCan2001PopulationAndDwellingCountsAreaParser)
#fetcher = Fetcher.new(StatsCan2001PopulationAndDwellingCountsAreaByProvinceParser::Url, StatsCan2001PopulationAndDwellingCountsAreaByProvinceParser)
fetcher.logger = Logger.new(STDERR)
CSV do |csv|
  fetcher.write_records_to_csv(csv, :flusher => STDOUT)
end
