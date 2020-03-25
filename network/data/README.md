# Network generation data

This directory contains inputs files required to generate a MATSim network for Melbourne. Depending on from which stage of the process you want to start and what functions are going to be used during network generation, here you need to have relevant inputs.

## How to populate

To populate this directory with the required data files, use the `./prepare.sh` if relevant arguments to indicate what inputs you want.
Valid arguments for `prepare.sh` are as follows:

| Argument | Input file                   | Description                                   |
|----------|------------------------------|-----------------------------------------------|
| -osm19   | melbourne.osm                | Raw OSM file for Melbourne, 2019              |
| -melb    | melbourne.sqlite             | Road attributes                               |
| -net     | network.sqlite               | non-planar edges and nodes                    |
| -gtfs19  | gtfs_au_vic_ptv_20191004.zip | GTFS feed - 2019-10-04                        |
| -demx10  | DEMx10EPSG28355.tif          | Digital Elevation Model data (x10, EPSG28355) |
| -A       | all of the above             | It Will download all the input files, (~1.2gb)|

For example, for starting from the first step, no elevation and no public transport, you need to run the following to get the required input:
```
./prepare.sh osm19
```

Alternatively, if you want to skip running the `../melbNetwork.sh` and start directly from `../MATSimNetworkGenerator.R` and you also want to include elevation and generate the PT network from GTFS, you need to run the following:
```
./prepare.sh melb net gtfs19 demx10
```
If you are not sure about which inputs are required, just simply run `./prepare.sh` without any arguments and it will download all possible inputs.

If that is not an option for you, please download each required file individually.
