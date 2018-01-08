Robert Wolfe, November 13, 2003

        0readme.txt - Readme file for the tilemap3 program (Release 4.0).

This tilemap3 program maps between geographic coordinates and various grids used
by the MODIS Land Science Team.

Usage:

  tilemap3 <projeciton> <pixel_size> <direction> <type> <point>

where 

  <projection>: is_k, is_h, is_q, gh, np or sp
     is_k - Integerized Sinusoidal using a ~1km (actually 30 arcsec) 
            underlying grid row size
     is_h - Integerized Sinusoidal using a ~500m (actually 15 arcsec)
            underlying grid row size
     is_q - Integerized Sinusoidal using a ~250m (actually 7.5 arcsec)
            underlying grid row size
     gh - Goodes Homolosine
     np - Lamberts Azmuthal Equal Area (LAEA), North Polar Region, EASI Grid
     sp - Lamberts Azmuthal Equal Area (LAEA), South Polar Region, EASI Grid
     sn - Sinusoidal grid
     ha - Hammer Atioff grid

  <pixel_size>: k, h or q
     k - ~1km
     h - ~500m
     q - ~250m
     s - ~240 km (small global grid)
     m - ~40 km (medium global grid)
     l - ~20 km (large global grid)
     x - ~5 km (extra large global grid)

  <direction>: fwd, inv, fwd, inv
     fwd - Forward mapping, from lat/long to projection
     inv - Inverse mapping, from projection to lat/long

  <type>: tp or gm
     tp - Map from/to tile and pixel within tile
     gm - Map from/to global map projection coordinates
     gp - Map from/to global pixel coordinates
     
  <point>: 
     forward mapping: <latitude> <longitude>
     inverse tile/pixel mapping: <vert tile> <horiz tile> <tile line> <tile samp> 
     inverse global map mapping: <map x> <map y>
     inverse global pixel mapping: <global line> <global sample>

Notes:

1. The latitude and longitude coordinates are in decimal degrees.
2. Map coordinates are in meters.
3. Tile coordinates are the horizontal and vertical tile locations. (0,0) is 
   the tile in the upper left corner of the grid.  Horizontal tile numbers
   increase to the right and vertical tiles numbers increase downward.
4. Pixel coordinates are line and sample locations within the tile or in the 
   global grid.  (0,0) is the pixel in the upper left corner of the tile.  
   Samples increase to the right and lines increase downward.
5. This program has been tested primarily on SGI computers.  Differences have 
   been found when running on a Linux platform when a point occurs very close
   to a row boundaries within the Integerized Sinusodal Projection.

Examples:

1. Forward map (fwd) a point with latitude 38.53 degrees and longitude -77.0 degrees
from Integerized Sinusoidal Grid with ~0.25km underlying grid size (is_q) and a ~1km
pixel size (k) to tile and pixel coordinates.

  % tilemap3 is_q k fwd tp 38.53 -77.0

  lat 38.530000  long -77.000000  =>  
    vert tile 5  horiz tile 11  line 175.90  samp 1171.23

2. Map the results from example 1 back to latitude and longitude

  % tilemap3 is_q k inv tp 5 11 175.90 1171.23
  vert tile 5  horiz tile 11  line 175.90  samp 1171.23  =>  
    lat 38.530000 long -77.000021

3. Map the original point to global map coordinates.

  % tilemap3 is_q k fwd gm 38.53 -77.0
  lat 38.530000  long -77.000000  =>  x -6697897.02  y 4284345.35

4. Map the original point to global pixel coordinates.

  % tilemap3 is_q k fwd gp 38.53 -77.0
  lat 38.530000  long -77.000000  =>  line 6175.90  samp 14371.23

----
