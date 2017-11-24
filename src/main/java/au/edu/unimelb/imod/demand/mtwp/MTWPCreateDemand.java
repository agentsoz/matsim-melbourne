package au.edu.unimelb.imod.demand.mtwp;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.TreeSet;

import org.apache.log4j.Logger;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.Activity;
import org.matsim.api.core.v01.population.Leg;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.Plan;
import org.matsim.api.core.v01.population.Population;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.api.core.v01.population.PopulationWriter;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.PlanCalcScoreConfigGroup.ActivityParams;
import org.matsim.core.config.groups.PlanCalcScoreConfigGroup.ModeParams;
import org.matsim.core.config.groups.PlansCalcRouteConfigGroup.ModeRoutingParams;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.geotools.MGC;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import com.vividsolutions.jts.geom.Geometry;
import com.vividsolutions.jts.geom.Point;

/**
 * This is probably chain based
 * 
 * @author (of documentation) kainagel
 *
 */
public class MTWPCreateDemand {
	private static final String pusTripsFile = "data/mtwp/Victoria_SA2_UR_by_SA2_POW.csv" ;
	private static final Logger log = Logger.getLogger( MTWPCreateDemand.class ) ;

	public final static class Visitors {
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
	ArrayList<Id<Person>> activePeople = new ArrayList<>();
	CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation(TransformationFactory.WGS84,"EPSG:28355");
	
	private final Set<String> modes = new TreeSet<>() ;
	private final Set<String> activityTypes = new TreeSet<>() ;
	
	Random random = new Random(4711) ;

	MTWPCreateDemand() {
		this.scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig());
	}

