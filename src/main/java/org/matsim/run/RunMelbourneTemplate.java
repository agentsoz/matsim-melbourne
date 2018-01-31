package org.matsim.run;

import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy;

import static org.matsim.run.RunMelbourne.prepareControler;
import static org.matsim.run.RunMelbourne.prepareScenario;

class RunMelbourneTemplate {
	private static final Logger log = Logger.getLogger(RunMelbourneTemplate.class) ;
	
	public static void main(String[] args) {
		// yyyyyy increase memory!
		
		Config config = ConfigUtils.loadConfig("scenarios/2017-11-scenario-by-kai-from-vista/config.xml");
		config.controler().setOverwriteFileSetting(OutputDirectoryHierarchy.OverwriteFileSetting.deleteDirectoryIfExists);
		
		Scenario scenario = prepareScenario(config);
		
		Controler controler = prepareControler(scenario);
		
		controler.run();
	}
}
