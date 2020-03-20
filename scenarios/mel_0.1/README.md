# MATSim Melbourne 2016 Example Scenario

This example contains a very small Melbourne population sample (0.1%), see [video](https://cloudstor.aarnet.edu.au/plus/s/KQfaxJPsTr5dfpE) and associated [legend for colours used](https://cloudstor.aarnet.edu.au/plus/s/qBpRrKQ2RpgQ3cT).

To run the example, do the following (in a Bash terminal window):

1. Change to the root of this repository, i.e., the directory with the `pom.xml` in it.

1. Build the MATSim-Melbourne JAR by doing:
```
mvn clean install
```

1. Download the required scenario files by doing:
```
./scenarios/mel_0.1/prepare.sh
```

1. Finally, run the scenario by doing:
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
