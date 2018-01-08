#!/bin/bash
#
#
# Make comparison stats figures between MCD43C and VNP43C

CMP_CMD="python /home/zhan.li/Workspace/src/viirs-tools/viirs-utils/compare_mv_datasets.py"
H4TOH5="/home/zhan.li/Programs/h4h5tools-2.2.3/bin/h4toh5"

read -d '' USAGE <<EOF
compare_mv_products.sh [options] MCD43C_FILE_NAME VNP43C_FILE_NAME

Options
  --pid1, required
    Product ID of the first input product file to be compared.
  --pid2, required
    Product ID of the second input product file to be compared.

  --outdir, required
    Directory to output all the preview figures.

  --outid, required
    A string label to attach to all the output figure files for identification.

EOF

function echoErrorStr () 
{
    echo -e '\033[31m'${1}'\033[0m'
}
function echoWarnStr () 
{
    echo -e '\033[33m'${1}'\033[0m'
}
function echoInfoStr () 
{
    echo -e '\033[32m'${1}'\033[0m'
}

OPTS=`getopt -o D --long pid1:,pid2:,outdir:,outid: -n 'compare_mv_products.sh' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options." >&2 ; echo "${USAGE}" ; exit 1 ; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in 
        --pid1 )
            case "${2}" in
                "") shift 2 ;;
                *) PID1=${2} ; shift 2 ;;
            esac ;;
        --pid2 )
            case "${2}" in
                "") shift 2 ;;
                *) PID2=${2} ; shift 2 ;;
            esac ;;
        --outdir )
            case "${2}" in
                "") shift 2 ;;
                *) OUTDIR=${2} ; shift 2 ;;
            esac ;;
        --outid )
            case "${2}" in
                "") shift 2 ;;
                *) OUTID=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done
MINPARAMS=2
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "${USAGE}"
    exit 1
fi
MFILE=${1}
VFILE=${2}

if [[ -z ${OUTDIR} || -z ${OUTID} ]]; then
    echo "${USAGE}"
    exit 1
fi

if [[ -z ${PID1} || -z ${PID2} ]]; then
    echo "${USAGE}"
    exit 1
fi

INPID1=${PID1}
INPID2=${PID2}
PID1=$(echo "${PID1^^}" | sed 's/[0-9]*$//')
PID2=$(echo "${PID2^^}" | sed 's/[0-9]*$//')

BANDS1=""
BANDS2=""
function getBandNames ()
{
    local pid1=${1^^}
    local pid2=${2^^}

    if [[ "${pid1}" == "MCD43A" && "${pid2}" == "VNP43IA" ]]; then
        BANDS1=("Band1" "Band2" "Band6")
        BANDS2=("I1" "I2" "I3")
        return 0
    elif [[ "${pid1}" == "VNP43A" && "${pid2}" == "MCD43IA" ]]; then
        BANDS2=("Band1" "Band2" "Band6")
        BANDS1=("I1" "I2" "I3")
        return 0
    fi
    if [[ "${pid1}" == "MCD43C" && "${pid2}" == "VNP43C" ]]; then
        BANDS1=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS2=("M5" "M7" "M3" "M4" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    elif [[ "${pid1}" == "VNP43C" && "${pid2}" == "MCD43C" ]]; then
        BANDS2=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS1=("M5" "M7" "M3" "M4" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    fi
    if [[ "${pid1}" == "MCD43D" && "${pid2}" == "VNP43D" ]]; then
        BANDS1=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS2=("M5" "M7" "M3" "M4" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    elif [[ "${pid1}" == "VNP43D" && "${pid2}" == "MCD43D" ]]; then
        BANDS2=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS1=("M5" "M7" "M3" "M4" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    fi

    if [[ "${pid1}" == "MCD43A" && "${pid2}" == "MCD43A" ]]; then
        BANDS1=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS2=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        return 0
    fi
    if [[ "${pid1}" == "MCD43C" && "${pid2}" == "MCD43C" ]]; then
        BANDS1=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS2=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        return 0
    fi
    if [[ "${pid1}" == "MCD43D" && "${pid2}" == "MCD43D" ]]; then
        BANDS1=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        BANDS2=("Band1" "Band2" "Band3" "Band4" "Band5" "Band6" "Band7" "vis" "nir" "shortwave")
        return 0
    fi

    if [[ "${pid1}" == "VNP43IA" && "${pid2}" == "VNP43IA" ]]; then
        BANDS1=("I1" "I2" "I3")
        BANDS2=("I1" "I2" "I3")
        return 0
    fi
    if [[ "${pid1}" == "VNP43MA" && "${pid2}" == "VNP43MA" ]]; then
        BANDS1=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        BANDS2=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    fi
    if [[ "${pid1}" == "VNP43C" && "${pid2}" == "VNP43C" ]]; then
        BANDS1=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        BANDS2=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 
    fi
    if [[ "${pid1}" == "VNP43D" && "${pid2}" == "VNP43D" ]]; then
        BANDS1=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        BANDS2=("M1" "M2" "M3" "M4" "M5" "M7" "M8" "M10" "M11" "vis" "nir" "shortwave")
        return 0
    fi

    return 1
}

MYCMPOPTS="--stretch_min 0 0 --stretch_max 1 1 --bin_size 1e-3 1e-3 --scale_factor 1e-3 1e-3"
function customCmpOpts ()
{
    local pid1=${1}
    local dsname1=${2}
    local pid2=${3}
    local dsname2=${4}

    local found1=-1
    local found2=-1
    
    echo "${dsname1}" | grep -q -i "Mandatory_Quality"
    found1=$?
    echo "${dsname2}" | grep -q -i "Mandatory_Quality"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 1 1 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "Band_Quality"
    found1=$?
    echo "${dsname2}" | grep -q -i "Band_Quality"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 3 3 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "BRDF_Quality"
    found1=$?
    echo "${dsname2}" | grep -q -i "BRDF_Quality"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        local tmp1=5 # C product
        local tmp2=5 # C product
        if [[ ${pid1:${#pid1}-1:1} == "D" ]]; then
            tmp1=1 # D product
        fi
        if [[ ${pid2:${#pid2}-1:1} == "D" ]]; then
            tmp2=1 # D product
        fi
        MYCMPOPTS="--stretch_min 0 0 --stretch_max ${tmp1} ${tmp2} --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -i "Snow" | grep -q -i -v "Percent"
    found1=$?
    echo "${dsname2}" | grep -i "Snow" | grep -q -i -v "Percent"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 1 1 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "Platform"
    found1=$?
    echo "${dsname2}" | grep -q -i "Platform"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 2 2 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "land.*water.*type"
    found1=$?
    echo "${dsname2}" | grep -q -i "land.*water.*type"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 7 7 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "local.*solar.*noon"
    found1=$?
    echo "${dsname2}" | grep -q -i "local.*solar.*noon"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 90 90 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "ValidObs"
    found1=$?
    echo "${dsname2}" | grep -q -i "ValidObs"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 16 16 --bin_size 1 1 --transform_func popcount"
        return 0
    fi

    echo "${dsname1}" | grep -q -i "Percent"
    found1=$?
    echo "${dsname2}" | grep -q -i "Percent"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 100 100 --bin_size 1 1"
        return 0
    fi

    echo "${dsname1}" | grep -q -i -E "(Nadir|NBAR)"
    found1=$?
    echo "${dsname2}" | grep -q -i -E "(Nadir|NBAR)"
    found2=$?
    if [[ (${found1} -eq 0) && (${found2} -eq 0) ]]; then
        local tmp1=1e-4
        local tmp2=1e-4
        if [[ "${pid1}" == "MCD43D" ]]; then
            tmp1=1e-3
        fi
        if [[ "${pid2}" == "MCD43D" ]]; then
            tmp2=1e-3
        fi
        MYCMPOPTS="--stretch_min 0 0 --stretch_max 1 1 --bin_size 1e-3 1e-3 --scale_factor ${tmp1} ${tmp2}"
        return 0
    fi

    # default options
    # Parameters, BSA, WSA, Uncertainty
    MYCMPOPTS="--stretch_min 0 0 --stretch_max 1 1 --bin_size 1e-3 1e-3 --scale_factor 1e-3 1e-3"
    return 0
}

function copyCsv ()
{
    local srccsv=${1}
    # Copy diff. stats from tmp.csv to the designated csv file
    if [[ ${HEADER} -eq 0 ]]; then
        cat ${srccsv} >> ${OUTCSVFILE}
        HEADER=1
    else
        tail -n +2 ${srccsv} >> ${OUTCSVFILE}
    fi
}

function compareMcdVnp () 
{
    # by default, bash variables are global. We have to explicitly
    # declare variables as local if we want to limit them within this
    # function.
    local mfname=$1
    local vfname=$2
    local oflabel=$3

    local tmp
    local mtmparr
    local vtmparr
    local mdsname
    local vdsname
    local i
    local j
    local k
    local BIDX
    local mdsfound

    # convert hdf4 to hdf5 file
    tmp=${mfname/".hdf"/".h5"}
    if [[ ! -r ${tmp} ]]; then
        echo "h4toh5 is converting ${mfname} to ${tmp} ..."
        ${H4TOH5} -eos ${mfname} ${tmp}
        if [[ $? != 0 ]]; then
            echo "h4toh5 failed to convert ${mfname} to ${tmp}!"
            return 1
        fi
    fi
    mfname=${tmp}

    tmp=${vfname/".hdf"/".h5"}
    if [[ ! -r ${tmp} ]]; then
        echo "h4toh5 is converting ${vfname} to ${tmp} ..."
        ${H4TOH5} -eos ${vfname} ${tmp}
        if [[ $? != 0 ]]; then
            echo "h4toh5 failed to convert ${vfname} to ${tmp}!"
            return 1
        fi
    fi
    vfname=${tmp}

    # Construct a CSV file name for writing difference stats between
    # corresponding datasets between the two files.
    OUTCSVFILE=${OUTDIR}/diff_stats_$(basename ${mfname} ".h5")_vs_$(basename ${vfname} ".h5").csv

    # Use newline to construct the array rather than space as the
    # dataset name may contain spaces.
    OLDIFS=${IFS}
    IFS=$'\n'
    mtmparr=($(h5ls -rl ${mfname} | sed -n 's/.*Data\\ Fields\/\(.*\) Dataset.*/\1/p' | sed 's/\\ / /'))
    vtmparr=($(h5ls -rl ${vfname} | sed -n 's/.*Data\\ Fields\/\(.*\) Dataset.*/\1/p' | sed 's/\\ / /'))
    IFS=${OLDIFS}

    # get band names
    getBandNames ${PID1} ${PID2}
    if [[ $? -ne 0 ]]; then
        echoErrorStr "Cannot compare the two product IDs: ${PID1}, ${PID2}"
        exit 1
    fi

    > ${OUTCSVFILE}
    local tmpcsv=$(mktemp --tmpdir=${OUTDIR})
    HEADER=0
    for ((j=0; j<${#vtmparr[@]}; j++))
    do
        vdsname=${vtmparr[j]}
        # see if this VIIRS dataset name has a band name
        BIDX=-1
        for ((k=0; k<${#BANDS2[@]}; k++))
        do
            echo ${vdsname} | grep -q "${BANDS2[k]}"
            if [[ $? == 0 ]]; then
                BIDX=${k}
                break
            fi
        done

        # find the corresponding MODIS dataset
        mdsfound=-1
        local name_wanted
        for ((k=0; k<${#mtmparr[@]}; k++))
        do
            mdsname=${mtmparr[k]}
            if [[ ${BIDX} -ge 0 ]]; then
                # it is a narrow band dataset
                name_wanted=${vdsname/"${BANDS2[BIDX]}"/"${BANDS1[BIDX]}"}
            else
                # it is a generic dataset
                name_wanted=${vdsname}
            fi

            if [[ ${mdsname^^} == ${name_wanted^^} ]]; then
                mdsfound=0
                break
            else
                # check if just diff in ' ' vs '_'
                tmpname1=$(echo ${mdsname^^} | sed 's/ /_/')
                tmpname2=$(echo ${name_wanted^^} | sed 's/ /_/')
                if [[ ${tmpname1} == ${tmpname2} ]]; then
                    echoWarnStr "WARNING: Use a pair of similar but NOT the same data field names found from the two given files."
                    echo "${mdsname} V.S. ${vdsname}"
                    mdsfound=0
                    break
                else
                    # for CMG products, check if its the culprit of
                    # initial word "Global"
                    if [[ ${tmpname1##"GLOBAL_"} == ${tmpname2##"GLOBAL_"} ]]; then
                        echoWarnStr "WARNING: Use a pair of similar but NOT the same data field names found from the two given files."
                        echo "${mdsname} V.S. ${vdsname}"
                        mdsfound=0
                        break
                    fi
                fi
            fi

        done

        if [[ ${mdsfound} -eq 0 ]]; then
            # found the corresponding MODIS dataset
            mlabel=${INPID1,,}_${mdsname,,}_${oflabel}
            mlabel=${mlabel//" "/"_"}
            vlabel=${INPID2,,}_${vdsname,,}_${oflabel}
            vlabel=${vlabel//" "/"_"}

            echoInfoStr "Comparing ${INPID1^^} ${mdsname} V.S. ${INPID2^^} ${vdsname}"

            # get customized options to run the compare python script.
            customCmpOpts "${PID1}" "${mdsname}" "${PID2}" "${vdsname}"

            echo ${CMP_CMD} --stats --ocsv ${tmpcsv} --files ${mfname} ${vfname} --datasets "${mdsname}" "${vdsname}" --outdir ${OUTDIR} --labels "${mlabel}" "${vlabel}" ${MYCMPOPTS}
            ${CMP_CMD} --stats --ocsv ${tmpcsv} --files ${mfname} ${vfname} --datasets "${mdsname}" "${vdsname}" --outdir ${OUTDIR} --labels "${mlabel}" "${vlabel}" ${MYCMPOPTS}
            copyCsv ${tmpcsv}
        else
            # failed to find the MODIS dataset
            echoErrorStr "Failed to find the corresponding MODIS dataset for the VIIRS dataset ${vdsname}\n"
        fi
    done

    rm -rf ${tmpcsv}
}

compareMcdVnp ${MFILE} ${VFILE} ${OUTID}