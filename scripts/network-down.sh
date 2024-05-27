#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils

########################################
# STOP NETWORK
########################################

print_header ">>>> Stopping the Network >>>>"

export COMPOSE_PROJECT_NAME=net
cd $HLF_NETWORK_DIR

docker_files=" -f docker/docker-compose-ca.yaml -f docker/docker-compose-org.yaml -f docker/docker-compose-ipfs.yaml -f docker/docker-compose-db.yaml"
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
    docker_files="$docker_files -f docker/docker-compose-orderer.yaml"
fi

docker-compose $docker_files down

successln "--------- NETWORK >>> D O W N -------------"
