#!/bin/bash

#
# variables
#

# AWS variables
AWS_PROFILE=default
AWS_REGION=eu-west-3
# project name
PROJECT_NAME=stress
# Docker image name
DOCKER_IMAGE=jeromedecoster/stress


# the directory containing the script file
dir="$(cd "$(dirname "$0")"; pwd)"
cd "$dir"

log()   { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }        # $1 uppercase background white
info()  { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }      # $1 uppercase background green
warn()  { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

# install eksctl if missing (no update)
install-eksctl() {
    if [[ -z $(which eksctl) ]]
    then
        log install eksctl
        warn warn sudo is required
        sudo wget -q -O - https://api.github.com/repos/weaveworks/eksctl/releases \
            | jq --raw-output 'map( select(.prerelease==false) | .assets[].browser_download_url ) | .[]' \
            | grep inux \
            | head -n 1 \
            | wget -q --show-progress -i - -O - \
            | sudo tar -xz -C /usr/local/bin

        # bash completion
        [[ -z $(grep eksctl_init_completion ~/.bash_completion 2>/dev/null) ]] \
            && eksctl completion bash >> ~/.bash_completion
    else
        log skip eksctl already installed
    fi
}

# install kubectl if missing (no update)
install-kubectl() {
    if [[ -z $(which kubectl) ]]
    then
        log install eksctl
        warn warn sudo is required
        local VERSION=$(curl --silent https://storage.googleapis.com/kubernetes-release/release/stable.txt)
        cd /usr/local/bin
        sudo curl https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl \
            --progress-bar \
            --location \
            --remote-name
        sudo chmod +x kubectl
    else
        log skip kubectl already installed
    fi
}

create-env() {
    log install convert npm modules
    cd "$dir/stress"
    npm install

    cd "$dir"
    if [[ ! -f kube-prometheus-v0.4.0.zip ]]
    then
        log download kube-prometheus-v0.4.0.zip
        curl https://github.com/prometheus-operator/kube-prometheus/archive/v0.4.0.zip \
            --progress-bar \
            --location \
            --output kube-prometheus-v0.4.0.zip

        unzip kube-prometheus-v0.4.0.zip
    fi
}

# install eksctl + kubectl, download kube-prometheus
setup() {
    install-eksctl
    install-kubectl
    create-env
}

# run site locally
dev() {
    cd "$dir/stress"
    node server
}

# build the production image
build() {
    cd "$dir/stress"
    VERSION=$(jq --raw-output '.version' package.json)
    log build $DOCKER_IMAGE:$VERSION
    docker image build \
        --tag $DOCKER_IMAGE:latest \
        --tag $DOCKER_IMAGE:$VERSION \
        .
}

# run the latest built production image on localhost
run() {
    [[ -n $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]] \
        && { error error container already exists; return; }
    log run $DOCKER_IMAGE on http://localhost:3000
    docker run \
        --detach \
        --name $PROJECT_NAME \
        --publish 3000:3000 \
        $DOCKER_IMAGE
}

# remove the running container
rm() {
    [[ -z $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]]  \
        && { warn warn no running container found; return; }
    docker container rm \
        --force $PROJECT_NAME
}

# push production image to docker hub
push() {
    cd "$dir/stress"
    VERSION=$(jq --raw-output '.version' package.json)
    docker push $DOCKER_IMAGE:latest
    docker push $DOCKER_IMAGE:$VERSION
}

# create the EKS cluster
cluster-create() { 
    # check if cluster already exists (return something if the cluster exists, otherwise return nothing)
    local exists=$(aws eks describe-cluster \
        --name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        --region $AWS_REGION \
        2>/dev/null)
        
    [[ -n "$exists" ]] && { error abort cluster $PROJECT_NAME already exists; return; }

    # create a cluster named $PROJECT_NAME
    log create eks cluster $PROJECT_NAME

    # t2.small == 11 pods max
    # t2.large == 35 pods max
    eksctl create cluster \
        --name $PROJECT_NAME \
        --region $AWS_REGION \
        --managed \
        --node-type t2.large \
        --nodes 1 \
        --profile $AWS_PROFILE
}

# deploy prometheus + grafana service to EKS
cluster-deploy-prometheus-grafana() { 
    cd "$dir"
    kubectl create -f kube-prometheus-0.4.0/manifests/setup
    kubectl create -f kube-prometheus-0.4.0/manifests
}

# deploy stress service to EKS
cluster-deploy-stress() { 
    cd "$dir"
    kubectl create -f k8s/namespace.yaml
    kubectl create -f k8s/deployment.yaml
    kubectl create -f k8s/service.yaml
}

# get the cluster ELB URI
cluster-elb() { 
    kubectl get svc \
        --namespace website \
        --output jsonpath="{.items[?(@.metadata.name=='website')].status.loadBalancer.ingress[].hostname}"
}

# delete the EKS cluster
cluster-delete() {
    eksctl delete cluster \
        --name $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
}


# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info execute $1; eval $1; } || usage;
exit 0