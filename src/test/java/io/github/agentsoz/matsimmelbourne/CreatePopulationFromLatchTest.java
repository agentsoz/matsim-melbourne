package io.github.agentsoz.matsimmelbourne;

import org.apache.log4j.Logger;
import org.junit.Test;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * Tests the CreatePopulationFromLatch class
 */
public class CreatePopulationFromLatchTest {

    private static final Logger log = Logger.getLogger(CreatePopulationFromLatchTest.class);

    public String[] setPopulationParameters(String oDir, String rMode, String samplePop, String fFormat, String fName) {

        String[] args = {

                "--output-dir", oDir,
                "--run-mode", rMode,
                "--sample-population", samplePop,
                "--file-format", fFormat,
                "--file-name", fName
        };

        return args;

    }

    // *******FIXED**********FIXME: rename testMain everywhere to be more meaningful wrt what is being tested

    @Test
    public final void createPopFromLatchTestMain() throws IOException {

        final String TEST_OUTPUT_FILENAME = "test";
        String[] args = setPopulationParameters("./output/test/", "d", "100", "x", TEST_OUTPUT_FILENAME);

        CreatePopulationFromLatch.main(args);

        String fileExpected = "./output/expected/" + CreatePopulationFromLatch.DEFAULT_OFNAME +
                CreatePopulationFromLatch
                .XML_OUT;
        File file = new File(fileExpected);

        if (!file.exists()) {
            CreatePopulationFromLatch.main(setPopulationParameters("./output/expected/", "d", "100", "x",
                    CreatePopulationFromLatch
                            .DEFAULT_OFNAME));
        }

        String fileActual = "./output/test/"+TEST_OUTPUT_FILENAME + CreatePopulationFromLatch.XML_OUT;

        String expectedExists = Files.exists(Paths.get(fileExpected)) ? " exists" : " does not exist!";
        log.warn(fileExpected + expectedExists);

        String actualExists = Files.exists(Paths.get(fileActual)) ? " exists" : " does not exist!";
        log.warn(fileActual + actualExists);

        byte[] bytes_expected = Files.readAllBytes(Paths.get(fileExpected));
        byte[] bytes_actual = Files.readAllBytes(Paths.get(fileActual));


        if (bytes_actual.length != bytes_expected.length)
            throw new RuntimeException("Output test file : " + fileExpected + " differs in size from expected file : " +
                    "" + fileActual);


        //*******FIXED********** FIXME: Not really testing anything here; save expected output file and then compare new
        // to old.

    }

}



