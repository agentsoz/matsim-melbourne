package io.github.agentsoz.matsimmelbourne.demand.latch;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvBindByPosition;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import io.github.agentsoz.matsimmelbourne.utils.MMUtils;
import org.apache.log4j.Logger;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.locationtech.jts.geom.Point;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.DefaultActivityTypes;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.Activity;
import org.matsim.api.core.v01.population.Leg;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.api.core.v01.population.PopulationWriter;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

public class AssignTripsToPopulationv1 {

    private static final Logger log = Logger.getLogger(AssignTripsToPopulation.class);
    public static final String[] FILE_NAMES = {

            "NORTHCOTE", "data/census/2011/mtwp/2018-02-16-mtwp-files/NORTHCOTE_PCHAR_POW_MTWP.csv",
            "VIEWBANK-YALLAMBIE", "data/census/2011/mtwp/2018-02-16-mtwp-files/VIEWBANK-YALLAMBIE_PCHAR_POW_MTWP.csv",
            "WATSONIA", "data/census/2011/mtwp/2018-02-16-mtwp-files/WATSONIA_PCHAR_POW_MTWP.csv",
            "MONTMORENCY-BRIARHILL", "data/census/2011/mtwp/2018-02-16-mtwp-files/MONTMORENCY" +
            "-BRIARHILL_PCHAR_POW_MTWP.csv",
            "BUNDOORA-EAST", "data/census/2011/mtwp/2018-02-16-mtwp-files/BUNDOORA-EAST_PCHAR_POW_MTWP.csv",
            "IVANHOE-EAST", "data/census/2011/mtwp/2018-02-16-mtwp-files/IVANHOE-EAST_PCHAR_POW_MTWP.csv",
            "ALPHINGTON", "data/census/2011/mtwp/2018-02-16-mtwp-files/ALPHINGTON_PCHAR_POW_MTWP.csv",
            "IVANHOE", "data/census/2011/mtwp/2018-02-16-mtwp-files/IVANHOE_PCHAR_POW_MTWP.csv",
            "HEIDELBERG-WEST", "data/census/2011/mtwp/2018-02-16-mtwp-files/HEIDELBERG-WEST_PCHAR_POW_MTWP.csv",
            "HEIDELBERG-ROSANNA", "data/census/2011/mtwp/2018-02-16-mtwp-files/HEIDELBERG-ROSANNA_PCHAR_POW_MTWP.csv",
            "GREENSBOROUGH", "data/census/2011/mtwp/2018-02-16-mtwp-files/GREENSBOROUGH_PCHAR_POW_MTWP.csv",
            "THORNBURY", "data/census/2011/mtwp/2018-02-16-mtwp-files/THORNBURY_PCHAR_POW_MTWP.csv"

    };

    public static final String[] INIT_POPULATION = {

            "--output-dir", ".",
            "--run-mode", "f",
            "--file-format", "z",

    };

    private Record record;
    private MTWPRecord mtwpRecord;
    private final Config config;
    private final Scenario scenario;
    private final PopulationFactory pf;

    Map<String, String> sa2NameFromSa1Id;
    Map<String, SimpleFeature> featureMap;
    Map<String, List<PersonChar>> sa2PersonCharGroupsLatch = new HashMap<>();
    //    Map<String, List<PersonChar>> sa2PersonCharGroupsCensus = new HashMap<>();
    Map<String, List<PersonChar>> sa2PersonCharGroupsMTWP = new HashMap<>();


    //2016 correspondence file below
    //    private final static String CORRESPONDENCE_FILE =
//            "data/census/2016/correspondences/2018-01-24-1270055001_sa2_sa1_2016_mapping_aust_shape/SA1_2016_AUST
// .csv";

    //Still using 2011 correspondence as the latch data and households have been mapped using 2011 data
    //2016 data is available in the respective folder
    private final static String CORRESPONDENCE_FILE =
            "data/census/2011/correspondences/2017-12-06-1270055001_sa2_sa1_2011_mapping_aust_shape/SA1_2011_AUST.csv";
    private final static String INPUT_CONFIG_FILE = "population-from-latch.xml.gz";
    private final static String OUTPUT_TRIPS_FILE = "population-with-home-work-trips.xml.gz";
    //    private final static String SA2_EMPSTATS_FILE = "data/census/2011/population/VIC -
    // SEXP_AGE5P_LFSP_UR_2011.csv";
    private static String MTWP_FILE = "";
    private final static String ZONES_FILE =
            "data/census/2011/shp/2017-12-06-1270055001_sa2_2011_aust_shape/SA2_2011_AUST" +
                    ".shp";

    private enum AgeGroups {u15, b15n24, b25n39, b40n54, b55n69, b70n84, b85n99, over100}

    private static final Map<String, String> ageCategoryToAgeRange;

