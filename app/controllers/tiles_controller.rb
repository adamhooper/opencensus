class TilesController < ApplicationController
  def show
    zoom_level = params[:zoom_level].to_i
    tile_column = params[:tile_column].to_i
    tile_row = params[:tile_row].to_i

    tile = Tile.find(zoom_level, tile_row, tile_column)

    response.headers['Content-Type'] = 'application/json'

    render(:text => tile.json)
  end
end
