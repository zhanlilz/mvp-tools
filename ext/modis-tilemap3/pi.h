
#ifndef PI_H
#define PI_H

#include <math.h>

#ifndef M_PI
#define PI (3.141592653589793238)
#else
#define PI (M_PI)
#endif

#define TWO_PI (2.0 * PI)
#define HALF_PI (PI / 2.0)

#define DEG (180.0 / PI)
#define RAD (PI / 180.0)

#endif
