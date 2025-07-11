## Overview

This repository contains a Dockerfile which generates TDB2 datasets for Fuseki.

It can:

1. Create TDB2 datasets
2. Create a spatial index for the dataset.
3. Create a text index for the dataset.

# Usage

Create a tdb2 dataset in the current directory from the RDF files in `./data`.

```bash
docker run \
  -v "./data:/rdf" \
  -v "$(pwd):/fuseki/databases" \
  --rm \
  ghcr.io/kurrawong/tdb2-generation:latest
```

> [!NOTE]  
> To persist the generated dataset files, you need to mount a volume to the location  
> where the dataset will be created.
>
> Typically, this is the location of the tdb2 dataset as specified in the mounted  
> assembler description (/config.ttl).
>
> If no assembler description is given then the dataset will be created at  
> /fuseki/databases/ds
>
> This can be overriden with the $DATASET Environment Variable.  
> See the Environment Variables section below for more information.

The loading process can be configured by passing environment variables to the container.
See the table below for all available options.

The text and spatial index creation are **opt-in** and will not be generated by default.

To create a tdb dataset with a text and spatial index:

```bash
docker run \
  -e "SPATIAL=true" \
  -e "TEXT=true" \
  -v "./data:/rdf" \
  -v "$(pwd):/fuseki/databases" \
  -v "./config.ttl:/config.ttl" \
  --rm \
  ghcr.io/kurrawong/tdb2-generation:latest
```

> [!WARNING]  
> Only quads are supported, this includes nquads, trig, and gzipped nquads.  
> Other files will be ignored.

## Environment Variables

| Variable          | Purpose                                                                                                                                              | Default                                                                                                                                                                        | Usage Example                    |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------- |
| `JENA_VERSION`    | which version of jena/fuseki to use for building the database.                                                                                       | 5.3.0 options: \[ 5.3.0, 4.10.0 ]                                                                                                                                              | `JENA_VERSION=4.10.0`            |
| `SPATIAL`         | If set, do spatial indexing                                                                                                                          | unset (false)                                                                                                                                                                  | `SPATIAL=true`                   |
| `TEXT`            | If set, do text indexing. Requires an assembler description mounted at `/config.ttl`                                                                 | unset (false)                                                                                                                                                                  | `TEXT=true`                      |
| `THREADS`         | Sets the number of threads to use for processing <br> (only applies to tdb2.xloader)                                                                 | Number of available processors minus 1                                                                                                                                         | `THREADS=4`                      |
| `USE_XLOADER`     | If set, use tdb2.xloader instead of tdb2.tdbloader. <br> See [tdb.xloader](https://jena.apache.org/documentation/tdb/tdb-xloader.html)               | unset (false)                                                                                                                                                                  | `USE_XLOADER=true`               |
| `TDB2_MODE`       | Specifies the loader mode for tdb2.tdbloader. <br> See [tdbloader options](https://jena.apache.org/documentation/tdb2/tdb2_cmds.html#loader-options) | `phased` if not set                                                                                                                                                            | `TDB2_MODE=sequential`           |
| `DATASET`         | Specifies the path where the tdb dataset should be created.                                                                                          | If no assembler description is mounted at /config.ttl it will defualt to `/fuseki/databases/ds`. Else it is derived from the `tdb2:location "..." ;` statement in /config.ttl. | `DATASET=/fuseki/databases/myds` |
| `SKIP_VALIDATION` | If set skip the validation check. By default, invalid RDF files will be marked as \*.invalid and not processed.                                      | unset (false)                                                                                                                                                                  | `SKIP_VALIDATION=true`           |

## Development

To build the image locally

```bash
docker build . -t tdb2-generation:dev
```

To run it against some test data / config

```bash
docker compose up
```
