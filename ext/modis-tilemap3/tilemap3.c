
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include "hdf.h"                /* HDF header files */
#include "mfhdf.h"
#include "HdfEosDef.h"
#include "PGS_GCT.h"
#include "error.h"
#include "proj.h"
#include "isinu.h"
#include "tile.h"
#include "pi.h"

/* #define DEBUG */

/* Constants */

#define HDF_ERROR (-1)

/* Type definitions */

#define NPIXEL_SIZE (7)
#define NTYPE_TILE (3)

enum {PIXEL_SIZE_RATIO_K = 1, PIXEL_SIZE_RATIO_H = 2, PIXEL_SIZE_RATIO_Q = 4, 
      PIXEL_SIZE_RATIO_S = -1, PIXEL_SIZE_RATIO_M = -2,  
      PIXEL_SIZE_RATIO_L = -3, PIXEL_SIZE_RATIO_X = -4};
enum {DIRECTION_FWD, DIRECTION_INV};
enum {TYPE_TILE_PIX, TYPE_GLOBAL_MAP, TYPE_GLOBAL_PIX};

typedef struct {
  int proj;
  int pixel_size_ratio;
  int direction;
  int type;
  char *map_name;
  double lon, lat;
  double line, samp;
  double line_global, samp_global;
  double x, y;
  int itile_line, itile_samp;
} Param_t;

/* Constants */

const Proj_t PROJ[NPROJ] = {
  {ISIN_K, PGSd_ISINUS, 1, 
   -20015109.354, 10007554.677, 926.62543305,
   -1, 6371007.181, 
   1200, 1200, 18, 36, 
   (18 * 1200), (36 * 1200),
   { 90,  540, 1080, 4320},  /* factors == 240, 40, 20, 5 */
   {180, 1080, 2160, 8640},
   {  0,    0,    0,    0},
   {  0,    0,    0,    0}},
  {ISIN_H, PGSd_ISINUS, 1, 
   -20015109.354, 10007554.677, 926.62543305,
   -1, 6371007.181, 
   1200, 1200, 18, 36, 
   (18 * 1200), (36 * 1200),
   { 90,  540, 1080, 4320},
   {180, 1080, 2160, 8640},
   {  0,    0,    0,    0},
   {  0,    0,    0,    0}},
  {ISIN_Q, PGSd_ISINUS, 1, 
   -20015109.354, 10007554.677, 926.62543305,
   -1, 6371007.181, 
   1200, 1200, 18, 36, 
   (18 * 1200), (36 * 1200),
   { 90,  540, 1080, 4320},
   {180, 1080, 2160, 8640},
   {  0,   0,    0,    0},
   {  0,   0,    0,    0}},
  {GOODE, PGSd_GOOD, 2,  
   -20015500.0, 8673500.0, 1000.0,
   19, 6370997.0,    
   964, 1112, 18, 36,
   17347, 40031,
   { 72,  433,  867, 3470},   /* factors == 240.93, 40.06, 20.01, 5.00 */
   {166, 1001, 2002, 8009},   /* factors == 241.15, 39.99, 20.00, 5.00 */
   {  0,   0,     0,    3},
   {  0,   0,     0,    1}}, 
  {LAEA_NP, PGSd_LAMAZ, 3, 
   -9058902.1845, 9058902.1845, 1002.701,
   -1, 6371228.0,
   951, 951, 19, 19,
   18069, 18069,
   { 70, 452, 903, 3614},   /* factors == 258.13, 39.98, 20.01, 5.00 */
   { 70, 452, 903, 3614},
   {  0,   1,   1,    7},
   {  0,   1,   1,    7}},
  {LAEA_SP, PGSd_LAMAZ, 4,  
   -9058902.1845, 9058902.1845, 1002.701,
   -1, 6371228.0,   
   951, 951, 19, 19,
   18069, 18069,
   { 70, 452, 903, 3614},
   { 70, 452, 903, 3614},
   {  0,   1,   1,    7},
   {  0,   1,   1,    7}},
  {SIN, PGSd_SNSOID, 5,  
   -20015109.354, 10007554.677, 926.62543305,
   -1, 6371007.181, 
   1200, 1200, 18, 36, 
   (18 * 1200), (36 * 1200),
   { 90,  540, 1080, 4320},
   {180, 1080, 2160, 8640},
   {  0,    0,    0,    0},
   {  0,    0,    0,    0}},
  {HAM, PGSd_HAMMER, 6,  
   -18020554.088,  9010277.044, 997.15328068, 
   -1, 6371228.0, 
   1004, 1004, 18, 36, 
   (18 * 1004), (36 * 1004),
   { 70, 452,  903, 3614},  /* factors == 258.17, 39.98, 20.01, 5.00 */
   {140, 904, 1806, 7228},
   {  0,   1,    1,    7},
   {  0,   2,    2,   14}}
};

