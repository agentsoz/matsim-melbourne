/* *********************************************************************** *
 * project: org.matsim.*												   *
 *                                                                         *
 * *********************************************************************** *
 *                                                                         *
 * copyright       : (C) 2008 by the members listed in the COPYING,        *
 *                   LICENSE and WARRANTY file.                            *
 * email           : info at matsim dot org                                *
 *                                                                         *
 * *********************************************************************** *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *   See also COPYING, LICENSE and WARRANTY file                           *
 *                                                                         *
 * *********************************************************************** */
package org.matsim.run;

import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ControlerConfigGroup.RoutingAlgorithmType;
import org.matsim.core.config.groups.QSimConfigGroup.TrafficDynamics;
import org.matsim.core.config.groups.StrategyConfigGroup.StrategySettings;
import org.matsim.core.config.groups.VspExperimentalConfigGroup.VspDefaultsCheckingLevel;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy.OverwriteFileSetting;
import org.matsim.core.replanning.strategies.DefaultPlanStrategiesModule.DefaultSelector;
import org.matsim.core.replanning.strategies.DefaultPlanStrategiesModule.DefaultStrategy;
import org.matsim.core.scenario.ScenarioUtils;

/**
 * @author nagel
 *
 */
public class RunMelbourne {
	private static final Logger log = Logger.getLogger(RunMelbourne.class) ;

	public static void main(String[] args) {
		// yyyyyy increase memory!
		
		Config config = prepareConfig(args);
		
		Scenario scenario = prepareScenario(config);

		Controler controler = prepareControler(scenario);
		
		controler.run();
	}
	
	static Controler prepareControler(Scenario scenario) {
		return new Controler( scenario ) ;
	}
	
	static Scenario prepareScenario(Config config) {

//		log.info("number of links before simplifying=" + scenario.getNetwork().getLinks().size() ) ;
//		List<Id<Link>> keysToRemove = new ArrayList<>() ;
//		for ( Link link : scenario.getNetwork().getLinks().values() ) {
//			if ( link.getFreespeed()<=11.12 && link.getCapacity()<=600. ) {
//				keysToRemove.add(link.getId()) ;
//			}
//		}
//		log.info( "removing " + keysToRemove.size() + " links" ) ;
//		for ( Id<Link> id : keysToRemove ) {
//			scenario.getNetwork().removeLink(id) ;
//		}
//		//		NetworkUtils.runNetworkCleaner( scenario.getNetwork() ) ;
//		NetworkUtils.runNetworkSimplifier( scenario.getNetwork() ) ;
//		NetworkUtils.runNetworkCleaner( scenario.getNetwork() ) ;
//		log.info("number of links after simplifying=" + scenario.getNetwork().getLinks().size() ) ;
//
//		NetworkUtils.writeNetwork( scenario.getNetwork(), "net.xml.gz" ) ;
		return ScenarioUtils.loadScenario(config);
	}
	
	static Config prepareConfig(String[] args) {
		Config config = null;
		
		if (args != null && args.length >= 1) {
			config = ConfigUtils.loadConfig(args[0]);
		} else {
			// === default config start (if no config file provided)
			
			config = ConfigUtils.loadConfig("scenarios/2017-11-scenario-by-kai-from-vista/baseConfig.xml");
			config.controler().setOverwriteFileSetting(OverwriteFileSetting.deleteDirectoryIfExists);

			config.controler().setLastIteration(0);
			
			config.global().setNumberOfThreads(4);
			config.qsim().setNumberOfThreads(4);
			config.qsim().setEndTime(36.*3600.);
			
			config.qsim().setFlowCapFactor(0.01);
			config.qsim().setStorageCapFactor(0.01);
			
			// === default config end
		}
		// === everything from here on applies to _all_ runs, that is, it overrides the base config.
		
		config.vspExperimental().setVspDefaultsCheckingLevel(VspDefaultsCheckingLevel.warn);
		
		config.qsim().setTrafficDynamics(TrafficDynamics.kinematicWaves);
		
		config.controler().setRoutingAlgorithmType( RoutingAlgorithmType.FastAStarLandmarks);
		
		config.plansCalcRoute().setInsertingAccessEgressWalk(true);
		
		{
			StrategySettings stratSets = new StrategySettings( ) ;
			stratSets.setStrategyName( DefaultStrategy.ReRoute.name() );
			stratSets.setWeight(0.1);
			config.strategy().addStrategySettings(stratSets);
		}
		{
			StrategySettings stratSets = new StrategySettings( ) ;
			stratSets.setStrategyName( DefaultSelector.ChangeExpBeta ) ;
			stratSets.setWeight(0.9);
			config.strategy().addStrategySettings(stratSets);
		}
		
		// === overriding config is loaded at end.  Allows to override config settings at the very end.  Could, for example, switch off kinematic waves,
		// or set the weight of re-routing to zero.  Not really recommended, but there may be cases where this is needed. kai, jan'18
		ConfigUtils.loadConfig(config,"scenarios/shared/overridingConfig.xml");
		return config;
	}
	
}