    static {
        ageCategoryToAgeRange = new HashMap<String, String>();
        ageCategoryToAgeRange.put("u15", "0-14");
        ageCategoryToAgeRange.put("b15n24", "15-24");
        ageCategoryToAgeRange.put("b25n39", "25-39");
        ageCategoryToAgeRange.put("b40n54", "40-54");
        ageCategoryToAgeRange.put("b55n69", "55-69");
        ageCategoryToAgeRange.put("b70n84", "70-84");
        ageCategoryToAgeRange.put("b85n99", "85-99");
        ageCategoryToAgeRange.put("over100", "100 years and over");

    }

    private final CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation
            (TransformationFactory.WGS84, "EPSG:28355");
    //    private final static String EMP_PART_TIME = "Employed, worked part-time";
//    private final static String EMP_FULL_TIME = "Employed, worked full-time";
//    private final static String TOTAL_POP = "Total";
    private Random rnd;


    /*Constructor for class*/
    public AssignTripsToPopulationv1() {

        config = ConfigUtils.createConfig();

        config.plans().setInputFile(INPUT_CONFIG_FILE);


        scenario = ScenarioUtils.loadScenario(config);
        pf = scenario.getPopulation().getFactory();

    }

    public static void main(String args[]) {

        createPopulationFromLatch();
        AssignTripsToPopulationv1 atp = new AssignTripsToPopulationv1();
        atp.readCorrespondences();
        atp.storeSyntheticPersonCharGroups();


        for (int i = 0; i < FILE_NAMES.length; i = i + 2) {

            MTWP_FILE = FILE_NAMES[i + 1];

            try {
                log.info("Reading SA2 - " + FILE_NAMES[i]);
                atp.readMTWPFile();

            } catch (IOException ii) {
                log.warn("readMTWPFile() : " + ii.getLocalizedMessage());

            }
        }

        atp.storeMTWPProportionsInLatch();
        atp.readShapefile();
        atp.assignTripsToLatchPopulation();

        log.info("Assigning trips to population finished");
        log.info("--------------------------------------");


    }

    //Read population file

    /*
* Method to create the population file using the files generated from the LATCH algorithm
* if the file has not been created already
*
* */
    private static void createPopulationFromLatch() {

        File fOpen = new File(INPUT_CONFIG_FILE);

        if (!fOpen.exists()) {

            log.warn(INPUT_CONFIG_FILE + "does not exist");
            log.info("Creating population from latch..");

            try {

                CreatePopulationFromLatch.main(INIT_POPULATION);

            } catch (FileNotFoundException ee) {

                log.error("File not found : " + INPUT_CONFIG_FILE + ee.getLocalizedMessage());

            } catch (IOException i) {

                log.error("Error creating file : " + INPUT_CONFIG_FILE + i.getLocalizedMessage());

            }
        }
    }

    /*
    * Method to bin age into enum age-range groups
    * */
    public AgeGroups binAgeIntoCategory(String age) {
        int ageInt = Integer.parseInt(age);

        if (ageInt >= 15 && ageInt <= 24)
            return AgeGroups.b15n24;
        else if (ageInt >= 25 && ageInt <= 39)
            return AgeGroups.b25n39;
        else if (ageInt >= 40 && ageInt <= 54)
            return AgeGroups.b40n54;
        else if (ageInt >= 55 && ageInt <= 69)
            return AgeGroups.b55n69;
        else if (ageInt >= 70 && ageInt <= 84)
            return AgeGroups.b70n84;
        else if (ageInt >= 85 && ageInt <= 99)
            return AgeGroups.b85n99;
        else if (ageInt > 100)
            return AgeGroups.over100;

        return AgeGroups.u15;
    }

    /*
    * Method to bin age range strings from the mtwp files into the enum age-range groups
    * */
    public AgeGroups binAgeRangeIntoCategory(String ageRange) {

        if (ageRange.equals("0-14"))
            return AgeGroups.u15;
        else if (ageRange.equals("15-24"))
            return AgeGroups.b15n24;
        else if (ageRange.equals("25-39"))
            return AgeGroups.b25n39;
        else if (ageRange.equals("40-54"))
            return AgeGroups.b40n54;
        else if (ageRange.equals("55-69"))
            return AgeGroups.b55n69;
        else if (ageRange.equals("70-84"))
            return AgeGroups.b70n84;
        else if (ageRange.equals("85-99"))
            return AgeGroups.b85n99;
        else if (ageRange.equals("100 years and over"))
            return AgeGroups.over100;

        return AgeGroups.u15;
    }


