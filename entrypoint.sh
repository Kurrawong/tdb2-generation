#!/bin/bash

set -euo pipefail

# warn about missing volume
mountpoint="/fuseki/databases"
if ! grep -q " $mountpoint " /proc/mounts; then
  printf "\n\n"
  echo "Warning! no volume is mounted to /fuseki/databases, outputs will not be persisted."
  printf "\n\n"
fi

# Fail if $TEXT is set but no config.ttl is given
TEXT="${TEXT:-}"
if [ "$TEXT" ]; then
  if ! [ -f "/config.ttl" ]; then
    echo "ERROR! TEXT is set but no config was mounted at /config.ttl"
    exit 1
  fi
fi

# Warn if $DATASET is not the same as what is in the config.ttl
DATASET="${DATASET:-db}"
config_ds_path=$(grep 'tdb2:location' /config.ttl | sed -n "s/.*['\"]\([^'\"]*\)['\"].*/\1/p")
# too hard to tell if more than one dataset defined
if [ $(echo "$config_ds_path" | wc -l) -lt 2 ]; then 
  if ! [ "$config_ds_path" = "/fuseki/databases/$DATASET" ]; then
    printf "\n\n"
    echo "Warning! The given dataset name does not appear to match the one defined in /config.ttl"
    echo "This may cause text indexing to fail."
    echo "    /fuseki/databases/$DATASET != $config_ds_path"
    printf "\n\n"
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
  find /rdf -type f \( -name "*.nq" -o -name "*.trig" -o -name "*.trig.gz" -o -name "*.nq.gz" \) > /tmp/targets
  if [ -s /tmp/targets ]; then
    echo "Found targets"
    cat /tmp/targets | xargs printf
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

# Default dataset name to 'db'
echo "Using dataset: $DATASET"

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

text_indexer="java --add-modules jdk.incubator.vector --enable-native-access=ALL-UNNAMED -Dorg.apache.lucene.store.MMapDirectory.enableMemorySegments=false -cp /apache-jena-fuseki-$JENA_VERSION/fuseki-server.jar jena.textindexer"
spatial_indexer="java -jar /spatialindexer.jar"

xargs $loader --loc "/fuseki/databases/$DATASET" < /tmp/targets

# Adjust permissions
chmod -R 0755 /fuseki/databases

if [ -n "${SPATIAL:-}" ]; then
  printf "\n\nBegin Spatial Indexing\n\n"
  $spatial_indexer --dataset "/fuseki/databases/$DATASET" --index "/fuseki/databases/$DATASET/spatial.index"
fi

if [ -n "$TEXT" ]; then
  printf "\n\nBegin Text Indexing\n\n"
  if ! [ -f "/config.ttl" ]; then
    echo "No assembler description mounted at /config.ttl, cannot complete text indexing"
    exit 1
  fi
  $text_indexer --desc=/config.ttl
fi
