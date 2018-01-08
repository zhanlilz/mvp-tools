
#ifndef TILE_H
#define TILE_H

#include "hdf.h"                /* HDF header files */
#include "mfhdf.h"
#include "HdfEosDef.h"
#include "PGS_GCT.h"
#include "isinu.h"

typedef struct {
  long nl, ns;
  long nl_tile, ns_tile;
  long nl_offset, ns_offset;
  long nl_p, ns_p;
  double siz_x, siz_y;
  double ul_x, ul_y;
  PGSt_integer projId;
  int proj;
  Isinu_t isinu;
} Tile_t;

Tile_t *TileInit(int iproj, int pixel_size_ratio, long *nl, long *ns);
int TileFwd(const Tile_t *tile, double lon, double lat,
            int *itile_line, int *itile_samp, double *line, double *samp);
int TileFwdMap(const Tile_t *tile, int itile_line, int itile_samp, 
               double line, double samp, double *x, double *y);
int TileFwdPix(const Tile_t *tile, int itile_line, int itile_samp, 
               double line, double samp, 
	       double *line_global, double *samp_global);
int TileInv(const Tile_t *tile, int itile_line, int itile_samp, 
            double line, double samp, double *lon, double *lat);
int TileInvMap(const Tile_t *tile, double x, double y,
               int *itile_line, int *itile_samp, double *line, double *samp);
int TileInvPix(const Tile_t *tile, double line_global, double samp_global,
               int *itile_line, int *itile_samp, double *line, double *samp);
void TileFree(Tile_t *tile);

#endif
