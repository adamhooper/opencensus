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
  { name: 'Occupied dwellings', unit: '', description: '', value_type: 'integer' },
  { name: 'Area', unit: 'km²', description: 'Land area', value_type: 'float' },
  { name: 'Population density', unit: 'people per km²', description: '', value_type: 'float', sql: '{Population} / {Area}' },
  { name: 'Dwelling density', unit: 'dwellings per km²', description: '', value_type: 'float', sql: '{Dwellings} / {Area}' },
  { name: 'People per dwelling', unit: 'people per dwelling', description: '', value_type: 'float', sql: '{Population} / {Dwellings}' }
])

RegionType.create([
  { name: 'Province', position: 1 },
  { name: 'ElectoralDistrict', position: 2 },
  { name: 'EconomicRegion', position: 3 },
  { name: 'MetropolitanArea', position: 4 },
  { name: 'Division', position: 5 },
  { name: 'ConsolidatedSubdivision', position: 6 },
  { name: 'Subdivision', position: 7 },
  { name: 'Tract', position: 8 },
  { name: 'DisseminationArea', position: 9 },
  { name: 'DisseminationBlock', position: 10 }
])

RegionTypeParent.create([
  { region_type: 'DisseminationBlock', parent_region_type: 'DisseminationArea' },
  { region_type: 'DisseminationBlock', parent_region_type: 'ElectoralDistrict' },
  { region_type: 'DisseminationArea', parent_region_type: 'Subdivision' },
  { region_type: 'DisseminationArea', parent_region_type: 'Tract' },
  { region_type: 'Tract', parent_region_type: 'MetropolitanArea' },
  { region_type: 'Subdivision', parent_region_type: 'ConsolidatedSubdivision' },
  { region_type: 'Subdivision', parent_region_type: 'MetropolitanArea' },
  { region_type: 'ConsolidatedSubdivision', parent_region_type: 'Division' },
  { region_type: 'Division', parent_region_type: 'EconomicRegion' },
  { region_type: 'ElectoralDistrict', parent_region_type: 'Province' },
  { region_type: 'EconomicRegion', parent_region_type: 'Province' }
])
