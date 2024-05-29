#!/bin/bash

### Dammavalam, Srirangam
### 01-JUN-2021

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils
. $_scripts_dir/hlf_utils

HLF_TEMPLATE_DIR=$HLF_HOME/templates

rm -rf $HLF_NETWORK_DIR

print_header ">>> Setting up $ORG_NAME >>>"

mkdir -p $HLF_NETWORK_DIR/docker
mkdir -p $HLF_NETWORK_DIR/organizations/peerOrganizations $HLF_NETWORK_DIR/organizations/ordererOrganizations
mkdir -p $HLF_NETWORK_DIR/fabric-ca/ca-tls $HLF_NETWORK_DIR/fabric-ca/ca-orderer $HLF_NETWORK_DIR/fabric-ca/ca-org

mkdir -p $HLF_NETWORK_DIR/fabric-ca/client
mkdir -p $HLF_NETWORK_DIR/fabric-ca/client/ca-tls $HLF_NETWORK_DIR/fabric-ca/client/ca-orderer $HLF_NETWORK_DIR/fabric-ca/client/ca-org

parse_template "$HLF_TEMPLATE_DIR/fabric-ca-client.cfg" "$HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml"
parse_template "$HLF_TEMPLATE_DIR/docker-compose-ca.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-ca.yaml"

export FABRIC_CA_CLIENT_DEBUG=false
#################################
#  TLS CA
#################################
print_header ">>> Setting TLS CA >>>"
HLF_CA_CN=${HLF_CA_TLS_CN}
HLF_CA_PORT=${HLF_CA_TLS_PORT}
HLF_CA_ID=${HLF_CA_TLS_ID}
HLF_CA_SECRET=${HLF_CA_TLS_SECRET}
export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-tls

parse_template "$HLF_TEMPLATE_DIR/fabric-ca-server.cfg" "$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml"

fabric-ca-server start &
ca_tls_pid=$!
infoln "PID: $ca_tls_pid"
if [ $(ps -p $ca_tls_pid | wc -l) -ne 2 ]; then
    fatalln "======>>>>> TLS CA server FAILED to start"
fi

parse_template "$HLF_TEMPLATE_DIR/ca.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-ca.yaml"

HLF_CA_TLS_CACERT=$FABRIC_CA_SERVER_HOME/ca-cert.pem
wait_for_file $HLF_CA_TLS_CACERT

successln "========>>>> TLS CA is UP"
export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client enroll --mspdir ca-tls/msp -u https://${HLF_CA_TLS_ID}:${HLF_CA_TLS_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

## Register and get TLS certs for Orderer CA
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
    fabric-ca-client register --mspdir ca-tls/msp --id.name ${HLF_CA_ORDR_ID} --id.secret ${HLF_CA_ORDR_SECRET} -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client enroll --mspdir ca-tls/${HLF_CA_ORDR_ID}/msp -u https://${HLF_CA_ORDR_ID}:${HLF_CA_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts ${HLF_CA_HOST} --tls.certfiles $HLF_CA_TLS_CACERT
fi

## Register and get TLS certs for Org CA
fabric-ca-client register --mspdir ca-tls/msp --id.name ${HLF_CA_ORG_ID} --id.secret ${HLF_CA_ORG_SECRET} -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll --mspdir ca-tls/${HLF_CA_ORG_ID}/msp -u https://${HLF_CA_ORG_ID}:${HLF_CA_ORG_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts ${HLF_CA_HOST} --tls.certfiles $HLF_CA_TLS_CACERT

if [ -n "${ca_tls_pid}" ]; then
    kill -15 $ca_tls_pid
fi
successln "------ TLS CA >>>> C O M P L E T E D -----------"

