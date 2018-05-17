#!/bin/bash

set -e

export DIRECTOR_PATH=state/environments/softlayer/director/$DIRECTOR_NAME

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int $DIRECTOR_PATH/vars.yml --path /admin_password`

./ci-resources/scripts/setup-env.sh
./ci-resources/scripts/bosh-login.sh

pushd ./eirini-release

bosh sync-blobs

bosh add-blob /eirini/eirinifs.tar cubefs/cubefs.tar

git submodule update --init --recursive

local nats_password=`bosh int ../state/cf-deployment/deployment-vars.yml --path /nats_password`

echo "::::::::::::::DEPLOY CUBE RELEASE:::::::"
bosh -e lite -d cf deploy -n ../cf-deployment/cf-deployment.yml \
     --vars-store ../state/cf-deployment/deployment-vars.yml \
     -o ../cf-deployment/operations/experimental/enable-bpm.yml \
     -o ../cf-deployment/operations/use-compiled-releases.yml \
     -o ../cf-deployment/operations/bosh-lite.yml \
     -o ../cf-deployment/operations/experimental/use-bosh-dns.yml \
     -o ./operations/cube-bosh-operations.yml \
     -o ./operations/dev-version.yml \
     -o ../bosh-lite-softlayer/operations/cf-deployment/add-dns-entry.yml \
     --var=k8s_flatten_cluster_config="$(kubectl config view --flatten=true)" \
     -v system_domain=$SYSTEM_DOMAIN \
     -v cc_api=$CC_API \
     -v kube_namespace=$KUBE_NAMESPACE \
     -v kube_endpoint=$KUBE_ENDPOINT \
     -v nats_ip=$NATS_IP \
     -v nats_password=$nats_password \
     -v registry_address=$REGISTRY_ADDRESS \
     -v cube_ip=$EIRINI_IP \
     -v cube_address=$EIRINI_ADDRESS \
     -v cube_local_path=./

echo "::::::::::::::CLEAN-UP:::::::;::::::::::"
bosh -e lite clean-up --non-interactive --all

popd
