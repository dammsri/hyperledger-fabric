#!/bin/bash

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $1)
    local CP=$(one_line_pem $2)
    sed -e "s#PEERPEM#$PP#" \
        -e "s#CAPEM#$CP#" \
        -e "s#ORG_NAME#$ORG_NAME#" \
        -e "s#NETWORK#$NETWORK#" \
        -e "s#CA_PORT#$CA_PORT#" \
        -e "s#PEER_ID#$PEER_ID#" \
        -e "s#PEER_PORT#$PEER_PORT#" \
        -e "s#CA_HOST#$CA_HOST#" \
        -e "s#CA_NAME#$CA_NAME#" \
        $HLF_HOME/templates/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $1)
    local CP=$(one_line_pem $2)
    sed -e "s#PEERPEM#$PP#" \
        -e "s#CAPEM#$CP#" \
        -e "s#ORG_NAME#$ORG_NAME#" \
        -e "s#NETWORK#$NETWORK#" \
        -e "s#CA_PORT#$CA_PORT#" \
        -e "s#PEER_ID#$PEER_ID#" \
        -e "s#PEER_PORT#$PEER_PORT#" \
        -e "s#CA_HOST#$CA_HOST#" \
        -e "s#CA_NAME#$CA_NAME#" \
        $HLF_HOME/templates/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

PEERPEM=$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/msp/tlscacerts/tls-cacert.pem
CAPEM=$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/msp/cacerts/cacert.pem
ORG_NAME=$ORG_NAME
NETWORK=$(dirname $HLF_NETWORK_DIR)
PEER_ID=$HLF_ORG_PEER1_ID
PEER_PORT=$HLF_ORG_PEER1_PORT
CA_PORT=$HLF_CA_ORG_PORT
CA_HOST=$HLF_CA_HOST
CA_NAME=$HLF_CA_ORG_CN

echo "$(json_ccp $PEERPEM $CAPEM)" >$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/ccp-$ORG_NAME.json
echo "$(yaml_ccp $PEERPEM $CAPEM)" >$HLF_NETWORK_DIR/organizations/peerOrganizations/$ORG_NAME/ccp-$ORG_NAME.yaml