    /**
     * Method to read the look up correspondence file
     * and maps the sa1 7 digit codes (2011) to the corresponding sa2 names (2016)
     */
    private void readCorrespondences() {

        sa2NameFromSa1Id = new HashMap<String, String>();

        try (final BufferedReader reader = new BufferedReader(new FileReader(CORRESPONDENCE_FILE))) {

            log.info("Parsing Correspondences file..");

            final CsvToBeanBuilder<SAMap> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(SAMap.class);
            builder.withSeparator(',');

            final CsvToBean<SAMap> reader2 = builder.build();
            for (Iterator<SAMap> it = reader2.iterator(); it.hasNext(); ) {
                SAMap saMap = it.next();

                sa2NameFromSa1Id.put(saMap.SA1_7DIGITCODE_2011, saMap.SA2_NAME_2011);
            }
        } catch (FileNotFoundException f) {

            log.error("File not found : " + CORRESPONDENCE_FILE + f.getLocalizedMessage());

        } catch (IOException e) {

            log.error("Error parsing file : " + CORRESPONDENCE_FILE + e.getLocalizedMessage());

        }
    }


    /**
     * Method to store the number of synthetic person groups for each SA2 location
     */
    public void storeSyntheticPersonCharGroups() {

        log.info("Storing person characteristic groups per SA2..");

        sa2PersonCharGroupsLatch = new HashMap<>();
        for (Person person : scenario.getPopulation().getPersons().values()) {

            String sa1Id = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");
            // (sa1 code of home location)

            Gbl.assertNotNull(sa1Id);

            // get corresponding sa2name (which comes from the correspondences file):
            String sa2name = this.sa2NameFromSa1Id.get(sa1Id);

            Gbl.assertNotNull(sa2name);

            if (!sa2PersonCharGroupsLatch.containsKey(sa2name)) {

                //create new sa2 named list of person characteristic groups
                sa2PersonCharGroupsLatch.put(sa2name, new ArrayList<PersonChar>());

            }

            //Retrieve list of Person Characteristic groupings
            List<PersonChar> pCharGroups = sa2PersonCharGroupsLatch.get(sa2name);

            String gender = (String) person.getAttributes().getAttribute("Gender");
            String age = (String) person.getAttributes().getAttribute("Age");
            AgeGroups ageGroups = binAgeIntoCategory(age);
            String relStatus = (String) person.getAttributes().getAttribute("RelationshipStatus");

            PersonChar pChar = new PersonChar(gender, ageGroups.name(), relStatus);

            boolean pCharFound = false;
            for (PersonChar eachPChar : pCharGroups) {
                if (eachPChar.equals(pChar)) {
                    pCharFound = true;
                    eachPChar.pCharCount++;
                    break;
                }
            }
            if (pCharFound == false)
                pCharGroups.add(pChar);


        }

        printLatchPersonStats("Latch_population_statistics.txt");
    }

    public void printLatchPersonStats(String fileName) {
        //Below prints out number of person groups in each sa2

        try {
            BufferedWriter fw = new BufferedWriter(new FileWriter(fileName));

            System.out.println();
            fw.newLine();

            for (String sa2Name : sa2PersonCharGroupsLatch.keySet()) {

//                System.out.println("SA2 NAME : " + sa2Name);
//                System.out.println("......................");

                fw.write("SA2 NAME : " + sa2Name);
                fw.newLine();
                fw.write("......................");
                fw.newLine();

                int total = 0;
                for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa2Name)) {
                    StringBuilder str = new StringBuilder();
                    str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
                            pChar.pCharCount);
//                    System.out.println(str);
                    fw.write(str.toString());
                    fw.newLine();

                    total += pChar.pCharCount;
                }

//                System.out.println("TOTAL : " + total);
//                System.out.println("......................");

