FROM eclipse-temurin:21-jre-alpine AS base

# Set environment variables
ENV JENA_VERSIONS=4.10.0,5.3.0

# Update system packages, install required tools
RUN apk update && \
    apk add --no-cache unzip curl jq bash coreutils && \
	apk upgrade openssl

# Add a user `fuseki` with no password, create a home directory for the user
# -D option for no password, -h for home directory
RUN adduser -D -h /home/fuseki fuseki

# Fetch & unpack Jena Binaries and Fuseki Server
COPY jena_download.sh ./
RUN chmod +x jena_download.sh
RUN ./jena_download.sh

# Copy the spatialindexer.jar file
COPY --from=ghcr.io/kurrawong/spatial-indexer:v0.0.1 /app/spatialindexer.jar /spatialindexer.jar

# Copy scripts, ensure they're owned by fuseki
COPY ./entrypoint.sh /entrypoint.sh
RUN chown fuseki:fuseki /entrypoint.sh && chmod +x /entrypoint.sh
RUN mkdir -p /fuseki/databases && chown fuseki:fuseki /fuseki/databases

# Set the working directory to the home directory of fuseki
WORKDIR /home/fuseki

# Switch to user `fuseki` for subsequent commands
USER fuseki

# Set the entrypoint
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

# Default CMD
CMD []
