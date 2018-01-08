#!/bin/bash

url_base1=https://e4ftl01.cr.usgs.gov/MODV6_Cmp_C/MOTA
url_base2=https://e4ftl01.cr.usgs.gov/MODV6_Cmp_B/MOTA

jul () { date -d "$1-01-01 +$2 days -1 day" "+%Y%m%d"; }

year=$1
band=$2

if [ -z $year ]; then
	echo "year=?"
	exit
fi

count=0

arr=(31 40 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21)

for ((i=0; i<23; i++)); do
	num=${arr[$i]}

	if [ ! -z $band ]; then
		min=$((${band}*3-2))
		max=$((${min}+2))
		if [ $num -lt $min ] || [ $num -gt $max ]; then
			continue
		fi
	fi

	for doy in {-120..486}; do

		yyyymmdd=`jul $year $doy`
		yyyy=${yyyymmdd:0:4}
		mm=${yyyymmdd:4:2}
		dd=${yyyymmdd:6:2}
	
		#MODIS
		if [ $yyyymmdd -lt 20000224 ]; then
			continue
		fi
		
		day=`date -d "${mm}/${dd}/${yyyy}" +%j`
		nn=`printf %02d $num`

		exist=`find ./${yyyy} -name "MCD43D${nn}.A${yyyy}${day}.006.*.hdf"`
		if [ ! -z $exist ]; then
#			echo "Skip $exist"
			continue
		fi
	
		str2=${yyyy}.${mm}.${dd}

		str1=MCD43D${nn}.006

		url=${url_base1}/${str1}/${str2}/
		if [ $num -eq 31 ]; then
			url=${url_base2}/${str1}/${str2}/
		fi

		wget -q -O tmp.html $url
		if [ $? -ne 0 ]; then
			echo "error found in downloading $url"
			continue
		fi

		hdf=`cat tmp.html | grep ".hdf<" | awk -F ">" '{print $3}'`
		hdf=${hdf%<*}
		if [ "${hdf}" == "" ]; then
			continue
		fi

		dir=./${yyyy}
		if [ ! -r $dir ]; then
			mkdir $dir
		fi
		cd $dir
		
		if [ ! -r $hdf ]; then
			url=${url}${hdf}
			stime=`date +%Y-%m-%d:%H:%M:%S`
			printf "[${stime}]Downloading ${dir}/${hdf} "
			SECONDS=0
			if [ $count -eq 0 ]; then
				wget -q --save-cookies cookies.txt --keep-session-cookies --http-user=USERNAME --http-password=PASSWORD $url
			else
				wget -q --load-cookies cookies.txt $url
			fi
			count=$((${count}+1))

			size=`ls -l $hdf | awk '{print $5}'`
			speed=`echo "${size}/1024/1024/${SECONDS}" | bc -l`
			speed=`printf %5.2f $speed`
			printf "[${size} BYTES, ${speed} M/S]\n"
		fi
		cd ..
	done
done
