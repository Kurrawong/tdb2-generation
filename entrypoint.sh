#!/bin/ash
set -euo pipefail

# Ensure proper Java environment
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH

echo "Starting Processing"
java -XX:+PrintFlagsFinal -version | grep -Ei "maxheapsize|maxram"

# Dataset name handling
DATASET="${DATASET:-db}"
echo "Using dataset: $DATASET"
THREADS="${THREADS:-$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))}"
echo "Using $THREADS threads"

# Debug: Show contents of /rdf directory
echo "Contents of /rdf directory:"
find /rdf -type f

echo "Searching for RDF files..."
# Simpler find command that works in Alpine
find /rdf -type f -name "*.nq" -print0 > /tmp/nq_files
find /rdf -type f -name "*.rdf" -o -name "*.ttl" -o -name "*.owl" -o -name "*.nt" -o -name "*.nquads" > /tmp/other_files

# Check if we found any nq files
if [ ! -s /tmp/nq_files ] && [ ! -s /tmp/other_files ]; then
    echo "No RDF files found."
    rm -f /tmp/nq_files /tmp/other_files
    exit 0
fi

echo "The following RDF files have been found and will be processed:"
echo "N-Quads files:"
xargs -0 printf "%s\n" < /tmp/nq_files || true
echo "Other RDF files:"
cat /tmp/other_files || true

echo "##############################"

# Load files into TDB2
if [ -n "${USE_XLOADER:-}" ]; then
    if [ -s /tmp/nq_files ]; then
        xargs -0 tdb2.xloader --threads "$THREADS" --loc "/fuseki/databases/$DATASET" < /tmp/nq_files
    else
        echo "Error: No .nq files found. xloader requires N-Quads files."
    fi
else
    TDB2_MODE="${TDB2_MODE:-phased}"
    echo "Using TDB2_MODE: $TDB2_MODE"

    if [ -s /tmp/nq_files ]; then
        xargs -0 tdb2.tdbloader --loader="$TDB2_MODE" --loc "/fuseki/databases/$DATASET" --verbose < /tmp/nq_files
    fi

    if [ -s /tmp/other_files ]; then
        xargs -0 tdb2.tdbloader --loader="$TDB2_MODE" --loc "/fuseki/databases/$DATASET" --graph "https://default" < /tmp/other_files
    fi
fi

# Cleanup temporary files
rm -f /tmp/nq_files /tmp/other_files

# Adjust permissions
chmod -R 0755 /fuseki/databases

# Spatial index creation
if [ "${NO_SPATIAL:-false}" = "true" ]; then
    echo "Skipping spatial index creation (NO_SPATIAL is true)"
else
    echo "Generating spatial index..."
    java -jar /spatialindexer.jar \
        --dataset "/fuseki/databases/$DATASET" \
        --index "/fuseki/databases/$DATASET/spatial.index"
fi

# Create Lucene text index
echo "Creating Lucene text index..."
java -cp /fuseki-server.jar jena.textindexer --desc=/config.ttl