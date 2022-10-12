#!/bin/bash
#set -eo pipefail

REGISTRY_DOMAIN=$1
: ${REGISTRY_DOMAIN:="registry.local"}
REGISTRY_LIBRARY="${REGISTRY_DOMAIN}/synchub"
REPO_PATH=$2
: ${REPO_PATH:=${PWD}}

NEW_TAG=$(date +"%Y%m%d%H%M")
TMP_DIR="/tmp/synchub"
SCRIPTS_PATH=$(cd $(dirname "${BASH_SOURCE}") && pwd -P)
echo ${SCRIPTS_PATH}
UPSTREAM="https://github.com/docker-library/official-images"

SKIP_TAG="windowsservercore"

cd ${REPO_PATH}
mkdir -p ${TMP_DIR}


skopeo_copy() {
    echo "---starting copy- from $1 --to $2"
    
    if skopeo copy  --insecure-policy --command-timeout 120s --retry-times 5 --src-tls-verify=false --dest-tls-verify=false -q docker://$1 docker://$2; then
        echo -e "$GREEN_COL Sync $1 successful $NORMAL_COL"
        echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-synchub-successful.list
        return 0
    
    else 
        echo -e "$RED_COL Sync $1 failed $NORMAL_CO"
        echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-synchub-failed.list
        return 1
    fi
}


sync_images() {
    IFS=$'\n'
    CURRENT_NUM=0
    IMAGES="$(cat ${SCRIPTS_PATH}/hub_images.txt)"
    for image in ${IMAGES}; do
        name="$(echo ${image} | cut -d ':' -f1)"
        tags="$(echo ${image} | cut -d ':' -f2)"
        if grep "${name}:${tags}" ${SCRIPTS_PATH}/hub.txt; then
            echo "---the images  ${REGISTRY_LIBRARY}/${name}:${tags} has exists , skipping --- " 
            continue
        fi
        echo "--tags start--"
        echo ${name}:${tags}
        echo "--tags end --"
        if skopeo_copy docker.io/${name}:${tags} ${REGISTRY_LIBRARY}/${name}:${tags}; then
            echo "+++++++++++copy start------------"
            skopeo_copy ${REGISTRY_LIBRARY}/${name}:${tags} ${REGISTRY_LIBRARY}/${name}:${tags}
        fi
    done
    unset IFS
}

sync_images
