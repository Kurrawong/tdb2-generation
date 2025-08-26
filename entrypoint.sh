#!/bin/bash

set -euo pipefail

# Initialise variables from env or defaults
# options for all loaders
JENA_VERSION="${JENA_VERSION:-5.5.0}"
DATASET="${DATASET:-}"
SKIP_LOAD="${SKIP_LOAD:-}"
SKIP_VALIDATION="${SKIP_VALIDATION:-}"
# tdb2.xloader options
USE_XLOADER="${USE_XLOADER:-}"
THREADS="${THREADS:-$(($(nproc) > 1 ? $(nproc) - 1 : 1))}"
TMP_DIR="${TMP_DIR:-}"
# tdb2.loader options
TDB2_MODE="${TDB2_MODE:-phased}"
GRAPH="${GRAPH:-}"
# indexing options
TEXT="${TEXT:-}"
SPATIAL="${SPATIAL:-}"

# Ensure proper Java environment
JAVA_HOME=/opt/java/openjdk
PATH=$JAVA_HOME/bin:$PATH
JVM_ARGS="${JVM_ARGS:-}"

echo "java opts:"
printf "\n"
java -XX:+PrintFlagsFinal -version | grep -Ei "maxheapsize|maxram"
printf "\n"

# Set the location of the required binaries
sparql="/apache-jena-$JENA_VERSION/bin/sparql"
riot="/apache-jena-$JENA_VERSION/bin/riot"

# Fail if $TEXT is set but no config.ttl is given
if [ "$TEXT" ]; then
  if ! [ -f "/config.ttl" ]; then
    echo "ERROR! TEXT is set but no config was mounted at /config.ttl"
    exit 1
  fi
fi

# Determine the name of the dataset to use
# if a dataset name is given as an environment variable use that
if [ "$DATASET" ]; then
  true
elif [ -f "/config.ttl" ]; then
  # else if a config.ttl is given use the dataset name from there
  results="$($sparql --query=/query.rq --data=/config.ttl --results=json)"
  num_results="$(echo "$results" | jq -r '.results.bindings | length')"
  if [ "$num_results" -gt 1 ]; then
    printf "\n\nERROR! there is only support for creating one dataset but two definitions were found in /config.ttl\n"
    echo "$results"
    exit 1
  fi
  DATASET="$(echo "$results" | jq -r '.results.bindings[0].tdb2_location.value')"
else
  # else default dataset name to ds
  DATASET="/fuseki/databases/ds"
fi

# Fail if the tdb database already exists and $USE_XLOADER is true.
if [ -n "$USE_XLOADER" ]; then
  if [ -d "${DATASET}" ]; then
    echo "ERROR! USE_XLOADER is set but $DATASET already exists, please remove it and try again"
    exit 1
  fi
fi

# Fail if SKIP_LOAD is true but no dataset exists
if [ -n "$SKIP_LOAD" ]; then
  if ! [ -d "$DATASET" ]; then
    echo "ERROR! SKIP_LOAD is set but no database was found at $DATASET. Did you forget to mount it?"
    exit 1
  fi
fi

# Ensure that the target output directory exists
mountpoint="$(dirname "$DATASET")"
if ! [ -d "$mountpoint" ]; then
  mkdir -p "$mountpoint"
fi

# Warn about data loss from missing volume
if ! grep -q " $mountpoint " /proc/mounts; then
  printf "\n\n"
  echo "Warning! no volume is mounted to $mountpoint, outputs will not be persisted."
  printf "\n\n"
fi

printf "\n\nBegin Processing\n\n"

