package au.edu.unimelb.imod.demand;

import java.io.IOException;
import java.io.PrintStream;

import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;

public class ZahraRunCreateDemand {

	public static void main(String[] args) throws IOException {
		
//		PrintStream pst = new PrintStream(basePath + "output/handlerErrors.txt");  
//		System.setOut(pst);
//		System.setErr(pst);
		
		ZahraCreateDemandCopy createDemand = new ZahraCreateDemandCopy();
		Config config = ConfigUtils.createConfig();
		Scenario scenario = ScenarioUtils.createScenario(config);
		createDemand.run(scenario);
		System.out.println("DONE");

	}

}
