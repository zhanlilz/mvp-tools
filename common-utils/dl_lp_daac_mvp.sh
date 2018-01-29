#!/bin/bash

usage="$0 --user [your_user_name] --password [your_password] -f ['h5'|'hdf'] -t [tile] -y [year] -p [parm] -n [num] -o <out_dir> -b <begin_doy> -e <end_doy>"

url_base='https://e4ftl01.cr.usgs.gov/MOTA/'

# jul year doy
# return YYYYMMDD
jul () { date -d "$1-01-01 +$2 days -1 day" "+%Y%m%d"; }

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
	echo "$dir not exists."
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

    echo "Downloading ${par} ${tile} ${year}${doystr}"

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
    if [ $count -eq 0 ]; then
        wget -a ${LOG} --save-cookies cookies.txt --keep-session-cookies --http-user="${user}" --http-password="${password}" -nc --wait=2 -t 0 --waitretry=${retry} --random-wait -r -l 1 -nd --no-parent -A "${fpat}" ${url_base}${rdir}
    else
        wget -a ${LOG} --load-cookies cookies.txt -nc --wait=2 -t 0 --waitretry=${retry} --random-wait -r -l 1 -nd --no-parent -A "${fpat}" ${url_base}${rdir}
    fi
    count=$((${count}+1))
    
    sleep $((RANDOM%(MAX_SLEEPTIME-MIN_SLEEPTIME)+MIN_SLEEPTIME))
done

rm -f cookies.txt
echo "Finished downloading ${par} of ${tile} of ${year} from ${begin_doy} to ${end_doy}"
