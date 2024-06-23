This docker image is used to generate TDB2 datasets used by Fuseki.
It includes:

1. Validation of RDF files using Apache Jena RIOT
   Files that fail validation are renamed with the suffix `.error` - this prevents tdbloader attempting to load them.
2. Creation of TDB2 datasets using `tdb2.tdbloader` or `tdb2.xloader` (for large datasets)
3. Creation of a Spatial Index for use with Apache Jena GeoSPARQL
4. Addition of Feature counts (via. a tdb2.update SPARQL update) - this is specific to OGC conformant datasets which contain geo:Features, and will be made optional in future versions (though the command will run harmlessly otherwise!).

An additional set of instructions is also provided for running this Dockerfile on an EC2 instance - note this has only been necessary for very large datasets.

Example command to build this image:
`docker build -t tdb-generation .`

Example command to run this image locally.
```
docker run -v $(pwd)/output:/databases -v $(pwd)/data:/rdf tdb2-generation
```

Where:
- `$(pwd)/output` is the directory where the TDB2 databases will be created
- `$(pwd)/data` is the directory containing the RDF files to be loaded