package io.github.agentsoz.matsimmelbourne.demand.vista;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import io.github.agentsoz.matsimmelbourne.utils.MMUtils;
import org.apache.log4j.Logger;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.locationtech.jts.geom.Point;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.*;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.PlanCalcScoreConfigGroup.ActivityParams;
import org.matsim.core.config.groups.PlanCalcScoreConfigGroup.ModeParams;
import org.matsim.core.config.groups.PlansCalcRouteConfigGroup.ModeRoutingParams;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.*;

/**
 * This is probably chain based
 * 
 * @author (of documentation) kainagel
 *
 */
final class CreateDemandFromVISTA {
	private static final String pusTripsFile = "data/vista/2017-11-01-vista2009/Trips_VISTA09_v3_VISTA_Online.csv" ;
	private static final String pusPersonsFile = "data/vista/2017-11-01-vista2009/Persons_VISTA09_v3_VISTA_Online.csv" ;
	private static final String zonesFile = "data/census/2006/shp/2017-11-08-1259030002_cd06avic_shape/CD06aVIC.shp";
	private static final Logger log = Logger.getLogger( CreateDemandFromVISTA.class ) ;
	
	public static Coord createRandomCoordinateInCcdZone(Random rnd, Map<String, SimpleFeature> featureMap,
														String ccdCode, Record record, CoordinateTransformation ct) {

		// get corresponding feature:
		SimpleFeature ft = featureMap.get(ccdCode) ;
		if ( ft==null ) {
			log.error("unknown ccdCode=" + ccdCode ); // yyyyyy look at this again
			log.error( record.toString() );
			double xmin = 271704. ; double xmax = 421000. ;
			double xx = xmin + rnd.nextDouble()*(xmax-xmin) ;
			double ymin = 5784843. ; double ymax = 5866000. ;
			double yy =ymin + rnd.nextDouble()*(ymax-ymin) ;
			return CoordUtils.createCoord( xx, yy) ;
			
//			return CoordUtils.createCoord(271704., 5784843. ) ; // dummy coordinate; should be around Geelong.  kai, nov'17
		}

		// get random coordinate in feature:
		Point point = MMUtils.getRandomPointInFeature(rnd, ft) ;

		Coord coordInOrigCRS = CoordUtils.createCoord( point.getX(), point.getY() ) ;

		Coord coordOrigin = ct.transform(coordInOrigCRS) ;
		return coordOrigin;
	}
	
	public final static class Record {
		// needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

		@CsvBindByName private String TRIPID ;
		@CsvBindByName private String PERSID ;
		@CsvBindByName private String ORIGSLA ;
		@CsvBindByName private String ORIGCCD ;
		@CsvBindByName private String DESTCCD ;
		@CsvBindByName private String DESTSLA ;
		@CsvBindByName private String ORIGPURP1 ;
		@CsvBindByName private String DESTPURP1 ;
		@CsvBindByName(column="STARTIME") private String trip_start_time ;
		@CsvBindByName private String DEPTIME ;
		@CsvBindByName private String Mode_Group ;

		@Override public String toString() {
			return this.PERSID
					+ "\t" + this.TRIPID 
					+ "\t" + this.ORIGSLA
					+ "\t" + this.ORIGCCD
					+ "\t" + this.ORIGPURP1
					+ "\t" + this.trip_start_time
					+ "\t" + this.Mode_Group
					+ "\t" + this.DESTSLA
					+ "\t" + this.DESTCCD
					+ "\t" + this.DESTPURP1
					+ "\t" + this.DEPTIME;
		}
	}

	private final Scenario scenario;
	private final ArrayList<Id<Person>> activePeople = new ArrayList<>();
	private final CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation(TransformationFactory.WGS84,"EPSG:28355");
	// yyyyyy the "from" of this is probably not right; should be GCS_GDA_1994 (EPSG:4283)
	
	private final Set<String> modes = new TreeSet<>() ;
	private final Set<String> activityTypes = new TreeSet<>() ;
	
	Random random = new Random(4711) ;

