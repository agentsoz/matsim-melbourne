package org.matsim.run;

import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ControlerConfigGroup;
import org.matsim.core.config.groups.QSimConfigGroup;
import org.matsim.core.config.groups.StrategyConfigGroup;
import org.matsim.core.config.groups.VspExperimentalConfigGroup;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy;
import org.matsim.core.replanning.strategies.DefaultPlanStrategiesModule;

import static org.matsim.run.RunMelbourne.prepareControler;
import static org.matsim.run.RunMelbourne.prepareScenario;

public class KSRunMelbourne {
	private static final Logger log = Logger.getLogger(KSRunMelbourne.class) ;
	
	public static void main(String[] args) {
		// yyyyyy increase memory!
		
		Config config = ConfigUtils.loadConfig
				("scenarios/2018-02-scenario-by-karthik-from-latch/config-modified_from_kai-06-02-2018.xml");
		config.controler().setOverwriteFileSetting(OutputDirectoryHierarchy.OverwriteFileSetting.deleteDirectoryIfExists);
		
		config.network().setInputFile("net.xml.gz");
		config.plans().setInputFile("../../population-with-home-work-trips.xml.gz");
		
		config.controler().setLastIteration(0);
		
		config.global().setNumberOfThreads(4);
		config.qsim().setNumberOfThreads(4);
		config.qsim().setEndTime(36.*3600.);
		
		config.qsim().setFlowCapFactor(0.01);
		config.qsim().setStorageCapFactor(0.01);
		
		config.vspExperimental().setVspDefaultsCheckingLevel(VspExperimentalConfigGroup.VspDefaultsCheckingLevel.warn);
		
		config.qsim().setTrafficDynamics(QSimConfigGroup.TrafficDynamics.kinematicWaves);
		
		config.controler().setRoutingAlgorithmType( ControlerConfigGroup.RoutingAlgorithmType.FastAStarLandmarks);
		
		config.plansCalcRoute().setInsertingAccessEgressWalk(true);
		
		{
			StrategyConfigGroup.StrategySettings stratSets = new StrategyConfigGroup.StrategySettings( ) ;
			stratSets.setStrategyName( DefaultPlanStrategiesModule.DefaultStrategy.ReRoute );
			stratSets.setWeight(0.1);
			config.strategy().addStrategySettings(stratSets);
		}
		{
			StrategyConfigGroup.StrategySettings stratSets = new StrategyConfigGroup.StrategySettings( ) ;
			stratSets.setStrategyName( DefaultPlanStrategiesModule.DefaultSelector.ChangeExpBeta ) ;
			stratSets.setWeight(0.9);
			config.strategy().addStrategySettings(stratSets);
		}
		
		// ---
		
		Scenario scenario = prepareScenario(config);
		
		Controler controler = prepareControler(scenario);
		
		controler.run();
	}
}
