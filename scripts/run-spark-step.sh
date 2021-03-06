#!/usr/bin/env bash

# Run a spark job on a EMR yarn cluster.
# Note: It requires the generate-spark-submit-yarn.sh to run during the
# EMR bootstrap stage, which will generate a script to run spark-submit with
# prepopulated yarn parameters.

# Die if anything happens
set -ex

# Usage
if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 [<spark options>] <jar-s3-uri> <class> [<args>]" >&2
  exit 1
fi

# Parse the spark options as any option until the first non-option (the jar)
SPARK_OPTIONS=""
SPARK_MASTER_OPTION="yarn-client"
SPARK_DRIVER_MEMORY_OPTION="9g"

while [[ $# > 0 ]]; do
  key=$1

  case ${key} in
    --master)
      shift
      SPARK_MASTER_OPTION="$1"
      shift
      ;;

    --driver-memory)
      shift
      SPARK_DRIVER_MEMORY_OPTION="$1"
      shift
      ;;

    --*)
      shift
      SPARK_OPTIONS="${SPARK_OPTIONS} ${key} $1"
      shift
      ;;

    *)
      break
      ;;
  esac
done

EMR_HOME="/home/hadoop"
ENV_FILE="${EMR_HOME}/hyperion_env.sh"

[ -f ${ENV_FILE} ] && source ${ENV_FILE}

EMR_SPARK_HOME="${EMR_HOME}/spark"
HYPERION_HOME="${EMR_HOME}/hyperion"

mkdir -p ${HYPERION_HOME}

REMOTE_JAR_LOCATION=$1; shift
JOB_CLASS=$1; shift

LOCAL_JAR_DIR="$(mktemp -p $HYPERION_HOME -d -t jars_XXXXXX)"
JAR_NAME="${REMOTE_JAR_LOCATION##*/}"
LOCAL_JAR="${LOCAL_JAR_DIR}/${JAR_NAME}"

# Download JAR file from S3 to local
hadoop fs -get ${REMOTE_JAR_LOCATION} ${LOCAL_JAR}

exec ${EMR_SPARK_HOME}/bin/spark-submit --master ${SPARK_MASTER_OPTION} --driver-memory ${SPARK_DRIVER_MEMORY_OPTION} ${SPARK_OPTIONS} --class ${JOB_CLASS} ${LOCAL_JAR} $@
