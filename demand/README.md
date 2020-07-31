# MATSim population for Melbourne

This script generates a sample population for Melbourne based on the [ABS 2016 census](https://www.abs.gov.au/websitedbs/censushome.nsf/home/2016) and using [VISTA-like](https://transport.vic.gov.au/about/data-and-research/vista) activities and trips.

## Setup

### R
The population generation code (in `*.R` files) is written in [R](https://www.r-project.org) and a working knowledge of R is assumed here. You may have to install some missing R packages for instance.

As of 30/Jul/20, this seems to be the dependency list:
```
install.packages("data.table", "reshape2", "ggplot2", "dplyr", "sf", "XML")
```

### How to get the Data

To get started, you must first download the required data files for generating the population and place them into `./data`. For download instructions see [`./data/README.md`](./data/README.md).

## How to build a sample Melbourne population

Here is an example of how to build a small sample population (0.1%) for Melbourne with census-like persons and VISTA-like activities and trips (for weekdays):
```
Rscript --vanilla -e 'source("makeExamplePopulation.R"); runexample()'
```

The script is quite verbose and takes a few minutes to run. If all went well you should get the MATSim population in `./output/plan.xml`.
