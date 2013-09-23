#!/bin/bash

if [[ -z $1 ]]; then
    echo "This script expects a single argument: {ASPACE_VERSION_ID}"
    exit 0;
fi


aspace_download='downloads/'$1'.zip'

url='https://github.com/archivesspace/archivesspace/archive/'$1'.zip'

if [[ ! -e $aspace_download ]]; then

    echo "Preparing to download: '${url}'"

    mkdir -p downloads

    curl -L -o 'downloads/'$1'.zip' $url
fi


validation_results=`unzip -tq 'downloads/'$1'.zip'`

if [[ ! ${validation_results:0:9} == 'No errors' ]]; then
    echo "Download does not appear to be a zip: 'downloads/${1}'"
    exit 0
fi


tools_dir='vendor/archivesspace/client_tools/'$1'/'
mkdir -p $tools_dir

client_files=( 
    common/archivesspace_json_schema.rb 
    common/asutils.rb
    common/exceptions.rb
    common/jsonmodel.rb 
    common/jsonmodel_client.rb 
    common/json_schema_concurrency_fix.rb 
    common/json_schema_utils.rb 
    common/jsonmodel_type.rb
    common/schemas/*
    common/validations.rb
    common/validator_cache.rb
    migrations/lib/jsonmodel_wrap.rb
    migrations/lib/parse_queue.rb
    migrations/lib/utils.rb
)


for file in "${client_files[@]}"
do 
    echo "Extracting '${file}'"
    
    sub_dir=`echo $file | sed 's/[._a-z]*$//' | sed 's/[^/]*$//'`

    if [[ $sub_dir != "" ]]; then
	mkdir -p $tools_dir$sub_dir
    fi

    unzip -j 'downloads/'$1'.zip' "*/${file}" -d $tools_dir$sub_dir
done