# Acquire targets for loading and validation
if [ -z "$SKIP_LOAD" ]; then
  if [ -d "/rdf" ]; then
    echo "Searching for *.nq | *.trig | *.nq.gz | *.ttl | *.nt"
    find /rdf -type f \( -name "*.nq" -o -name "*.trig" -o -name "*.nq.gz" -o -name "*.ttl" -o -name "*.nt" \) >/tmp/targets
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

  # check for unprocessable file names
  problematic_chars="#!"
  bad_filenames="$(grep "[${problematic_chars}]" /tmp/targets || true)"
  if [ -n "$bad_filenames" ]; then
    echo "ERROR! Target filenames contain characters known to cause issues. Please rectify before continuing."
    echo "problematic_chars: $problematic_chars"
    echo "$bad_filenames"
    printf "\n"
  fi
  whitespace_filenames="$(grep -E '[[:space:]]' /tmp/targets || true)"
  if [ -n "$whitespace_filenames" ]; then
    echo "ERROR! Target filenames contain whitespace. Please rectify before continuing."
    echo "$whitespace_filenames"
    printf "\n"
  fi
  if [ -n "$bad_filenames" ] || [ -n "$whitespace_filenames" ]; then
    exit 1
  fi

  # check for unused inputs
  find /rdf -type f >/tmp/allfiles
  if ! diff -q /tmp/allfiles /tmp/targets >/dev/null; then
    printf "\n"
    echo "Warning! /rdf contains files that wont be processed"
    comm -13 <(sort /tmp/targets) <(sort /tmp/allfiles)
  fi
fi

# validation
if [ -z "$SKIP_VALIDATION" ] && [ -z "$SKIP_LOAD" ]; then
  printf "\nBegin Validation\n\n"
  echo "Using Jena version: $JENA_VERSION"
  errors=0
  warnings=0
  mv /tmp/targets /tmp/targets2
  while read -r line; do
    printf "\n%s: " "$line"
    messages="$($riot --validate "$line" 2>&1 || true)"
    if echo "$messages" | grep -q '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} ERROR'; then
      printf "errors"
      errors=$((errors + 1))
    elif echo "$messages" | grep -q '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} WARN'; then
      printf "warnings"
      warnings=$((warnings + 1))
      echo "$line" >>/tmp/targets
    else
      printf "ok"
      echo "$line" >>/tmp/targets
    fi
  done </tmp/targets2
  printf "\n\nvalidation done. %s errors. %s warnings\n" "$errors" "$warnings"
fi

# loading
if [ -z "$SKIP_LOAD" ]; then
  if [ -n "$USE_XLOADER" ]; then
    echo "Using tdb2.xloader with $THREADS threads"
    loader="/apache-jena-$JENA_VERSION/bin/tdb2.xloader --threads $THREADS"
    if [ -n "$TMP_DIR" ]; then
      loader="$loader --tmpdir $TMP_DIR"
    fi
  else
    echo "Using $TDB2_MODE tdb2.loader"
    loader="/apache-jena-$JENA_VERSION/bin/tdb2.tdbloader --loader=$TDB2_MODE"
    if [ -n "$GRAPH" ]; then
      loader="$loader --graph $GRAPH"
    fi
  fi

  printf "\n\nBegin TDB2 load\n\n"
  echo "Using Dataset $DATASET"

  # Compose the loader command with all targets as arguments
  loader_cmd="$loader --loc \"$DATASET\""
  while read -r file; do
    loader_cmd="$loader_cmd '$file'"
  done </tmp/targets

  # Execute the composed command
  eval "$loader_cmd"
fi

# Adjust permissions for the indexers
chmod -R 0755 "$DATASET"

# Optional spatial indexing
if [ -n "$SPATIAL" ]; then
  printf "\n\nBegin Spatial Indexing\n\n"
  export SIS_DATA=/home/fuseki
  spatial_indexer="java -jar /spatialindexer.jar"
  $spatial_indexer --dataset "$DATASET" --index "$DATASET/spatial.index"
fi

# Optional text indexing
if [ -n "$TEXT" ]; then
  printf "\n\nBegin Text Indexing\n\n"
  text_indexer="java --add-modules jdk.incubator.vector --enable-native-access=ALL-UNNAMED -Dorg.apache.lucene.store.MMapDirectory.enableMemorySegments=false -cp /apache-jena-fuseki-$JENA_VERSION/fuseki-server.jar jena.textindexer"
  $text_indexer --desc=/config.ttl
fi

# More permissive ownership
chown -R fuseki:fuseki "$(dirname "$DATASET")"

printf "\n\nEnd Processing\n\n"