#################################
#  ORDERER CA
#################################
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
    export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-orderer
    print_header ">>> Setting Orderer CA >>>"
    HLF_CA_CN=${HLF_CA_ORDR_CN}
    HLF_CA_PORT=${HLF_CA_ORDR_PORT}
    HLF_CA_ID=${HLF_CA_ORDR_ID}
    HLF_CA_SECRET=${HLF_CA_ORDR_SECRET}

    HLF_CA_TLS_CERT=tls/cert.pem
    HLF_CA_TLS_KEY=tls/key.pem
    mkdir -p $FABRIC_CA_SERVER_HOME/tls
    cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORDR_ID}/msp/keystore/* $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_KEY
    cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORDR_ID}/msp/signcerts/cert.pem $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_CERT

    parse_template "$HLF_TEMPLATE_DIR/fabric-ca-server.cfg" "$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml"

    fabric-ca-server start &
    ca_ordr_pid=$!
    infoln "PID: $ca_ordr_pid"
    if [ $(ps -p $ca_ordr_pid | wc -l) -ne 2 ]; then
        fatalln "=====>>>>> ORDERER CA server FAILED to start"
    fi

    parse_template "$HLF_TEMPLATE_DIR/ca.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-ca.yaml"
    wait_for_file $FABRIC_CA_SERVER_HOME/ca-cert.pem

    successln "=====>>> ORDERER CA is UP"

    export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
    fabric-ca-client enroll --mspdir ca-orderer/msp -u https://${HLF_CA_ORDR_ID}:${HLF_CA_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client register --mspdir ca-orderer/msp --id.name ${HLF_ORDR_ID} --id.secret ${HLF_ORDR_SECRET} --id.type orderer -u https://${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client register --mspdir ca-orderer/msp --id.name ${HLF_ORDR_ADMIN_ID} --id.secret ${HLF_ORDR_ADMIN_SECRET} --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

    if [ -n "${ca_ordr_pid}" ]; then
        kill -15 $ca_ordr_pid
    fi
fi
successln "------ ORDERER CA >>>> C O M P L E T E D -----------"

#################################
#  ORG CA
#################################
export FABRIC_CA_SERVER_HOME=$HLF_NETWORK_DIR/fabric-ca/ca-org
print_header ">>> Setting Org CA >>>"
HLF_CA_CN=${HLF_CA_ORG_CN}
HLF_CA_PORT=${HLF_CA_ORG_PORT}
HLF_CA_ID=${HLF_CA_ORG_ID}
HLF_CA_SECRET=${HLF_CA_ORG_SECRET}

HLF_CA_TLS_CERT=tls/cert.pem
HLF_CA_TLS_KEY=tls/key.pem
mkdir -p $FABRIC_CA_SERVER_HOME/tls
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORG_ID}/msp/keystore/* $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_KEY
cp $HLF_NETWORK_DIR/fabric-ca/client/ca-tls/${HLF_CA_ORG_ID}/msp/signcerts/cert.pem $FABRIC_CA_SERVER_HOME/$HLF_CA_TLS_CERT

parse_template "$HLF_TEMPLATE_DIR/fabric-ca-server.cfg" "$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml"

fabric-ca-server start &
ca_org_pid=$!
infoln "PID: $ca_org_pid"
if [ $(ps -p $ca_org_pid | wc -l) -eq 1 ]; then
    fatalln "=========>>>>>> ORG CA server FAILED to start"
fi

parse_template "$HLF_TEMPLATE_DIR/ca.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-ca.yaml"
wait_for_file $FABRIC_CA_SERVER_HOME/ca-cert.pem

successln "========>>>>>>> ORG CA is UP"

export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
fabric-ca-client enroll --mspdir ca-org/msp -u https://${HLF_CA_ORG_ID}:${HLF_CA_ORG_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register --mspdir ca-org/msp --id.name ${HLF_ORG_ADMIN_ID} --id.secret ${HLF_ORG_ADMIN_SECRET} --id.type admin -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client register --mspdir ca-org/msp --id.name ${HLF_ORG_USER_ID} --id.secret ${HLF_ORG_USER_SECRET} --id.type client -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
_peer_num_=1
while [ ${_peer_num_} -le ${HLF_ORG_PEERS_COUNT} ]; do
    HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${_peer_num_}_ID)
    HLF_ORG_PEER_SECRET=$(get_val HLF_ORG_PEER${_peer_num_}_SECRET)
    fabric-ca-client register --mspdir ca-org/msp --id.name ${HLF_ORG_PEER_ID} --id.secret ${HLF_ORG_PEER_SECRET} --id.type peer -u https://${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
    let _peer_num_=_peer_num_+1
done
unset _peer_num_

if [ -n "${ca_org_pid}" ]; then
    kill -15 $ca_org_pid
fi
wait_for_seconds 2
successln "------ ORG CA >>>> C O M P L E T E D -----------"

##------------------------------------------------
print_header ">>>>> Starting Fabric CAs >>>>>"
cd $HLF_NETWORK_DIR
export COMPOSE_PROJECT_NAME=net
docker-compose -f docker/docker-compose-ca.yaml up -d
wait_for_seconds 30
successln "------ FABRIC CA >>>> S T A R T E D -----------"

#################################
# PREPARE EXTRA HOSTS
#################################

print_header ">>>>> Preparing extra host info >>>>>"
echo -n "- \\\"${HLF_CA_HOST}:${HLF_CA_HOST_IP}\\\"\n      " >$HLF_TEMPLATE_DIR/extra_hosts.txt
echo -n "- \\\"${HLF_ORDR_ID}:${HLF_CA_HOST_IP}\\\"\n      " >>$HLF_TEMPLATE_DIR/extra_hosts.txt
_peer_num_=1
while [ ${_peer_num_} -le ${HLF_ORG_PEERS_COUNT} ]; do
    HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${_peer_num_}_ID)
    echo -n "- \\\"${HLF_ORG_PEER_ID}:${HLF_CA_HOST_IP}\\\"\n      " >>$HLF_TEMPLATE_DIR/extra_hosts.txt
    let _peer_num_=_peer_num_+1
done
unset _peer_num_
successln "------ EXTRA HOST INFO >>>> C O M P L E T E D -----------"

#################################
# SETUP ORDERER
#################################
if [ "${HLF_CA_ORDR_REQ}" = "Y" ]; then
    print_header ">>>>>> Setting up Orderer >>>>>>"
    HLF_ORDR_ORG_DIR=$HLF_NETWORK_DIR/organizations/ordererOrganizations/${ORG_NAME}
    HLF_ORDR_DIR=$HLF_ORDR_ORG_DIR/orderers/${HLF_ORDR_ID}
    mkdir -p ${HLF_ORDR_ORG_DIR}/msp
    HLF_CA_PORT=${HLF_CA_ORDR_PORT}

    parse_template "$HLF_TEMPLATE_DIR/config.cfg" "$HLF_ORDR_ORG_DIR/config.yaml"
    parse_template "$HLF_TEMPLATE_DIR/docker-compose-orderer.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-orderer.yaml"

    EXTRA_HOSTS=$(cat $HLF_TEMPLATE_DIR/extra_hosts.txt)
    sed -i "s/DOCKER_EXTRA_HOSTS/$EXTRA_HOSTS/g" $HLF_NETWORK_DIR/docker/docker-compose-orderer.yaml

    export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
    fabric-ca-client register --mspdir ca-tls/msp --id.name $HLF_ORDR_ID --id.secret $HLF_ORDR_SECRET -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
    export FABRIC_CA_CLIENT_HOME=$HLF_ORDR_ORG_DIR
    cp $HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml $HLF_ORDR_ORG_DIR/

    fabric-ca-client enroll -M orderers/${HLF_ORDR_ID}/msp -u https://${HLF_ORDR_ID}:${HLF_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --csr.hosts "${HLF_ORDR_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client enroll -M orderers/${HLF_ORDR_ID}/tls -u https://${HLF_ORDR_ID}:${HLF_ORDR_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts "${HLF_ORDR_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client enroll -M users/Admin@${ORG_NAME}/msp -u https://${HLF_ORDR_ADMIN_ID}:${HLF_ORDR_ADMIN_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORDR_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

    mv $HLF_ORDR_DIR/tls/keystore/* $HLF_ORDR_DIR/tls/keystore/key.pem
    cp $HLF_ORDR_DIR/tls/tlscacerts/tls-* $HLF_ORDR_DIR/tls/tlscacerts/tls-cacert.pem
    cp -r $HLF_ORDR_DIR/tls/tlscacerts $HLF_ORDR_ORG_DIR/msp/
    cp -r $HLF_ORDR_DIR/msp/cacerts $HLF_ORDR_ORG_DIR/msp/
    cp $HLF_ORDR_ORG_DIR/msp/cacerts/* $HLF_ORDR_ORG_DIR/msp/cacerts/cacert.pem
    cp -r $HLF_ORDR_DIR/tls/tlscacerts $HLF_ORDR_DIR/msp/
    cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_DIR/msp/
    cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_ORG_DIR/msp/
    cp $HLF_ORDR_ORG_DIR/config.yaml $HLF_ORDR_ORG_DIR/users/Admin@${ORG_NAME}/msp/
    successln "------ ORDERER SETUP >>>> C O M P L E T E D -----------"
fi
#-------------------------------------------

#################################
# SETUP ORG
#################################

print_header ">>>>>> Setting up ORG >>>>>>"
HLF_ORG_DIR=$HLF_NETWORK_DIR/organizations/peerOrganizations/${ORG_NAME}
mkdir -p $HLF_ORG_DIR/msp

HLF_CA_PORT=${HLF_CA_ORG_PORT}
parse_template "$HLF_TEMPLATE_DIR/config.cfg" "$HLF_ORG_DIR/config.yaml"
cp $HLF_NETWORK_DIR/fabric-ca/client/fabric-ca-client-config.yaml $HLF_ORG_DIR/
parse_template "$HLF_TEMPLATE_DIR/docker-compose-org.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-org.yaml"

_peer_num_=1
while [ ${_peer_num_} -le ${HLF_ORG_PEERS_COUNT} ]; do
    HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${_peer_num_}_ID)
    echo "  ${HLF_ORG_PEER_ID}:" >>$HLF_NETWORK_DIR/docker/docker-compose-org.yaml
    let _peer_num_=_peer_num_+1
done
echo -e "\nservices:" >>$HLF_NETWORK_DIR/docker/docker-compose-org.yaml

_peer_num_=1
while [ ${_peer_num_} -le ${HLF_ORG_PEERS_COUNT} ]; do
    HLF_ORG_PEER_ID=$(get_val HLF_ORG_PEER${_peer_num_}_ID)
    HLF_ORG_PEER_SECRET=$(get_val HLF_ORG_PEER${_peer_num_}_SECRET)
    HLF_ORG_PEER_PORT=$(get_val HLF_ORG_PEER${_peer_num_}_PORT)
    HLF_ORG_PEER_CC_PORT=$(get_val HLF_ORG_PEER${_peer_num_}_CC_PORT)
    HLF_ORG_PEER_COUCHDB=$(get_val HLF_ORG_PEER${_peer_num_}_COUCHDB)
    HLF_ORG_PEER_COUCHDB_USER=$(get_val HLF_ORG_PEER${_peer_num_}_COUCHDB_USER)
    HLF_ORG_PEER_COUCHDB_PASSWD=$(get_val HLF_ORG_PEER${_peer_num_}_COUCHDB_PASSWD)
    HLF_ORG_PEER_COUCHDB_PORT=$(get_val HLF_ORG_PEER${_peer_num_}_COUCHDB_PORT)
    HLF_ORG_PEER_DIR=$HLF_ORG_DIR/peers/${HLF_ORG_PEER_ID}

    parse_template "$HLF_TEMPLATE_DIR/peer.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-org.yaml"

    export FABRIC_CA_CLIENT_HOME=$HLF_NETWORK_DIR/fabric-ca/client
    fabric-ca-client register --mspdir ca-tls/msp --id.name $HLF_ORG_PEER_ID --id.secret $HLF_ORG_PEER_SECRET -u https://${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --tls.certfiles $HLF_CA_TLS_CACERT

    export FABRIC_CA_CLIENT_HOME=$HLF_ORG_DIR
    fabric-ca-client enroll -M peers/$HLF_ORG_PEER_ID/msp -u https://${HLF_ORG_PEER_ID}:${HLF_ORG_PEER_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --csr.hosts "${HLF_ORG_PEER_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT
    fabric-ca-client enroll -M peers/$HLF_ORG_PEER_ID/tls -u https://${HLF_ORG_PEER_ID}:${HLF_ORG_PEER_SECRET}@${HLF_CA_HOST}:${HLF_CA_TLS_PORT} --enrollment.profile tls --csr.hosts "${HLF_ORG_PEER_ID},${HLF_CA_HOST}" --tls.certfiles $HLF_CA_TLS_CACERT

    mv $HLF_ORG_PEER_DIR/tls/keystore/* $HLF_ORG_PEER_DIR/tls/keystore/key.pem
    cp $HLF_ORG_PEER_DIR/tls/tlscacerts/tls-* $HLF_ORG_PEER_DIR/tls/tlscacerts/tls-cacert.pem
    cp $HLF_ORG_DIR/config.yaml $HLF_ORG_PEER_DIR/msp/
    let _peer_num_=_peer_num_+1
done
unset _peer_num_
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/msp/
cp -r $HLF_ORG_PEER_DIR/tls/tlscacerts $HLF_ORG_DIR/msp/
cp -r $HLF_ORG_PEER_DIR/msp/cacerts $HLF_ORG_DIR/msp/
cp $HLF_ORG_DIR/msp/cacerts/* $HLF_ORG_DIR/msp/cacerts/cacert.pem
#cp -r $HLF_ORG_PEER_DIR/tls/tlscacerts $HLF_ORG_DIR/tlsca
#cp -r $HLF_ORG_PEER_DIR/msp/cacerts $HLF_ORG_DIR/ca

fabric-ca-client enroll -M users/User1@$ORG_NAME/msp -u https://${HLF_ORG_USER_ID}:${HLF_ORG_USER_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
fabric-ca-client enroll -M users/Admin@$ORG_NAME/msp -u https://${HLF_ORG_ADMIN_ID}:${HLF_ORG_ADMIN_SECRET}@${HLF_CA_HOST}:${HLF_CA_ORG_PORT} --tls.certfiles $HLF_CA_TLS_CACERT
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/users/User1@$ORG_NAME/msp/
cp $HLF_ORG_DIR/config.yaml $HLF_ORG_DIR/users/Admin@$ORG_NAME/msp/

EXTRA_HOSTS=$(cat $HLF_TEMPLATE_DIR/extra_hosts.txt)
sed -i "s/DOCKER_EXTRA_HOSTS/$EXTRA_HOSTS/g" $HLF_NETWORK_DIR/docker/docker-compose-org.yaml
successln "------ ORG SETUP >>>> C O M P L E T E D -----------"

##--------------------------------------------

print_header ">>>>> Generating Configtx >>>>>"
mkdir -p $HLF_NETWORK_DIR/configtx $HLF_NETWORK_DIR/channel-artifacts $HLF_NETWORK_DIR/system-genesis-block
#mkdir -p $HLF_NETWORK_DIR/config
infoln "Parse configtx template ..."
parse_template "$HLF_TEMPLATE_DIR/configtx.cfg" "$HLF_NETWORK_DIR/configtx/configtx.yaml"
#cp $HLF_HOME/config/* $HLF_NETWORK_DIR/config/
successln "------ CONFIGTX GENERATION >>>> C O M P L E T E D -----------"

##########################################
## Channel Connection Profile (CCP)
##########################################

print_header ">>>>> Generating CCP >>>>>"
${HLF_HOME}/scripts/ccp-generate.sh ${HLF_HOME}/network.conf
successln "------ CCP GENERATION >>>> C O M P L E T E D -----------"

## PostgreSQL
print_header ">>>>> Generate PostgreSQL Docker-compose >>>>>"
infoln "Parse postgres template ..."
parse_template "$HLF_TEMPLATE_DIR/docker-compose-postgres.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-postgres.yaml"
successln "postgres docker-compose generated"

##--------------------------------------------
