# MVP-Toolbox: a collection of handy tools to use MODIS and VIIRS products from NASA.

## Authors and contacs:
* Zhan Li, zhan.li AT umb dot edu, the current custodian.
* Qingsong Sun, qingsong.sun AT umb dot edu.
* Yan Liu, yan.liu AT umb dot edu.
* Crystal Schaaf, crystal.schaaf AT umb dot edu. 
* SPECTRALMASS website [https://www.umb.edu/spectralmass]

## Introduction to the Toolbox

A large component of this tool box concerns the use of
BRDF/Albedo/NBAR products from MODIS/VIIRS and related MODIS/VIIRS
products such as MOD08 the gridded atmospheric product for the
calculation of diffuse light fraction for blue-sky albedo
calcuation. However, as this toolbox grows through the evolution of
MODIS/VIIRS products, we expect to add more tools to cover wider range
of MODIS/VIIRS products.


## Organization of the Toolbox

### actual-albedo-tool

A vintage program to calculate the blue-sky albedo with either (1) weighted sum of BSA and WSA, or (2) full expression. To be updated for the latest M/V products. 

### common-utils

Tools that apply to both MODIS and VIIRS products including:

* Downloading M/V products from NASA test product ftps, and a few DAACs such as LAADS and LP. 
* Generate preview images and stats of a given MCD43/VNP43 product file.
* Compare two MCD43/VNP43 product files and generate comparison figures and stats. 

### mcd43t-processing

Processing of internal MCD43T products for product testing. 

### modis-utils

Tools that apply to only MODIS products. 

### VIIRS-utils

Tools that apply to only VIIRS products. 

### data

Supporting data to run some of the tools. 

### ext

External dependencies (libraries and programs) to run some of the tools.
