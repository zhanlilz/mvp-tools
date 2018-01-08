
#include <stdlib.h>
#include <math.h>
#include "error.h"
#include "tile.h"
#include "proj.h"
#include "pi.h"

/* Constants */

#define GEO_EPS1 (0.0e-9)
#define GEO_EPS2 (0.5e-3)
#define MAP_EPS1 GEO_EPS1
#define MAP_EPS2 (GEO_EPS2 * 55)

extern const Proj_t PROJ[NPROJ];

Tile_t *TileInit(int iproj, int pixel_size_ratio, long *nl, long *ns) {
  Tile_t *tile;
  PGSt_double projParam[13];
  PGSt_integer directFlag;
  PGSt_SMF_status status;
  int i;
  long nrow_half;
  
  if (iproj < 0  ||  iproj >= NPROJ)
    ERROR("invalid projection", "TileInit");

  if ((tile = (Tile_t *) malloc(sizeof(Tile_t))) == NULL) 
    ERROR("allocating geo grid data structure", "TileInit");

  tile->proj = iproj;

  for (i = 0; i < 13; i++) projParam[i] = 0.0;
  projParam[0] = PROJ[iproj].sphere;
  switch (PROJ[iproj].proj) {
    case ISIN_K: 
      nrow_half = 180 * 60;
      IsinuInit(&tile->isinu, nrow_half, PROJ[iproj].sphere);
      projParam[8] = nrow_half * 2.0;
      projParam[10] = 1.0;
      break;
    case ISIN_H: 
      nrow_half = 180 * 60 * 2;
      IsinuInit(&tile->isinu, nrow_half, PROJ[iproj].sphere);
      projParam[8] = nrow_half * 2.0;
      projParam[10] = 1.0;
      break;
    case ISIN_Q: 
      nrow_half = 180 * 60 * 4;
      IsinuInit(&tile->isinu, nrow_half, PROJ[iproj].sphere);
      projParam[8] = nrow_half * 2.0;
      projParam[10] = 1.0;
      break;
    case LAEA_NP:
      projParam[5] = 90.0 * RAD;
      break;
    case LAEA_SP:
      projParam[5] = -90.0 * RAD;
      break;
  }

  if (pixel_size_ratio > 0) {

    *nl = PROJ[iproj].nl_grid * pixel_size_ratio;
    *ns = PROJ[iproj].ns_grid * pixel_size_ratio;
  
    tile->nl = *nl;
    tile->ns = *ns;
    tile->nl_tile = PROJ[iproj].nl_tile * pixel_size_ratio;
    tile->ns_tile = PROJ[iproj].ns_tile * pixel_size_ratio;
    tile->nl_offset = 0;
    tile->ns_offset = 0;
    tile->nl_p = *nl;
    tile->ns_p = *ns;
    tile->siz_x = tile->siz_y = PROJ[iproj].pixel_size / pixel_size_ratio;
    tile->ul_x = PROJ[iproj].ul_xul + (0.5 * tile->siz_x);
    tile->ul_y = PROJ[iproj].ul_yul - (0.5 * tile->siz_y);

  } else {

    *nl = PROJ[iproj].nl_global[(-1 - pixel_size_ratio)];
    *ns = PROJ[iproj].ns_global[(-1 - pixel_size_ratio)];
  
    tile->nl = *nl;
    tile->ns = *ns;
    tile->nl_tile = *nl;
    tile->ns_tile = *ns;
    tile->nl_offset = PROJ[iproj].nl_offset[(-1 - pixel_size_ratio)];
    tile->ns_offset = PROJ[iproj].ns_offset[(-1 - pixel_size_ratio)];
    tile->nl_p = *nl - (2 * tile->nl_offset);
    tile->ns_p = *ns - (2 * tile->ns_offset);
    tile->siz_x = (2.0 * -PROJ[iproj].ul_xul) / *ns;
    tile->siz_y = (2.0 *  PROJ[iproj].ul_yul) / *nl;
    tile->ul_x = PROJ[iproj].ul_xul + (0.5 * tile->siz_x);
    tile->ul_y = PROJ[iproj].ul_yul - (0.5 * tile->siz_y);

  }

  tile->projId = PROJ[iproj].gctp_id;

  directFlag = PGSd_GCT_FORWARD;
  status = PGS_GCT_Init(tile->projId, projParam, directFlag);
  if (status != PGS_S_SUCCESS) 
    ERROR("initializing forward map projection", "TileInit");

  directFlag = PGSd_GCT_INVERSE;
  status = PGS_GCT_Init(tile->projId, projParam, directFlag);
  if (status != PGS_S_SUCCESS) 
    ERROR("initializing inverse map projection", "TileInit");

  return tile;
}

int TileFwd(const Tile_t *tile, double lon, double lat,
            int *itile_line, int *itile_samp, double *line, double *samp) {
  PGSt_integer directFlag;
  PGSt_integer nPoints;
  PGSt_integer zone[1];
  PGSt_double latitude[1], longitude[1];
  PGSt_double mapX[1], mapY[1];
  PGSt_SMF_status status;
  double x, y;

  if (fabs(lon) > PI) ERROR("bad longitude", "MapFwd");
  if (fabs(lat) > HALF_PI) ERROR("bad latitude", "MapFwd");

  directFlag = PGSd_GCT_FORWARD;
  nPoints = 1;
  longitude[0] = lon;
  latitude[0] = lat;
  status = PGS_GCT_Proj(tile->projId, directFlag, nPoints,
                        longitude, latitude, mapX, mapY, zone);
  if (status != PGS_S_SUCCESS) 
    ERROR("forward mapping", "MapFwd");
  x = mapX[0];
  y = mapY[0];

  if (TileInvMap(tile, x, y, itile_line, itile_samp, line, samp) != 0)
    return (1);
  
  return (0);
}

