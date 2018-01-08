
#ifndef PROJ_H
#define PROJ_H

enum {ISIN_K, ISIN_H, ISIN_Q, GOODE, LAEA_NP, LAEA_SP, SIN, HAM, NPROJ};

typedef struct {
  int proj;
  int gctp_id; 
  int iproj_tile; 
  double ul_xul, ul_yul;
  double pixel_size;
  int sphere_code;
  double sphere;
  int nl_tile, ns_tile;
  int ntile_line, ntile_samp;
  int nl_grid, ns_grid;
  int nl_global[4], ns_global[4];
  int nl_offset[4], ns_offset[4];
} Proj_t;

#endif