/* Prototypes */

void GetParam(int argc, const char **argv, Param_t *p);
void Usage(const char *message);

/* Functions */

int main (int argc, const char **argv) {
  Tile_t *tile;
  long nl, ns;
  Param_t param;
  
  GetParam(argc, argv, &param);

  tile = TileInit(param.proj, param.pixel_size_ratio, &nl, &ns);

  if (param.direction == DIRECTION_FWD) {

    printf("lat %.6f  long %.6f  =>", (param.lat * DEG), (param.lon * DEG));
    if (TileFwd(tile, param.lon, param.lat, 
                &param.itile_line, &param.itile_samp, 
		&param.line, &param.samp))
      ERROR("invalid forward mapping (TileFwd)", "main");

    if (param.type == TYPE_TILE_PIX) {
      printf("  vert tile %d  horiz tile %d  line %.2f  samp %.2f\n",
              param.itile_line, param.itile_samp, param.line, param.samp);
    } else if (param.type == TYPE_GLOBAL_MAP) {
      if (TileFwdMap(tile, param.itile_line, param.itile_samp, 
		     param.line, param.samp, &param.x, &param.y))
        ERROR("invalid forward mapping (TileFwdMap)", "main");
      printf("  x %.2f  y %.2f\n", param.x, param.y);
    } else if (param.type == TYPE_GLOBAL_PIX) {
      if (TileFwdPix(tile, param.itile_line, param.itile_samp, 
		     param.line, param.samp, 
		     &param.line_global, &param.samp_global))
        ERROR("invalid forward mapping (TileFwdMap)", "main");
      printf("  line %.2f  samp %.2f\n", param.line_global, param.samp_global);
    }

  } else {

    if (param.type == TYPE_TILE_PIX) {
      printf("vert tile %d  horiz tile %d  line %.2f  samp %.2f  =>",
             param.itile_line, param.itile_samp, param.line, param.samp);
    } else if (param.type == TYPE_GLOBAL_MAP) {
      printf("x %.2f  y %.2f  =>", param.x, param.y);
      if (TileInvMap(tile, param.x, param.y, 
                     &param.itile_line, &param.itile_samp, 
		     &param.line, &param.samp))
        ERROR("invalid inverse mapping (TileInvMap)", "main");
    } else if (param.type == TYPE_GLOBAL_PIX) {
      printf("  line %.2f  samp %.2f  =>", 
             param.line_global, param.samp_global);
      if (TileInvPix(tile, param.line_global, param.samp_global, 
		     &param.itile_line, &param.itile_samp, 
		     &param.line, &param.samp))
        ERROR("invalid inverse mapping (TileInvMap)", "main");
    }

    if (TileInv(tile, param.itile_line, param.itile_samp, 
		param.line, param.samp, 
		&param.lon, &param.lat))
        ERROR("invalid inverse mapping", "main");
    printf("  lat %.6f  long %.6f\n", (param.lat * DEG), (param.lon * DEG));

  }

  TileFree(tile);

  exit(0);
}

