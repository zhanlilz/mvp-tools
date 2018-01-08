
#include <stdlib.h>
#include <math.h>
#include "error.h"
#include "isinu.h"
#include "pi.h"

/* Constants */

void IsinuInit(Isinu_t *this, long nrow_half, double sphere) {
  long irow;
  double clat;
  long ncol, ncol_cen;

  if (nrow_half < 1) ERROR("invalid parameter (nrow_half)", "IsinuInit");

  this->nrow_half = nrow_half;
  this->nrow = this->nrow_half * 2;
  this->sphere_inv = 1.0 / sphere;
  this->ang_size_inv = ((double)this->nrow) / PI;

  this->icol_cen = (long *)calloc((size_t)this->nrow_half, sizeof(long));
  if (this->icol_cen == (long *)NULL) 
    ERROR("allocating memory (icol_cen)", "IsinuInit");
  this->ncol_inv = (double *)calloc((size_t)this->nrow, sizeof(double));
  if (this->ncol_inv == (double *)NULL) 
    ERROR("allocating memory (ncol_inv)", "IsinuInit");

  /* Do for each row */

  for (irow = 0; irow < nrow_half; irow++) {

    /* Calculate latitude at center of row */

    clat = HALF_PI * (1.0 - ((double)irow + 0.5) / this->nrow_half);
    
    /* Calculate number of columns per row */

    ncol = (long)((2.0 * cos(clat) * this->nrow) + 0.5);
    if (ncol < 1) ncol = 1;

    /* Save the center column and inverse of the number of columns */

    this->icol_cen[irow] = (ncol + 1) / 2;
    this->ncol_inv[irow] = 1.0 / ((double)ncol);
    ncol_cen = ncol;
  }

  /* Inverse of the distance at the equator between 
   * the centers of two columns */

  this->col_dist_inv = ncol_cen / (TWO_PI * sphere);

  return;
}

int IsinuCheck(const Isinu_t *this, double x, double y) {
  double lat, flon;
  double row, col;
  long irow;

  /* Latitude */

  lat = y * this->sphere_inv;
  if (lat < -HALF_PI  ||  lat > HALF_PI) return (1);

  /* Integer row number */

  row = (HALF_PI - lat) * this->ang_size_inv;
  irow = (long)row;
  if (irow >= this->nrow_half) irow = (this->nrow - 1) - irow;
  if (irow < 0) irow = 0;
  
  /* Column number (relative to center) */

  col = x * this->col_dist_inv;
  
  /* Fractional longitude (between 0 and 1) */

  flon = (col + this->icol_cen[irow]) * this->ncol_inv[irow];
  if (flon < 0.0  ||  flon > 1.0) return (1);

  return (0);
}

void IsinuFree(Isinu_t *this) {
  free(this->icol_cen);
  free(this->ncol_inv);
  return;
}
