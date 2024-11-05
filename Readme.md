## Overview
This repository contains a Dockerfile to build an image which generates TDB2 datasets used by Fuseki.
It includes:

1. Validation of RDF files using Apache Jena RIOT
   Files that fail validation are renamed with the suffix `.error` - this prevents tdbloader attempting to load them.
2. Creation of TDB2 datasets using `tdb2.tdbloader` or `tdb2.xloader` (for large datasets)
3. Creation of a Spatial Index for use with Apache Jena GeoSPARQL

An additional set of instructions is also provided for running this Dockerfile on an EC2 instance - note this has only been necessary for very large datasets.

Example command to build this image:
`docker build -t tdb-generation:<tag> .`

Example command to run this image locally.
```
docker run -v $(pwd)/output:/databases -v $(pwd)/data:/rdf tdb2-generation:<tag>
```

Where:
- `$(pwd)/output` is the directory where the TDB2 databases will be created
- `$(pwd)/data` is the directory containing the RDF files to be loaded

## Text indexing

Not currently supported - can be supported by adding functionality to optionally include a mounted config.ttl file. This is required as the text index is not configurable via the command line.

## Environment Variables

| Variable | Purpose                                                                                                                                                                                                                                  | Default                                                                        | Usage Example |
|-----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|----------------|
| `DATASET` | Specifies the name of the dataset to be created                                                                                                                                                                                          | `"db"` if not set. NB: Can change name when mounting data to runtime database. | `DATASET=my_dataset` |
| `THREADS` | Sets the number of threads to use for processing                                                                                                                                                                                         | Number of available processors minus 1                                         | `THREADS=4` |
| `SKIP_VALIDATION` | If set, skips the validation step for RDF files                                                                                                                                                                                          | Validation is performed if not set                                             | `SKIP_VALIDATION=true` |
| `USE_XLOADER` | If set, uses tdb2.xloader instead of tdb2.tdbloader. xloader can handle large datasets of any size. tdb2.tdbloader can only handle datasets up to a certain size (probably <100 GB, depending on the memory of the instance being used). | Uses tdb2.tdbloader if not set                                                 | `USE_XLOADER=true` |
| `TDB2_MODE` | Specifies the loader mode for tdb2.tdbloader. See [tdbloader documentation](https://jena.apache.org/documentation/tdb2/tdb2_cmds.html) for information on available modes.                                                                                                                        | `"phased"` if not set                                                          | `TDB2_MODE=sequential` |
| `NO_SPATIAL` | If set to true, skips the creation of a spatial index                                                                                                                                                                                    | Spatial index is created if not set                                            | `NO_SPATIAL=true` |