#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils
. $_scripts_dir/hlf_utils

cd $HLF_NETWORK_DIR

########################################
# ADD ORG
########################################

_org_n=$(echo $ORG_NAME | sed -n 's/^Org\([0-9]*\).*$/\1/p')

while [ -z "${_new_org_id}" ]; do
    read -p "Enter New Org ID: " _new_org_id
done

while [ -z "${_new_org_request_file}" ]; do
    read -p "Enter New Org request file : " _new_org_request_file
done

test ! -f $_new_org_request_file && fatalln "New Org request file '$_new_org_request_file' Not found"

print_header ">>> Add New Org >>>" "New Org: $_new_org_id" "Request File: $_new_org_request_file"

_channel_config="$HLF_NETWORK_DIR/channel-artifacts/channel_config.json"
_modified_channel_config="$HLF_NETWORK_DIR/channel-artifacts/modified_channel_config.json"
_update_config_tx="$HLF_NETWORK_DIR/channel-artifacts/update_config_tx.pb"

fetch_channel_config $_org_n $HLF_NETWORK_CHANNEL_ID $_channel_config
jq -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"${_new_org_id}MSP\":.[1]}}}}}" $_channel_config $_new_org_request_file >$_modified_channel_config
prepare_config_update $HLF_NETWORK_CHANNEL_ID $_channel_config $_modified_channel_config $_update_config_tx
sign_configtx $_org_n $_update_config_tx

successln "------ Please submit $_update_config_tx to Org2 to approve -------"
