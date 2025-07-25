#!/bin/bash

set -euo pipefail

# Fail early if $TEXT is set but no config.ttl is given
TEXT="${TEXT:-}"
if [ "$TEXT" ]; then
  if ! [ -f "/config.ttl" ]; then
    echo "ERROR! TEXT is set but no config was mounted at /config.ttl"
    exit 1
  fi
fi

# Ensure proper Java environment
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH

printf "\n\nBegin Processing\n\n"

echo "java opts:"
printf "\n"
java -XX:+PrintFlagsFinal -version | grep -Ei "maxheapsize|maxram"
printf "\n"

if [ -d "/rdf" ]; then
  echo "Searching for *.nq | *.trig | *.nq.gz"
  find /rdf -type f \( -name "*.nq" -o -name "*.trig" -o -name "*.nq.gz" \) > /tmp/targets
  if [ -s /tmp/targets ]; then
    echo "Found targets"
    cat /tmp/targets
    printf "\n"
  else
    echo "No targets found, exiting"
    exit 1
  fi
else
  echo "Nothing mounted to /rdf, exiting"
  exit 1
fi

# check for unused inputs
find /rdf -type f > /tmp/allfiles
if ! diff -q /tmp/allfiles /tmp/targets > /dev/null; then
  printf "\n"
  echo "Warning! /rdf contains files that wont be processed"
  comm -13 <(sort /tmp/targets) <(sort /tmp/allfiles)
fi

printf "\n\nBegin TDB2 load\n\n"

JENA_VERSION="${JENA_VERSION:-5.3.0}"
echo "Using Jena version: $JENA_VERSION"

riot="/apache-jena-$JENA_VERSION/bin/riot"
SKIP_VALIDATION="${SKIP_VALIDATION:-}"
if ! [ "$SKIP_VALIDATION" ]; then
  printf "\nBegin Validation\n\n"
  echo "invalid files will be renamed as *.invalid"
  errors=0
  while read -r line; do
    printf "\n$line: "
    if ! $riot --validate "$line" 2>/dev/null; then
      printf "invalid"
      mv "$line" "$line.invalid"
      sed -i "\#$line#d" /tmp/targets
      errors=$(($errors + 1))
    else
      printf "ok"
    fi
  done < /tmp/targets
  printf "\n\nvalidation done. $errors errors.\n\n"
fi

sparql="/apache-jena-$JENA_VERSION/bin/sparql"
DATASET="${DATASET:-}"
if [ "$DATASET" ]; then
  true
elif [ -f "/config.ttl" ]; then
  # if config.ttl is given override dataset name from there
  results="$($sparql --query=/query.rq --data=/config.ttl --results=json)"
  num_results="$(echo $results | jq -r '.results.bindings | length')"
  if [ "$num_results" -gt 1 ]; then
    printf "\n\nERROR! there is only support for creating one dataset but two definitions were found in /config.ttl\n"
    echo "$results"
    exit 1
  fi
  DATASET="$(echo $results | jq -r '.results.bindings[0].tdb2_location.value')"
else
  # default dataset name to ds
  DATASET="/fuseki/databases/ds"
fi

echo "Using Dataset $DATASET"

mountpoint="$(dirname $DATASET)"
if ! [ -d "$mountpoint" ]; then
  mkdir -p "$mountpoint"
fi

# warn about missing volume
if ! grep -q " $mountpoint " /proc/mounts; then
  printf "\n\n"
  echo "Warning! no volume is mounted to $mountpoint, outputs will not be persisted."
  printf "\n\n"
fi

USE_XLOADER="${USE_XLOADER:-}"
if [ -n "$USE_XLOADER" ]; then
  THREADS="${THREADS:-$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))}"
  echo "Using tdb2.xloader with $THREADS threads"
  loader="/apache-jena-$JENA_VERSION/bin/tdb2.xloader --threads $THREADS"
else
  TDB2_MODE="${TDB2_MODE:-phased}"
  echo "Using $TDB2_MODE tdb2.loader"
  loader="/apache-jena-$JENA_VERSION/bin/tdb2.tdbloader --loader=$TDB2_MODE"
fi

printf "\n"

xargs $loader --loc "$DATASET" < /tmp/targets

# Adjust permissions
chmod -R 0755 "$DATASET"

if [ -n "${SPATIAL:-}" ]; then
  printf "\n\nBegin Spatial Indexing\n\n"
  export SIS_DATA=/home/fuseki
  spatial_indexer="java -jar /spatialindexer.jar"
  $spatial_indexer --dataset "$DATASET" --index "$DATASET/spatial.index"
fi

if [ -n "$TEXT" ]; then
  printf "\n\nBegin Text Indexing\n\n"
  text_indexer="java --add-modules jdk.incubator.vector --enable-native-access=ALL-UNNAMED -Dorg.apache.lucene.store.MMapDirectory.enableMemorySegments=false -cp /apache-jena-fuseki-$JENA_VERSION/fuseki-server.jar jena.textindexer"
  $text_indexer --desc=/config.ttl
fi

chown -R fuseki:fuseki "$DATASET"

printf "\n\nEnd Processing\n\n"
