FROM eclipse-temurin:21-jre-alpine AS base

# Set environment variables
ENV JENA_VERSION=5.2.0


# Update system packages, install required tools
RUN apk update && \
    apk add --no-cache unzip curl jq bash coreutils && \
	apk upgrade openssl

# Add a user `fuseki` with no password, create a home directory for the user
# -D option for no password, -h for home directory
RUN adduser -D -h /home/fuseki fuseki

# Fetch & unpack Jena and Jena Fuseki
RUN curl "https://dlcdn.apache.org/jena/binaries/apache-jena-$JENA_VERSION.tar.gz" -o "/jena.tar.gz" && \
    tar -xzf /jena.tar.gz && rm /jena.tar.gz && \
    curl "https://dlcdn.apache.org/jena/binaries/apache-jena-fuseki-$JENA_VERSION.tar.gz" -o "/fuseki.tar.gz" && \
    tar -xzf /fuseki.tar.gz apache-jena-fuseki-$JENA_VERSION/fuseki-server.jar && \
    mv apache-jena-fuseki-$JENA_VERSION/fuseki-server.jar /fuseki-server.jar && \
    rm /fuseki.tar.gz && \
    rm -r apache-jena-fuseki-$JENA_VERSION

# Copy the spatialindexer.jar file
COPY --from=ghcr.io/kurrawong/spatial-indexer:v0.0.1 /app/spatialindexer.jar /spatialindexer.jar

# Copy scripts, ensure they're owned by fuseki
COPY ./entrypoint.sh /entrypoint.sh
RUN chown fuseki:fuseki /entrypoint.sh && chmod +x /entrypoint.sh
RUN mkdir -p /databases && chown fuseki:fuseki /databases

# Set the working directory to the home directory of fuseki
WORKDIR /home/fuseki

# Add binaries to PATH
ENV PATH="/apache-jena-${JENA_VERSION}/bin:${PATH}"

# Switch to user `fuseki` for subsequent commands
USER fuseki
# Set the entrypoint
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

# Default CMD
CMD []
