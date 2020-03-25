# MATSim network for Melbourne

This page explains the steps for building MATSim network for Melbourne, including active transportation attributes. There are two main entry points to this process:
1. From a raw OSM extract,
2. From a set of nodes, edges and edge attributes (in OSM format)   

## Setup

### Prerequisites
* R
* Required R packages
* Postgres [if starting from raw OSM]
* GDAL/OGR [if starting from raw OSM]

### Data

To get started, you must first download the required input files for generating the network. The required input files depends on the point of entry and what functions are going to be used during network generation. See `./data/README.md` for more details about the input files. An script is also provided that can be used to download relevant input files. For example, if starting point is from raw OSM and GTFS2PT is also going to be use, the following script will download the required inputs:
```
cd data && ./prepare.sh -osm19 -gtfs19
```


## Overview of the process
This diagram proves an overview of the network generation process.
![diagram](networkGeneration.svg)

## Building the network
### Starting from raw OSM (Entry point 1)

**Minimum** required inputs to start from here is `melbourne.osm`.
```
cd data && ./prepare.sh -osm19
```
After downloading the all the required input files, run `./melbNetwork.sh` to process raw OSM data:
```
./melbNetwork.sh
```
And then run `./MATSimNetworkGenerator.R` to generate the MATSim network:
```
Rscript ./MATSimNetworkGenerator.R
```
You can configure the following options from within `MATSimNetworkGenerator.R` to produce your desired network:
- Cropping the network to a specific study area,
- Limiting the detailed network only for a focus area, major network for the rest
- Simplifying the network: minimum link threshold (default=20m)
- Including the road elevation
- Generating PT network from GTFS
- MATSim network outputs format (xml and sqlite)

### Starting from nodes, edges and edge attributes (Entry point 2)
**Minimum** required inputs to start from here are `melbourne.sqlite` and `network.sqlite `:
```
cd data && ./prepare.sh -melb -net
```
After downloading the all the required input files, skip running the `./melbNetwork.sh` and start directly from `./MATSimNetworkGenerator.R`:
```
Rscript ./MATSimNetworkGenerator.R
```
