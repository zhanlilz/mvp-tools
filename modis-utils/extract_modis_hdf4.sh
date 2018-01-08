#!/bin/bash

# Helper shell script to run IDL procedure extract_modis_hdf4.pro to
# retrieve MODIS product values at given lat/lon
#
# Zhan Li, zhan.li@umb.edu
# Created: Sat Mar 25 09:00:26 EDT 2017

read -d '' USAGE <<EOF
$(basename ${0}) [-D | --product_dir] PRODUCTDIR [-I | --product_id] PRODUCTID [-P | --parameter] PARAMETER_NAMES --loc LOCID --lat LAT --lon LON --year YEAR --bdoy BDOY --edoy EDOY --output OUTFILE

PARAMETER_NAMES, LOCID, LAT, LON, YEAR
  Accept multiple values separated by ','. The whole input must be
  enclosed by '"' if there is space.

List of sample names of parameters:
NBAR in red: Nadir_Reflectance_Band1
NBAR in NIR: Nadir_Reflectance_nir
WSA in shortwave: Albedo_WSA_shortwave
BSA in shortwave: Albedo_BSA_shortwave
QA for shortwave albedo: BRDF_Albedo_Band_Mandatory_Quality_shortwave

EOF

IDL="/usr/local/exelis/idl85/bin/idl -quiet -e"

OPTS=`getopt -o D:I:P: --long product_dir:,product_id:,parameter:,loc:,lat:,lon:,year:,bdoy:,edoy:,output: -n '$(basename ${0})' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options" >&2; echo "${USAGE}"; exit 1; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in
        -D | --product_dir )
            case "${2}" in
                "" ) shift 2 ;;
                *) PRODUCTDIR=${2} ; shift 2 ;;
            esac ;;
        -I | --product_id )
            case "${2}" in
                "" ) shift 2 ;;
                *) PRODUCTID=${2} ; shift 2 ;;
            esac ;;
        -P | --parameter )
            case "${2}" in
                "" ) shift 2 ;;
                *) PARAMETER_NAMES=${2} ; shift 2 ;;
            esac ;;
        --loc )
            case "${2}" in
                "" ) shift 2 ;;
                *) LOCID=${2} ; shift 2 ;;
            esac ;;
        --lat )
            case "${2}" in
                "" ) shift 2 ;;
                *) LAT=${2} ; shift 2 ;;
            esac ;;
        --lon )
            case "${2}" in
                "" ) shift 2 ;;
                *) LON=${2} ; shift 2 ;;
            esac ;;
        --year )
            case "${2}" in
                "" ) shift 2 ;;
                *) YEAR=${2} ; shift 2 ;;
            esac ;;
        --bdoy )
            case "${2}" in
                "" ) shift 2 ;;
                *) BDOY=${2} ; shift 2 ;;
            esac ;;
        --edoy )
            case "${2}" in
                "" ) shift 2 ;;
                *) EDOY=${2} ; shift 2 ;;
            esac ;;
        --output )
            case "${2}" in
                "" ) shift 2 ;;
                *) OUTFILE=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done

if ([ -z ${PRODUCTDIR} ] \
    || [ -z ${PRODUCTID} ] \
    || [ -z ${PARAMETER_NAMES} ] \
    || [ -z ${LAT} ] \
    || [ -z ${LON} ] \
    || [ -z ${YEAR} ] \
    || [ -z ${OUTFILE} ]); then
    echo "${USAGE}"
    echo
    echo "Missing required inputs"
    exit 2
fi
if [[ -z ${BDOY} ]]; then
    BDOY=1
fi
if [[ -z ${EDOY} ]]; then
    EDOY=366
fi

MYSH=$(readlink -f ${0})
MYDIR=$(dirname ${MYSH})
MYPRO="${MYDIR}/$(basename ${MYSH} ".sh").pro"
if [[ ! -f ${MYPRO} ]]; then
    echo "Can't find the IDL .pro file $(basename ${MYPRO})!"
    echo "It must be in the same folder as the helper shell script $(basename ${MYSH})"
    exit 3
fi

MYTM="${MYDIR}/../ext/modis-tilemap3/tilemap3_linux"
if [[ ! -f ${MYTM} ]]; then
    echo "Can't find the tile mapper command to use, "
    echo ${MYTM}
    exit 3
fi

# set up environmental variable IDL_PATH to include our .pro and
# dependent .pro
IDLPATHS="${MYDIR}"
export IDL_PATH='<IDL_DEFAULT>:'${IDLPATHS}

NDAYS=$((${EDOY}-${BDOY}+1))

PARAMETER_NAMES="'"${PARAMETER_NAMES//","/"','"}"'"

PRONAME=$(basename ${MYPRO} ".pro")
PROEXTRA=","
if [[ ! -z ${LOCID} ]]; then
    LOCID=${LOCID//","/"','"}
    PROEXTRA="${PROEXTRA} LOCID=['${LOCID}'],"
fi
PROEXTRA=${PROEXTRA%","}

${IDL} "RESOLVE_ROUTINE, '${PRONAME}', /COMPILE_FULL_FILE & ${PRONAME}, '${PRODUCTDIR}', '${PRODUCTID}', "[${PARAMETER_NAMES}]", "[${LAT}]", "[${LON}]", "[${YEAR}]", indgen(${NDAYS})+${BDOY}, '${OUTFILE}', TILEMAP3='${MYTM}' ${PROEXTRA}"
