/* 

File: bool.h

Purpose: Header file for declaring the bool type.

Author: Robert Wolfe, NASA GSFC Code 922, Raytheon ITSS

Date: November 6, 1998
  
*/


#ifndef BOOL_H
#define BOOL_H

#ifdef true
#undef true
#endif
#ifdef false
#undef false
#endif
typedef enum {false = 0, true = 1} bool;

#endif
