/**
 * calculate black-sky, white-sky and actual albedo for a single pixel
 * by accepting the following command line parameters:
 * [-par]    parameters for three kernels
 * They should be entered in the sequence of f_iso, f_vol and f_geo 
 * (same as in the MOD43B1) and should be the actual float number. 
 * Please note the file values in MOD43B1 are the scaled interger 
 * numbers. They should be re-scaled to the actual values by dividing by
 * 1000. Normally, these parameters are in the range of [0..1]
 * [-fd]    fraction of the diffuse light
 * You can use your own estimation or by running program "tell_skyl.exe" 
 * to get the estimation from a pre-defined lookup table. The data range
 * should be [0..1]
 * [-szn]   solar zenith angle in degree
 * data range should be between 0 and 89 degrees  
 *
 * by Feng Gao at Boston University on July, 2002
 * contact fgao@crsa.bu.edu
 *
 **/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef struct
{
  float iso;
  float vol;
  float geo;
} PARAMETERS;

typedef struct
{
  int aerosol_type;
  int bandno;
  float solar_zenith;
  float optical_depth;
  float skyl;
} SKYL;

#ifndef PI
#define PI 3.1415926535
#endif
#define D2R PI/180.0

#define DBL_FILL (-9999.9)

float cal_bsa (PARAMETERS p, float szn);
float cal_bsa_klut (PARAMETERS p, float szn);
float cal_wsa (PARAMETERS p);
float cal_actual_albedo (PARAMETERS p, SKYL s);

double bsaLiSparseRker[91] =
  { -1.287889, -1.287944, -1.288058, -1.288243, -1.288516, -1.288874,
  -1.289333, -1.289877, -1.290501, -1.291205,
  -1.291986, -1.292855, -1.293812, -1.294861, -1.295982, -1.297172,
  -1.298447, -1.299805, -1.301228, -1.302730,
  -1.304319, -1.306023, -1.307829, -1.309703, -1.311615, -1.313592,
  -1.315674, -1.317847, -1.320090, -1.322396,
  -1.324763, -1.327212, -1.329779, -1.332436, -1.335150, -1.337899,
  -1.340710, -1.343621, -1.346625, -1.349686,
  -1.352780, -1.355925, -1.359123, -1.362429, -1.365825, -1.369290,
  -1.372774, -1.376264, -1.379825, -1.383465,
  -1.387144, -1.390834, -1.394543, -1.398269, -1.402071, -1.405931,
  -1.409818, -1.413691, -1.417533, -1.421378,
  -1.425284, -1.429204, -1.433052, -1.436887, -1.440693, -1.444474,
  -1.448251, -1.452013, -1.455691, -1.459185,
  -1.462709, -1.466247, -1.469651, -1.472869, -1.476028, -1.479219,
  -1.482235, -1.485117, -1.487871, -1.490654,
  -1.493254, -1.495838, -1.498365, -1.500982, -1.503707, -1.506758,
  -1.510596, -1.516135, -1.526204, -1.555139, -37286.245539
};

double bsaRossThickker[91] = {
  -0.021079, -0.021026, -0.020866, -0.020598, -0.020223, -0.019740,
  -0.019148, -0.018447, -0.017636, -0.016713,
  -0.015678, -0.014529, -0.013265, -0.011883, -0.010383, -0.008762,
  -0.007018, -0.005149, -0.003152, -0.001024,
  0.001236, 0.003633, 0.006170, 0.008850, 0.011676, 0.014653, 0.017785,
  0.021076, 0.024531, 0.028154,
  0.031952, 0.035929, 0.040091, 0.044444, 0.048996, 0.053752, 0.058720,
  0.063908, 0.069324, 0.074976,
  0.080873, 0.087026, 0.093443, 0.100136, 0.107117, 0.114396, 0.121987,
  0.129904, 0.138161, 0.146772,
  0.155755, 0.165127, 0.174906, 0.185112, 0.195766, 0.206890, 0.218509,
  0.230649, 0.243337, 0.256603,
  0.270480, 0.285003, 0.300209, 0.316139, 0.332839, 0.350356, 0.368744,
  0.388061, 0.408372, 0.429747,
  0.452264, 0.476012, 0.501088, 0.527602, 0.555677, 0.585457, 0.617102,
  0.650800, 0.686769, 0.725269,
  0.766607, 0.811157, 0.859381, 0.911864, 0.969367, 1.032915, 1.103966,
  1.184742, 1.279047, 1.394945, 1.568252
};

double wsaKer[3] = { 1.0, 0.189184, -1.377622 };

