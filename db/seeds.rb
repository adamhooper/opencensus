# encoding: utf-8
#
# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Indicator.create([
  { name: 'Population', unit: '', description: '', value_type: 'integer' },
  { name: 'Dwellings', unit: '', description: '', value_type: 'integer' },
  { name: 'Area', unit: 'km²', description: 'Land area', value_type: 'float' },
  { name: 'Population density', unit: 'people per km²', description: '', value_type: 'float' }#,
  #{ name: 'Dwelling density', unit: 'dwellings per km²', description: '', value_type: 'float', sql: '#{Dwellings} / #{Area}' }
])
