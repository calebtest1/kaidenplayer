#!/usr/bin/env bash

appname=$(basename -s .git `git config --get remote.origin.url`)

source ./fierce-common/fierce-common.sh

txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
grn=$(tput setaf 2)             # Green
red=$(tput setaf 1)             # Red
gold=$(tput setaf 3)            # Gold
bldgrn=${txtbld}$(tput setaf 2) # Bold Green
bldred=${txtbld}$(tput setaf 1) # Bold Red
txtrst=$(tput sgr0)             # Reset

usage()
{
cat << EOF
Usage
${txtbld}kaidenplayer.sh test once${txtrst}
${txtbld}kaidenplayer.sh test refresh${txtrst}
${txtbld}kaidenplayer.sh run${txtrst}
${txtbld}kaidenplayer.sh build${txtrst}
${txtbld}kaidenplayer.sh deploy${txtrst}
EOF
exit 1
}

setup_cljs() {
    echo_message "Installing shadow-cljs globally" && \
    npm install -g shadow-cljs@2.4.1 && \
    echo_message "Installing local NPM modules" && \
    npm install
}

test_web_setup() {
    echo_message "Installing Karma CLI globally" && \
    npm install -g karma-cli@1.0.1 && \
    setup_cljs

}

test_web_once() {
    test_web_setup && \
    echo_message "Compiling tests" && \
    shadow-cljs compile test && \
    echo_message "Running tests once through karma" && \
    karma start --single-run
}

test_web_refresh() {
    test_web_setup && \
    echo_message "Running unit tests on refresh" && \
    karma start & shadow-cljs watch test
}

sync_submodule() {
      git submodule sync
      git submodule update --init
}

build_web() {
    setup_cljs && \
    echo_message "Create build ready for prod release" && \
    shadow-cljs release release
}

run_server() {
    echo_message "Running server server locally"
    lein run
}

run_web() {
    setup_cljs && \
    export backend_url="http://localhost:5000" && \
    echo_message "Starting and watching :dev profile (Shadow-CLJS)" && \
    shadow-cljs watch dev
}

deploy_web() {
    local workspace=$1 && \
    require_var workspace && \
    echo_message "Deploying web" && \
    build_web && \
    cd infrastructure && \
    terraform init && \
    terraform workspace select ${workspace} || terraform workspace new ${workspace} && \
    local website_bucket_name=$(terraform output website_bucket_name) && \
    local website_distribution_id=$(terraform output website_distribution_id) && \
    cd ../ && \
    aws s3 sync ./resources/public s3://${website_bucket_name}/ --acl public-read --delete && \
    aws cloudfront create-invalidation --distribution-id ${website_distribution_id} --paths '/*'
}

test_web() {
    local cmd=${1} && shift
    case ${cmd} in
        once)
            echo_message "Running all tests once"
            test_web_once;;
        refresh)
            echo_message "Running unit tests on refresh"
            test_web_refresh;;
        usage|*)
            usage
            exit 1;;
    esac
}

parse() {
    local cmd=${1} && shift
    case ${cmd} in
        test)
            test_web $@;;
        run)
            run_web;;
        build)
            build_web;;
        deploy)
            deploy_web $@;;
        sync_submodule|sync-submodule)
            sync_submodule;;
        usage|*)
            usage
            exit 1;;
    esac
}

parse $@
abort_on_error
