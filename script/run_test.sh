#!/bin/bash

set -e  # exit on error!

#####################################################
# BUILD PLUGIN AND RUN NEO4J                        #
#####################################################

docker_name="neo4j:latest"
docker_name="neo4j:3.5"
apoc_version="3.5.0.1"
docker_id=""
__dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# ============================================================ #
#       #####    ####    ####   #    #  ######  #####          #
#       #    #  #    #  #    #  #   #   #       #    #         #
#       #    #  #    #  #       ####    #####   #    #         #
#       #    #  #    #  #       #  #    #       #####          #
#       #    #  #    #  #    #  #   #   #       #   #          #
#       #####    ####    ####   #    #  ######  #    #         #
# ============================================================ #

function run_docker() {

    if [ ! -z "$(docker ps | grep ${docker_name})" ]; then
        echo "############################"
        echo "Docker already running ... "
        echo "############################"
        echo
        docker ps | grep ${docker_name}
        echo
        echo "############################"
        echo "#  stop it first           #"
        echo "#  run the command         #"
        echo "# docker stop $(docker ps | grep ${docker_name} | awk '{print $1}') #"
        echo "############################"

        docker stop $(docker ps | grep ${docker_name} | awk '{print $1}')
        # exit 0
    fi

    NEO4J_DATA_DIR=${__dir}/neo4j/neo4kobra/data
    NEO4J_DIR=${__dir}/neo4j/neo4kobra/

    mkdir -p ${NEO4J_DATA_DIR}
    mkdir -p ${NEO4J_DIR}

    rm -rf ${NEO4J_DIR}

    echo "=========== Running neo4j =============="
    echo "  * create directories for the data"
    mkdir -p ${NEO4J_DIR}/data
    mkdir -p ${NEO4J_DIR}/import
    mkdir -p ${NEO4J_DIR}/plugins
    mkdir -p ${NEO4J_DIR}/logs

    echo "  * Update plugins"
    PLUGIN_POM="${__dir}/../"
    mvn clean install -f "${PLUGIN_POM}/pom.xml"
    echo "     - copying plugin"
    PLUGIN_TARGET_DIR="${__dir}/../target"
    cp "${PLUGIN_TARGET_DIR}/procedure-template-1.0.0-SNAPSHOT.jar" \
       ${__dir}/neo4j/neo4kobra/plugins

    # docker build -t neo4k ${KOBRA_BASE_GIT_REPO}/res/neo4j/

    echo "  * Running container in background"
    docker_id=$(docker run \
                       --publish=7474:7474 \
                       --publish=7687:7687 \
                       --volume=${NEO4J_DATA_DIR}:/data \
                       --volume=${__dir}/neo4j/neo4kobra/import:/import \
                       --volume=${__dir}/neo4j/neo4kobra/plugins:/plugins \
                       --volume=${__dir}/neo4j/neo4kobra/logs:/logs \
                       --env=NEO4J_dbms_memory_pagecache_size=4G \
                       --env=NEO4J_dbms_memory_heap_maxSize=4G \
                       --env NEO4J_apoc_export_file_enabled=true \
                       --env NEO4J_apoc_import_file_enabled=true \
                       --user="$(id -u):$(id -g)" \
                       --env=NEO4J_AUTH=none \
                       -d ${docker_name})
    echo "  * Docker id: ${docker_id}"
    echo -ne "waiting to start "
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        echo -ne "."
    done

    echo -ne "Waiting to start ."
    docker logs ${docker_id}

    i=0
    while (true); do
        i=$((i+1))
        started_=$(docker logs "${docker_id}" | grep "INFO  Started." || true)
        if [ ! -z "${started_}" ]; then
            echo
            echo "Server started ..."
            break
        fi
        echo -ne "."
        sleep 1
        if [ "${i}" -gt 10 ]; then
            break
        fi
    done

    echo
    echo "   ===> docker logs:"
    docker logs ${docker_id}

    echo "  * 'neo4j-server' is listening on port 7474 & 7687"

    echo "====== DONE ======"
    echo "docker logs -f $docker_id"

}

function run_python() {
    python3 -u ${__dir}/my_neo4j_test.py 'prepare' 'save' 'clean' | tee  ${__dir}/neo4j/my_neo4j_test.log
}

function run_cpp() {
    cd ${__dir}/../c/
    make
    cd -

    python3 -u ${__dir}/my_neo4j_test.py 'prepare'

    ${__dir}/../c/test_neo4jpp_timer | tee  ${__dir}/neo4j/my_neo4j_test.log

    python3 -u ${__dir}/my_neo4j_test.py 'clean'

}

function run_rest() {

    python3 -u ${__dir}/my_neo4j_test.py 'prepare'

    echo -ne "calculate_save  # " > ${__dir}/neo4j/my_neo4j_test.log
    { time curl -X POST -H 'Content-type: application/json' http://localhost:7474/db/data/transaction/commit -d '{"statements": [{"statement": "CALL example.calculate.save(0, 80000) YIELD out as o RETURN o"}]}' > /dev/null; } |& grep real | cut -d'm' -f 2 >>  ${__dir}/neo4j/my_neo4j_test.log

    python3 -u ${__dir}/my_neo4j_test.py 'clean'

}


function collect_server_stats() {
    docker logs ${docker_id} > ${__dir}/neo4j/docker_neo4j.log
}

function print_comparison() {
    # calculate timings
    time_server=$(cat ${__dir}/neo4j/docker_neo4j.log  | grep "calculate_and_save" | tail -n 1 | cut -d"#" -f 2 | cut -d'm' -f 1)
    time_client=$(cat ${__dir}/neo4j//my_neo4j_test.log  | grep calculate_save | tail -n 1 | cut -d'#' -f 2)

    echo "========================================================="
    echo "| RESULT $1:            "
    echo "| * server: procedure returned after     ${time_server}"
    echo "| * client: session.run() returned after ${time_client}"
    echo "========================================================="

}

# ====================
# $1 function
function do_run_test() {
    echo "waiting 10 seconds ..."
    sleep 10
    $1
    collect_server_stats
    print_comparison "$1" >> ${__dir}/results.txt
}

# ============================================================ #
#  #####   #    #  #    #       #####  ######   ####   #####   #
#  #    #  #    #  ##   #         #    #       #         #     #
#  #    #  #    #  # #  #  ###    #    #####    ####     #     #
#  #####   #    #  #  # #         #    #            #    #     #
#  #   #   #    #  #   ##         #    #       #    #    #     #
#  #    #   ####   #    #         #    ######   ####     #     #
# ============================================================ #

run_docker

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> ${__dir}/results.txt

do_run_test run_python
do_run_test run_rest
# do_run_test run_cpp

# ============================================================ #
#    #####   ######   ####   #    #  #     #####   ####        #
#    #    #  #       #       #    #  #       #    #            #
#    #    #  #####    ####   #    #  #       #     ####        #
#    #####   #            #  #    #  #       #         #       #
#    #   #   #       #    #  #    #  #       #    #    #       #
#    #    #  ######   ####    ####   #####   #     ####        #
# ============================================================ #

cat ${__dir}/results.txt

# ============================================================ #

