# MATSim-Melbourne Example Scenario

*Updated March 20, 2020*

## About this scenario
* This scenario constitutes a small population sample of roughly 0.1%.
* Generated daily plans are VISTA 2012-18 like.
* Currently no matching is done of VISTA-like plans to census-like persons (plans are arbitrarily assigned to persons).
* The transport network is circa 2019 and derived from OpenStreetMap.
* Currently public transport and bicycle travel modes do not directly use the transport network (MATSim teleportation used instead).

**The scenario input and output files listed below are available [here](https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr?path=%2Fscenarios%2Fmel_0.1).**

| File | Type | Description
|---|---|---|
| `mel0.1-2020-03-20.demand.tgz` | Input | Output directory of the demand generation algorithm |
| `plan.xml.gz` | Input | MATSim population file output by the demand generation algorithm |
| `GMel_2D_IVABMPT_GMel_20m_MatsimCleanedCar_pnrAdded_v010.xml.gz` | Input |  MATSim Transport network |
|  `mel0.1-2020-03-20.output.tgz` | Output | MATSim output directory |
| `mel0.1-2020-03-20.mp4` | Output | Video of the MATSim run created using Via |
| `mel0.1-2020-03-20.legend.png` | Output | Legend for colours used in the video |


## How to run

To run the example, do the following in a Bash terminal window:

1. Change to the root of this repository, i.e., the directory with the `pom.xml` in it.

1. Build the MATSim-Melbourne JAR by doing:
```
mvn clean install
```

1. Download the required scenario files by doing:
```
./scenarios/mel_0.1/prepare.sh
```

1. Run the scenario by doing:
```
mvn exec:exec \
  -Dexec.executable=java \
  -Dexec.classpathScope=test \
  -Dexec.args=" \
    -cp %classpath org.matsim.run.RunMatsim \
    ./scenarios/mel_0.1/config.xml \
    ./scenarios/mel_0.1/output \
    "
```
