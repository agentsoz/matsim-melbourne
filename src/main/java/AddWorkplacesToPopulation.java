import au.edu.unimelb.imod.demand.CreateDemandFromVISTA;
import com.vividsolutions.jts.geom.Point;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.Activity;
import org.matsim.api.core.v01.population.Leg;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.PopulationWriter;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.population.io.PopulationReader;
import org.matsim.core.scenario.ScenarioUtils;
import org.opengis.feature.simple.SimpleFeature;

import java.util.Random;

class AddWorkplacesToPopulation {
	
	public static void main( String[] args ) {
		AddWorkplacesToPopulation abc = new AddWorkplacesToPopulation() ;
		abc.readShapefile() ; // zones as used in the OD matrix.  ASGS
		abc.readODMatrix() ;
		abc.parsePopulation() ;
	}
	
	private void readShapefile() {
		
		// read shapefile; see CreateDemandFromVISTA for example.
		
	}
	
	private void readODMatrix() {
		
		// csv reader; start at line 12 (or 13); read only car to get started.
		
	}
	
	private void parsePopulation() {
		Random rnd = new Random(4711) ;
		
		Config config= ConfigUtils.createConfig() ;
		config.plans().setInputFile("population-from-latch.xml");  // add gz after debugging
		
		Scenario scenario = ScenarioUtils.loadScenario(config) ;
		// (this will read the population file)
	
		for ( Person person : scenario.getPopulation().getPersons().values() ) {
			
			String origin = null ; // in which ASGS are we?   Where do we get this from?
			
			String destination = null ; // draw destination from OD Matrix.   Start with car only.
			
			SimpleFeature ft = null ; // get this from the shp file
			
//			Point point = CreateDemandFromVISTA.getRandomPointInFeature(rnd, ft);
//			final Coord coord = new Coord(point.getX(), point.getY());
			final Coord coord = new Coord( 50000.,  50000. ) ;
			
			Leg leg = scenario.getPopulation().getFactory().createLeg(TransportMode.car) ;
			person.getSelectedPlan().addLeg(leg);
			
			Activity act = scenario.getPopulation().getFactory().createActivityFromCoord( "work", coord) ;
			person.getSelectedPlan().addActivity(act);
			
			// todo: add trip back home
			
		}
		
		PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
		writer.write("population-with-home-work-trips.xml") ;
		
	}
	
}
