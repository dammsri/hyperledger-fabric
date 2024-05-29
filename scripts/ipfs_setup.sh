#!/bin/bash

### Dammavalam, Srirangam
### 16-MAY-2024

_scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. $_scripts_dir/set_env
. $_scripts_dir/helper_utils
. $_scripts_dir/hlf_utils

print_header ">>>>> Setup ipfs-cluster-ctl >>>>>"
infoln "Downloading ipfs-cluster-ctl"
wget https://dist.ipfs.tech/ipfs-cluster-ctl/v1.0.8/ipfs-cluster-ctl_v1.0.8_linux-amd64.tar.gz
test $? -ne 0 && fatalln "Unable to download ipfs-cluster-ctl"
tar xzf ipfs-cluster-ctl_v1.0.8_linux-amd64.tar.gz ipfs-cluster-ctl/ipfs-cluster-ctl
test -d ${HLF_HOME}/bin && mv ipfs-cluster-ctl/ipfs-cluster-ctl ${HLF_HOME}/bin/
rm -rf ipfs-cluster-ctl 
successln "ipfs-cluster-ctl downloaded"

print_header ">>>>> Generate IPFS SECRET >>>>>"
infoln "Generting IPFS SECRET"
export IPFS_CLUSTER_SECRET=$(od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
test -n $IPFS_CLUSTER_SECRET && successln "IPFS SECRET generated successfully"

print_header ">>>>> Generate IPFS Docker-compose >>>>>"
infoln "Parse IPFS template ..."
parse_template "$HLF_TEMPLATE_DIR/docker-compose-ipfs.cfg" "$HLF_NETWORK_DIR/docker/docker-compose-ipfs.yaml"
successln "IPFS docker-compose generated"

