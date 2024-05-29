#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils
. $_scripts_dir/hlf_utils

cd $HLF_NETWORK_DIR

########################################
# Start Peers
########################################

print_header ">>>> Starting Peers >>>>"
export COMPOSE_PROJECT_NAME=net
docker-compose -f docker/docker-compose-org.yaml up -d
wait_for_seconds 60
successln "----- PEERS >>> S T A R T E D -------"

_org_n=$(echo $ORG_NAME | sed -n 's/^Org\([0-9]*\).*$/\1/p')
CHANNEL_TX_FILE="./channel-artifacts/${HLF_NETWORK_CHANNEL_ID}.tx"
CHANNEL_BLOCK_FILE="./channel-artifacts/${HLF_NETWORK_CHANNEL_ID}.block"
if [ "${HLF_CHANNEL_CREATOR}" = "Y" ]; then
    print_header ">>>> Creating Channel ${HLF_NETWORK_CHANNEL_ID} >>>>"
    create_channel $_org_n $HLF_NETWORK_CHANNEL_ID $CHANNEL_TX_FILE $CHANNEL_BLOCK_FILE
    wait_for_seconds 30
fi

print_header ">>>> Fetch Config from Channel ${HLF_NETWORK_CHANNEL_ID} >>>>"
test ! -f $CHANNEL_BLOCK_FILE && fetch_channel_config $_org_n $HLF_NETWORK_CHANNEL_ID $CHANNEL_BLOCK_FILE 0

print_header ">>>> Joining Channel ${HLF_NETWORK_CHANNEL_ID} >>>>"
_peer_num=1
while [ ${_peer_num} -le ${HLF_ORG_PEERS_COUNT} ]; do
    join_channel $_org_n $_peer_num $HLF_NETWORK_CHANNEL_ID $CHANNEL_BLOCK_FILE
    let _peer_num=_peer_num+1
done
unset _peer_num

# Some ad-hoc tasks for CouchDB containers (to avoid errors / warnings in the log)
_peer_num=1
while [ ${_peer_num} -le ${HLF_ORG_PEERS_COUNT} ]; do
    HLF_ORG_PEER_COUCHDB_USER=$(get_val HLF_ORG_PEER${_peer_num}_COUCHDB_USER)
    HLF_ORG_PEER_COUCHDB_PASSWD=$(get_val HLF_ORG_PEER${_peer_num}_COUCHDB_PASSWD)
    HLF_ORG_PEER_COUCHDB_PORT=$(get_val HLF_ORG_PEER${_peer_num}_COUCHDB_PORT)
    curl --version >&/dev/null && curl -X PUT http://${HLF_ORG_PEER_COUCHDB_USER}:${HLF_ORG_PEER_COUCHDB_PASSWD}@${HLF_CA_HOST}:${HLF_ORG_PEER_COUCHDB_PORT}/_users
    let _peer_num=_peer_num+1
done
unset _peer_num

#-----------------------------------
## set anchor peer(s)
#-----------------------------------

HLF_ORG_ANCHOR_PEERS=$(echo ${HLF_ORG_ANCHOR_PEERS} | sed 's/,/ /g')
_anchor_peers_list=""
infoln "Anchor Peers: $HLF_ORG_ANCHOR_PEERS"
for _peer_num_ in ${HLF_ORG_ANCHOR_PEERS}; do
    HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${_peer_num_}_ID)
    HLF_ORG_PEER_PORT=$(get_val HLF_ORG_PEER${_peer_num_}_PORT)
    [[ -z "${_anchor_peers_list}" ]] && { _anchor_peers_list="{\"host\": \"${HLF_ORG_PEER_ID}\",\"port\": ${HLF_ORG_PEER_PORT}}"; } || {
        _anchor_peers_list="$(echo ${_anchor_peers_list}),{\"host\":\"${HLF_ORG_PEER_ID}\",\"port\":${HLF_ORG_PEER_PORT}}"
    }
done
unset _peer_num_

print_header ">>>> Setting Anchor Peers >>>>" "Anchor Peers: $_anchor_peers_list"

_channel_config="./channel-artifacts/channel_config.json"
_modified_channel_config="./channel-artifacts/modified_channel_config.json"
_anchor_peers_config="./channel-artifacts/anchors.tx"

fetch_channel_config $_org_n $HLF_NETWORK_CHANNEL_ID $_channel_config
jq ".channel_group.groups.Application.groups.${ORG_MSPID}.values += {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": [${_anchor_peers_list}]},\"version\": \"0\"}}" $_channel_config >$_modified_channel_config
prepare_config_update $HLF_NETWORK_CHANNEL_ID $_channel_config $_modified_channel_config $_anchor_peers_config
update_channel_config $_org_n $HLF_NETWORK_CHANNEL_ID $_anchor_peers_config

successln "----------- CHANNEL UPDATE >>> C O M P L E T E D >>> ----------"
