/* 

File: error.c
  
Purpose: Function for handling fatal errors.

Functions:
  Error - Exit's program with failure status after writting error message.

Notes:
  The ERROR macro can be used to automaticlly get the source file name and line
  number.

Author: Robert Wolfe, NASA GSFC Code 922, Raytheon ITSS

Date: July 30, 1999
  
*/

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

void Error(const char *message, const char *module, 
               const char *source, long line) {
  if (errno) perror(" i/o error ");
  fprintf(stderr, " error [%s, %s:%ld] : %s\n", module, source, line, message);
  exit(EXIT_FAILURE);
}
