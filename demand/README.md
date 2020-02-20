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

## How to build a sample 2016 Melbourne population

Here is an example of how to build a very small sample population (0.0001%) for Melbourne with census-like persons and VISTA-like activities and trips (for weekdays). Note the R commands being called (everything following `Rscript --vanilla -e`); you can run those commands directly in R to get the same result.

```
./make.sh 0.0001
Rscript --vanilla -e 'source("make2016Population.R"); make2016MATSimMelbournePopulation(0.0001, "./mel2016_0.0001")'
2020-01-29 10:36:23 | Extracting VISTA weekday/end activities from ./data/vista_2012_16_v1_sa1_csv.zip.dir/VISTA_2012_16_v1_SA1_CSV/T_VISTA12_16_SA1_V1.csv (can take a while)
2020-01-29 10:36:51 | Wrote ./vista_2012_16_extracted_activities_weekday.csv.gz and ./vista_2012_16_extracted_activities_weekend.csv.gz
2020-01-29 10:36:51 | Grouping some VISTA activities
2020-01-29 10:36:52 | Updated ./vista_2012_16_extracted_activities_weekday.csv.gz
2020-01-29 10:36:52 | Updated ./vista_2012_16_extracted_activities_weekend.csv.gz
2020-01-29 10:36:52 | Generating markov chain model of VISTA activities from ./vista_2012_16_extracted_activities_weekday.csv.gz (can take a while)
2020-01-29 10:37:01 | Wrote markov chain model to ./vista_2012_16_extracted_activities_weekday_markov_chain_model.rds
2020-01-29 10:37:01 | Wrote model visualisation to ./vista_2012_16_extracted_activities_weekday_markov_chain_model.pdf
2020-01-29 10:37:01 | Setup complete.
2020-01-29 10:37:01 | Selecting a 0.0001% population sample from Melbourne's 306 SA2 areas (can take a while)
2020-01-29 10:37:01 | ..........|..........|..........|..........|..........| 50
2020-01-29 10:37:03 | ..........|..........|..........|..........|..........| 100
2020-01-29 10:37:06 | ..........|..........|..........|..........|..........| 150
2020-01-29 10:37:09 | ..........|..........|..........|..........|..........| 200
2020-01-29 10:37:11 | ..........|..........|..........|..........|..........| 250
2020-01-29 10:37:14 | ..........|..........|..........|..........|..........| 300
2020-01-29 10:37:17 | ......
2020-01-29 10:37:18 | Wrote 265 sampled persons to ./mel2016_0.0001.sample.csv.gz
2020-01-29 10:37:18 | Assigning SA1_MAINCODE_2016 to persons in ./mel2016_0.0001.sample.csv.gz (can take a while)
2020-01-29 10:37:22 | Updated ./mel2016_0.0001.sample.csv.gz
2020-01-29 10:37:22 | Loading census-like persons from ./mel2016_0.0001.sample.csv.gz
2020-01-29 10:37:22 | Loading markov chain model from ./vista_2012_16_extracted_activities_weekday_markov_chain_model.rds
2020-01-29 10:37:22 | Generating VISTA-like activities and trips for 265 census-like persons (can take a while)
2020-01-29 10:37:22 | ..........|..........|..........|..........|..........| 50
2020-01-29 10:37:58 | ..........|..........|..........|..........|..........| 100
2020-01-29 10:38:31 | ..........|..........|..........|..........|..........| 150
2020-01-29 10:39:04 | ..........|..........|..........|..........|..........| 200
2020-01-29 10:39:36 | ..........|..........|..........|..........|..........| 250
2020-01-29 10:40:07 | ..........|.....
2020-01-29 10:40:17 | Finished generating 265/265 persons
2020-01-29 10:40:17 | Wrote persons to ./mel2016_0.0001.pax.csv.gz
2020-01-29 10:40:17 | Wrote activities to ./mel2016_0.0001.acts.csv.gz
2020-01-29 10:40:17 | Wrote trips to ./mel2016_0.0001.legs.csv.gz
2020-01-29 10:40:17 | Saving MATSim population to ./mel2016_0.0001.xml
2020-01-29 10:40:17 | All done (see ./mel2016_0.0001.log)
```
