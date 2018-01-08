/* 

File: error.h
  
Purpose: Header file for error.c - see error.c for more information. 

Author: Robert Wolfe, NASA GSFC Code 922, Raytheon ITSS

Date: July 30, 1999
  
*/

#ifndef ERROR_H
#define ERROR_H

#define ERROR(message, module) \
          Error((message), (module), (__FILE__), (long)(__LINE__))

void Error(const char *message, const char *module, 
              const char *source, long line);

#endif
