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
import org.matsim.api.core.v01.network.Link;
import org.matsim.contrib.emissions.EmissionModule;
import org.matsim.contrib.emissions.utils.EmissionsConfigGroup;
import org.matsim.contrib.noise.NoiseConfigGroup;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ControlerConfigGroup.RoutingAlgorithmType;
import org.matsim.core.config.groups.QSimConfigGroup;
import org.matsim.core.config.groups.QSimConfigGroup.TrafficDynamics;
import org.matsim.core.config.groups.StrategyConfigGroup.StrategySettings;
import org.matsim.core.controler.AbstractModule;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy.OverwriteFileSetting;
import org.matsim.core.network.NetworkUtils;
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
		config.controler().setOverwriteFileSetting(OverwriteFileSetting.deleteDirectoryIfExists);
		
		Scenario scenario = prepareScenario(config);

		Controler controler = prepareControler(scenario);
		
		controler.run();
	}
	
	static Controler prepareControler(Scenario scenario) {
		final Controler controler = new Controler(scenario);

		// add emissions:
		controler.addOverridingModule(new AbstractModule() {
			@Override
			public void install() {
				bind(EmissionModule.class).asEagerSingleton();
//				install(new NoiseModule(scenario));
			}
		});
		
		return controler;
	}
	
	static Scenario prepareScenario(Config config) {
		
		final Scenario scenario = ScenarioUtils.loadScenario(config);
		
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
		
		for ( Link link : scenario.getNetwork().getLinks().values() ) {
//			NetworkUtils.setType(link,"URB/Local/50"); // for emissions; should be more differentiated
			// roadType is an index from roadTypeMapping file and 'URB/Local/50' is HBEFA road type.
			// In current setup, links get indices and mapped to HBEFA road type later using 'roadTypeMapping.txt' file. (see https://matsim.atlassian.net/browse/MATSIM-785) Amit, Feb'18
			NetworkUtils.setType(link,"43");
		}
		
		return scenario;
	}
	
	static Config prepareConfig(String[] args) {
		Config config = null;
		
		if (args != null && args.length >= 1) {
			config = ConfigUtils.loadConfig(args[0]);
		} else {
			// === default config start (if no config file provided)
			
			config = ConfigUtils.loadConfig("scenarios/2017-11-scenario-by-kai-from-vista/config.xml");
			config.controler().setOverwriteFileSetting(OverwriteFileSetting.deleteDirectoryIfExists);

			config.controler().setLastIteration(0);
			
			config.global().setNumberOfThreads(4);
			config.qsim().setNumberOfThreads(4);
			config.qsim().setEndTime(36.*3600.);
			
			// === default config end
		}
		// === everything from here on applies to _all_ runs, that is, it overrides the base config.
		
		config.controler().setRoutingAlgorithmType( RoutingAlgorithmType.FastAStarLandmarks);
		
		config.plansCalcRoute().setInsertingAccessEgressWalk(true);
		
		{
			StrategySettings stratSets = new StrategySettings( ) ;
			stratSets.setStrategyName( DefaultStrategy.ReRoute );
			stratSets.setWeight(0.1);
			config.strategy().addStrategySettings(stratSets);
		}
		{
			StrategySettings stratSets = new StrategySettings( ) ;
			stratSets.setStrategyName( DefaultSelector.ChangeExpBeta ) ;
			stratSets.setWeight(0.9);
			config.strategy().addStrategySettings(stratSets);
		}
		
		config.qsim().setTrafficDynamics(TrafficDynamics.kinematicWaves);
		
		// ---
		
		EmissionsConfigGroup emissionsConfig = ConfigUtils.addOrGetModule(config, EmissionsConfigGroup.class);
		emissionsConfig.setEmissionRoadTypeMappingFile("sample_roadTypeMapping.txt");
		emissionsConfig.setAverageWarmEmissionFactorsFile("sample_EFA_HOT_vehcat_2005average.txt");
		emissionsConfig.setAverageColdEmissionFactorsFile("sample_EFA_ColdStart_vehcat_2005average.txt");
		emissionsConfig.setUsingDetailedEmissionCalculation(false);
		emissionsConfig.setWritingEmissionsEvents(true);
		emissionsConfig.setUsingVehicleTypeIdAsVehicleDescription(false);
		
		// one also needs to have an appropriate vehicles file:
		
		config.vehicles().setVehiclesFile("sample_emissionVehicles_v2.xml");
		config.qsim().setVehiclesSource(QSimConfigGroup.VehiclesSource.modeVehicleTypesFromVehiclesData);
		
		// ---
		
		NoiseConfigGroup noiseConfig = ConfigUtils.addOrGetModule(config, NoiseConfigGroup.class ) ;
		noiseConfig.setReceiverPointGap(500.);
		noiseConfig.setWriteOutputIteration(100);
		
		// === overriding config is loaded at end.  Allows to override config settings at the very end.  Could, for example, switch off kinematic waves,
		// or set the weight of re-routing to zero.  Not really recommended, but there may be cases where this is needed. kai, jan'18
		ConfigUtils.loadConfig(config,"overridingConfig.xml");
		return config;
	}
	
}
