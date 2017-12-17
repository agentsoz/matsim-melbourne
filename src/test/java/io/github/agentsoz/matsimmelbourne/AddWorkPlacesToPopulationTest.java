package io.github.agentsoz.matsimmelbourne;

import org.junit.Test;

import java.io.IOException;

/**
 * Tests the AddWorkingPlacesToPopulation class
 */
public class AddWorkPlacesToPopulationTest {

    @Test
    public final void testMain() throws IOException {
        // FIXME: not really testing anything at the moment; also relies on availability of population-from-latch.xml which may not exist (think up a dir structure for this)
        // Maybe look at: https://github.com/agentsoz/bdi-abm-integration/blob/kaibranch/examples/bushfire/src/test/java/io/github/agentsoz/ees/FireAreaMaldon600Test.java
        AddWorkPlacesToPopulation.main(null);

    }
}