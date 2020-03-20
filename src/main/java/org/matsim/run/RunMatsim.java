package org.matsim.run;

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

import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy;
import org.matsim.core.scenario.ScenarioUtils;

/**
 * @author nagel
 *
 */
public class RunMatsim{

    public static void main(String[] args) {

        if(args.length != 2) {
            System.out.println("\nusage: " + RunMatsim.class.getName() + " CONFIG_XML OUTDIR\n");
            System.exit(0);
        }

        Config config = ConfigUtils.loadConfig( args[0] ) ;
        config.controler().setOutputDirectory( args[1] );
        config.controler().setOverwriteFileSetting(OutputDirectoryHierarchy.OverwriteFileSetting.deleteDirectoryIfExists);

        // possibly modify config here

        // ---

        Scenario scenario = ScenarioUtils.loadScenario(config) ;

        // possibly modify scenario here

        // ---

        Controler controler = new Controler( scenario ) ;

        // possibly modify controler here

//		controler.addOverridingModule( new OTFVisLiveModule() ) ;

        // ---

        controler.run();
    }

}