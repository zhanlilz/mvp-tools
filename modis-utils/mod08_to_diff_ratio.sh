#!/bin/bash

# Helper shell script to run IDL procedure mod08_to_diff_ratio.pro to
# calculate diffuse light ratio from MOD08 data.
#
# Zhan Li, zhan.li@umb.edu
# Created: Sat Mar 25 09:00:26 EDT 2017

read -d '' USAGE <<EOF
$(basename ${0}) --mod08 MOD08DIR --loc LOCID --lat LAT --lon LON --year YEAR --bdoy BDOY --edoy EDOY --time TIME --output OUTFILE [options]

LOCID, LAT, LON, YEAR, TIME
  Accept multiple values separated by ','. The whole input must be
  enclosed by '"' if there is space.

Options:

  -U, --UTC
    If set, the time given is UTC. Otherwise, by default the time is
    given as geographic local time, e.g. the satellite overpass local
    time, NOT the local time observed by adminitrative areas or
    daylight saving time.

EOF

IDL="/usr/local/exelis/idl85/bin/idl -quiet -e"

UTCFLAG=0
OPTS=`getopt -o U --long UTC,mod08:,loc:,lat:,lon:,year:,bdoy:,edoy:,time:,output: -n '$(basename ${0})' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options" >&2; echo "${USAGE}"; exit 1; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in
        --mod08 )
            case "${2}" in
                "" ) shift 2 ;;
                *) MOD08DIR=${2} ; shift 2 ;;
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
        --time )
            case "${2}" in
                "" ) shift 2 ;;
                *) TIME=${2} ; shift 2 ;;
            esac ;;
        --output )
            case "${2}" in
                "" ) shift 2 ;;
                *) OUTFILE=${2} ; shift 2 ;;
            esac ;;
        -U | --UTC )
            UTCFLAG=1 ; shift ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done

if ([ -z ${MOD08DIR} ] \
    || [ -z ${LAT} ] \
    || [ -z ${LON} ] \
    || [ -z ${YEAR} ] \
    || [ -z ${TIME} ] \
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

MYLUT="${MYDIR}/../data/skyl_lut-IDL.dat"
if [[ ! -f ${MYLUT} ]]; then
    echo "Can't find the LUT file to use, "
    echo ${MYLUT}
    exit 3
fi

# set up environmental variable IDL_PATH to include our .pro and
# dependent .pro
EXTPATH="${MYDIR}/../ext/astrolib/pro"
if [[ ! -d ${EXTPATH} ]]; then
    echo "Missisng external IDL dependencies astrolib"
    echo ${EXTPATH}
    exit 3
fi
IDLPATHS="${EXTPATH}:${MYDIR}"
for d in ${EXTPATH}/*/; do
    IDLPATHS="${d}:${IDLPATHS}"
done
export IDL_PATH='<IDL_DEFAULT>:'${IDLPATHS}

NDAYS=$((${EDOY}-${BDOY}+1))

PRONAME=$(basename ${MYPRO} ".pro")
PROEXTRA=","
if [[ ${UTCFLAG} -eq 1 ]]; then
    PROEXTRA="${PROEXTRA} /UTC,"
fi
if [[ ! -z ${LOCID} ]]; then
    LOCID=${LOCID//","/"','"}
    PROEXTRA="${PROEXTRA} LOCID=['${LOCID}'],"
fi
PROEXTRA=${PROEXTRA%","}
${IDL} "RESOLVE_ROUTINE, '${PRONAME}', /COMPILE_FULL_FILE & ${PRONAME}, '${MOD08DIR}', "[${LAT}]", "[${LON}]", "[${YEAR}]", indgen(${NDAYS})+${BDOY}, "[${TIME}]", '${OUTFILE}', LUTFILE='${MYLUT}' ${PROEXTRA}"