void
main (int argc, char **argv)
{

  int i;
  PARAMETERS p;
  SKYL s;

  if (argc != 9) {
    printf ("Usage: %s [-par][-fd][-szn]\n", argv[0]);
    printf ("Example: %s -par 0.2 0.10 0.03 -fd 0.2 -szn 45\n", argv[0]);
    exit (1);
  }

  /* parse command line */
  for (i = 1; i < argc; i++) {
    if (strcmp (argv[i], "-par") == 0) {
      p.iso = atof (argv[++i]);
      p.vol = atof (argv[++i]);
      p.geo = atof (argv[++i]);
    } else if (strcmp (argv[i], "-fd") == 0)
      s.skyl = atof (argv[++i]);
    else if (strcmp (argv[i], "-szn") == 0)
      s.solar_zenith = atof (argv[++i]);
    else {
      printf ("\nWrong option:%s\n", argv[i]);
      printf ("Usage: %s [-par][-fd][-szn]\n", argv[0]);
      printf ("Example: %s -par 0.2 0.10 0.03 -fd 0.2 -szn 45\n", argv[0]);
      exit (1);
    }
  }

  printf ("Black-sky albedo: %5.3f\n", cal_bsa_klut (p, s.solar_zenith));
  printf ("White-sky albedo: %5.3f\n", cal_wsa (p));
  printf ("Actual surface albedo: %5.3f\n", cal_actual_albedo (p, s));

  exit (0);
}


/********************************************
 calculate actual albedo with the linear 
 combination of white-sky and black-sky albedo  
**********************************************/
float
cal_actual_albedo (PARAMETERS p, SKYL s)
{

  float actual_albedo;
  float bsa, wsa;

  bsa = cal_bsa_klut (p, s.solar_zenith);
  wsa = cal_wsa (p);

  actual_albedo = wsa * s.skyl + bsa * (1.0 - s.skyl);

  if (actual_albedo < 0)
    actual_albedo = 0;
  if (actual_albedo > 1)
    actual_albedo = 1;

  return actual_albedo;

}



/*******************************************
 calculate black-sky albedo according to 
 Wolfgang's polynomial albedo representation 
********************************************/
float
cal_bsa (PARAMETERS p, float solar_zenith)
// solar_zenith: in degree.
{

  int i;
  float bsa, bsa_weight[3], szn, sq_szn, cub_szn;
  float poly_coef[3][3] = { 1.0, -0.007574, -1.284909,
    0.0, -0.070987, -0.166314,
    0.0, 0.307588, 0.041840
  };

  szn = solar_zenith * D2R;
  sq_szn = szn * szn;
  cub_szn = sq_szn * szn;

  for (i = 0; i < 3; i++)
    bsa_weight[i] =
      poly_coef[0][i] + poly_coef[1][i] * sq_szn + poly_coef[2][i] * cub_szn;

  bsa = bsa_weight[0] * p.iso + bsa_weight[1] * p.vol + bsa_weight[2] * p.geo;

  return bsa;

}


/*******************************************
 calculate black-sky albedo using full
 integral of kernels accoring to the kernel
 integral LUT.
********************************************/
float
cal_bsa_klut (PARAMETERS p, float szn)
// szn: in degree
{
  float pars[3];
  pars[0] = p.iso;
  pars[1] = p.vol;
  pars[2] = p.geo;

  if (pars[0] < 0.0 || pars[1] < 0.0 || pars[2] < 0.0) {
    return DBL_FILL;
  }

  float ret = 0.0;


  int thisang;
  double angdis;

  thisang = (int) szn;
  angdis = szn - (double) thisang;

  if (thisang < 0)
    thisang = 0;
  if (thisang > 88.99999)
    thisang = (int) 88.99999;   /*only up to 89 degree for BSA LUT */

  double baskervalueLiSparseR;
  double bsakervalueRossThick;

  bsakervalueRossThick =
    bsaRossThickker[thisang] + (bsaRossThickker[thisang + 1] -
                                bsaRossThickker[thisang]) * angdis;
  baskervalueLiSparseR =
    bsaLiSparseRker[thisang] + (bsaLiSparseRker[thisang + 1] -
                                bsaLiSparseRker[thisang]) * angdis;

  ret =
    (1.0 * pars[0] + bsakervalueRossThick * pars[1] +
     baskervalueLiSparseR * pars[2]);

  if (ret < 0.0 && ret > -0.03) {
    ret = 0.0;
  }
  if (ret < 0.0) {
    ret = DBL_FILL;
  }

  return ret;
}


/* calculate white-sky albedo with fixed weight */
float
cal_wsa (PARAMETERS p)
{

  float wsa, wsa_weight[3] = { 1.0, 0.189184, -1.377622 };
  wsa = wsa_weight[0] * p.iso + wsa_weight[1] * p.vol + wsa_weight[2] * p.geo;
  return wsa;

}

float
cal_wsa_klut (PARAMETERS p)
{
  float pars[3];
  pars[0] = p.iso;
  pars[1] = p.vol;
  pars[2] = p.geo;

  if (pars[0] < 0.0 || pars[1] < 0.0 || pars[2] < 0.0) {
    return DBL_FILL;
  }

  int i;
  float ret = 0.0;

  for (i = 0; i < 3; i++) {
    ret += pars[i] * wsaKer[i];
  }

  if (ret < 0.0 && ret > -0.03) {
    ret = 0.0;
  }
  if (ret < 0.0) {
    ret = DBL_FILL;
  }

  return ret;
}
