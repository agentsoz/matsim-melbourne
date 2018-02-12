package io.github.agentsoz.matsimmelbourne.demand.latch;

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
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.*;

/**
 * Class to create population in MatSIM format from LATCH process
 */
public class CreatePopulationFromLatch {

    //************FIXED************* TODO: Add input parameter defaults here

    private static final String PARAM_RUN_MODE = "f";
    private static final String PARAM_OUTPUT_FORMAT = "x";

    //Path for the LATCH file
    private static final String LATCH_PERSONS = "data/census/2011/latch/2018-02-01-files-from-bhagya/AllAgents.csv";
    private final static String SYNTHETIC_HMAP_FILE_PATH =
            "data/census/2011/latch/2018-02-01-files-from-bhagya/Hh-mapped-address.json";
    public static final String DEFAULT_OFNAME = "population-from-latch";
    public static final String XML_OUT = ".xml";
    public static final String ZIPPED_OUT = ".xml.gz";

    private final CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation
            (TransformationFactory.WGS84, "EPSG:28355");

    private final Scenario scenario;
    private final Population population;
    private final PopulationFactory populationFactory;

    private Map<String, Coord> hhs = new HashMap<>();
    private Map<String, String> hhsa1Code = new HashMap<>();

    private String runMode = PARAM_RUN_MODE;
    private StringBuilder oFile = new StringBuilder();
    private int samplePopulation = 0;


    public CreatePopulationFromLatch(String outputDir, String runMode, String samplePopulation, String fileFormat,
                                     String fName) {

        this.runMode = runMode;

        try {
            this.samplePopulation = Integer.parseInt(samplePopulation);
        } catch (NumberFormatException n) {
            System.err.println("Error parsing string : " + n.getCause());
        }

        if (outputDir != null)
            oFile.append(outputDir.endsWith("/") ? outputDir : outputDir + "/");

        if (fName != null)
            oFile.append(fName);
        else
            oFile.append(DEFAULT_OFNAME);

        if (fileFormat != null)
            oFile.append(fileFormat.equals(PARAM_OUTPUT_FORMAT) ? XML_OUT : ZIPPED_OUT);
        else
            oFile.append(XML_OUT);


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

        // ***********FIXED*************FIXME: stop if parsing fails; should say what options are valid and what the
        // defaults are for each
        // See example in https://github.com/agentsoz/jill/blob/master/jill/src/main/java/io/github/agentsoz/jill
        // /util/ArgumentsLoader.java

        Map<String, String> config = LatchUtils.parse(args);

        String oDir = null;
        String rrMode = null;
        String fFormat = null;
        String samplePop = null;
        String fName = null;

        if (config.containsKey(LatchUtils.OUTPUT_DIRECTORY_INDICATOR))
            oDir = config.get(LatchUtils.OUTPUT_DIRECTORY_INDICATOR);

        if (config.containsKey(LatchUtils.RUN_MODE))
            rrMode = config.get(LatchUtils.RUN_MODE);

        if (rrMode.equals("d"))
            samplePop = config.get(LatchUtils.SAMPLE_POPULATION);

        if (config.containsKey(LatchUtils.FILE_FORMAT))
            fFormat = config.get(LatchUtils.FILE_FORMAT);

        if (config.containsKey((LatchUtils.FILE_NAME)))
            fName = config.get(LatchUtils.FILE_NAME);


        CreatePopulationFromLatch createPop = new CreatePopulationFromLatch(oDir, rrMode, samplePop, fFormat, fName);
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

        int cnt = 0;

        try (final FileReader reader = new FileReader(LATCH_PERSONS)) {
            // try-with-resources

            int nullsa1Count = 0;
            List<String> excludedPersons = new ArrayList<>();

            final CsvToBeanBuilder<LatchPopulationRecord> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(LatchPopulationRecord.class);
            builder.withSeparator(',');
            final CsvToBean<LatchPopulationRecord> reader2 = builder.build();
            for (Iterator<LatchPopulationRecord> it = reader2.iterator(); it.hasNext(); ) {
                LatchPopulationRecord record = it.next();


//                In case people are to be added even without a valid sa1code for their household uncomment the lines
//                 below and remove from the if loop
//                Person person = populationFactory.createPerson(Id.createPersonId(record.AgentId));
//                population.addPerson(person);


                //Changed from hhsa1Code.containsKey(record.HouseholdId)
                if (hhsa1Code.containsKey(record.GroupId)) {

                    Person person = populationFactory.createPerson(Id.createPersonId(record.AgentId));
                    population.addPerson(person);

                    // TODO: for now put in a heuristic to calculate the 'LabourForceStatus' attribute for the person
                    person.getAttributes().putAttribute("RelationshipStatus", record.RelationshipStatus);
                    person.getAttributes().putAttribute("Age", record.Age);
                    person.getAttributes().putAttribute("Gender", record.Gender);
//                    person.getAttributes().putAttribute("HouseHoldId", record.HouseholdId);
                    person.getAttributes().putAttribute("HouseHoldId", record.GroupId);

                    //*********FIXED**************FIXME: null sa1code for householdid error in MATSim
//                    person.getAttributes().putAttribute("sa1_7digitcode_2011",
//                            hhsa1Code.get(record.HouseholdId));// hhsa1Code.contains(record.HouseholdId)? hhsa1Code.get
                    person.getAttributes().putAttribute("sa1_7digitcode_2011",
                            hhsa1Code.get(record.GroupId));// hhsa1Code.contains(record.HouseholdId)? hhsa1Code.get

                    // (record.HouseholdId) : "NULL");

                    Plan plan = populationFactory.createPlan();
                    person.addPlan(plan);
                    person.setSelectedPlan(plan);


                    Coord coord = hhs.get(record.GroupId);


                    Activity activity = populationFactory.createActivityFromCoord("At Home", coord);
                    plan.addActivity(activity);

                    //Testing for a small sample of the population
                    //*********** FIXED *********** FIXME: move "30" to a runtime argument
                    if (runMode.equals("d") && cnt >= this.samplePopulation) {
                        break;
                    }
                    //else runs completely
                    cnt++;

                }
                //check for null sa1 coordinate
                else {

                    nullsa1Count++;
                    excludedPersons.add(record.AgentId);
                }

            } // end of for loop

//            int cnt2 = 0;
            System.out.println("TOTAL EXCLUDED PERSONS = " + nullsa1Count);
            System.out.println("##########################");
//            for (String eachPerson : excludedPersons) {
//                cnt2++;
//                System.out.println("P" + cnt2 + " : " + eachPerson);
//            }
        }

//            System.out.println("COUNT : " + cnt);
        PopulationWriter populationWriter = new PopulationWriter(scenario.getPopulation(), scenario.getNetwork());
        populationWriter.write(oFile.toString());

    }

