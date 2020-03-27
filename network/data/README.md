# Network generation data

This directory contains inputs files required to generate a MATSim network for Melbourne. Depending on which step of the process you want to start and what functions are going to be used during network generation, here you need to have relevant inputs.

## How to populate

To populate this directory with the required data files, use the `./prepare.sh` with the relevant arguments. Valid arguments and their descriptions are presented in the table below:

| Argument | Input file                   | Description                                   |
|----------|------------------------------|-----------------------------------------------|
| -osm19   | melbourne.osm                | Raw OSM file for Melbourne, 2019              |
| -melb    | melbourne.sqlite             | Road attributes                               |
| -net     | network.sqlite               | non-planar edges and nodes                    |
| -gtfs19  | gtfs_au_vic_ptv_20191004.zip | GTFS feed - 2019-10-04                        |
| -demx10  | DEMx10EPSG28355.tif          | Digital Elevation Model data (x10, EPSG28355) |
| -A       | all of the above             | It Will download all the input files, (~1.2gb)|

As an example, to start from processing raw OSM (step 1), and generating a network without elevation and public transport, you need to run the following to get the required input:
```
./prepare.sh -osm19
```

Alternatively, if you want to skip processing raw OSM and start directly from `makeNetwork.sh`, and generate a network that has elevation and PT network from GTFS, you need to run the following to download required inputs:
```
./prepare.sh -melb -net -gtfs19 -demx10
```
If you are not sure about which inputs are required, just simply run the following to download all the inputs:
```
./prepare.sh -A
```

If any issues with the script, please download each required file directly.
