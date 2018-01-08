
#ifndef ISINU_H
#define ISINU_H

typedef struct {
  long nrow_half, nrow;
  double sphere_inv, ang_size_inv, col_dist_inv;
  long *icol_cen;
  double *ncol_inv;
} Isinu_t;

void IsinuInit(Isinu_t *this, long nrow_half, double sphere);
int IsinuCheck(const Isinu_t *this, double x, double y);
void IsinuFree(Isinu_t *this);

#endif
