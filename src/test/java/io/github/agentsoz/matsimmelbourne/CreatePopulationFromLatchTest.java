package io.github.agentsoz.matsimmelbourne;

import org.junit.Test;
import java.io.IOException;


/**
 * Tests the CreatePopulationFromLatch class
 */
public class CreatePopulationFromLatchTest {

    @Test
    public final void testMain() throws IOException{

//        testRunMode();
//        testOutputDir();
//        testRunOutputDir();

        CreatePopulationFromLatch.main(new String[]{MMUtils.OUTPUT_DIRECTORY_INDICATOR,".",MMUtils.RUN_MODE,"d"});

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



