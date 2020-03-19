package au.edu.unimelb.imod.demand.archive;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.population.Activity;
import org.matsim.api.core.v01.population.Leg;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.Plan;
import org.matsim.api.core.v01.population.Population;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.api.core.v01.population.PopulationWriter;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;

/**
 * This version is just doing trips, not chains.
 * 
 * @author (of documentation) kainagel
 *
 */
public class ZahraCreateDemandGmelb {
	
	private Scenario scenario;
	// We need another population, the PUS population
	private Scenario scenarioPUS;
	ArrayList<Id<Person>> activePeople = new ArrayList<Id<Person>>();
	private static final String pusTripsFile =  "C:/Users/znavidikasha/Google Drive/1-PhDProject/GreaterMelbourne/GMelbourneTrips_XY.csv";//"C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/personsTripsAllLmtdWSA.csv";
	private static final String pusPersonsFile = "C:/Users/znavidikasha/Google Drive/1-PhDProject/GreaterMelbourne/GMelbourneTrips_people.csv";//"C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/personsAll.csv";
	CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation(TransformationFactory.WGS84,"EPSG:28355");
	
	String outputFile = "C:/Users/znavidikasha/Google Drive/1-PhDProject/GreaterMelbourne/plansGmelb.xml.gz";
	
	public void run(Scenario scenario) throws IOException {
		this.scenario = scenario;
		this.scenarioPUS = ScenarioUtils.createScenario(ConfigUtils.createConfig());
		this.createPUSPersons();// create all the people and add a plan to each
		this.createPUSPlans();// create the plans according to the trip files (pusTripsFile)
		this.removeNonActivePeople();//remove the people who has no trip
		this.matchFirstAndLastAct();// add a trip to the end or beginning of the plan to match the first and last activity to have a tour based plan
		this.matchHomeCoord(); //since in adding the activities the coordinates have been randomised in for each destination, agents have different home locations, this method is need to set all the home location to a single one. 
		this.matchNumbersAndNames();// all the destinations' and modes' names are digits, this just make them words (e.g. mode=2 -->mode = car)
		this.addSubpopulation();
		this.populationWriting();
	}

	private void createPUSPersons() {
		/*
		 * For convenience and code readability store population and population factory in a local variable 
		 */
		Population population = this.scenarioPUS.getPopulation();   
		PopulationFactory populationFactory = population.getFactory();
		
		/*
		 * Read the PUS file
		 */
		try {
			BufferedReader bufferedReader = new BufferedReader(new FileReader(pusPersonsFile));
			bufferedReader.readLine(); //skip header
			
			int index_personId = 3;

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
		/*
		 * For convenience and code readability store population and population factory in a local variable 
		 */
		Population population = this.scenarioPUS.getPopulation();   
		PopulationFactory populationFactory = population.getFactory();
		
		
		String[][] parts = ZahraUtility.Data(79870, 73, pusTripsFile);
		
		
		int index_personId = 3;
		int index_xCoordOrigin = 68;
		int index_yCoordOrigin = 69;
		int index_xCoordDestination = 70;
		int index_yCoordDestination = 71;
//		int index_activityDuration = 31;
		int index_mode = 27;
		int index_activityType = 20;
		int index_activityEndTime = 72;
		int index_Origin = 12;
		
		Id<Person> previousPerson = null;

		for (int i = 1 ; i <parts.length -1;  ++i ) 
		{

			Id<Person> personId = Id.create(parts[i][index_personId].trim(), Person.class);
			Person person = population.getPersons().get(personId);
			//setting a person's subpopulation
//			this.scenarioPUS.getPopulation().getPersonAttributes().putAttribute(personId.toString(),"subpopulation", "one");
//			this.scenarioPUS.getPopulation().getPersonAttributes().putAttribute(personId.toString(),"age", 15);
			Plan plan = person.getSelectedPlan();
			/* 
			 * If a new person is read
			 */
			Id<Person> nextPersonId = Id.create(parts[i+1][index_personId].trim(), Person.class);
			if (!personId.equals(previousPerson))  // a new person
			{
				//add the original place
				Coord coordOrigin = ZahraUtility.createRamdonCoord(ct.transform(new Coord( Double.parseDouble(parts[i][index_xCoordOrigin]), Double.parseDouble(parts[i][index_yCoordOrigin]))));
				Activity activity = populationFactory.createActivityFromCoord(parts[i][index_Origin] , coordOrigin);
				activity.setEndTime(Double.parseDouble(parts[i][index_activityEndTime]));
				plan.addActivity(activity);
				
				// and the first travel leg
				String mode = "car";//parts[i][index_mode];
				plan.addLeg(populationFactory.createLeg(mode));

				/*
				 *add the destination
				 */
				Coord coordDestination = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[i][index_xCoordDestination]), Double.parseDouble(parts[i][index_yCoordDestination]))));				
				String activityType = parts[i][index_activityType].trim();
				Activity activity1 = populationFactory.createActivityFromCoord(activityType, coordDestination);
//				Double duration = Double.parseDouble(parts[i][index_activityDuration]);
				if (personId.equals(nextPersonId))
					activity1.setEndTime(Double.parseDouble(parts[i+1][index_activityEndTime]));
				plan.addActivity(activity1);

			}
			else // previous person
			{ 
				// if it's not the last activity of the person
				if (personId.equals(nextPersonId))  
				{
					/*
					 * Add a leg from previous location to this location with the given mode
					 */
					Leg mode = (Leg) plan.getPlanElements().get(1);
					plan.addLeg(mode);

					/*
					 * Add activity given its type.
					 */
					Coord coordDestination = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[i][index_xCoordDestination]), Double.parseDouble(parts[i][index_yCoordDestination]))));				
					String activityType = parts[i][index_activityType].trim();
					Activity activity = populationFactory.createActivityFromCoord(activityType, coordDestination);
