#!/bin/bash

usage="$0 --ftp [ftp.address, default=ladssci.nascom.nasa.gov] --user [your_user_name] --password [your_password] -f ['h5'|'hdf'] -t [tile] -y [year] -p [parm] -n [num] -o <out_dir> -b <begin_doy> -e <end_doy>"

# wget retry times
retry=10

ftpurl="ladssci.nascom.nasa.gov"
fmt=h5
tile="*"
# parse parameters
while [[ $# > 1 ]]
  do
  key="$1"
  shift

  case $key in
    --ftp)
        ftpurl="$1"
        shift
        ;;
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
	tile="all";
fi

if [ -z $dir ]; then
	dir=./
fi
if [ -z $begin_doy ]; then
	begin_doy=1
	if [ $year -eq 2000 ]; then
		begin_doy=55
	fi
fi
if [ -z $end_doy ]; then
	end_doy=366
fi

if [ ! -r $dir ]; then
	echo "$dir not exists."
	exit
fi

let n1=$year%4
let n2=$year%100
let n3=$year%400

flag=0
if [ $n1 -eq 0 -a $n2 -ne 0 ] || [ $n3 -eq 0 ]; then
  flag=1
fi

days[1]=31
days[2]=28
days[3]=31
days[4]=30
days[5]=31
days[6]=30
days[7]=31
days[8]=31
days[9]=30
days[10]=31
days[11]=30
days[12]=31

if [ $flag -eq 1 ]; then
	days[2]=29
fi

out_dir=${dir}/${year}
if [ ! -r $out_dir ]; then
	mkdir -p $out_dir
fi

cd $out_dir

# ################################################
# #            download SNOW COVER               #
# ################################################
# ftprc=ftp.txt

# echo "
# quote USER anonymous
# quote PASS sqs@bu.edu
# binary
# prompt
# " > $ftprc

# for mon in {1..12};do
# 	day=1
# 	while [ $day -le ${days[$mon]} ]; do

# 		_mon=`printf %02d $mon`	
# 		_day=`printf %02d $day`	
		
# 		doy=`date -d "${_mon}/${_day}/${year}" +%j`
# 		if [ $doy -lt $begin_doy ] || [ $doy -gt $end_doy ]; then
# 			day=$((${day}+1))	
# 			continue
# 		fi

# 		exist=`find ./ -name MOD10A1.A${year}${doy}.${tile}*.hdf`
# 		if [ -z $exist ]; then
# 			rdir=/DP0/MOST/MOD10A1.005/${year}.${_mon}.${_day}
# 			echo "cd $rdir" >> $ftprc
# 			echo "mget MOD10A1.*.${tile}*.hdf" >> $ftprc
# 		fi

# 		day=$((${day}+1))	
# 	done	
# done

# echo "bye" >> $ftprc

# #ftp -n n5eil01u.ecs.nsidc.org < $ftprc 

# ################################################
# #          end of download SNOW COVER          #
# ################################################

ftprc=ftp2.txt

# using -p option rather than passive or quote PASV here is more
# robust and works on both ghpcc and neponset.
echo "
quote USER ${user}
quote PASS ${password}

binary
prompt
" > $ftprc

for mon in {1..12};do
	day=1
	while [ $day -le ${days[$mon]} ]; do

		_mon=`printf %02d $mon`	
		_day=`printf %02d $day`	
		
		doy=`date -d "${_mon}/${_day}/${year}" +%j`
		if [ $doy -lt $begin_doy ] || [ $doy -gt $end_doy ]; then
			day=$((${day}+1))	
			continue
		fi

		exist=`find ./ -name ${par}.A${year}${doy}.${tile}.*.$fmt`
		if [ -z $exist ]; then
			rdir=/allData/${num}/${par}/${year}/${doy}
			echo "cd $rdir" >> $ftprc
#			mkdir -p ".${rdir}"
                        if [ "$tile" == "all" ]; then
                            echo "mget ${par}.*.$fmt" >> $ftprc
                        else
                            echo "mget ${par}.*.${tile}.*.$fmt" >> $ftprc
                        fi
		fi

		day=$((${day}+1))	
	done	
done

echo "bye" >> $ftprc

ftp -p -n ${ftpurl} < $ftprc 
ftp_exit=$?

if [[ $ftp_exit == 0 ]]; then
    echo "Finished downloading ${par} of ${tile} of ${year} from ${begin_doy} to ${end_doy}"
else
    echo "Failed downloading ${par} of ${tile} of ${year} from ${begin_doy} to ${end_doy}"
fi
