#!/bin/bash
#
#
# Make preview pictures of MCD43D products

PREVIEW_CMD="python /home/zhan.li/Workspace/src/viirs-tools/viirs-utils/plot_hdf5_preview.py"
H4TOH5="/home/zhan.li/Programs/h4h5tools-2.2.3/bin/h4toh5"

read -d '' USAGE <<EOF
preview_mcd43d.sh [options] MCD43D_FILE_NAME

Options

  --outdir, required
    Directory to output all the preview figures.

  --outid, required
    A string label to attach to all the output figure files for identification.

  --pid, required
    Product ID of the input product file to preview.

  --datafield, optional
    Names of data field to preview, one or multiple names separated by
    comma ','. If data field name has spaces, enclose the name with
    double quotes '"' or single quotes "'". For example:
    --datafield='BRDF_Albedo_Parameters_Band1',"BRDF_Albedo_Band_Mandatory_Quality_Band1". If
    no data field name provided, preview all the recognizalbe data
    fields in the input file.

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

DATAFIELD=""

OPTS=`getopt -o D --long pid:,outdir:,outid:,datafield: -n 'preview_mcd43d.sh' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options." >&2 ; echo "${USAGE}" ; exit 1 ; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in 
        --pid )
            case "${2}" in
                "") shift 2 ;;
                *) PID=${2} ; shift 2 ;;
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
        --datafield )
            case "${2}" in 
                "") shift 2 ;;
                *) DATAFIELD=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done
MINPARAMS=1
if [[ ${#} < ${MINPARAMS} ]]; then
    echo "${USAGE}"
    exit 1
fi
INFILE=${1}

if [[ -z ${OUTDIR} || -z ${OUTID} ]]; then
    echo "${USAGE}"
    exit 1
fi

if [[ -z ${PID} ]]; then
    echo "${USAGE}"
    exit 1
fi

INPID=${PID}
PID=$(echo "${PID^^}" | sed 's/[0-9]*$//')

function inArray ()
{
    local id=${1}
    local list=($(echo "${2}"))
    local i
    for (( i=0; i<${#list[@]}; ++i ));
    do
        if [[ ${list[i]^^} == ${id^^} ]]; then
            return 1
        fi
    done
    return 0
}

MYPRVOPTS="--downsample_size 1 --stretch_min 0 --stretch_max 1000 --colormap jet"
function customPrvOpts ()
{
    local pid=${1}
    local ds=${2}

    local found=-1

    local partopts="--downsample_size 1"
    if [[ ${pid:${#pid}-1:1} == "D" ]]; then
        partopts="--downsample_size 10"
    fi
    
    echo "${ds}" | grep -q -i "Mandatory_Quality"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 1 --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -q -i "Band_Quality"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 3 --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -q -i "BRDF_Quality"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        local tmp=5 # C product
        if [[ ${pid:${#pid}-1:1} == "D" ]]; then
            tmp=1 # D product
        fi
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max ${tmp} --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -i "Snow" | grep -q -i -v "Percent"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 1 --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -q -i "Platform"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 2 --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -q -i "land.*water.*type"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 7 --colormap Paired"
        return 0
    fi

    echo "${ds}" | grep -q -i "local.*solar.*noon"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 90 --colormap jet"
        return 0
    fi

    echo "${ds}" | grep -q -i "ValidObs"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 16 --colormap Paired --transform_func popcount"
        return 0
    fi

    echo "${ds}" | grep -q -i "Percent"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 100 --colormap jet"
        return 0
    fi

    echo "${ds}" | grep -q -i -E "(Nadir|NBAR)"
    found=$?
    if [[ ${found} -eq 0 ]]; then
        local tmp=10000
        if [[ "${pid}" == "MCD43D" ]]; then
            tmp=1000
        fi
        MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max ${tmp} --colormap jet"
        return 0
    fi

    # default options
    # Parameters, BSA, WSA, Uncertainty
    MYPRVOPTS="${partopts} --stretch_min 0 --stretch_max 1000 --colormap jet"
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

plotPreview () 
{
    # by default, bash variables are global. We have to explicitly
    # declare variables as local if we want to limit them within this
    # function.
    local fname=$1
    local oflabel=$2

    local tmp
    local alldsnamearr
    local alldsnamearr_us
    local dsnamearr
    local dsname
    local i
    local j
    local k

    # convert MCD43 hdf4 to hdf5 file
    tmp=${fname/".hdf"/".h5"}
    if [[ ! -r ${tmp} ]]; then
        echo "h4toh5 is converting ${fname} to ${tmp} ..."
        ${H4TOH5} -eos ${fname} ${tmp}
        if [[ $? != 0 ]]; then
            echoErrorStr "h4toh5 failed to convert ${fname} to ${tmp}!"
            return 1
        fi
    fi
    fname=${tmp}

    OUTCSVFILE=${OUTDIR}/metadata_$(basename ${fname} ".h5").csv

    # Use newline to construct the array rather than space as the
    # dataset name may contain spaces.
    OLDIFS=${IFS}
    IFS=$'\n'
    alldsnamearr=($(h5ls -rl ${fname} | sed -n 's/.*Data\\ Fields\/\(.*\) Dataset.*/\1/p' | sed 's/\\ / /'))
    alldsnamearr_us=($(h5ls -rl ${fname} | sed -n 's/.*Data\\ Fields\/\(.*\) Dataset.*/\1/p' | sed 's/\\ /_/'))
    IFS=${OLDIFS}

    if [[ -z ${DATAFIELD} ]]; then
        for ((j=0; j<${#alldsnamearr[@]}; j++))
        do
            dsnamearr+=("${alldsnamearr[j]}")
        done
    else
        while IFS= read -r -d ',' tmp;
        do
            inArray "$(echo ${tmp} | sed s/" "/"_"/)" "$(echo ${alldsnamearr_us[@]})"
            if [[ $? != 1 ]]; then
                echoWarnStr "${tmp} NOT found, will be skipped."
            else
                dsnamearr+=("${tmp}")
            fi
        done < <(echo "${DATAFIELD},")
    fi

    > ${OUTCSVFILE}
    local tmpcsv=$(mktemp --tmpdir=${OUTDIR})
    HEADER=0
    ATTR_KEYS="long_name _FillValue units valid_range scale_factor Description"
    for ((j=0; j<${#dsnamearr[@]}; j++))
    do
        dsname=${dsnamearr[j]}
        echoInfoStr "${INPID^^} data field name = ${dsname}"

        outprefix=${INPID,,}_${dsname,,}
        outprefix=${outprefix//" "/"_"}

        customPrvOpts "${PID}" "${dsname}"
        echo ${PREVIEW_CMD} --h5f ${fname} --dataset "${dsname}" --background 255 255 255 --colorbar --of "${OUTDIR}/${outprefix}_${oflabel}.png" ${MYPRVOPTS} --attr_keys ${ATTR_KEYS} --ocsv ${tmpcsv}
        ${PREVIEW_CMD} --h5f ${fname} --dataset "${dsname}" --background 255 255 255 --colorbar --of "${OUTDIR}/${outprefix}_${oflabel}.png" ${MYPRVOPTS} --attr_keys ${ATTR_KEYS} --ocsv ${tmpcsv}
        copyCsv ${tmpcsv}

    done

    rm -rf ${tmpcsv}
}

plotPreview ${INFILE} ${OUTID}