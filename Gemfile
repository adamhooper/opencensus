source 'http://rubygems.org'

gem 'rails', '3.1.3'
gem 'pg'
gem 'activerecord-postgis-adapter'
gem 'haml'
gem 'therubyracer'

gem 'ffi' # TODO: remove when ffi-geos depends upon it as it should
gem 'ffi-geos'
gem 'rgeo'
gem 'rgeo-geojson', :require => 'rgeo/geo_json'

group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
end

gem 'jquery-rails'

group :development do
  gem 'unicorn'
  gem 'dbf'
  gem 'rgeo-shapefile', :require => 'rgeo/shapefile'
  gem 'ruby-debug19', :require => 'ruby-debug'
end

group :test do
  gem 'rspec-rails'
end
