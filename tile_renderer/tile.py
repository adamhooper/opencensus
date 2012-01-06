#!/usr/bin/env python

import math

class Tile(object):
    def __init__(self, width, height, coord):
        self.width = width
        self.height = height
        self.coord = coord

    # Returns the number of WGS84 degrees in each pixel.
    #
    # This will return the smaller dimension. For instance, in a
    # 256x256 tile at zoom 0, there are 360 degrees East-West and
    # 170 degrees North-South (Google's spherical Mercator projection),
    # so the result will be 170 / 256.
    #
    # Why lower? See getFloatDecimalsForZoom(). Lower degrees per pixel
    # makes that function look to make things sharper. Better too sharp
    # than not sharp enough.
    def getDegreesPerPixel(self):
        zoomFactor = 2 ** self.coord.zoom

        # at zoom 0, each tile is 360 degrees (e-w) and 180 degrees (n-s)
        ewDegrees = 360.0 / zoomFactor
        nsDegrees = 170.0 / zoomFactor

        ewDegreesPerPixel = ewDegrees / self.width
        nsDegreesPerPixel = nsDegrees / self.height

        return min(ewDegreesPerPixel, nsDegreesPerPixel)

    def getMetersPerPixel(self):
        zoomFactor = 2 ** self.coord.zoom
        # http://wiki.openstreetmap.org/wiki/Zoom_levels
        metersPerPixel = 156412.0 / zoomFactor
        return metersPerPixel

    # Returns the number of decimals of precision we need to transfer.
    #
    # When zoomed way out, we don't need to transfer 15 decimal places. This
    # method will determine the minimum number of decimal places which will
    # make the output correct within 0.5 pixels.
    def getFloatDecimalsForZoom(self):
        degreesPerPixel = self.getDegreesPerPixel()
        error = degreesPerPixel / 2
        return int(math.ceil(-math.log10(error)))

    # Get the minimum area a polygon must have to be rendered.
    #
    # We hide smaller polygons because they take long to process, both on the
    # back-end and the front-end. What's more, they make the map seem
    # cluttered. People can find the smaller polygons by zooming in.
    def getMinAreaForZoom(self):
        min_pixels = 200
        return int(self.getMetersPerPixel() ** 2 * min_pixels)

    # Get the minimum area an island polygon must have to be rendered.
    #
    # Islands have a smaller minimum area than normal land. That's because
    # we assume landlocked polygons have larger parent polygons, so the map
    # won't seem like it's missing data. Island polygons do not have larger
    # parents, so if we omitted them there would be no data to cover up our
    # shortcut.
    def getMinIslandAreaForZoom(self):
        min_pixels = 30
        return int(self.getMetersPerPixel() ** 2 * min_pixels)

    def getTopLeftCoord(self):
        return self.coord

    def getBottomRightCoord(self):
        return self.coord.right().down()