int TileFwdPix(const Tile_t *tile, int itile_line, int itile_samp, 
               double line, double samp, 
	       double *line_global, double *samp_global) {

  *line_global = *samp_global = 0.0;

  if (line < -0.5  ||  line > (tile->nl_tile - 0.5)  ||
      samp < -0.5  ||  samp > (tile->ns_tile - 0.5)) 
    return (1);

  *line_global = line + (tile->nl_tile * (long)itile_line);
  *samp_global = samp + (tile->ns_tile * (long)itile_samp);
  if (*line_global < -0.5  ||  *line_global > (tile->nl_p - 0.5)  ||
      *samp_global < -0.5  ||  *samp_global > (tile->ns_p - 0.5)) 
    return (1);

  return (0);
}

int TileInvMap(const Tile_t *tile, double x, double y,
               int *itile_line, int *itile_samp, double *line, double *samp) {
  double line_global, samp_global;
  int istat;

  *itile_line = *itile_samp = 0;
  *line = *samp = 0.0;
 
  line_global = ((tile->ul_y - y) / tile->siz_y) - tile->nl_offset;
  samp_global = ((x - tile->ul_x) / tile->siz_x) - tile->ns_offset;

  istat = TileInvPix(tile, line_global, samp_global, 
                     itile_line, itile_samp, line, samp);
  if (istat != 0) return (1);

  return (0);
}

int TileInv(const Tile_t *tile, int itile_line, int itile_samp, 
           double line, double samp, double *lon, double *lat) {
  PGSt_integer directFlag;
  PGSt_integer nPoints;
  PGSt_integer zone[1];
  PGSt_double latitude[1], longitude[1];
  PGSt_double mapX[1], mapY[1];
  PGSt_SMF_status status;
  double x, y;

  *lat = *lon = 0.0;
  if (TileFwdMap(tile, itile_line, itile_samp, line, samp, &x, &y) != 0) 
    return (1);

  mapX[0] = x;
  mapY[0] = y;

  *lat = *lon = 0.0;
  if (tile->projId == ISIN_K  ||  
      tile->projId == ISIN_H  ||  
      tile->projId == ISIN_Q) {
    if (IsinuCheck(&tile->isinu, mapX[0], mapY[0])) return (1);
  }

  directFlag = PGSd_GCT_INVERSE;
  nPoints = 1;
  status = PGS_GCT_Proj(tile->projId, directFlag, nPoints,
                        longitude, latitude, mapX, mapY, zone);
  if (status == PGSGCT_W_INTP_REGION) return (1);
  if (status != PGS_S_SUCCESS) 
    ERROR("inverse mapping", "TileInv");
  
  *lon = longitude[0];
  *lat = latitude[0];
  if (fabs(*lon) > (PI + MAP_EPS1)) 
    ERROR("bad longitude returned from PGS_GCT_Proj", "TileInv");
  if (fabs(*lat) > (HALF_PI + MAP_EPS1)) 
    ERROR("bad latitude returned from PGS_GCT_Proj", "TileInv");

  return (0);
}

int TileFwdMap(const Tile_t *tile, int itile_line, int itile_samp, 
               double line, double samp, double *x, double *y) {
  double line_global, samp_global;
  int istat;

  *x = *y = 0.0;
  istat = TileFwdPix(tile, itile_line, itile_samp, line, samp, 
                     &line_global, &samp_global);
  if (istat != 0) return (1);

  *y = tile->ul_y - ((line_global + tile->nl_offset) * tile->siz_y);
  *x = tile->ul_x + ((samp_global + tile->ns_offset) * tile->siz_x);

  return (0);
}

int TileInvPix(const Tile_t *tile, double line_global, double samp_global,
               int *itile_line, int *itile_samp, double *line, double *samp) {
  long iline_global, isamp_global;

  *itile_line = *itile_samp = 0;
  *line = *samp = 0.0;

  if (line_global < (-0.5 - MAP_EPS2)  ||  
      line_global > (tile->nl - 0.5 + MAP_EPS2)) 
    return (1);
  if (samp_global < (-0.5 - MAP_EPS2)  ||  
      samp_global > (tile->ns - 0.5 + MAP_EPS2)) 
    return (1);

  iline_global = (long)(line_global + 0.5);
  if (iline_global >= tile->nl_p) iline_global = tile->nl - 1;
  if (iline_global < 0) iline_global = 0;

  isamp_global = (long)(samp_global + 0.5);
  if (isamp_global >= tile->ns_p) isamp_global = tile->ns - 1;
  if (isamp_global < 0) isamp_global = 0;
  
  *itile_line = iline_global / tile->nl_tile;
  *itile_samp = isamp_global / tile->ns_tile;
  
  *line = line_global - (*itile_line * (long)tile->nl_tile);
  *samp = samp_global - (*itile_samp * (long)tile->ns_tile);

  return (0);
}

void TileFree(Tile_t *tile) {
  if (tile->projId == ISIN_K  ||  
      tile->projId == ISIN_H  ||  
      tile->projId == ISIN_Q) IsinuFree(&tile->isinu);
  free(tile); 
  return;
}
