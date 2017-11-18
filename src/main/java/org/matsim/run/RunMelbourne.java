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

import java.util.ArrayList;
import java.util.List;

import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.network.Link;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ControlerConfigGroup.RoutingAlgorithmType;
import org.matsim.core.config.groups.QSimConfigGroup.TrafficDynamics;
import org.matsim.core.config.groups.StrategyConfigGroup.StrategySettings;
import org.matsim.core.config.groups.VspExperimentalConfigGroup.VspDefaultsCheckingLevel;
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

		Config config = ConfigUtils.loadConfig("scenarios/devel/baseConfig.xml") ;
		config.controler().setOverwriteFileSetting(OverwriteFileSetting.deleteDirectoryIfExists);

		//		config.network().setInputFile("mergedGmelbNetwork.xml.gz");
		config.network().setInputFile("net.xml.gz");

		config.plans().setInputFile("pop.xml.gz") ;
//		config.plans().setInputFile("pop-routed-accessegress.xml.gz") ;

		config.controler().setLastIteration(100);

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

		config.global().setNumberOfThreads(4);
		config.qsim().setNumberOfThreads(4);
		config.qsim().setEndTime(36.*3600.);

		config.qsim().setFlowCapFactor(0.01);
		config.qsim().setStorageCapFactor(0.01);
		config.qsim().setTrafficDynamics(TrafficDynamics.kinematicWaves);
		
		config.vspExperimental().setVspDefaultsCheckingLevel(VspDefaultsCheckingLevel.abort);

		// ---

		Scenario scenario = ScenarioUtils.loadScenario(config) ;

		log.info("number of links before simplifying=" + scenario.getNetwork().getLinks().size() ) ;
		List<Id<Link>> keysToRemove = new ArrayList<>() ;
		for ( Link link : scenario.getNetwork().getLinks().values() ) {
			if ( link.getFreespeed()<=11.12 && link.getCapacity()<=600. ) {
				keysToRemove.add(link.getId()) ;
			}
		}
		log.info( "removing " + keysToRemove.size() + " links" ) ;
		for ( Id<Link> id : keysToRemove ) {
			scenario.getNetwork().removeLink(id) ;
		}
		//		NetworkUtils.runNetworkCleaner( scenario.getNetwork() ) ;
		NetworkUtils.runNetworkSimplifier( scenario.getNetwork() ) ;
		NetworkUtils.runNetworkCleaner( scenario.getNetwork() ) ;
		log.info("number of links after simplifying=" + scenario.getNetwork().getLinks().size() ) ;

		NetworkUtils.writeNetwork( scenario.getNetwork(), "net.xml.gz" ) ;

		// ---

		Controler controler = new Controler( scenario ) ;

		controler.run();

	}

}