//					Double duration = Double.parseDouble(parts[i][index_activityDuration]);
					activity.setEndTime(Double.parseDouble(parts[i + 1][index_activityEndTime]));
					plan.addActivity(activity);
				}
				else //if it's the last activity of the person
				{
					/*
					 * Add a leg from previous location to this location with the given mode
					 */
					Leg mode = (Leg) plan.getPlanElements().get(1);
					plan.addLeg(mode);

					/*
					 * Add activity given its type.
					 */
					Coord coordDestination = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[i][index_xCoordDestination]), Double.parseDouble(parts[i][index_yCoordDestination]))));				
					String activityType = parts[i][index_activityType].trim();
					Activity activity = populationFactory.createActivityFromCoord(activityType, coordDestination);
//					Double duration = Double.parseDouble(parts[i][index_activityDuration]);
					plan.addActivity(activity);
				}
				
			}
			previousPerson = personId;			
		} // end of for loop
		
		//// ======= the last activity of the last person should be added separately due to the i + 1 in the code=======
		Id<Person> personId = Id.create(parts[parts.length -1][index_personId], Person.class);
		Person person = population.getPersons().get(personId);
		Plan plan = person.getSelectedPlan();
		System.out.println(parts.length);
		
		//if new person
		if (!personId.equals(previousPerson))  // a new person
		{
			//add the original place  
			Coord coordOrigin = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[parts.length - 1][index_xCoordOrigin]), Double.parseDouble(parts[parts.length - 1][index_yCoordOrigin]))));
			Activity activity = populationFactory.createActivityFromCoord(parts[parts.length - 1][index_Origin] , coordOrigin);
			activity.setEndTime(Double.parseDouble(parts[parts.length - 1][index_activityEndTime]));
			plan.addActivity(activity);
			
			// and the first travel
			String mode = "car";//parts[parts.length - 1][index_mode];
			plan.addLeg(populationFactory.createLeg(mode));

			/*
			 * Add activity given its type.
			 */
			Coord coordDestination = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[parts.length - 1][index_xCoordDestination]), Double.parseDouble(parts[parts.length - 1][index_yCoordDestination]))));				
			String activityType = parts[parts.length - 1][index_activityType].trim();

			Activity activity1 = populationFactory.createActivityFromCoord(activityType, coordDestination);
//			Double duration = Double.parseDouble(parts[parts.length - 1][index_activityDuration]);
			plan.addActivity(activity1);
		}
		
		//if not new person
		/*
		 * Add a leg from previous location to this location with the given mode
		 */
		Leg mode = (Leg) plan.getPlanElements().get(1);
		plan.addLeg(mode);

		/*
		 * Add activity given its type.
		 */
		Coord coordDestination = ZahraUtility.createRamdonCoord(ct.transform(new Coord(Double.parseDouble(parts[parts.length - 1][index_xCoordDestination]), Double.parseDouble(parts[parts.length - 1][index_yCoordDestination]))));				
		String activityType = parts[parts.length - 1][index_activityType].trim();
		Activity activity = populationFactory.createActivityFromCoord(activityType, coordDestination);
