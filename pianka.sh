#!/usr/bin/env bash

_SHORT_OPTIONS="
h C: L: v
"

_LONG_OPTIONS="
help composer-name: composer-location: verbose
"

APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -euo pipefail

APP_CACHE_DIR="${APP_DIR}/.pianka-cache-dir"

mkdir -pv "${APP_CACHE_DIR}"

CMDNAME="$(basename -- "$0")"

KUBECONFIG=$(mktemp)
export KUBECONFIG

trap 'rm -f "${KUBECONFIG}"' EXIT

function save_to_file {
    # shellcheck disable=SC2005
    echo "$(eval echo "\$$1")" > "${APP_CACHE_DIR}/.$1"
}

function read_from_file {
    cat "${APP_CACHE_DIR}/.$1" 2>/dev/null || true
}

# Composer global variables
COMPOSER_NAME=$(read_from_file COMPOSER_NAME)
export COMPOSER_NAME=${COMPOSER_NAME:=}

COMPOSER_LOCATION=$(read_from_file COMPOSER_LOCATION)
export COMPOSER_LOCATION=${COMPOSER_LOCATION:=}

export VERBOSE="false"

usage() {
cat << EOF
Usage: ${CMDNAME} [-h] [-C] [-L] [-v] <command>

Help manage Cloud Composer instances

The script is adapted to work properly when added to the PATH variable. This will allow you to use
this script from any location.

Flags:

-h, --help
        Shows this help message.
-C, --composer-name <COMPOSER_NAME>
        Composer instance used to run the operations on. Defaults to ${COMPOSER_NAME}
-L, --composer-location <COMPOSER_LOCATION>
        Composer locations. Defaults to ${COMPOSER_LOCATION}
-v, --verbose
        Add even more verbosity when running the script.


These are supported commands used in various situations:

shell
        Open shell access to Airflow's worker. This allows you to test commands in the context of
        the Airflow instance.

info
        Print basic information about the environment.

run
        Run arbitrary command on the Airflow worker.

        Example:
        If you want to list currnet running process, run following command:
        ${CMDNAME} run -- ps -aux

        If you want to list DAGs, run following command:
        ${CMDNAME} run -- airflow list_dags

mysql
        Starts the MySQL console. Additional parameters are passed to the mysql client.

        Tip:
        If you want to execute \"SELECT 123\" query, run following command:
        ${CMDNAME} mysql -- --execute=\"SELECT 123\"

help
        Print help
EOF
echo
}

set +e

getopt -T >/dev/null
GETOPT_RETVAL=$?

if [[ ${GETOPT_RETVAL} != 4 ]]; then
    echo
    if [[ $(uname -s) == 'Darwin' ]] ; then
        echo "You are running ${CMDNAME} in OSX environment"
        echo "And you need to install gnu commands"
        echo
        echo "Run 'brew install gnu-getopt coreutils'"
        echo
        echo "Then link the gnu-getopt to become default as suggested by brew by typing:"
        echo "echo 'export PATH=\"/usr/local/opt/gnu-getopt/bin:\$PATH\"' >> ~/.bash_profile"
        echo ". ~/.bash_profile"
        echo
        echo "Login and logout afterwards"
        echo
    else
        echo "You do not have necessary tools in your path (getopt). Please install the"
        echo "Please install latest/GNU version of getopt."
        echo "This can usually be done with 'apt install util-linux'"
    fi
    echo
    exit 1
fi


if ! PARAMS=$(getopt \
    -o "${_SHORT_OPTIONS:=}" \
    -l "${_LONG_OPTIONS:=}" \
    --name "$CMDNAME" -- "$@")
then
    usage
    exit 1
fi


eval set -- "${PARAMS}"
unset PARAMS

# Parse Flags.
while true
do
  case "${1}" in
    -h|--help)
      usage;
      exit 0 ;;
    -C|--composer-name)
      export COMPOSER_NAME="${2}";
      shift 2 ;;
    -L|--composer-location)
      export COMPOSER_LOCATION="${2}";
      shift 2 ;;
    -v|--verbose)
      export VERBOSE="true";
      echo "Verbosity turned on" >&2
      shift ;;
    --)
      shift ;
      break ;;
    *)
      usage
      echo "ERROR: Unknown argument ${1}"
      exit 1
      ;;
  esac
done

if [ -z "$COMPOSER_NAME" ] && [ -z "$COMPOSER_LOCATION" ] ; then
    echo 'The configuration of the environment is unknown.'
    echo 'Execute this program with "--composer-name" and "--composer-location" flags to set the current environment.'
    echo "The values will be saved and subsequent starts will not require configuration."
    exit 1
fi
save_to_file COMPOSER_NAME
save_to_file COMPOSER_LOCATION

# Utils
function log() {
    if [[ ${VERBOSE} == "true" ]]; then
        echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
    fi
}

# Run functions
function run_command_on_composer {
    log "Running \"$*\" command on \"${COMPOSER_GKE_WORKER_NAME}\""
    kubectl exec --namespace="${COMPOSER_GKE_NAMESPACE_NAME}" -t "${COMPOSER_GKE_WORKER_NAME}" --container airflow-worker -- "$@"
}

