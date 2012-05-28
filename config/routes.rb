Opencensus::Application.routes.draw do
  match('/censusfile/tiles/:zoom_level/:tile_column/:tile_row' => 'tiles#show',
        :constraints => { :zoom_level => /[0-9]+/, :tile_column => /[-0-9]+/, :tile_row => /[-0-9]+/ })

  root(:to => 'map#show')
end
