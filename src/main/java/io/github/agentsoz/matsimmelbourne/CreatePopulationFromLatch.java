package io.github.agentsoz.matsimmelbourne;

import com.google.gson.Gson;
import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.population.*;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.households.Households;
import org.matsim.households.HouseholdsFactory;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Class to create population in MatSIM format from LATCH process
 */
public class CreatePopulationFromLatch {

    //Path for the LATCH file
    private static final String LATCH_PERSONS = "data/census/2011/latch/2017-11-30-files-from-bhagya/AllAgents.csv";
    private final static String SYNTHETIC_HMAP_FILE_PATH = "data/census/2011/latch/2017-11-30-files-from-bhagya/Hh-mapped-address.json";
    private final static String OUTPUT_POPULATION_FILE = "population-from-latch.xml";
    private final Scenario scenario;
    private final Population population;
    private final PopulationFactory populationFactory;
	private Map<String,Coord> hhs = new HashMap<>() ;
	private Map<String,String>hhsa1Code = new HashMap<>();

	public CreatePopulationFromLatch(){
        scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig());
        population = scenario.getPopulation();
        populationFactory = population.getFactory();


    }
    /**
     * Main method
     *
     * @param args
     * @throws IOException
     */
    public static void main(String[] args) throws IOException {
		Map<String, String> config = MMUtils.parse(args);

		CreatePopulationFromLatch createPop = new CreatePopulationFromLatch();
		createPop.storeHouseholdFeatures();
        createPop.createPopulation();

    }

    /**
     * Method to read the LATCH Persons file, creates a record for each person
     * and creates a MatSIM output with each attribute in the record for the corresponding person
     *
     * @throws IOException
     */
    void createPopulation() throws IOException {



        try (final FileReader reader = new FileReader(LATCH_PERSONS)) {
            // try-with-resources

            int cnt = 0;

            final CsvToBeanBuilder<LatchRecord> builder = new CsvToBeanBuilder<>(reader);
                builder.withType(LatchRecord.class);
                builder.withSeparator(',');
                final CsvToBean<LatchRecord> reader2 = builder.build();
                for (Iterator<LatchRecord> it = reader2.iterator(); it.hasNext(); ) {
                    LatchRecord record = it.next();
//				System.out.println( "AgentId=" + record.AgentId + "; rs=" + record.RelationshipStatus ) ;

                Person person = populationFactory.createPerson(Id.createPersonId(record.AgentId));
                population.addPerson(person);

                person.getAttributes().putAttribute("RelationshipStatus", record.RelationshipStatus);
                person.getAttributes().putAttribute("Age", record.Age);
                person.getAttributes().putAttribute("Gender", record.Gender);
                person.getAttributes().putAttribute("HouseHoldId", record.HouseHoldId);
                person.getAttributes().putAttribute("sa1_7digitcode_2011",hhsa1Code.get(record.HouseHoldId));

                Plan plan = populationFactory.createPlan();
                person.addPlan(plan);
                person.setSelectedPlan(plan);

//                Household hh = scenario.getHouseholds().getHouseholds().get( Id.create( record.HouseHoldId, Household.class) ) ;
//                Coord coord = (Coord) hh.getAttributes().getAttribute("Coord");
				Coord coord = hhs.get( record.HouseHoldId ) ;

				person.getAttributes().putAttribute("homeCoords", Double.toString(coord.getX())+","+Double.toString(coord.getY()));

                    Activity activity = populationFactory.createActivityFromCoord( "home", coord ) ;
                plan.addActivity(activity);

                //TO limit the output for testing purpose
                if (cnt >= 30) {
                    break;
                }
                cnt++;

            }

        } // end of for loop

        PopulationWriter populationWriter = new PopulationWriter(scenario.getPopulation(), scenario.getNetwork());
        populationWriter.write(OUTPUT_POPULATION_FILE);

    }

    /**
     * Store the household feature information
     */
    void storeHouseholdFeatures() {

        BufferedReader fr;
        StringBuilder json = new StringBuilder();
        String line;

        Households households = scenario.getHouseholds();
        HouseholdsFactory hf = households.getFactory();

        try {


            fr = new BufferedReader(new FileReader(SYNTHETIC_HMAP_FILE_PATH));

            while ((line = fr.readLine()) != null)
                json.append(line);

            fr.close();

            //System.out.println(json);

            //Testing String for JSON file storage as Java Object
            //Original file is large about 43 MB takes considerable time
//            json = "{\"features\":[{\"properties\":{\"EZI_ADD\":\"12 WATERLOO ROAD NORTHCOTE 3070\",\"STATE\":\"VIC\",\"POSTCODE\":\"3070\",\"LGA_CODE\":\"316\",\"LOCALITY\":\"NORTHCOTE\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2111138\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[324058.8753037447,5817187.2590698935]},\"HOUSEHOLD_ID\":\"11604\"},{\"properties\":{\"EZI_ADD\":\"38 MACORNA STREET WATSONIA NORTH 3087\",\"STATE\":\"VIC\",\"POSTCODE\":\"3087\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"WATSONIA NORTH\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120407\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[331160.92976421374,5825765.298372125]},\"HOUSEHOLD_ID\":\"64297\"},{\"properties\":{\"EZI_ADD\":\"27 DURHAM STREET EAGLEMONT 3084\",\"STATE\":\"VIC\",\"POSTCODE\":\"3084\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"EAGLEMONT\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120112\",\"BEDD\":\"4 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[329627.89563218964,5818811.241577283]},\"HOUSEHOLD_ID\":\"49237\"},{\"properties\":{\"EZI_ADD\":\"30 KILLERTON CRESCENT HEIDELBERG WEST 3081\",\"STATE\":\"VIC\",\"POSTCODE\":\"3081\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"HEIDELBERG WEST\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2119902\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[327226.127194053,5821253.361783082]},\"HOUSEHOLD_ID\":\"38295\"},{\"properties\":{\"EZI_ADD\":\"5/68 YARRA STREET HEIDELBERG 3084\",\"STATE\":\"VIC\",\"POSTCODE\":\"3084\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"HEIDELBERG\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2119810\",\"BEDD\":\"2 bedroom\",\"STRD\":\"Flats or units (3 storeys or less)\",\"TENLLD\":\"Private Renter\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[329383.2924766755,5819340.600254489]},\"HOUSEHOLD_ID\":\"34846\"},{\"properties\":{\"EZI_ADD\":\"35A CAMERON STREET RESERVOIR 3073\",\"STATE\":\"VIC\",\"POSTCODE\":\"3073\",\"LGA_CODE\":\"316\",\"LOCALITY\":\"RESERVOIR\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120829\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[323503.89143659646,5822569.286676848]},\"HOUSEHOLD_ID\":\"100800\"}]}";

            Gson gson = new Gson();
			HouseholdsFromJson data = gson.fromJson(json.toString(), HouseholdsFromJson.class);

            for ( HouseholdFromJson feature : data.features ) {
                String hhIdString = feature.householdID;
                List<Float> coords = feature.hgeometry.coordinates;

//                Id<Household> hhId = Id.create( hhIdString, Household.class ) ;
//                Household hh = hf.createHousehold(hhId);;
//                households.getHouseholds().put( hhId, hh ) ;
//
//                hh.getAttributes().putAttribute("Coord", new Coord( coords.get(0), coords.get(1) ) ) ;

				if ( hhIdString!=null ) {

				    hhsa1Code.put(hhIdString,feature.hproperty.SA1_7DIG11);
				    hhs.put(hhIdString, new Coord(coords.get(0), coords.get(1)));
					System.out.println("just stored hh w id=" + hhIdString);
				}
            }

//            System.out.println(data.toString());
            System.out.println("House-Hold JSON file mapping complete..");


//       System.out.println(data.toString());
        } catch (IOException e) {

            e.printStackTrace();
        }

    }


    /**
     *
     */
    void createTrip(String HouseHoldId) {



    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    @SuppressWarnings("WeakerAccess") // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17
	public final static class LatchRecord {
		@CsvBindByName private String AgentId;
        @CsvBindByName private String RelationshipStatus;
        @CsvBindByName private String Age;
        @CsvBindByName private String Gender;
        @CsvBindByName private String HouseHoldId;
        @CsvBindByName private String homeCoords;
        @CsvBindByName private String sa1_7digitcode_2011;
	}


    /*
* Class to store data from the house hold mapped address JSON file created from the LATCH algorithm
* */
    public static class HouseholdsFromJson {

        @SerializedName("features")
        @Expose
        private List<HouseholdFromJson> features;

        @Override
        public String toString() {

            int count = 0;
            StringBuilder s = new StringBuilder();

            for (HouseholdFromJson hf : features) {
                count++;
                s.append(hf.toString()).append("\n");

                if(count>500)
                    break;
            }
            return s.toString();
        }
    }

    /*Class to store different features from the House hold mapped address JSON file
    * */
    private static class HouseholdFromJson {

        @SerializedName("properties")
        @Expose
        private HProperty hproperty;

        @SerializedName("geometry")
        @Expose
        private HGeometry hgeometry;

        @SerializedName("HOUSEHOLD_ID")
        @Expose
        private String householdID;

        @Override
        public String toString() {

            return hproperty.toString() + "," + hgeometry.toString() + householdID;
        }
    }

    /*Clas to store information about the property fields in the household JSON address file*/
    private static class HProperty {

        @SerializedName("EZI_ADD")
        @Expose
        private String EZI_ADD;
        @SerializedName("STATE")
        @Expose
        private String state;
        @SerializedName("POSTCODE")
        @Expose
        private String postCode;
        @SerializedName("LGA_CODE")
        @Expose
        private String LGA_Code;
        @SerializedName("LOCALITY")
        @Expose
        private String locality;
        @SerializedName("ADD_CLASS")
        @Expose
        private String add_class;
        @SerializedName("SA1_7DIG11")
        @Expose
        private String SA1_7DIG11;
        @SerializedName("BEDD")
        @Expose
        private String bedd;
        @SerializedName("STRD")
        @Expose
        private String strd;
        @SerializedName("TENLLD")
        @Expose
        private String tenlld;
        @SerializedName("TYPE")
        @Expose
        private String type;

        @Override
        public String toString() {


            return EZI_ADD + "," + state + "," + postCode + "," + LGA_Code + "," + locality + "," + add_class + "," + SA1_7DIG11
                    + "," + bedd + "," + strd + "," + tenlld + "," + type;
        }
    }

    /*Class to store the household geometry information*/
    private static class HGeometry {

        @SerializedName("coordinates")
        @Expose
        private List<Float> coordinates;

        @Override
        public String toString() {

            StringBuilder s = new StringBuilder();
            for (Float hc : coordinates)
                s.append(Float.toString(hc)).append(",");

            return s.toString();
        }
    }


}
