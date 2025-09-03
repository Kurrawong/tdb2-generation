FROM eclipse-temurin:21-jre-alpine AS base

# Set environment variables
ENV JENA_VERSIONS=5.5.0

# Update system packages, install required tools
RUN apk update && \
    apk add --no-cache unzip curl jq bash coreutils parallel && \
	apk upgrade openssl

# Add a user `fuseki` with no password, create a home directory for the user
# -D option for no password, -h for home directory
RUN adduser -D -h /home/fuseki fuseki

# Fetch & unpack Jena Binaries and Fuseki Server
COPY jena_download.sh ./
RUN chmod +x jena_download.sh
RUN ./jena_download.sh

# Copy the spatialindexer.jar file
COPY --from=ghcr.io/kurrawong/spatial-indexer:v5.5.0-2 /app/spatialindexer.jar /spatialindexer.jar

# Copy scripts, ensure they're owned by fuseki
COPY ./entrypoint.sh /entrypoint.sh
COPY ./queries/ /queries

# Set the entrypoint
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
