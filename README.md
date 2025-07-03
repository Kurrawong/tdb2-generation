## Overview

This repository contains a Dockerfile which generates TDB2 datasets for Fuseki.

It can:

1. Create TDB2 datasets using `tdb2.tdbloader` or `tdb2.xloader` (for large datasets)
2. Compute a spatial index for the dataset.
3. Create a text index for the dataset as defined in a given assembler description.

# Usage

Create a TDB2 database from the RDF files in the ./data directory and save it in the
./output directory.

```bash
docker run -v ./data:/rdf -v ./output:/fuseki/databases --rm ghcr.io/kurrawong/tdb2-generation:latest
```

Create a TDB2 database called `myds` with a text and spatial index

```bash
docker run \
  -e "DATASET=myds" \
  -e "TEXT=true" \
  -e "SPATIAL=true" \
  -v "./config.ttl:/config.ttl" \
  -v "./data:/rdf" \
  -v "./output:/fuseki/databases" \
  --rm \
  ghcr.io/kurrawong/tdb2-generation:latest
```

> [!NOTE]  
> Only quads are supported, this includes nquads, trig, and gzipped nquads.
> Other files will be ignored.

## Environment Variables

| Variable       | Purpose                                                                                                                                                                                                                                  | Default                                                                        | Usage Example          |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------- |
| `DATASET`      | Specifies the name of the dataset to be created                                                                                                                                                                                          | `"db"` if not set. NB: Can change name when mounting data to runtime database. | `DATASET=my_dataset`   |
| `THREADS`      | Sets the number of threads to use for processing (only applies to tdb2.xloader)                                                                                                                                                          | Number of available processors minus 1                                         | `THREADS=4`            |
| `USE_XLOADER`  | If set, uses tdb2.xloader instead of tdb2.tdbloader. xloader can handle large datasets of any size. tdb2.tdbloader can only handle datasets up to a certain size (probably <100 GB, depending on the memory of the instance being used). | Uses tdb2.tdbloader if not set                                                 | `USE_XLOADER=true`     |
| `TDB2_MODE`    | Specifies the loader mode for tdb2.tdbloader. See [tdbloader documentation](https://jena.apache.org/documentation/tdb2/tdb2_cmds.html) for information on available modes.                                                               | `"phased"` if not set                                                          | `TDB2_MODE=sequential` |
| `SPATIAL`      | If set to true, spatial indexing will be performed                                                                                                                                                                                       |
| `TEXT`         | If set, text indexing will be performed using the mounted assembler description.                                                                                                                                                         |
| `JENA_VERSION` | which version of jena/fuseki to use for building the database. options: 4.10.0, 5.3.0 (default)                                                                                                                                          |

## Development

To build the image locally

```bash
docker build . -t tdb2-generation:dev
```

To run it against some test data / config

```bash
docker compose up
```
