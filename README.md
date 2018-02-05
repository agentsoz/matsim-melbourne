# MATSim-Melbourne

* [About this project](#about-this-project)
* [Getting started](#getting-started)
* [Input Data](#input-data)
* [How to build and run](#how-to-build-and-run)
* [Contributors](#contributors)
* [License](#license)


## About this project

This repository will provide an open and validated MATSim traffic model for the greater Melbourne area. The project is a collaborative effort between individuals and groups from [RMIT University](http://www.rmit.edu.au), [University of Melbourne](http://www.unimelb.edu.au/), [CSIRO Data61](http://data61.csiro.au/), [Swinburne University](http://www.swinburne.edu.au/), [KPMG Australia](https://home.kpmg.com/au/en/home.html), and others.

The first release of the model is expected to be made in Jan 2018.

## Directory organization

**data** contains original data.  This is sometimes in MATSim format, because that was the
way we received it, but more often it comes in other formats.

**scenarios** contains generated MATSim scenarios.  In consequence, these are
files on which a MATSim run can be started.  There are often also intermediate files,
such as plans after routing, since that accelerates MATSim runs a lot. 

**results** contains output from MATSim runs.  One should be a bit careful of 
putting this into git despite the large file support, but for small (1%) runs it seems 
feasible and is useful for many results.  Maybe something like
[http://www.mytardis.org] should be considered for larger outputs.

**src** contains source code

**test** contains test input files (for regression tests) 


## Getting started

### Support for large files

If you are just using the project from the browser, you can ignore this section.
If you want to pull a git clone, this is important: Given that the model will invariably be using large data files from various sources, we will use [Git LFS support](https://help.github.com/articles/versioning-large-files/) in GitHub for storing these. The idea is to keep all such files in the `./data` directory. LFS is already set up to track any file in this directory, so there is nothing special 
you have to do. Other than ensuring that you [install Git LFS](https://help.github.com/articles/installing-git-large-file-storage/), otherwise when you clone the repository you only receive the *pointers* to the large files and not the actual data.


## How to build and run

To build the project, do:
```concept
mvn clean install
```

### (Re)create MATSim plans based on VISTA

Find the `CreateDemandFromVISTA` class somewhere under `src/main` and look there.

### (Re)create MATSim plans based on LATCH

To convert the Synthetic population generated using the latch algorithm to the MatSim syntax, use the command below. It
generates the output file saved as `population-from-latch.xml`
```concept
mvn exec:java -Dexec.mainClass="io.github.agentsoz.matsimmelbourne.CreatePopulationFromLatch" --output-dir . --run-mode f --file-format x
```
To convert the Synthetic households generated using the latch algorithm to the MatSim syntax, use the command below. It
generates the output file saved as `households-from-latch.xml`
```concept
mvn exec:java -Dexec.mainClass="io.github.agentsoz.matsimmelbourne.CreateHouseHoldFromLatch"
```

To generate the MatSim activity plans with planned mode of transport car-as-driver for the Synthetic population, use the command below. 
It generates the output file saved as `population-with-home-work-trips.xml`
```concept
mvn exec:java -Dexec.mainClass="io.github.agentsoz.matsimmelbourne.AddWorkPlacesToPopulation" carAsDriver
```

### Run MATSim

Then to run the simulation with the generated MATSim population, run `MATSimGUI` in the matsim-melbourne project.  This can
* either be done from the IDE
* or be done from the command line as follows:
```concept
mvn exec:java -Dexec.mainClass="org.matsim.gui/MATSimGUI"
```
Then choose the correct config file (presumably in the `scenarios' directory), then run.

Evidently, you could modify the material of a scenario, in particular the config file.

If you are a bit more experienced, you could copy `RunMelbourneTemplate.java`, adjust to your needs, and run that one.

## Contributors

* Karthikey Surineni, RMIT University
* Claire Boulange, RMIT University
* Dhirendra Singh, RMIT University
* Jonathan Arundel, RMIT University
* Kai Nagel, TU Berlin
* Leorey Marquez, Data61/CSIRO
* Lin Padgham, RMIT University
* Nicole Ronald, Swinburne University
* Renan Grace, KPMG 
* Roberto Sabatini, RMIT University 
* Sara Moridpour, RMIT University 
* Stephan Winter, University of Melbourne 
* Zahra Navidi, University of Melbourne

## License

Open source license still to be agreed.

