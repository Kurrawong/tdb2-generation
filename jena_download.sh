#!/bin/bash

set -e

JENA_ARCHIVE=https://archive.apache.org/dist/jena/binaries

IFS="," read -ra versions <<< "${JENA_VERSIONS}"
for version in "${versions[@]}"; do
    echo "Downloading jena $version binaries"
    curl "$JENA_ARCHIVE/apache-jena-$version.tar.gz" -o "/jena.tar.gz"
    echo "Extracting jena $version binaries"
    tar -xzf /jena.tar.gz
    rm /jena.tar.gz

    echo "Downloading fuseki server $version"
    curl "$JENA_ARCHIVE/apache-jena-fuseki-$version.tar.gz" -o "/fuseki.tar.gz"
    echo "Extracting fuseki server $version"
    tar -xzf /fuseki.tar.gz
    rm /fuseki.tar.gz
done