                fw.write("TOTAL : " + total);
                fw.newLine();
                fw.write("......................");
                fw.newLine();
            }

            fw.close();

        } catch (IOException e) {
            e.printStackTrace();
        }

    }


    /*
    * Method to read the census mtwp file and store the workforce number per person characteristic, labour force
    * status and SA2 work location grouping
    * The fraction of the number of working people using a specific mode of transport is calculated out of the total
    * number of people in the labour force status type (working part-time or working full-time)
    * */
    public void readMTWPFile() throws IOException {

        String sa2Name = "";
        String gender = "";
        String ageRange = "";
        String relStatus = "";
        String lfsp = "";
        String sa2Work = "";

        PersonChar pChar = null;
        AgeGroups ageGroups = null;
        int lineCount = 0;

        double totalTrips = 0.;

        double tramTrips = 0.;
        double trainTrips = 0.;
        double busTrips = 0.;
        double ferryTrips = 0.;
        double taxiTrips = 0.;
        double truckTrips = 0.;
        double motorbikeTrips = 0.;
        double otherTrips = 0.;
        double multiModeTrips = 0.;
        double bicycleTrips = 0.;

        double totalCarDrvrTrips = 0.;
        double totalCarPassTrips = 0.;

        try (final BufferedReader reader = new BufferedReader(new FileReader(MTWP_FILE))) {

            log.info("Parsing MTWP file : " + MTWP_FILE);

            while (++lineCount < 12) {
                reader.readLine();
            }

            final CsvToBeanBuilder<MTWPRecord> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(MTWPRecord.class);
            builder.withSeparator(',');

            final CsvToBean<MTWPRecord> reader2 = builder.build();
            for (Iterator<MTWPRecord> it = reader2.iterator(); it.hasNext(); ) {

                mtwpRecord = it.next();

                if (mtwpRecord.sa2Name == null && mtwpRecord.workForce == null)
                    break;

                if (mtwpRecord.sa2Name != null) {
                    sa2Name = mtwpRecord.sa2Name;
                    sa2PersonCharGroupsMTWP.put(sa2Name, new ArrayList<PersonChar>());
                }

                List<PersonChar> pCharGroups = sa2PersonCharGroupsMTWP.get(sa2Name);
                Gbl.assertNotNull(pCharGroups);

                if (mtwpRecord.sex != null)
                    gender = mtwpRecord.sex;

                if (mtwpRecord.age != null) {
                    ageRange = mtwpRecord.age;
                    ageGroups = binAgeRangeIntoCategory(ageRange);
                }
                if (mtwpRecord.relStatus != null) {

                    relStatus = mtwpRecord.relStatus;

                    pChar = new PersonChar(gender, ageGroups.name(), relStatus);
                    pCharGroups.add(pChar);

                }

                if (mtwpRecord.lfsp != null) {

                    lfsp = mtwpRecord.lfsp;
                    pChar.sa2TransportMode.put(lfsp, new HashMap<>());

                }

                if (mtwpRecord.sa2Work != null) {

                    sa2Work = mtwpRecord.sa2Work;
                    pChar.sa2TransportMode.get(lfsp).put(sa2Work, new HashMap<>());

                }

                pChar.sa2TransportMode.get(lfsp).get(sa2Work).put(mtwpRecord.transportMode,
                        Double.parseDouble(mtwpRecord.workForce));

//                if(mtwpRecord.transportMode.equals("Car, as driver") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    totalCarDrvrTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Car, as passenger") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    totalCarPassTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Train") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    trainTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Tram") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    tramTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Bus") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    busTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Ferry") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    ferryTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Taxi") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    taxiTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Motorbike/scooter") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    motorbikeTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Other") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    otherTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Multi-mode") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    multiModeTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Truck") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    truckTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(mtwpRecord.transportMode.equals("Bicycle") && !mtwpRecord.workForce.equals("Total") &&
//                        !mtwpRecord.workForce.equals("TotalMode"))
//                    bicycleTrips += Double.parseDouble(mtwpRecord.workForce);
//
//                if(!mtwpRecord.workForce.equals("Total") && !mtwpRecord.workForce.equals("TotalMode"))
//                    totalTrips += Double.parseDouble(mtwpRecord.workForce);
            }

//            System.out.println("TOTAL TRIPS : "+totalTrips);
//            System.out.println("TOTAL CAR DRIVER TRIPS : "+totalCarDrvrTrips);
//            System.out.println("TOTAL CAR PASSENGER TRIPS : "+totalCarPassTrips);
//            System.out.println("TOTAL TRAIN TRIPS : "+trainTrips);
//            System.out.println("TOTAL TRAM TRIPS : "+tramTrips);
//            System.out.println("TOTAL TAXI TRIPS : "+taxiTrips);
//            System.out.println("TOTAL TRUCK TRIPS : "+truckTrips);
//            System.out.println("TOTAL BUS TRIPS : "+busTrips);
//            System.out.println("TOTAL FERRY TRIPS : "+ferryTrips);
//            System.out.println("TOTAL MOTORBIKE/SCOOTER TRIPS : "+motorbikeTrips);
//            System.out.println("TOTAL MULTI-MODE TRIPS : "+multiModeTrips);
//            System.out.println("TOTAL OTHER TRIPS : "+otherTrips);
//            System.out.println("TOTAL BICYCLE TRIPS : "+bicycleTrips);
        }

//System.out.println();
    }

    /**
     * Store the corresponding proportions for the synthetic population using the census data proportions
     * A fraction of the working synthetic population is assigned a specific transport mode using the proportions
     * from the census mtwp population
     */
    public void storeMTWPProportionsInLatch() {

        String sa2NameUR = "";
        log.info("Storing MTWP proportions in Latch Data");

        List<PersonChar> mtwpCharList = null;
        List<PersonChar> latchPCharList = null;
        boolean sa2NameFound = false;

        for (String sa2NameMTWP : sa2PersonCharGroupsMTWP.keySet()) {
            for (String sa2NameLatch : sa2PersonCharGroupsLatch.keySet()) {

                if (sa2NameMTWP.equals(sa2NameLatch)) {

                    mtwpCharList = sa2PersonCharGroupsMTWP.get(sa2NameMTWP);
                    latchPCharList = sa2PersonCharGroupsLatch.get(sa2NameLatch);

                    Gbl.assertNotNull(mtwpCharList);
                    Gbl.assertNotNull(latchPCharList);

                    for (PersonChar pCharMTWP : mtwpCharList) {
                        for (PersonChar pCharLatch : latchPCharList) {

                            if (pCharMTWP.equals(pCharLatch)) {

                                pCharLatch.sa2TransportMode = pCharMTWP.sa2TransportMode;

                            }
                        }//closing loop for iterating through synthetic person characteristic groupings
                    }//closing loop for iterating through census mtwp person characteristic groupings
                    break;
                }
            }
        }

        //Print out stored workforce transport mode numbers for the synthetic population
//        for (String sa : sa2PersonCharGroupsLatch.keySet()) {
//            System.out.println("SA2 NAME : " + sa);
//            System.out.println("-----+++++   +++++-------");
//
//            for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa)) {
//                System.out.println(pChar.toString());
//            }
//        }
//
//        System.out.println("-----+++++   +++++-------");

        //Below prints out number of person groups in each sa2

        try {
            BufferedWriter fw = new BufferedWriter(new FileWriter("Latch_population_with_mode_numbers.txt"));

            System.out.println();
            fw.newLine();

            for (String sa2Name : sa2PersonCharGroupsLatch.keySet()) {

//                System.out.println("SA2 NAME : " + sa2Name);
//                System.out.println("......................");

                fw.write("SA2 NAME : " + sa2Name);
                fw.newLine();
                fw.write("......................");
                fw.newLine();


                double tramMode = 0.;
                double trainMode = 0.;
                double busMode = 0.;
                double ferryMode = 0.;
                double taxiMode = 0.;
                double truckMode = 0.;
                double motorbikeMode = 0.;
                double otherMode = 0.;
                double multiModeMode = 0.;
                double bicycleMode = 0.;

                int total = 0;
                double totaltrips = 0.;
                double totalCarDrvrTrips = 0.;
                double totalCarPassTrips = 0.;
                double totalUndefinedLocationTrips = 0.;

                for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa2Name)) {
                    StringBuilder str = new StringBuilder();
                    str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
                            pChar.pCharCount);
//                    System.out.println(str);
                    fw.write(str.toString());
                    fw.newLine();

                    for (String empStat : pChar.sa2TransportMode.keySet()) {

                        //All Multi-mode legs grouped as a single legged mode of transport
                        double totOfAllSingleLegMode = 0.;
                        double totOfundefinedAllSingleLegMode = 0.;
                        double totOfCarDrverMode = 0.;
                        double totOfCarPassMode = 0.;

                        double tramTrips = 0.;
                        double trainTrips = 0.;
                        double busTrips = 0.;
                        double ferryTrips = 0.;
                        double taxiTrips = 0.;
                        double truckTrips = 0.;
                        double motorbikeTrips = 0.;
                        double otherTrips = 0.;
                        double multiModeTrips = 0.;
                        double bicycleTrips = 0.;

                        fw.write(empStat);
                        fw.newLine();
                        fw.write("-------------------------");
                        fw.newLine();

                        for (String sa2work : pChar.sa2TransportMode.get(empStat).keySet()) {

                            for (String trMode : pChar.sa2TransportMode.get(empStat).get(sa2work).keySet()) {

                                if (sa2work.equals("POW State/Territory undefined (Vic.)") || sa2work.equals("POW No " +
                                        "Fixed Address (Vic.)") || sa2work.equals("Migratory - Offshore - Shipping " +
                                        "(Vic.)") || sa2work.equals("POW Capital city undefined (Greater Melbourne)")) {

                                    if (!trMode.equals("TotalMode") && !trMode.equals("Total")) {
                                        totOfundefinedAllSingleLegMode += pChar.sa2TransportMode.get(empStat).get
                                                (sa2work).get
                                                (trMode);

                                    }

                                }


                                if (!trMode.equals("TotalMode") && !trMode.equals("Total")) {
//
//                                        fw.write(trMode + " : " + pChar.sa2TransportMode.get(empStat).get(sa2work)
//                                                .get(trMode));
//                                        fw.newLine();

                                    totOfAllSingleLegMode += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                            (trMode);


                                    if (trMode.equals("Car, as driver")) {
                                        totOfCarDrverMode += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Car, as passenger")) {
                                        totOfCarPassMode += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Tram")) {
                                        tramTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Train")) {
                                        trainTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }if (trMode.equals("Bus")) {
                                        busTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Ferry")) {
                                        ferryTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }if (trMode.equals("Motorbike/scooter")) {
                                        motorbikeTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Taxi")) {
                                        taxiTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }if (trMode.equals("Bicycle")) {
                                        bicycleTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                    if (trMode.equals("Other")) {
                                        otherTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }if (trMode.equals("Truck")) {
                                        truckTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }if (trMode.equals("Multi-mode")) {
                                        multiModeTrips += pChar.sa2TransportMode.get(empStat).get(sa2work).get
                                                (trMode);

                                    }

                                }

                            }
                        }
                        fw.newLine();
                        fw.write("Total Assigned trips : " + totOfAllSingleLegMode);
                        fw.newLine();
                        totaltrips += totOfAllSingleLegMode;

                        fw.write("Total of car as driver trips : " + totOfCarDrverMode);
                        fw.newLine();
                        totalCarDrvrTrips += totOfCarDrverMode;

                        fw.write("Total of car as passenger trips : " + totOfCarPassMode);
                        fw.newLine();
                        totalCarPassTrips += totOfCarPassMode;

                        fw.write("Total Assigned trips (only to POW Undefined) : " + totOfundefinedAllSingleLegMode);
                        fw.newLine();
                        totalUndefinedLocationTrips += totOfundefinedAllSingleLegMode;


                        trainMode += trainTrips;
                        truckMode += truckTrips;
                        busMode += busTrips;
                        otherMode += otherTrips;
                        multiModeMode += multiModeTrips;
                        ferryMode += ferryTrips;
                        taxiMode += taxiTrips;
                        bicycleMode += bicycleTrips;
                        motorbikeMode += motorbikeTrips;
                        tramMode += tramTrips;



                        fw.write("-------------------------");
                        fw.newLine();
                    }

                    total += pChar.pCharCount;

                }

//                System.out.println("TOTAL : " + total);
//                System.out.println("......................");

                fw.write("TOTAL : " + total);
                fw.newLine();
                fw.write("TOTAL TRIPS : " + totaltrips);
                fw.newLine();
                fw.write("TOTAL CAR DRIVER TRIPS : " + totalCarDrvrTrips);
                fw.newLine();
                fw.write("TOTAL CAR PASSENGER TRIPS : " + totalCarPassTrips);
                fw.newLine();
                fw.write("TOTAL TRIPS TO UNDEFINED LOCATIONS : " + totalUndefinedLocationTrips);
                fw.write("......................");
                fw.newLine();
                fw.write("TOTAL TRAIN TRIPS : "+trainMode);
                fw.newLine();
                fw.write("TOTAL TRAM TRIPS : "+tramMode);
                fw.newLine();
                fw.write("TOTAL TAXI TRIPS : "+taxiMode);
                fw.newLine();
                fw.write("TOTAL TRUCK TRIPS : "+truckMode);
                fw.newLine();
                fw.write("TOTAL BUS TRIPS : "+busMode);
                fw.newLine();
                fw.write("TOTAL FERRY TRIPS : "+ferryMode);
                fw.newLine();
                fw.write("TOTAL MOTORBIKE/SCOOTER TRIPS : "+motorbikeMode);
                fw.newLine();
                fw.write("TOTAL MULTI-MODE TRIPS : "+multiModeMode);
                fw.newLine();
                fw.write("TOTAL OTHER TRIPS : "+otherMode);
                fw.newLine();
                fw.write("TOTAL BICYCLE TRIPS : "+bicycleMode);
            }

            fw.close();

        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    /**
     * Method to read the shape file and store all the features associated with a given sa2 name (2011)
     */
    private void readShapefile() {

        log.info("Storing features from shapefile..");

        //reads the shape file in
        SimpleFeatureSource fts = ShapeFileReader.readDataFile(ZONES_FILE);

        featureMap = new LinkedHashMap<>();

        //Iterator to iterate over the features from the shape file
        try (SimpleFeatureIterator it = fts.getFeatures().features()) {
            while (it.hasNext()) {

                // get feature
                SimpleFeature ft = it.next();

                // store the feature by SA2 name (because that is the way in which we will need it later)
                featureMap.put((String) ft.getAttribute("SA2_NAME11"), ft);
            }
            it.close();
        } catch (Exception ee) {

            log.error("Error reading shape file features. File : " + ZONES_FILE);
            throw new RuntimeException(ee);
        }

    }

    /**
     * Copied from bdi project synthetic population
     *
     * @param actType
     * @return
     */
    private double activityEndTime(String actType) {
        double endTime = 0.0;
        if (actType.equals(DefaultActivityTypes.work)) {
            /*
             * Allow people to leave work between 16.45 and 17.10
			 */
            endTime = 60300 + (60 * 25 * Math.random());
            return endTime;
        }

        Random rnd = new Random();
        if (actType.equals(DefaultActivityTypes.home)) {

            /*
             * Allow people to leave work between
			 */
            endTime = 21600 + (60 *
                    rnd.nextInt(180));
            return endTime;
        }

        return 21600;
    }

    /*
    * Method to convert the localized string for the transport method
    * to a Transport Mode class defined string constant
    * */
    private String getTransportModeString(String transportMode) {

        switch (transportMode.toLowerCase()) {

            case "train": {

                return TransportMode.pt;
            }
            case "tram": {

                return TransportMode.pt;
            }
            case "bus": {

                return TransportMode.pt;
            }

            case "ferry": {

                return TransportMode.pt;
            }
            case "taxi": {

                return TransportMode.car;
            }
            case "car, as driver": {

                return TransportMode.car;
            }
            case "car, as passenger": {

                return TransportMode.car;
            }
            case "truck": {

                return TransportMode.other;
            }
            case "motorbike/scooter": {

                return TransportMode.ride;
            }
            case "bicycle": {

                return TransportMode.bike;
            }
            case "other": {

                return TransportMode.other;
            }
            case "multi-mode": {

                return TransportMode.other;
            }
            default: {

                return TransportMode.other;
            }
        }
    }

    /*
    * Method to assign trips to the synthetic population using the stored proportions in the previous steps
    * Iterating through each person stored in the population file, the residence sa2 location and person
    * characteristic is used to determine which person characteristic grouping, sa2 work location and transport mode
    * to c
    * */
    public void assignTripsToLatchPopulation() {

        rnd = new Random(4711);

        log.info("Assigning trips to population");

        for (Person person : scenario.getPopulation().getPersons().values()) {

            boolean tripAssigned = false;
            String ageRange = binAgeIntoCategory((String) person.getAttributes().getAttribute("Age")).name();
            String gender = (String) person.getAttributes().getAttribute("Gender");
            String relStatus = (String) person.getAttributes().getAttribute("RelationshipStatus");
            PersonChar pChar = new PersonChar(gender, ageRange, relStatus);

            boolean pCharFound = false;
            for (String sa2Name : sa2PersonCharGroupsLatch.keySet()) {
                String sa1Id = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");
                // (sa1 code of home location)

                Gbl.assertNotNull(sa1Id);

                // get corresponding sa2name (which comes from the correspondences file):
                String sa2name = this.sa2NameFromSa1Id.get(sa1Id);

                Gbl.assertNotNull(sa2name);

                if (sa2Name.equals(sa2name)) {

                    PersonChar personChar = null;

                    for (PersonChar eachPersonChar : sa2PersonCharGroupsLatch.get(sa2Name)) {
                        if (eachPersonChar.equals(pChar)) {
                            pCharFound = true;
                            personChar = eachPersonChar;
                            break;
                        }
                    }
                    if (pCharFound == false) {
                        log.warn("Person Char not found :\n" + pChar.toString());
                    }

                    if (pCharFound == true) {

                        Gbl.assertNotNull(personChar);
                        for (String lfsp : personChar.sa2TransportMode.keySet()) {
                            for (String sa2Dest : personChar.sa2TransportMode.get(lfsp).keySet()) {
                                for (String tMode : personChar.sa2TransportMode.get(lfsp).get(sa2Dest).keySet()) {

                                    //statement should be unecessary
                                    if (tMode.equals("TotalMode") || tMode.equals("Total")) {
                                        continue;
                                    }

                                    Double numTripsbyDestMode = personChar.sa2TransportMode.get(lfsp).get
                                            (sa2Dest).get
                                            (tMode);
                                    if (personChar.pCharCount >= 1. && numTripsbyDestMode >= 1. && tripAssigned ==
                                            false) {

                                        personChar.pCharCount--;

                                        Gbl.assertNotNull(sa2Dest);

                                        // find a coordinate for the destination:
                                        SimpleFeature ft = this.featureMap.get(sa2Dest);

                                        //Gbl.assertNotNull(ft.getDefaultGeometry());

                                        if (ft == null) {

                                            person.getAttributes().putAttribute("POW Undefined", sa2Dest);

//                                            continue;
                                        } else {

                                            Activity homeActivity = (Activity) person.getSelectedPlan()
                                                    .getPlanElements()

                                                    .get(0);
                                            homeActivity.setEndTime(activityEndTime(DefaultActivityTypes.home));

                                            // --- add a leg:

                                            Leg leg = pf.createLeg(getTransportModeString(tMode));

                                            person.getSelectedPlan().addLeg(leg);

                                            // --- add work activity:
                                            Point point = MMUtils.getRandomPointInFeature(rnd, ft);
                                            Gbl.assertNotNull(point);

                                            Coord coord = new Coord(point.getX(), point.getY());
                                            Coord coordTransformed = ct.transform(coord);

//                                        Coord coordTransformed = coord;

                                            person.getAttributes().putAttribute("POW Defined", sa2Dest);
                                            Activity actWork = pf.createActivityFromCoord(DefaultActivityTypes.work,
                                                    coordTransformed);
                                            person.getSelectedPlan().addActivity(actWork);

                                            actWork.setEndTime(activityEndTime(DefaultActivityTypes.work));

                                            // --- add leg:

                                            person.getSelectedPlan().addLeg(leg);

                                            // --- add home activity:

                                            Activity actGoHome = pf.createActivityFromCoord(DefaultActivityTypes.home,
                                                    homeActivity.getCoord());
                                            person.getSelectedPlan().addActivity(actGoHome);

                                            // check what we have:
//                                        System.out.println("plan=" + person.getSelectedPlan());
//
//                                        for (PlanElement pe : person.getSelectedPlan().getPlanElements()) {
//                                            System.out.println("pe=" + pe);
//                                        }

                                        }
                                        tripAssigned = true;
                                        personChar.sa2TransportMode.get(lfsp).get(sa2Dest).put(tMode,
                                                numTripsbyDestMode - 1.);

                                    }
                                }
                            }
                        }
                    }

                    break;
                }
            }

        }

        //Write out the population to xml file
        PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
        writer.write(OUTPUT_TRIPS_FILE);

        printLatchPersonStats("Latch_un-assigned_population_statistics.txt");
    }

    /**
     * Class to build the correspondence for SA1 ids to SA2 names bound by the column header found in the csv file
     */
    public final static class SAMap {
        // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

        @CsvBindByName
        private String SA1_7DIGITCODE_2011;

        @CsvBindByName
        private String SA2_NAME_2011;


    }

    /*
    * Class to include person characteristc grouping based on the format used in the mtwp files
    * */
    public static class PersonChar {

        String gender;
        String ageGroup;
        String relStatus;
        double pCharCount;
        double partTimeProportion = 0;
        double fullTimeProportion = 0;
        Map<String, Map<String, Map<String, Double>>> sa2TransportMode = new HashMap<>();


        @Override
        public String toString() {

            StringBuilder str = new StringBuilder();


            for (String lfsp : sa2TransportMode.keySet()) {
                str.append(gender).append(" ").append(ageGroup).append(" ").append(relStatus).append("\n");
                str.append(lfsp).append("\n");
                str.append("----------------").append("\n");
                for (String sa2Name : sa2TransportMode.get(lfsp).keySet()) {
                    str.append(sa2Name).append("\n");
                    str.append("----------------").append("\n");
                    for (String mode : sa2TransportMode.get(lfsp).get(sa2Name).keySet()) {

                        str.append(gender).append(" ").append(ageGroup).append(" ").append(relStatus).append("\n");
                        str.append(lfsp).append("\n");
                        str.append("----------------").append("\n");
//                        str.append(sa2Name).append("\n");
//                        str.append("----------------").append("\n");
                        str.append(mode).append(" : ").append(sa2TransportMode.get(lfsp).get(sa2Name).get(mode))
                                .append("\n");

                    }

                    str.append("----------------").append("\n");
                }

            }
            return str.toString();

        }


        //Constructor for reading employment status Census file storing workforce proportions or latch data count
        //lfsp and mtwp Map not used
        public PersonChar(String gender, String ageGroup, String relStatus) {

            this.gender = gender;
            this.ageGroup = ageGroup;
            this.relStatus = relStatus;
            this.pCharCount = 1;
        }

        public boolean equals(PersonChar p) {

            if (this.gender.equals(p.gender) && this.ageGroup.equals(p.ageGroup) && this
                    .relStatus.equals(p.relStatus))
                return true;
            return false;
        }

        public void setEmpPartTimeProportion(double empProportion) {
            this.partTimeProportion = empProportion;
        }


        public void setFullTimeProportion(double empProportion) {
            this.fullTimeProportion = empProportion;
        }
    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    public final static class Record {
        // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

        @CsvBindByPosition(position = 0)
        private String sa2Name;

        @CsvBindByPosition(position = 1)
        private String sex;

        @CsvBindByPosition(position = 2)
        private String age;


        @CsvBindByPosition(position = 3)
        private String relStatus;

        @CsvBindByPosition(position = 4)
        private String lfsp;

        @CsvBindByPosition(position = 5)
        private String population;

        @Override
        public String toString() {

            return sa2Name + " " + age + " " + relStatus + " " + lfsp + " " + population;
        }
    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    public final static class MTWPRecord {
        // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

        @CsvBindByPosition(position = 0)
        private String sa2Name;

        @CsvBindByPosition(position = 1)
        private String sex;

        @CsvBindByPosition(position = 2)
        private String age;

        @CsvBindByPosition(position = 3)
        private String relStatus;

        @CsvBindByPosition(position = 4)
        private String lfsp;

        @CsvBindByPosition(position = 5)
        private String sa2Work;

        @CsvBindByPosition(position = 6)
        private String transportMode;

        @CsvBindByPosition(position = 7)
        private String workForce;

        @Override
        public String toString() {

            return sa2Name + " " + age + " " + relStatus + " " + lfsp + " " + sa2Work + " " + transportMode;
        }
    }
}
