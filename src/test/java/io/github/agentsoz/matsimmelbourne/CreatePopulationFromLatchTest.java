package io.github.agentsoz.matsimmelbourne;

import org.junit.Test;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * Tests the CreatePopulationFromLatch class
 */
public class CreatePopulationFromLatchTest {

    //private static final Logger log = Logger.getLogger(CreatePopulationFromLatchTest.class) ;;

    @Test
    public final void testMain() throws IOException{

        String TEST_OUTPUT_FILENAME = "test";
        String fileExpected = CreatePopulationFromLatch.DEFAULT_OUT + CreatePopulationFromLatch.XML_OUT;
        String fileActual = TEST_OUTPUT_FILENAME + CreatePopulationFromLatch.XML_OUT;

        String [] args = {

                "--output-dir",".",
                "--run-mode","d",
                "--sample-population","100",
                "--file-format","x",
                "--file-name",TEST_OUTPUT_FILENAME
        };

        CreatePopulationFromLatch.main(args);

        byte[] bytes_expected = Files.readAllBytes(Paths.get(fileExpected));
        byte[] bytes_actual = Files.readAllBytes(Paths.get(fileActual));


        if(bytes_actual.length != bytes_expected.length)
            throw new RuntimeException("Output test file : "+fileExpected+" differs in size from expected file : " +
                    ""+fileActual);



        //*******FIXED********** FIXME: Not really testing anything here; save expected output file and then compare new
        // to old.

    }

    }



