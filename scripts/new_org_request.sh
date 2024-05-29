#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils

HLF_TEMPLATE_DIR=$HLF_HOME/templates
cd $HLF_NETWORK_DIR

########################################
# ADD ORG
########################################

print_header ">>> New Org Request >>>" "Org: $ORG_NAME"

infoln "Parse configtx template ..."
>$HLF_NETWORK_DIR/configtx/configtx.yaml
parse_template "$HLF_TEMPLATE_DIR/org_configtx.cfg" "$HLF_NETWORK_DIR/configtx/configtx.yaml"

export FABRIC_CFG_PATH=${HLF_HOME}/config/
infoln "Generate New Org request ..."
configtxgen -configPath ./configtx -printOrg ${ORG_MSPID} >$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/${ORG_NAME}.json

successln "------- Please submit the file: $HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/${ORG_NAME}.json to Org1 to update channel config --------"