	public void run() throws IOException {
		this.createPUSPersons();// create all the people and add a plan to each
		this.createPUSPlans();// create the plans according to the trip files (pusTripsFile)
		//		this.removeNonActivePeople();//remove the people who has no trip
		//		this.matchFirstAndLastAct();// add a trip to the end or beginning of the plan to match the first and last activity to have a tour based plan
		//		this.matchHomeCoord(); //since in adding the activities the coordinates have been randomised in for each destination, agents have different home locations, this method is need to set all the home location to a single one. 
		//		this.matchNumbersAndNames();// all the destinations' and modes' names are digits, this just make them words (e.g. mode=2 -->mode = car)
		//		this.addSubpopulation();
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

	public void createPUSPlans() throws IOException {
		// ===

		/*
		 * For convenience and code readability store population and population factory in a local variable 
		 */

		Population population = this.scenario.getPopulation();   
		PopulationFactory pf = population.getFactory();

		// ===

		String zonesFile = "data/shp/1259030002_cd06avic_shape/CD06aVIC.shp";

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
			final CsvToBeanBuilder<Visitors> builder = new CsvToBeanBuilder<>(reader)  ;
			builder.withType(Visitors.class);
			builder.withSeparator(',') ;
			final CsvToBean<Visitors> reader2 = builder.build();
//			int ii=0 ;
			Id<Person> previousPersonId = null;
			Coord coordOrigin = null ;
			for ( Iterator<Visitors> it = reader2.iterator() ; it.hasNext() ; ) {
//				ii++ ; if ( ii>10 ) break ;
				Visitors record = it.next() ;
				Id<Person> personId = Id.create(record.PERSID, Person.class);
				Person person = population.getPersons().get(personId);
				Gbl.assertNotNull(person);
				Plan plan = person.getSelectedPlan();
				Gbl.assertNotNull(plan);

				if (!personId.equals(previousPersonId) ) { // a new person

					//add the original place
					coordOrigin = createRandomCoordinateInCcdZone(rnd, featureMap, record.ORIGCCD.trim(), record );

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
			Visitors record, Plan plan) {
		// and the first travel leg
		String mode = record.Mode_Group;
		if ( "Vehicle Driver".equals(mode) ) {
			mode = TransportMode.car ; // not necessary, but easier to use the matsim default.  kai, nov'17
		}
		modes.add(mode) ;
		plan.addLeg(pf.createLeg(mode));

		// add the destination
		Coord coordDestination = createRandomCoordinateInCcdZone(rnd, featureMap, record.DESTCCD.trim(), record );
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

	private Coord createRandomCoordinateInCcdZone(Random rnd, Map<String, SimpleFeature> featureMap,
			String ccdCode, Visitors record ) {

		// get corresponding feature:
		SimpleFeature ft = featureMap.get(ccdCode) ;
		if ( ft==null ) {
			log.error("unknown ccdCode=" + ccdCode ); // yyyyyy look at this again
			log.error( record.toString() );
			double xmin = 271704. ; double xmax = 421000. ;
			double xx = xmin + this.random.nextDouble()*(xmax-xmin) ; 
			double ymin = 5784843. ; double ymax = 5866000. ;
			double yy =ymin + this.random.nextDouble()*(ymax-ymin) ;
			return CoordUtils.createCoord( xx, yy) ;
			
//			return CoordUtils.createCoord(271704., 5784843. ) ; // dummy coordinate; should be around Geelong.  kai, nov'17
		}

		// get random coordinate in feature:
		Point point = getRandomPointInFeature(rnd, ft) ;

		Coord coordInOrigCRS = CoordUtils.createCoord( point.getX(), point.getY() ) ;

		Coord coordOrigin = ct.transform(coordInOrigCRS) ;
		return coordOrigin;
	}

	///****************remove people with no plans***************************
	private void removeNonActivePeople(){
		// I don't think that one has to do this for matsim.  Neither do I think that this is advisable.  kai, nov'17
		
		try {
			BufferedReader bufferedReader = new BufferedReader(new FileReader(pusPersonsFile));
			bufferedReader.readLine(); //skip header

			int index_personId = 12;

			String line;
			while ((line = bufferedReader.readLine()) != null) {
				String parts[] = line.split(",");

				Id<Person> checkPersonId = Id.create(parts[index_personId].trim(), Person.class);

				if (this.scenario.getPopulation().getPersons().get(checkPersonId).getSelectedPlan().getPlanElements().isEmpty())
				{
					this.scenario.getPopulation().getPersons().remove(checkPersonId);	
				}
				else
				{
					activePeople.add(checkPersonId);
				}
			}
			bufferedReader.close();
		} // end try
		catch (IOException e) {
			e.printStackTrace();
		}

		System.out.println("removing done");
	}

	private void matchFirstAndLastAct()
	{
		Population population = this.scenario.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();

		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Person eachPerson = this.scenario.getPopulation().getPersons().get(activePeople.get(i));
			Plan eachPlan = eachPerson.getSelectedPlan();
			int NoOfPlans = eachPlan.getPlanElements().size() - 1;
			Activity currentFirstAct = (Activity) eachPlan.getPlanElements().get(0);
			Activity currentLastAct = (Activity) eachPlan.getPlanElements().get(NoOfPlans) ;
			String currentFirstActType = currentFirstAct.getType().toString().trim();
			String currentLastActType = currentLastAct.getType().toString().trim();
			Leg leg = (Leg) eachPlan.getPlanElements().get(1);

			//to make a different acts
			String actType = "";
			Coord newActCoord = new Coord(0, 0);
			Activity newAct = populationFactory.createActivityFromCoord(actType, newActCoord);


			if (!(currentFirstActType.equals(currentLastActType)))
			{
				//if the first act is home make the last act home too
				if (currentFirstActType.equals("1"))
				{
					actType = currentFirstAct.getType();
					newActCoord = new Coord(currentFirstAct.getCoord().getX(), currentFirstAct.getCoord().getY());
					newAct = populationFactory.createActivityFromCoord(actType, newActCoord);

					Activity secondLast = (Activity) eachPlan.getPlanElements().get(NoOfPlans - 2);
					String secondLastActType = secondLast.getType().toString().trim();

					if (currentLastActType.equals("2"))
						currentLastAct.setEndTime(secondLast.getEndTime() + 32400);
					else if (currentLastActType.equals("3"))
						currentLastAct.setEndTime(secondLast.getEndTime() + 18000);
					else if (currentLastActType.equals("4") || currentLastActType.equals("5"))
						currentLastAct.setEndTime(secondLast.getEndTime() + 9000);
					else if (currentLastActType.equals("6"))
					{
						currentLastAct.setEndTime(secondLast.getEndTime() + 1800);
					}
					eachPlan.getPlanElements().add(populationFactory.createLeg(leg.getMode()));
					eachPlan.getPlanElements().add(newAct);	
				}

				// match the first act with last
				else
				{
					actType = currentLastAct.getType();
					newActCoord = new Coord(currentLastAct.getCoord().getX(), currentLastAct.getCoord().getY());
					newAct = populationFactory.createActivityFromCoord(actType, newActCoord);
					eachPlan.getPlanElements().add(0, newAct);
					eachPlan.getPlanElements().add(1, populationFactory.createLeg(leg.getMode()));

					Activity newFirstAct = (Activity) eachPlan.getPlanElements().get(0);
					Activity timeRefAct = (Activity) eachPlan.getPlanElements().get(2);
					String timeRefActType = timeRefAct.getType().toString().trim();

					if (timeRefActType.equals("2"))
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 32400);
					else if (timeRefActType.equals("3"))
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 18000);
					else if (timeRefActType.equals("4") || timeRefActType.equals("5"))
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 9000);
					else if (timeRefActType.equals("6"))
					{
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 1800);
					}
					//if after the process start time of a trip is minus, it will be set to 04:00am which is the earliest travel in vista trips
					if (newFirstAct.getEndTime() < 0)
					{
						System.out.println( eachPerson.getId());
						newFirstAct.setEndTime(14400);
					}
				}	
			}
		}
		System.out.println("matching done");
	}

	public void matchHomeCoord()
	{
		Population population = this.scenario.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();

		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Coord homeCoord = new Coord(0,0);
			Person eachPerson = this.scenario.getPopulation().getPersons().get(activePeople.get(i));
			Plan eachPlan = eachPerson.getSelectedPlan();
			int NoOfPlans = eachPlan.getPlanElements().size();
			for (int j = 0 ; j < NoOfPlans ; j+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(j);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("1"))
					homeCoord = activityToCheck.getCoord();
				break;
			}

			for (int k = 0 ; k < NoOfPlans ; k+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(k);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("1"))
				{
					activityToCheck.setCoord(homeCoord);
				}

			}

		}
	}

	public void matchNumbersAndNames()
	{
		Population population = this.scenario.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();

		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Coord homeCoord = new Coord(0,0);
			Person eachPerson = this.scenario.getPopulation().getPersons().get(activePeople.get(i));
			Plan eachPlan = eachPerson.getSelectedPlan();
			int NoOfPlans = eachPlan.getPlanElements().size();
			for (int j = 0 ; j < NoOfPlans ; j+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(j);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("1")) activityToCheck.setType("Home");
				if (activityToCheckType.equals("2")) activityToCheck.setType("Work");
				if (activityToCheckType.equals("3")) activityToCheck.setType("Education");
				if (activityToCheckType.equals("4")) activityToCheck.setType("Shopping");
				if (activityToCheckType.equals("5")) activityToCheck.setType("Leisure");
				if (activityToCheckType.equals("6")) activityToCheck.setType("Other");
			}

			for (int j = 1 ; j < NoOfPlans ; j+=2)
			{
				Leg legToCheck = (Leg) eachPlan.getPlanElements().get(j);
				String legToCheckMode = legToCheck.getMode().toString().trim() ;
				if (legToCheckMode.equals("1") || legToCheckMode.equals("2") || legToCheckMode.equals("9") || legToCheckMode.equals("3") || legToCheckMode.equals("6")) legToCheck.setMode("car");
				if (legToCheckMode.equals("7") || legToCheckMode.equals("8") || legToCheckMode.equals("10") || legToCheckMode.equals("12")) legToCheck.setMode("pt");
			}
		}
	}

	public void addSubpopulation(){
		Population population = this.scenario.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();

		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Person eachPerson = this.scenario.getPopulation().getPersons().get(activePeople.get(i));
			Id personId = eachPerson.getId();
			Plan eachPlan = eachPerson.getSelectedPlan();
			Leg leg = (Leg) eachPlan.getPlanElements().get(1);
			if (leg.getMode().equals("pt"))
				this.scenario.getPopulation().getPersonAttributes().putAttribute(personId.toString(),"subpopulation", "noCar");
		}
	}

	public void populationWriting(){
		PopulationWriter populationWriter = new PopulationWriter(this.scenario.getPopulation(), this.scenario.getNetwork());
		populationWriter.write("plansCoM.xml.gz");
		//		new ObjectAttributesXmlWriter(this.scenarioPUS.getPopulation().getPersonAttributes()).writeFile("C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/YRsPlansSubAtts.xml");
		
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
	}//end of writing

	private static Point getRandomPointInFeature(Random rnd, SimpleFeature ft) {
		Gbl.assertNotNull(ft);
		Point p = null;
		double x, y;
		// generate a random point until a point inside the feature geometry is found
		do {
			x = ft.getBounds().getMinX() + rnd.nextDouble() * (ft.getBounds().getMaxX() - ft.getBounds().getMinX());
			y = ft.getBounds().getMinY() + rnd.nextDouble() * (ft.getBounds().getMaxY() - ft.getBounds().getMinY());
			p = MGC.xy2Point(x, y);
		} while (!(((Geometry) ft.getDefaultGeometry()).contains(p)));
		return p;
	} 

	public static void main(String[] args) throws IOException {

		MTWPCreateDemand createDemand = new MTWPCreateDemand();
		Config config = ConfigUtils.createConfig();
		Scenario scenario = ScenarioUtils.createScenario(config);
		createDemand.run();
		System.out.println("DONE");

	}



} // end of class