    /**
     * Store the household feature information
     */


    void storeHouseholdFeatures() {

        BufferedReader fr;
        StringBuilder json = new StringBuilder();
        String line;

        try {


            fr = new BufferedReader(new FileReader(SYNTHETIC_HMAP_FILE_PATH));

            while ((line = fr.readLine()) != null)
                json.append(line);

            fr.close();


            Gson gson = new Gson();
            HouseholdsFromJson data = gson.fromJson(json.toString(), HouseholdsFromJson.class);


            int hhcount = 0;
            for (HouseholdFromJson feature : data.features) {
//                String hhIdString = feature.householdID;

                if(feature.householdID == null)
                    continue;

                hhcount++;
                List<String> hhIDStrings = feature.householdID;

//                System.out.println(hhIDStrings.size());
                String hhIdString = hhIDStrings.get(0);
//                System.out.println(hhIdString);

                 List<Float> coords = feature.hgeometry.coordinates;

                if (hhIdString != null) {

                    hhsa1Code.put(hhIdString, feature.hproperty.SA1_7DIG11);
                    Coord cd = new Coord(coords.get(0), coords.get(1));
                    Coord cdTransform = ct.transform(cd);
                    hhs.put(hhIdString,cdTransform);
//                    System.out.println("just stored hh w id=" + hhIdString);
                }
            }

            System.out.println("House-Hold JSON file mapping complete.. "+hhcount);

        } catch (IOException e) {

            e.printStackTrace();
        }

    }


    /**
     * Class to build the records bound by the column header found in the csv file
     */
    @SuppressWarnings("WeakerAccess")
    // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17
    public final static class LatchPopulationRecord {
        @CsvBindByName
        private String AgentId;
        @CsvBindByName
        private String RelationshipStatus;
        @CsvBindByName
        private String Age;
        @CsvBindByName
        private String Gender;
        @CsvBindByName
        private String HouseholdId;
        @CsvBindByName
        private String GroupId;
        @CsvBindByName
        private String homeCoords;
        @CsvBindByName
        private String sa1_7digitcode_2011;
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

                if (count > 500)
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
//        private String householdID;
        private List<String> householdID;

        @Override
        public String toString() {

            return hproperty.toString() + "," + hgeometry.toString() + householdID.toString();
        }
    }

    /*Clas to store information about the property fields in the household JSON address file*/
    private static class HProperty {

        @SerializedName("duplicate_OF")
        @Expose
        private String duplicate_OF;

        @SerializedName("CENSUS_HHSIZE")
        @Expose
        private String census_hhsize;

        @SerializedName("BUILDING_TYPE")
        @Expose
        private String building_type;

        @SerializedName("SA1_MAINCODE_2011")
        @Expose
        private String sa1_maincode_2011;

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


            return EZI_ADD + "," + state + "," + postCode + "," + LGA_Code + "," + locality + "," + add_class + "," +
                    SA1_7DIG11
                    + "," + bedd + "," + strd + "," + tenlld + "," + type;
        }
    }

    /*Class to store the household geometry information*/
    private static class HGeometry {

        @SerializedName("type")
        @Expose
        private String type;

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
