#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'httparty'
require 'nokogiri'

require 'csv'
require 'logger'

class HTTP
  include HTTParty
  default_timeout 60
end

class Parser
  attr_reader(:html)

  def initialize(html)
    @html = html
  end

  def url_list
    raise NotImplementedError.new
  end

  def records
    raise NotImplementedError.new
  end

  protected

  def doc
    @doc ||= Nokogiri::HTML(html)
  end
end

class Fetcher
  attr_accessor(:logger)
  attr_reader(:index_url, :parser_class)

  def initialize(index_url, parser_class)
    @index_url = index_url
    @parser_class = parser_class
  end

  def url_list
    @url_list ||= calculate_url_list
  end

  def records
    @records ||= calculate_records
  end

  def write_records_to_csv(csv, options = {})
    url_list.each do |url|
      parsed_page(url).records.each do |record|
        csv << record
      end
      options[:flusher].flush if options[:flusher]
    end
  end

  protected

  def html_page(url)
    @html_pages ||= {}
    @html_pages[url] ||= calculate_html_page(url)
  end

  def parsed_page(url)
    @parsed_pages ||= {}
    @parsed_pages[url] ||= parse_page(html_page(url))
  end

  def parse_page(html)
    parser_class.new(html)
  end

  def calculate_html_page(url)
    get(url, :retries => 3).body
  end

  def calculate_url_list
    parsed_page(index_url).url_list
  end

  def calculate_records
    ret = []
    (1..pages).each do |page|
      records = parsed_page(page).records
      log("Records: #{records.inspect}")
      ret.concat(records)
    end
    ret
  end

  def get(url, options = {})
    log("Fetching #{url}... (#{options[:retries]} retries left if this one fails)")
    HTTP.get(url)
  rescue
    if options[:retries] && options[:retries] > 0
      sleep 5
      get(url, :retries => options[:retries] - 1)
    else
      raise
    end
  end

  def log(msg)
    logger.info(msg) if logger
  end
end
