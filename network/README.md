# MATSim network for Melbourne

This page explains the steps for building a MATSim network for Melbourne, including active transportation related infrastructure and attributes. To do so, you can start from a raw OSM extract (step 1) or from a set of nodes, edges and edge attributes in a format similar to OSM (step 2).    

## Prerequisites
* Postgres [Step 1]
* GDAL/OGR [Step 1]
* R [Step 2]
* Required R packages [Step 2]

## Building the network

### Step 0: Download the required inputs

To get started, you must first download the required input files for generating the network. The required input files depend on the selected entry point and what functions are going to be used during network generation. See `./data/README.md` for more details about the input files. A script is also provided that can be used to download relevant input files. For example, if the starting point is from raw OSM (entry point 1) and GTFS2PT is also going to be used to generate PT network, the following script will download the required inputs:
```
cd data && ./prepare.sh -osm19 -gtfs19
```

### Step 1: Raw OSM processing

This step processes the raw OSM data and generates two outcomes: `network.sqlite` and  `melbourne.sqlite`.

The only required inputs for this step is `melbourne.osm`.
```
cd data && ./prepare.sh -osm19
```
Once the required input is downloaded, run `./processOSM.sh` to process raw OSM data:
```
./processOSM.sh
```
**NOTE** To skip this step, you can download the previously generated outputs with the following script and go directly to step 2:
```
cd data && ./prepare.sh -melb -net
```

### Step 2: Generating MATSim network
This step does a series of processes to generate a MATSim readable network which includes the desired details and options.
You can simply run `makeNetwork.sh` **with its predefined flags**
to generate this network you want. A list of options for `makeNetwork.sh` and a brief description for each is presented in this table:

| Argument | Description                                                                       |
|----------|-----------------------------------------------------------------------------------|
| -t       | Cropping to a small test area (Boundary can be adjusted by editing the code)      |
| -s       | simplifying the network, minimum link length=20m                                  |
| -z       | Adding elevation (requires the elevation data)                                    |
| -pt      | Adding pt from GTFS (requires the GTFS data)                                      |
| -ivabm   | Adding pt from IVABM (requires the IVABM network)                                 |
| -xml     | Writing the output network in MATSim readable XML format                          |
| -sqlite  | Writing the output network in SQLite format                                       |

**Note** Make sure to **at least specify one output format** for the `makeNetwork.sh`. For example, run the following to generate a MATSim readable XML output network, without public transportation, simplification, elevation, focus area and test area:

```
./makeNetwork.sh -xml
```

For further adjustments, such as changing the boundary areas for test area and focus area, edit `./MATSimNetworkGenerator.R`
