# MATSim population for Melbourne

This script generates a sample population for Melbourne based on the [ABS 2016 census](https://www.abs.gov.au/websitedbs/censushome.nsf/home/2016) and using [VISTA-like](https://transport.vic.gov.au/about/data-and-research/vista) activities and trips.

## Setup

### R
The population generation code (in `*.R` files) is written in [R](https://www.r-project.org) and a working knowledge of R is assumed here. You may have to install some missing R packages for instance.

### Data

To get started, you must first download the required data files for generating the population. This can be done conveniently, using the provided Bash script, as follows (see [./data/README.md](./data/README.md) for details):
```
cd ./data && ./prepare.sh
```

If running a Bash script is not an option for you, then you may have to download the data files manually (look in the bash file for the URLs it is accessing).

## How to build a sample Melbourne population

Here is an example of how to build a very small sample population (0.0001%) for Melbourne with census-like persons and VISTA-like activities and trips (for weekdays). Note the R commands being called (everything following `Rscript --vanilla -e`); you can run those commands directly in R to get the same result.

```
```
