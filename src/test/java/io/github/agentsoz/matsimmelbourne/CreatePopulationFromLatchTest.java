package io.github.agentsoz.matsimmelbourne;

import org.junit.Rule;
import org.apache.log4j.Logger;
import org.junit.Test;
import org.matsim.core.utils.misc.CRCChecksum;
import java.io.IOException;

/**
 * Tests the CreatePopulationFromLatch class
 */
public class CreatePopulationFromLatchTest {

    private static final Logger log = Logger.getLogger(CreatePopulationFromLatchTest.class) ;;

    @Test
    public final void testMain() throws IOException{

//        private static final String LATCH_PERSONS = "data/census/2011/latch/2017-11-30-files-from-bhagya/AllAgents.csv";
//        private final static String SYNTHETIC_HMAP_FILE_PATH =
//                "data/census/2011/latch/2017-11-30-files-from-bhagya/Hh-mapped-address.json";
//        private static final String XML_OUT = "population-from-latch.xml";
//        private static final String ZIPPED_OUT = "population-from-latch.xml.gz";
//
//        private final Scenario scenario;
//        private final Population population;
//        private final PopulationFactory populationFactory;
//
//        private Map<String, Coord> hhs = new HashMap<>();
//        private Map<String, String> hhsa1Code = new HashMap<>();
//
//        private static String runMode;
//        private static String OUTPUT_POPULATION_FILE = "";

//       String [] args = {

//                "--config",  "scenarios/campbells-creek-01/scenario_main.xml",
//                "--logfile", "scenarios/campbells-creek-01/scenario.log",
//                "--loglevel", "INFO",//	                "--plan-selection-policy", "FIRST", // ensures it is deterministic, as default is RANDOM
//                "--seed", "12345",
//                "--safeline-output-file-pattern", "scenarios/campbells-creek-01/safeline.%d%.out",
//                "--matsim-output-directory", utils.getOutputDirectory(),
//                "--jillconfig", "--config={"+
//                "agents:[{classname:io.github.agentsoz.ees.agents.Resident, args:null, count:1}],"+
//                "logLevel: WARN,"+
//                "logFile: \"scenarios/campbells-creek-01/jill.log\","+
//                "programOutputFile: \"scenarios/campbells-creek-01/jill.out\","+
//                "randomSeed: 12345"+ // jill random seed
//                //"numThreads: 1"+ // run jill in single-threaded mode so logs are deterministic

//                "}"};


        String [] args = {

                "--output-dir",".",
                "--run-mode","d",
                "--sample-population","100",
                "--file-format","x",

        };

        CreatePopulationFromLatch.main(args);


//        testRunMode();
//        testOutputDir();
//        testRunOutputDir();

        //FIXME: Not really testing anything here; save expected output file and then compare new to old.
        // See how expected/actual directories are organised here https://github.com/agentsoz/bdi-abm-integration/blob/kaibranch/examples/bushfire/src/test/java/io/github/agentsoz/ees/MainCampbellsCreek01Test.java
//        CreatePopulationFromLatch.main(new String[]{MMUtils.OUTPUT_DIRECTORY_INDICATOR,".",MMUtils.RUN_MODE,"d"});

    }

//    @Test
//    public final void testRunMode() throws IOException {
//
//        CreatePopulationFromLatch.main(new String[]{MMUtils.RUN_MODE,"d"});
//
//    }
//
//    @Test
//    public final void testOutputDir() throws IOException {
//
//        CreatePopulationFromLatch.main(new String[]{MMUtils.OUTPUT_DIRECTORY_INDICATOR,"."});
//
//    }
//
//    @Test
//    public final void testRunOutputDir() throws IOException{
//
//        CreatePopulationFromLatch.main(new String[]{MMUtils.OUTPUT_DIRECTORY_INDICATOR,".",MMUtils.RUN_MODE,"d"});
//    }
    }