	CreateDemandFromVISTA() {
		this.scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig());
	}

	public void run() throws IOException {
		this.createPUSPersons();// create all the people and add a plan to each
		this.createPUSPlans();// create the plans according to the trip files (pusTripsFile)
		//		this.matchFirstAndLastAct();// add a trip to the end or beginning of the plan to match the first and last activity to have a tour based plan
		//		this.matchHomeCoord(); //since in adding the activities the coordinates have been randomised in for each destination, agents have different home locations, this method is need to set all the home location to a single one. 
		this.populationWriting();
	}

	private void createPUSPersons() {
		/*
		 * For convenience and code readability store population and population factory in a local variable 
		 */
		Population population = this.scenario.getPopulation();   
		PopulationFactory populationFactory = population.getFactory();

		/*
		 * Read the PUS file
		 */
		try ( BufferedReader bufferedReader = new BufferedReader(new FileReader(pusPersonsFile)) ) {
			bufferedReader.readLine(); //skip header

			int index_personId = 0;

			String line;
			while ((line = bufferedReader.readLine()) != null) {
				String parts[] = line.split(",");
				/*
				 * Create a person and add it to the population
				 */
				Person person = populationFactory.createPerson(Id.create(parts[index_personId].trim(), Person.class));
				population.addPerson(person);
				/*
				 * Create a day plan and add it to the person
				 */
				Plan plan = populationFactory.createPlan();
				person.addPlan(plan);
				person.setSelectedPlan(plan);
			}
			bufferedReader.close();
		} // end try
		catch (IOException e) {
			e.printStackTrace();
		}
		System.out.println("population done" + "\n" + population);
	} // end of createPUSPersons

	void createPUSPlans() throws IOException {
		// ===

		/*
		 * For convenience and code readability store population and population factory in a local variable 
		 */

		Population population = this.scenario.getPopulation();   
		PopulationFactory pf = population.getFactory();

		// ===



		SimpleFeatureSource fts = ShapeFileReader.readDataFile(zonesFile); //reads the shape file in
		Random rnd = new Random();

		Map<String,SimpleFeature> featureMap = new LinkedHashMap<>() ;

		//Iterator to iterate over the features from the shape file
		try ( SimpleFeatureIterator it = fts.getFeatures().features() ) {
			while (it.hasNext()) {

				// get feature
				SimpleFeature ft = it.next(); //A feature contains a geometry (in this case a polygon) and an arbitrary number

				featureMap.put( (String) ft.getAttribute("CD_CODE06") , ft ) ;
			}
			it.close();
		} catch ( Exception ee ) {
			throw new RuntimeException(ee) ;
		}


		// ===

		try ( final FileReader reader = new FileReader(pusTripsFile) ) { 
			final CsvToBeanBuilder<Record> builder = new CsvToBeanBuilder<>(reader)  ;
			builder.withType(Record.class);
			builder.withSeparator(',') ;
			final CsvToBean<Record> reader2 = builder.build();
//			int ii=0 ;
			Id<Person> previousPersonId = null;
			Coord coordOrigin = null ;
			for (Iterator<Record> it = reader2.iterator(); it.hasNext() ; ) {
//				ii++ ; if ( ii>10 ) break ;
				Record record = it.next() ;
				Id<Person> personId = Id.createPersonId(record.PERSID);
				Person person = population.getPersons().get(personId);
				Gbl.assertNotNull(person);
				Plan plan = person.getSelectedPlan();
				Gbl.assertNotNull(plan);

				if (!personId.equals(previousPersonId) ) { // a new person

					//add the original place
					coordOrigin = createRandomCoordinateInCcdZone(rnd, featureMap, record.ORIGCCD.trim(), record, ct );

					final String actType = record.ORIGPURP1.trim();
					activityTypes.add(actType) ; 
					Activity activity = pf.createActivityFromCoord( actType , coordOrigin);
					activity.setEndTime( fuzzifiedTimeInSecs(record.trip_start_time) ) ;
					plan.addActivity(activity);

					addLegActPair(pf, rnd, featureMap, record, plan);

				} else { // previous person

					addLegActPair(pf, rnd, featureMap, record, plan);

				}
				previousPersonId = personId;
			}
		} // end of for loop

		System.out.println("plnas done");
	}// end of createPUSPlans

	private double fuzzifiedTimeInSecs(final String time) {
		return 60. * Double.parseDouble( time ) + (random.nextDouble()-0.5)*1800.;
	}

	private void addLegActPair(PopulationFactory pf, Random rnd, Map<String, SimpleFeature> featureMap,
							   Record record, Plan plan) {
		// and the first travel leg
		String mode = record.Mode_Group;
		if ( "Vehicle Driver".equals(mode) ) {
			mode = TransportMode.car ; // not necessary, but easier to use the matsim default.  kai, nov'17
		}
		modes.add(mode) ;
		plan.addLeg(pf.createLeg(mode));

		// add the destination
		Coord coordDestination = createRandomCoordinateInCcdZone(rnd, featureMap, record.DESTCCD.trim(), record, ct );
		String activityType = record.DESTPURP1.trim();
		activityTypes.add(activityType) ;
		Activity activity1 = pf.createActivityFromCoord(activityType, coordDestination);
		if ( ! ( record.DEPTIME.equals("N/A") ) ) {
			activity1.setEndTime( fuzzifiedTimeInSecs( record.DEPTIME ) ) ;
			// otherwise, it should be the last activity, in which case we just don't set it, which is the preferred matsim 
			// convention anyways. kai, nov'17
		}
		plan.addActivity(activity1);
	}
	
	void populationWriting(){
		PopulationWriter populationWriter = new PopulationWriter(this.scenario.getPopulation(), this.scenario.getNetwork());
		populationWriter.write("plansCoM.xml.gz");
		
		Config config = ConfigUtils.createConfig() ;
		
		for ( String type : activityTypes ) {
			ActivityParams params = new ActivityParams(type) ;
			config.planCalcScore().addActivityParams(params);
		}
		List<String> networkModes = Arrays.asList(new String [] {TransportMode.car}) ;
		for ( String mode : modes ) {
			ModeParams params = new ModeParams(mode) ;
			config.planCalcScore().addModeParams(params);

			if ( !networkModes.contains(mode) ) {
				ModeRoutingParams pars = new ModeRoutingParams( mode ) ;
				pars.setTeleportedModeSpeed(20.); // m/s
				config.plansCalcRoute().addModeRoutingParams(pars);
			}
		}
		
		ConfigUtils.writeMinimalConfig(config,"config.xml");
		
		System.out.println("writing done");
	}
	
	public static void main(String[] args) throws IOException {

		CreateDemandFromVISTA createDemand = new CreateDemandFromVISTA();
		createDemand.run();
		System.out.println("DONE");

	}



}