//		Double duration = Double.parseDouble(parts[parts.length - 1][index_activityDuration]);
		plan.addActivity(activity);
		//===============================================================================
		
		System.out.println("plnas done");
	}// end of createPUSPlans
	
	///****************remove people with no plans***************************
	private void removeNonActivePeople(){
		try {
			BufferedReader bufferedReader = new BufferedReader(new FileReader(pusPersonsFile));
			bufferedReader.readLine(); //skip header
			
			int index_personId = 3;

			String line;
			while ((line = bufferedReader.readLine()) != null) {
				String parts[] = line.split(",");
				
				Id<Person> checkPersonId = Id.create(parts[index_personId].trim(), Person.class);
	
				if (this.scenarioPUS.getPopulation().getPersons().get(checkPersonId).getSelectedPlan().getPlanElements().isEmpty())
				{
					this.scenarioPUS.getPopulation().getPersons().remove(checkPersonId);	
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
	
	public void matchFirstAndLastAct()
	{
		Population population = this.scenarioPUS.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();
		
		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Person eachPerson = this.scenarioPUS.getPopulation().getPersons().get(activePeople.get(i));
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
				if (currentFirstActType.equals("2"))
				{
					actType = currentFirstAct.getType();
					newActCoord = new Coord(currentFirstAct.getCoord().getX(), currentFirstAct.getCoord().getY());
					newAct = populationFactory.createActivityFromCoord(actType, newActCoord);
					
					Activity secondLast = (Activity) eachPlan.getPlanElements().get(NoOfPlans - 2);
					String secondLastActType = secondLast.getType().toString().trim();
					
					if (currentLastActType.equals("3"))//work
						currentLastAct.setEndTime(secondLast.getEndTime() + 32400);
					else if (currentLastActType.equals("5")) // education
						currentLastAct.setEndTime(secondLast.getEndTime() + 18000);
					else if (currentLastActType.equals("4") || currentLastActType.equals("8") || currentLastActType.equals("9")) //leisure
						currentLastAct.setEndTime(secondLast.getEndTime() + 10800);
					else if (currentLastActType.equals("6")) //shopping
						currentLastAct.setEndTime(secondLast.getEndTime() + 9000);
					else if (currentLastActType.equals("1") || currentLastActType.equals("7") || currentLastActType.equals("10")) //other
						currentLastAct.setEndTime(secondLast.getEndTime() + 3600);
					
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
					
					if (timeRefActType.equals("3"))//work
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 32400);
					else if (timeRefActType.equals("5"))//education
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 18000);
					else if (timeRefActType.equals("4") || timeRefActType.equals("8") || timeRefActType.equals("9"))//leisure
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 10800);
					else if (timeRefActType.equals("6"))//shopping
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 9000);
					else if (timeRefActType.equals("1") || timeRefActType.equals("7") || timeRefActType.equals("10"))
						newFirstAct.setEndTime(timeRefAct.getEndTime() - 3600);

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
		Population population = this.scenarioPUS.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();
		
		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Coord homeCoord = new Coord(0,0);
			Person eachPerson = this.scenarioPUS.getPopulation().getPersons().get(activePeople.get(i));
			Plan eachPlan = eachPerson.getSelectedPlan();
			int NoOfPlans = eachPlan.getPlanElements().size();
			for (int j = 0 ; j < NoOfPlans ; j+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(j);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("2"))
					homeCoord = activityToCheck.getCoord();
				break;
			}
			
			for (int k = 0 ; k < NoOfPlans ; k+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(k);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("2"))
				{
					activityToCheck.setCoord(homeCoord);
				}
					
			}
			
		}
	}
	
	public void matchNumbersAndNames()
	{
		Population population = this.scenarioPUS.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();
		
		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Coord homeCoord = new Coord(0,0);
			Person eachPerson = this.scenarioPUS.getPopulation().getPersons().get(activePeople.get(i));
			Plan eachPlan = eachPerson.getSelectedPlan();
			int NoOfPlans = eachPlan.getPlanElements().size();
			for (int j = 0 ; j < NoOfPlans ; j+=2)
			{
				Activity activityToCheck = (Activity) eachPlan.getPlanElements().get(j);
				String activityToCheckType = activityToCheck.getType().toString().trim();
				if (activityToCheckType.equals("2")) activityToCheck.setType("Home");
				if (activityToCheckType.equals("3")) activityToCheck.setType("Work");
				if (activityToCheckType.equals("5")) activityToCheck.setType("Education");
				if (activityToCheckType.equals("6")) activityToCheck.setType("Shopping");
				if (activityToCheckType.equals("4") || activityToCheckType.equals("8") || activityToCheckType.equals("9")) activityToCheck.setType("Leisure");
				if (activityToCheckType.equals("1") || activityToCheckType.equals("7") || activityToCheckType.equals("10")) activityToCheck.setType("Other");
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
		Population population = this.scenarioPUS.getPopulation(); 
		PopulationFactory populationFactory = population.getFactory();
		
		for (int i = 0 ; i < activePeople.size() ; i++)
		{
			Person eachPerson = this.scenarioPUS.getPopulation().getPersons().get(activePeople.get(i));
			Id personId = eachPerson.getId();
			Plan eachPlan = eachPerson.getSelectedPlan();
			Leg leg = (Leg) eachPlan.getPlanElements().get(1);
			if (leg.getMode().equals("pt"))
				this.scenarioPUS.getPopulation().getPersons().get(personId.toString()).getAttributes().putAttribute("subpopulation", "noCar");
		}
	}
	
	public void populationWriting(){
		PopulationWriter populationWriter = new PopulationWriter(this.scenarioPUS.getPopulation(), this.scenario.getNetwork());
		populationWriter.write(outputFile);
//		new ObjectAttributesXmlWriter(this.scenarioPUS.getPopulation().getPersonAttributes()).writeFile("C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/YRsPlansSubAtts.xml");
		System.out.println("writing done");
	}//end of writing
	
	
} // end of class