function run_interactive_command_on_composer {
    log "Running \"$*\" command on \"${COMPOSER_GKE_WORKER_NAME}\""
    kubectl exec --namespace="${COMPOSER_GKE_NAMESPACE_NAME}" -it "${COMPOSER_GKE_WORKER_NAME}" --container airflow-worker -- "$@"
}

# Fetch info functions
function fetch_composer_gke_info {
    log "Fetching information about the GKE cluster"

    COMPOSER_GKE_CLUSTER_NAME=$(gcloud beta composer environments describe "${COMPOSER_NAME}" --location "${COMPOSER_LOCATION}" '--format=value(config.gkeCluster)')
    COMPOSER_GKE_CLUSTER_ZONE=$(echo "${COMPOSER_GKE_CLUSTER_NAME}" | cut -d '/' -f 4)

    gcloud container clusters get-credentials "${COMPOSER_GKE_CLUSTER_NAME}" --zone "${COMPOSER_GKE_CLUSTER_ZONE}" &>/dev/null
    COMPOSER_GKE_NAMESPACE_NAME=$(kubectl get namespaces | grep "composer" | cut -d " " -f 1)
    COMPOSER_GKE_WORKER_NAME=$(kubectl get pods --namespace="${COMPOSER_GKE_NAMESPACE_NAME}" | grep "airflow-worker" | grep "Running" | head -1 | cut -d " " -f 1)

    if [[ ${COMPOSER_GKE_WORKER_NAME} == "" ]]; then
        echo "No running airflow-worker!"
        exit 1
    fi
    log "GKE Cluster Name:     ${COMPOSER_GKE_CLUSTER_NAME}"
    log "GKE Worker Name:      ${COMPOSER_GKE_WORKER_NAME}"
}

function fetch_composer_bucket_info {
    log "Fetching information about the bucket"

    COMPOSER_DAG_BUCKET=$(gcloud beta composer environments describe "${COMPOSER_NAME}" --location "${COMPOSER_LOCATION}" --format='value(config.dagGcsPrefix)')
    COMPOSER_DAG_BUCKET=${COMPOSER_DAG_BUCKET%/dags}
    COMPOSER_DAG_BUCKET=${COMPOSER_DAG_BUCKET#gs://}

    log "DAG Bucket:           ${COMPOSER_DAG_BUCKET}"
}

function fetch_composer_webui_info {
    log "Fetching information about the bucket"

    COMPOSER_WEB_UI_URL=$(gcloud beta composer environments describe "${COMPOSER_NAME}" --location "${COMPOSER_LOCATION}" --format='value(config.airflowUri)')

    log "WEB UI URL:           ${COMPOSER_WEB_UI_URL}"
}

function fetch_composer_mysql_info {
    log "Fetching information about the mysql"

    # shellcheck disable=SC2016
    COMPOSER_MYSQL_URL="$(run_command_on_composer bash -c 'echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN')"
    COMPOSER_MYSQL_HOST="$(echo "${COMPOSER_MYSQL_URL}" | cut -d "/" -f 3 | cut -d "@" -f 2)"
    COMPOSER_MYSQL_DATABASE="$(echo "${COMPOSER_MYSQL_URL}" | cut -d "/" -f 4)"

    log "SQL Alchemy URL:       ${COMPOSER_MYSQL_URL}"
    log "SQL Alchemy Host:      ${COMPOSER_MYSQL_HOST}"
    log "SQL Alchemy Database:  ${COMPOSER_MYSQL_DATABASE}"
}


if [[ "$#" -eq 0 ]]; then
    echo "You must provide at least one command."
    usage
    exit 1
fi

CMD=$1
shift

if [[ "${CMD}" == "shell" ]] ; then
    fetch_composer_gke_info
    run_interactive_command_on_composer /bin/bash
    exit 0
elif [[ "${CMD}" == "info" ]] ; then
    fetch_composer_bucket_info
    echo "DAG Bucket:            ${COMPOSER_DAG_BUCKET}"

    fetch_composer_gke_info
    echo "GKE Cluster Name:      ${COMPOSER_GKE_CLUSTER_NAME}"
    echo "GKE Worker Name:       ${COMPOSER_GKE_WORKER_NAME}"

    fetch_composer_webui_info
    echo "WEB UI URL:            ${COMPOSER_WEB_UI_URL}"

    fetch_composer_mysql_info
    echo "SQL Alchemy URL:       ${COMPOSER_MYSQL_URL}"
    echo "SQL Alchemy Host:      ${COMPOSER_MYSQL_HOST}"
    echo "SQL Alchemy Database:  ${COMPOSER_MYSQL_DATABASE}"

    exit 0
elif [[ "${CMD}" == "run" ]] ; then
    fetch_composer_gke_info
    run_command_on_composer "$@"
    exit 0
elif [[ "${CMD}" == "mysql" ]] ; then
    fetch_composer_gke_info
    fetch_composer_mysql_info
    run_interactive_command_on_composer mysql -u root -h "${COMPOSER_MYSQL_HOST}" "${COMPOSER_MYSQL_DATABASE}" "$@"
    exit 0
else
    usage
    exit 0
fi
