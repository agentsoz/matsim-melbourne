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

Here is an example of how to build a small sample population (0.1%) for Melbourne with census-like persons and VISTA-like activities and trips (for weekdays). Note the R script being called (i.e., `Rscript --vanilla -e '<script>'`); you can run the script directly in R to get the same result.

```
./make.sh 0.01
Rscript --vanilla -e 'source("makePopulation.R"); makeMATSimMelbournePopulation(0.01, "./mel_0.01", "mel_0.01")'
2020-02-21 07:23:59 | Initialising
2020-02-21 07:24:11 | Pre-processing data into ./setup
2020-02-21 07:24:11 | Extracting VISTA weekday/end activities from data/VISTA_12_18_CSV.zip.dir/T_VISTA1218_V1.csv (can take a while)
2020-02-21 07:24:53 | Wrote ./setup/vista_2012_18_extracted_activities_weekday.csv.gz and ./setup/vista_2012_18_extracted_activities_weekend.csv.gz
2020-02-21 07:24:53 | Grouping some VISTA activities
2020-02-21 07:24:55 | Updated ./setup/vista_2012_18_extracted_activities_weekday.csv.gz
2020-02-21 07:24:55 | Updated ./setup/vista_2012_18_extracted_activities_weekend.csv.gz
2020-02-21 07:24:55 | Extracting VISTA weekday/end activities times into 48 bins (can take a while)
2020-02-21 07:25:06 | Wrote ./setup/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz and ./setup/vista_2012_18_extracted_activities_weekend_time_bins.csv.gz
2020-02-21 07:25:06 | Generating markov chain model of VISTA activities from ./setup/vista_2012_18_extracted_activities_weekday.csv.gz (can take a while)
2020-02-21 07:26:11 | Wrote markov chain model to ./setup/vista_2012_18_extracted_activities_weekday_markov_chain_model.rds
2020-02-21 07:26:11 | Wrote model visualisation to ./setup/vista_2012_18_extracted_activities_weekday_markov_chain_model.pdf
2020-02-21 07:26:11 | Setup complete
2020-02-21 07:26:11 | Creating output directory ./mel_0.01
2020-02-21 07:26:11 | Selecting a 0.01% population sample from Melbourne's 306 SA2 areas (can take a while)
2020-02-21 07:26:11 | ..........|..........|..........|..........|..........| 50
2020-02-21 07:26:13 | ..........|..........|..........|..........|..........| 100
2020-02-21 07:26:16 | ..........|..........|..........|..........|..........| 150
2020-02-21 07:26:18 | ..........|..........|..........|..........|..........| 200
2020-02-21 07:26:21 | ..........|..........|..........|..........|..........| 250
2020-02-21 07:26:24 | ..........|..........|..........|..........|..........| 300
2020-02-21 07:26:27 | ......
2020-02-21 07:26:27 | Wrote 419 sampled persons to ./mel_0.01/mel_0.01.sample.csv.gz
2020-02-21 07:26:27 | Assigning SA1_MAINCODE_2016 to persons in ./mel_0.01/mel_0.01.sample.csv.gz (can take a while)
2020-02-21 07:26:28 | Updated ./mel_0.01/mel_0.01.sample.csv.gz
2020-02-21 07:26:28 | Loading census-like persons from ./mel_0.01/mel_0.01.sample.csv.gz
2020-02-21 07:26:28 | Loading markov chain model from ./setup/vista_2012_18_extracted_activities_weekday_markov_chain_model.rds
2020-02-21 07:26:28 | Saving MATSim population to ./mel_0.01/mel_0.01.sample.csv.gz
2020-02-21 07:26:28 | Generating VISTA-like activities and trips for 419 census-like persons (can take a while)
2020-02-21 07:26:29 | ..........|..........|..........|..........|..........|..........|..........|..........|..........|..........| 100
2020-02-21 07:26:35 | ..........|..........|..........|..........|..........|..........|..........|..........|..........|..........| 200
2020-02-21 07:26:41 | ..........|..........|..........|..........|..........|..........|..........|..........|..........|..........| 300
2020-02-21 07:26:46 | ..........|..........|..........|..........|..........|..........|..........|..........|...x......|..........| 400
2020-02-21 07:26:53 | ..........|.........
2020-02-21 07:26:54 | Finished generating 418/419 persons
2020-02-21 07:26:54 | Wrote 1 discarded persons to ./mel_0.01/mel_0.01.discarded.csv.gz
2020-02-21 07:26:54 | Wrote 418 persons to ./mel_0.01/mel_0.01.pax.csv.gz
2020-02-21 07:26:54 | Wrote activities to ./mel_0.01/mel_0.01.acts.csv.gz
2020-02-21 07:26:54 | Wrote trips to ./mel_0.01/mel_0.01.legs.csv.gz
2020-02-21 07:26:54 | All done (see mel_0.01.log)
```
