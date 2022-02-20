#!/bin/bash

usage="$0 --user [your_user_name] --password [your_password] -f ['h5'|'hdf'] -t [tile] -y [year] -p [parm] -n [num] -o <out_dir> -b <begin_doy> -e <end_doy>"

url_base='https://e4ftl01.cr.usgs.gov/MOTA/'

# jul year doy
# return YYYYMMDD
jul () { date -d "$1-01-01 +$2 days -1 day" "+%Y%m%d"; }

function echoErrorStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [ERR] "'\033[31m'${1}'\033[0m'
}
function echoWarnStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [WRN] "'\033[33m'${1}'\033[0m'
}
function echoInfoStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [INF] "'\033[32m'${1}'\033[0m'
}
function echoStatStr () 
{
    echo -e $(date +"%Y-%m-%d %T")" [STA] "'\033[0m'${1}'\033[0m'
}

# wget retry times
retry=10
MIN_SLEEPTIME=1
MAX_SLEEPTIME=3

fmt=h5
tile="*"
# parse parameters
while [[ $# > 1 ]]
  do
  key="$1"
  shift

  case $key in
    --user)
        user="$1"
        shift
        ;;
    --password)
        password="$1"
        shift
        ;;
    -f|--format)
        fmt="$1"
        shift
        ;;
    -t|--tile)
        tile="$1"
        shift
        ;;
    -y|--year)
        year="$1"
        shift
        ;;
    -n|--num)
        num="$1"
        shift
        ;;
    -p|--par)
        par="$1"
        shift
        ;;
    -o|--output)
        dir="$1"
        shift
        ;;
    -b|--begin)
        begin_doy="$1"
        shift
        ;;
    -e|--end)
        end_doy="$1"
        shift
        ;;
    *)
        # unknown option
        ;;
  esac
done

if [ -z $year ] || [ -z $num ] || [ -z ${user} ] || [ -z ${password} ]; then
	echo $usage
	exit
fi
if [ "$tile" == "all" ] || [ "$tile" == "*" ]; then
    tile="all"
    tilestr="";
else
    tilestr="${tile}."
    # check if the tile numbers are legal
    hnum=$(( $(echo ${tile:1:2} | sed 's/^0*//') ))
    vnum=$(( $(echo ${tile:3:2} | sed 's/^0*//') ))
    if [[ ${hnum} -lt 0 || ${hnum} -gt 35 || ${vnum} -lt 0 || ${vnum} -gt 17 ]]; then
       echoErrorStr "Illegal tile numbers in ${tile}"
       exit 2
    fi
fi

if [ -z $dir ]; then
	dir="./"
fi
if [ -z $begin_doy ]; then
	begin_doy=1
	if [ $year -eq 2000 ]; then
		begin_doy=55
	fi
fi
if [ -z $end_doy ]; then
    let n1=$year%4
    let n2=$year%100
    let n3=$year%400
    if [ $n1 -eq 0 -a $n2 -ne 0 ] || [ $n3 -eq 0 ]; then
        end_doy=366
    else
        end_doy=365
    fi
fi

if [ ! -r $dir ]; then
	echoErrorStr "$dir not exists."
	exit
fi

out_dir=${dir}/${year}
if [ ! -r $out_dir ]; then
	mkdir -p $out_dir
fi

cd $out_dir

LOG="wget_lp_daac_${par}_${tile}_${year}_$(printf %03d ${begin_doy})_$(printf %03d ${end_doy}).log"
>${LOG}

numstr=`printf %03d ${num}`

count=0
for ((doy=${begin_doy}; doy<=${end_doy}; doy++));
do
    doystr=`printf %03d ${doy}`

    # echoStatStr "Downloading ${par} ${tile} ${year}${doystr}"

    yyyymmdd=`jul $year $doy`
    yyyy=${yyyymmdd:0:4}
    mm=${yyyymmdd:4:2}
    dd=${yyyymmdd:6:2}
    
    # MODIS
    if [ $yyyymmdd -lt 20000224 ]; then
        continue
    fi

    fpat="${par}.A${year}${doystr}.${tilestr}${numstr}.*.${fmt}"
    rdir="${par}.${numstr}/${year}.${mm}.${dd}/"

    wget -a ${LOG} --wait=2 -t 0 --waitretry=${retry} --random-wait -O index.html ${url_base}${rdir}
    fhref=$(grep -o "href=\"${fpat}\"" index.html | cut -d'=' -f2 | cut -d'"' -f2)

    if [[ ! -z ${fhref} ]]; then
        if [[ ${count} -eq 0 ]]; then
            wget -a ${LOG} --save-cookies cookies.txt --keep-session-cookies --http-user="${user}" --http-password="${password}" -c -t 0 --waitretry=${retry} --random-wait ${url_base}${rdir}${fhref}
        else
            wget -a ${LOG} --load-cookies cookies.txt -c -t 0 --waitretry=${retry} --random-wait ${url_base}${rdir}${fhref}
        fi

        if [[ $? -eq 0 ]]; then
            echoStatStr "Downloading ${par} ${tile} ${year}${doystr}, SUCCESS"
        else
            echoErrorStr "Download ${par} ${tile} ${year}${doystr}, FAILED"
        fi
        count=$((${count}+1))
    fi
    
    sleep $((RANDOM%(MAX_SLEEPTIME-MIN_SLEEPTIME)+MIN_SLEEPTIME))
done

rm -f cookies.txt
echoStatStr "Finished downloading ${par} of ${tile} of ${year} from ${begin_doy} to ${end_doy}"