void GetParam(int argc, const char **argv, Param_t *p) {
  char cproj[5], cpixel_size[2], cdirection[5], ctype[3];
  char *tproj[NPROJ] = {"is_k", "is_h", "is_q", "gh", "np", "sp", "sn", "ha"};
  char *tpixel_size[NPIXEL_SIZE] = {"k", "h", "q", "s", "m", "l", "x"};
  int pixel_size_ratio_lookup[NPIXEL_SIZE] = {
    PIXEL_SIZE_RATIO_K, PIXEL_SIZE_RATIO_H, PIXEL_SIZE_RATIO_Q,
    PIXEL_SIZE_RATIO_S, PIXEL_SIZE_RATIO_M, PIXEL_SIZE_RATIO_L,
    PIXEL_SIZE_RATIO_X
  };
  char *tdirection[2] = {"fwd", "inv"};
  int direction_lookup[2] = {DIRECTION_FWD, DIRECTION_INV};
  char *ttype[NTYPE_TILE] = {"tp", "gm", "gp"};
  int type_lookup[NTYPE_TILE] = {
    TYPE_TILE_PIX, TYPE_GLOBAL_MAP, TYPE_GLOBAL_PIX
  };
  int i, ic, len;
  double val1, val2;
  int ival1, ival2;

  /* parse the command line */

  argv++; argc--;
  i = 0;
  if (argc != 6  &&  argc != 8) Usage("invalid number of arguments (a)");

  /* get output projection */

  len = strlen(*argv);
  if (len > 4) ERROR("invalid value (proj)", "GetParam");
  for (ic = 0; ic < len; ic++) cproj[ic] = (*argv)[ic];
  cproj[len] = '\0';
  argv++; argc--;

  for (i = 0; i < NPROJ; i++)
    if (strcmp(cproj, tproj[i]) == 0) break;
  if (i >= NPROJ) ERROR("unknown value (proj)", "GetParam");
  p->proj = i;

  /* get pixel size ratio */

  len = strlen(*argv);
  if (len > 2) ERROR("invalid value (pixel_size)", "GetParam");
  for (ic = 0; ic < len; ic++) cpixel_size[ic] = (*argv)[ic];
  cpixel_size[len] = '\0';
  argv++; argc--;

  for (i = 0; i < NPIXEL_SIZE; i++)
    if (strcmp(cpixel_size, tpixel_size[i]) == 0) break;
  if (i >= NPIXEL_SIZE) ERROR("unknown value (pixel_size)", "GetParam");
  p->pixel_size_ratio = pixel_size_ratio_lookup[i];

  /* direction */

  len = strlen(*argv);
  if (len > 4) ERROR("invalid value (direction)", "GetParam");
  for (ic = 0; ic < len; ic++) cdirection[ic] = (*argv)[ic];
  cdirection[len] = '\0';
  argv++; argc--;

  for (i = 0; i < 3; i++)
    if (strcmp(cdirection, tdirection[i]) == 0) break;
  if (i >= 2) ERROR("unknown value (direction)", "GetParam");
  p->direction = direction_lookup[i];

  /* type */

  len = strlen(*argv);
  if (len > 2) ERROR("invalid value (type)", "GetParam");
  for (ic = 0; ic < len; ic++) ctype[ic] = (*argv)[ic];
  ctype[len] = '\0';
  argv++; argc--;

  for (i = 0; i < NTYPE_TILE; i++)
    if (strcmp(ctype, ttype[i]) == 0) break;
  if (i >= NTYPE_TILE) ERROR("unknown value (type)", "GetParam");
  p->type = type_lookup[i];

  if (p->direction == DIRECTION_FWD) {

    /* Get the arguments for the forward direction */

    if (argc != 2) Usage("invalid number of arguments");

    if (sscanf(*argv, "%lg", &val1) != 1) Usage("invalid argument");
    p->lat = val1 * RAD;
    argv++; argc--;

    if (sscanf(*argv, "%lg", &val2) != 1) Usage("invalid argument");
    p->lon = val2 * RAD;
    argv++; argc--;

  } else if (p->type == TYPE_TILE_PIX) {

    /* Get the arguments for the inverse direction (tiles) */

    if (argc != 4) Usage("invalid number of arguments (b)");

    if (sscanf(*argv, "%d", &ival1) != 1) Usage("invalid argument");
    argv++; argc--;

    if (sscanf(*argv, "%d", &ival2) != 1) Usage("invalid argument");
    argv++; argc--;

    p->itile_line = ival1;
    p->itile_samp = ival2;

    if (sscanf(*argv, "%lg", &val1) != 1) Usage("invalid argument");
    argv++; argc--;

    if (sscanf(*argv, "%lg", &val2) != 1) Usage("invalid argument");
    argv++; argc--;

    p->line = val1;
    p->samp = val2;

  } else if (p->type == TYPE_GLOBAL_MAP) {

    /* Get the arguments for the inverse direction (global) */

    if (argc != 2) Usage("invalid number of arguments (c)");

    if (sscanf(*argv, "%lg", &val1) != 1) Usage("invalid argument");
    argv++; argc--;

    if (sscanf(*argv, "%lg", &val2) != 1) Usage("invalid argument");
    argv++; argc--;

    p->x = val1;
    p->y = val2;

  } else if (p->type == TYPE_GLOBAL_PIX) {

    /* Get the arguments for the inverse direction (global) */

    if (argc != 2) Usage("invalid number of arguments (c)");

    if (sscanf(*argv, "%lg", &val1) != 1) Usage("invalid argument");
    argv++; argc--;

    if (sscanf(*argv, "%lg", &val2) != 1) Usage("invalid argument");
    argv++; argc--;

    p->line_global = val1;
    p->samp_global = val2;

  }

  return;
}

void Usage(const char *message) {
  printf("Usage: \n");
  printf("  tilemap3 <projeciton> <pixel_size> <direction> <type> <point>\n");
  printf("     where <projection>: is_k, is_h, is_q, gh, np, sp, sn or ha\n");
  printf("           <pixel_size>: k, h, q, s, m, l or x\n");
  printf("           <direction>: fwd or inv\n");
  printf("           <type>: tp, gm or gp\n");
  printf("           <point>: <latitude>, <longitude> (forward mapping)\n");
  printf("                    <vert tile> <horiz tile> <tile line> <tile samp>\n");
  printf("                       (inverse tile pixel mapping)\n");
  printf("                    <global line> <global samp>"
                              " (inverse global pixel mapping)\n");
  printf("                    <map x> <map y>"
                              " (inverse global map mapping)\n");
  ERROR(message, "Usage");
}
