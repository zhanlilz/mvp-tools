#!/bin/bash

# Download data ordered from LAADS DAAC
# [https://ladsweb.nascom.nasa.gov/]. 
#
# Zhan Li, zhan.li@umb.edu
# Created: Fri Mar 24 14:14:28 EDT 2017

read -d '' USAGE <<EOF
download_laads_daac_order.sh -o ORDER_NUMBER -u USERNAME -p PASSWORD -t TARGET_DIRECTORY

Download data ordered from LAADS DAAC
[https://ladsweb.nascom.nasa.gov/] to a given directory
TARGET_DIRECTORY. For all the required information including
ORDER_NUMBER, USERNAME, PASSWORD, please refer to the email from LAADS
DAAC sent to you after you order the data.

EOF

OPTS=`getopt -o o:u:p:t: --long order:,username:,password:,target_dir: -n 'download_laads_daac_order.sh' -- "$@"`
if [[ $? != 0 ]]; then echo "Failed parsing options" >&2; echo "${USAGE}"; exit 1; fi
eval set -- "${OPTS}"
while true;
do
    case "${1}" in
        -o | --order )
            case "${2}" in
                "" ) shift 2 ;;
                *) ORDER_NUMBER=${2} ; shift 2 ;;
            esac ;;
        -u | --username )
            case "${2}" in
                "" ) shift 2 ;;
                *) USERNAME=${2} ; shift 2 ;;
            esac ;;
        -p | --password )
            case "${2}" in
                "" ) shift 2 ;;
                *) PASSWORD=${2} ; shift 2 ;;
            esac ;;
        -t | --target_dir )
            case "${2}" in
                "" ) shift 2 ;;
                *) TARGET_DIR=${2} ; shift 2 ;;
            esac ;;
        -- ) shift ; break ;;
        * ) break ;;
    esac
done

if ([ -z ${ORDER_NUMBER} ] || [ -z ${USERNAME} ] || [ -z ${PASSWORD} ] || [ -z ${TARGET_DIR} ]); then
    echo "${USAGE}"
    echo
    echo "Missing required options!"
    exit 2
fi

if [[ ! -d ${TARGET_DIR} ]]; then
    mkdir -p ${TARGET_DIR}
fi

FTPRC=${TARGET_DIR}/"ftprc.txt"

echo "
quote USER ${USERNAME}
quote PASS ${PASSWORD}
passive
binary
prompt
cd /orders/${ORDER_NUMBER}
mget *
" > ${FTPRC}

cd ${TARGET_DIR}
ftp -n ladsweb.modaps.eosdis.nasa.gov < ${FTPRC}