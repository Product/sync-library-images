#!/bin/bash
set -eo pipefail

GREEN_COL="\\033[32;1m"
RED_COL="\\033[1;31m"
YELLOW_COL="\\033[33;1m"
NORMAL_COL="\\033[0;39m"

REGISTRY_DOMAIN=$1
: ${REGISTRY_DOMAIN:="registry.local"}
REGISTRY_LIBRARY="${REGISTRY_DOMAIN}/synctest"
REPO_PATH=$2
: ${REPO_PATH:=${PWD}}

NEW_TAG=$(date +"%Y%m%d%H%M")
TMP_DIR="/tmp/docker-library2"
SCRIPTS_PATH=$(cd $(dirname "${BASH_SOURCE}") && pwd -P)
UPSTREAM="https://github.com/docker-library/official-images"

SKIP_TAG="windowsservercore"

cd ${REPO_PATH}
mkdir -p ${TMP_DIR}

diff_images() {
    git remote remove upstream &> /dev/null || true
    git remote add upstream ${UPSTREAM}
    git fetch --tag
    git fetch --all
    CURRENT_COMMIT=$(git log -1 upstream/master --format='%H')
    echo ${CURRENT_COMMIT}
    LAST_TAG=$(git tag -l | egrep --only-matching -E '^([[:digit:]]{12})' | sort -nr | head -n1 || true )
    echo "--ok1--"
    : ${LAST_TAG:=$(git log upstream/master --format='%H' | tail -n1)}
    IMAGES=$(git diff --name-only --ignore-space-at-eol --ignore-space-change \
    --diff-filter=AM ${LAST_TAG} ${CURRENT_COMMIT} library | xargs -L1 -I {} sed "s|^|{}:|g" {} \
    | sed -n "s| ||g;s|library/||g;s|:Tags:|:|p;s|:SharedTags:|:|p" | sort -u | sed "/${SKIP_TAG}/d")
    echo "--ok2--"
    if [ -s ${SCRIPTS_PATH}/images.list ];then
        echo "---update sync---"
        LIST="$(cat ${SCRIPTS_PATH}/images.list | sed 's|^|\^|g' | tr '\n' '|' | sed 's/|$//')"
        IMAGES=$(echo -e ${IMAGES} | tr ' ' '\n' | grep -E "${LIST}")
    fi
}


skopeo_copy() {
    echo "---starting copy- from $1 --to $2"

    FLAG="$(skopeo copy  --insecure-policy --command-timeout 120s  --src-tls-verify=false --dest-tls-verify=false -q docker://$1 docker://$2 || true)"
    RESULT="$(echo -e ${FLAG} | grep 'connection reset by peer')"
    TEST="$(echo -e ${FLAG} | grep 'variant')"

    while [ ${RESULT} -ne "" ];do
        echo "++++the server reset by peer ,waiting retry after 5 seconds++++"
        sleep 5
        FLAG="$(skopeo copy  --insecure-policy --command-timeout 120s  --src-tls-verify=false --dest-tls-verify=false -q docker://$1 docker://$2 || true)"
        RESULT="$(echo -e ${FLAG} | grep 'connection reset by peer')"
    done
    echo -e "$GREEN_COL Sync $1 successful $NORMAL_COL"
    echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-successful.list
    return 0

    if [ ${TEST} -ne ""]; then
        echo -e "$RED_COL Sync $1 failed $NORMAL_CO"
        echo ${name}:${tags} >> ${TMP_DIR}/${NEW_TAG}-failed.list
        return 1
    fi
}

sync_images() {
    IFS=$'\n'
    CURRENT_NUM=0
    TOTAL_NUMS=$(echo -e ${IMAGES} | tr ' ' '\n' | wc -l)
    for image in ${IMAGES}; do
        echo ${image}

        let CURRENT_NUM=${CURRENT_NUM}+1
        echo -e "$YELLOW_COL Progress: ${CURRENT_NUM}/${TOTAL_NUMS} $NORMAL_COL"
        name="$(echo ${image} | cut -d ':' -f1)"
        tags="$(echo ${image} | cut -d ':' -f2 | cut -d ',' -f1)"
        if skopeo inspect docker://${REGISTRY_LIBRARY}/${name}:${tags} --raw | jq '.' | grep "schemaVersion";then
            echo "---the images  ${REGISTRY_LIBRARY}/${name}:${tags} has exists , skipping --- "
            continue
        fi
        echo "--tags start--"
        echo ${name}:${tags}
        echo "--tags end --"
        if skopeo_copy docker.io/${name}:${tags} ${REGISTRY_LIBRARY}/${name}:${tags}; then
            for tag in $(echo ${image} | cut -d ':' -f2 | tr ',' '\n'); do
                echo "+++++++++++copy start------------"
                skopeo_copy ${REGISTRY_LIBRARY}/${name}:${tags} ${REGISTRY_LIBRARY}/${name}:${tag}
            done
        fi
    done
    unset IFS
}

gen_repo_tag() {
    if git rebase upstream/master; then
        git tag ${NEW_TAG} --force
        git push origin --force
        git push origin --tag --force
    fi
}

diff_images
sync_images
gen_repo_tag
