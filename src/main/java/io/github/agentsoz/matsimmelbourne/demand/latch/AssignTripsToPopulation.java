package io.github.agentsoz.matsimmelbourne.demand.latch;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvBindByPosition;
import com.opencsv.bean.CsvToBean;
import com.vividsolutions.jts.geom.Point;
import io.github.agentsoz.matsimmelbourne.utils.DefaultActivityTypes;
import io.github.agentsoz.matsimmelbourne.utils.MMUtils;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.*;
import org.matsim.core.gbl.Gbl;
import com.opencsv.bean.CsvToBeanBuilder;
import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import java.io.*;
import java.util.*;

public class AssignTripsToPopulation {

    private static final Logger log = Logger.getLogger(AssignTripsToPopulation.class);
    public static final String[] FILE_NAMES = {

            "NORTHCOTE", "data/census/2011/mtwp/NORTHCOTE_PCHAR_POW_MTWP.csv",
            "ALPHINGTON", "data/census/2011/mtwp/ALPHINGTON_PCHAR_POW_MTWP.csv",
            "BUNDOORA-EAST", "data/census/2011/mtwp/BUNDOORA-EAST_PCHAR_POW_MTWP.csv",
            "THORNBURY", "data/census/2011/mtwp/THORNBURY_PCHAR_POW_MTWP.csv"

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
    Map<String, List<PersonChar>> sa2PersonCharGroupsCensus = new HashMap<>();
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
    private final static String SA2_EMPSTATS_FILE = "data/census/2011/population/VIC - SEXP_AGE5P_LFSP_UR_2011.csv";
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
    private final static String EMP_PART_TIME = "Employed, worked part-time";
    private final static String EMP_FULL_TIME = "Employed, worked full-time";
    private final static String TOTAL_POP = "Total";
    private Random rnd;

//    private enum Sex {male, female}
//
//    private enum RelationShipStatus {loneParent, married, u15Child, o15Child, relative, student}
//
//    private enum EmpStats {employedFull, employedPart, unemployed}

    //    private class PersonChar {
//
//        AgeGroups ageGroups;
//        Sex sex;
//        RelationShipStatus relationStatus;
//        EmpStats empStats;
//    }


    /*Constructor for class*/
    public AssignTripsToPopulation() {

        config = ConfigUtils.createConfig();

        config.plans().setInputFile(INPUT_CONFIG_FILE);

        scenario = ScenarioUtils.loadScenario(config);
        pf = scenario.getPopulation().getFactory();

    }

    public static void main(String args[]) {

        createPopulationFromLatch();
        AssignTripsToPopulation atp = new AssignTripsToPopulation();
        atp.readCorrespondences();
        atp.storeSyntheticPersonCharGroups();

        try {
            atp.readSA2EmploymentStatusCensusFile();
        } catch (IOException ii) {
            log.warn("readSA2EmploymentStatusCensusFile() : " + ii.getLocalizedMessage());
        }

        try {
            atp.storeLatchWorkingProportionNumbers();
        } catch (RuntimeException r) {
            log.warn("storeLatchWorkingProportionNumbers() : " + r.getLocalizedMessage());
        }

        for (int i = 0; i < FILE_NAMES.length; i = i + 2) {

            MTWP_FILE = FILE_NAMES[i + 1];

            try {
                log.info("Reading SA2 - " + FILE_NAMES[i]);
                atp.readMTWPFile();

            } catch (IOException ii) {
                log.warn("readMTWPFile() : " + ii.getLocalizedMessage());

            }
        }

        for (String sa2Home : atp.sa2PersonCharGroupsMTWP.keySet())
            System.out.println(sa2Home + " " + atp.sa2PersonCharGroupsMTWP.get(sa2Home).size());

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
     * to map the sa1 7 digit codes (2011) to the corresponding sa2 names (2016)
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


    /*Method to store the number of synthetic person groups for each SA2 location*/
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

            } else {

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


        }

        //Below prints out number of person groups in each sa2

//        System.out.println();
//        for (String sa2Name : sa2PersonCharGroupsLatch.keySet()) {
//
//            System.out.println("SA2 NAME : " + sa2Name);
//            System.out.println("......................");
//
//            int total = 0;
//            for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa2Name)) {
//                StringBuilder str = new StringBuilder();
//                str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
//                        pChar.pCharCount);
//                System.out.println(str);
//                total += pChar.pCharCount;
//            }
//
//            System.out.println("TOTAL : " + total);
//
//            System.out.println("......................");
//        }
    }


    public void readSA2EmploymentStatusCensusFile() throws IOException {

        String sa2Name = "";
        String gender = "";
        String ageRange = "";
        String relStatus = "";

        String fullTimeWorkForce = "";
        String partTimeWorkForce = "";
        String totalPopulation = "";

        double partTimeWorkForceProportion;
        double fullTimeWorkForceProportion;

        int lineCount = 0;

        try (final BufferedReader reader = new BufferedReader(new FileReader(SA2_EMPSTATS_FILE))) {

            log.info("Parsing Census SA2 - Person Characteristics - Employment Status file..");

            while (++lineCount < 12) {
                reader.readLine();
            }

            final CsvToBeanBuilder<Record> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(Record.class);
            builder.withSeparator(',');

            final CsvToBean<Record> reader2 = builder.build();

            sa2PersonCharGroupsCensus = new HashMap<>();

            for (Iterator<Record> it = reader2.iterator(); it.hasNext(); ) {

                record = it.next();

                if (record.sa2Name != null) {
                    sa2Name = record.sa2Name;
                    sa2PersonCharGroupsCensus.put(sa2Name, new ArrayList<PersonChar>());
                }
                if (record.sex != null)
                    gender = record.sex;

                if (record.age != null)
                    ageRange = record.age;

                if (record.relStatus != null) {
                    relStatus = record.relStatus;
                }

//                System.out.println(record.toString());
                if (record.lfsp != null) {
                    if (record.lfsp.equals(EMP_FULL_TIME))
                        fullTimeWorkForce = record.population;

                    if (record.lfsp.equals(EMP_PART_TIME))
                        partTimeWorkForce = record.population;

                    if (record.lfsp.equals(TOTAL_POP)) {
                        totalPopulation = record.population;


                        fullTimeWorkForceProportion = Double.parseDouble(fullTimeWorkForce) / Double.parseDouble
                                (totalPopulation);

                        partTimeWorkForceProportion = Double.parseDouble(partTimeWorkForce) / Double.parseDouble
                                (totalPopulation);


                        if (Double.parseDouble(totalPopulation) == 0.0) {

                            fullTimeWorkForceProportion = 0.0;
                            partTimeWorkForceProportion = 0.0;
                        }

                        //part-time and full-time should be zero too and avoid being stored as NaN

//                          if(Double.parseDouble(fullTimeWorkForce) == 0.0)  fullTimeWorkForceProportion = 0.0;
//                          if(Double.parseDouble(partTimeWorkForce) == 0.0)  partTimeWorkForceProportion = 0.0;


                        //Retrieve list of Person Characteristic groupings
                        List<PersonChar> pCharGroups = sa2PersonCharGroupsCensus.get(sa2Name);
                        Gbl.assertNotNull(pCharGroups);

                        AgeGroups ageGroups = binAgeRangeIntoCategory(ageRange);
                        PersonChar pChar = new PersonChar(gender, ageGroups.name(), relStatus);

                        pChar.setEmpPartTimeProportion(partTimeWorkForceProportion);
                        pChar.setFullTimeProportion(fullTimeWorkForceProportion);

                        pCharGroups.add(pChar);

                    }
                }
            }
        }

//        for (String sa : sa2PersonCharGroupsCensus.keySet()) {
//            System.out.println("SA2 NAME : " + sa);
//            System.out.println("-----------------------");
//
//            for (PersonChar pChar : sa2PersonCharGroupsCensus.get(sa)) {
//                StringBuilder str = new StringBuilder();
//                str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
//                        pChar.partTimeProportion + " " + pChar.fullTimeProportion);
//                System.out.println(str);
//
//            }
//            System.out.println("-----------------------");
//        }
    }

    //Store the proportionate number of working full-time and working part-time people in the latch data using the
    // proportions from the census data
    public void storeLatchWorkingProportionNumbers() {

        log.info("Storing workforce proportions in Latch Data");

        List<PersonChar> censusPCharList = null;
        List<PersonChar> latchPCharList = null;
        boolean sa2NameFound = false;

        for (String sa2NameLatch : sa2PersonCharGroupsLatch.keySet()) {
            for (String sa2NameCensus : sa2PersonCharGroupsCensus.keySet()) {
                if (sa2NameCensus.equals(sa2NameLatch)) {

                    sa2NameFound = true;
                    censusPCharList = sa2PersonCharGroupsCensus.get(sa2NameCensus);
                    latchPCharList = sa2PersonCharGroupsLatch.get(sa2NameLatch);
                    break;
                }
            }
        }

        if (sa2NameFound == false) {
            log.warn("Bad SA2 name or latch SA2 name not found in census data");
            throw new RuntimeException("SA2 name not found");
        }

        Gbl.assertNotNull(censusPCharList);
        Gbl.assertNotNull(latchPCharList);

        for (PersonChar pCharCensus : censusPCharList) {
            for (PersonChar pCharLatch : latchPCharList) {

                if (pCharCensus.equals(pCharLatch)) {
                    pCharLatch.setEmpPartTimeProportion(pCharCensus.partTimeProportion);
                    pCharLatch.setFullTimeProportion(pCharCensus.fullTimeProportion);
                }
            }
        }

    }

    public void calcMTWPProportion(PersonChar pChar, String lfsp) {

        Double totalPersonCharacTrips = 0.;

        for (String eachSA2Work : pChar.sa2TransportMode.get(lfsp)
                .keySet())
            for (String eachTMode : pChar.sa2TransportMode.get(lfsp).get
                    (eachSA2Work).keySet())
                if (eachTMode.equals("TotalMode"))
                    totalPersonCharacTrips += pChar.sa2TransportMode.get(lfsp).get
                            (eachSA2Work).get(eachTMode);

//        System.out.println(pChar.gender+ " " + pChar.ageGroup + " " + pChar.relStatus+ " " + lfsp);
//        System.out.println("TOTAL OF TOTALMODES : "+totalPersonCharacTrips);

        //Get the proportion of individual modes to the total calculated above
        for (String eachSA2Work : pChar.sa2TransportMode.get(lfsp).keySet())
            for (String eachTMode : pChar.sa2TransportMode.get(lfsp).get
                    (eachSA2Work).keySet()) {

                //Just to print out proportions
//        if(pChar.sa2TransportMode
//                .get(lfsp).get(eachSA2Work).get(eachTMode)>0){
//            System.out.println(pChar.gender+ " " + pChar.ageGroup + " " + pChar.relStatus+ " " + lfsp + " " +
//                    eachSA2Work + " " + eachTMode);
//            System.out.println(eachTMode+" : " +pChar.sa2TransportMode
//                    .get(lfsp).get(eachSA2Work).get(eachTMode));
//            System.out.println("TOTAL OF TOTALMODE : "+totalPersonCharacTrips);
//            System.out.println(pChar.sa2TransportMode
//                    .get(lfsp).get(eachSA2Work).get(eachTMode) / totalPersonCharacTrips);
//
//        }

                if (!eachTMode.equals("TotalMode")) {
                    if (totalPersonCharacTrips == 0.)
                        pChar.sa2TransportMode.get(lfsp).get(eachSA2Work).put(eachTMode, 0.);
                    else
                        pChar.sa2TransportMode.get(lfsp).get(eachSA2Work).put(eachTMode, pChar.sa2TransportMode
                                .get(lfsp).get(eachSA2Work).get(eachTMode) / totalPersonCharacTrips);

                }
            }
    }
    //

    public void readMTWPFile() throws IOException {

        String sa2Name = "";
        String gender = "";
        String ageRange = "";
        String relStatus = "";
        String lfsp = "";
        String sa2Work = "";


//        String fullTimeWorkForce = "";
//        String partTimeWorkForce = "";
//        String totalPopulation = "";
//
//        double partTimeWorkForceProportion;
//        double fullTimeWorkForceProportion;

        PersonChar pChar = null;
        AgeGroups ageGroups = null;
        int lineCount = 0;

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


//                mtwpRecord.toString();

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
                    Gbl.assertNotNull(ageGroups);

                    if (!lfsp.equals("")) {
                        calcMTWPProportion(pChar, lfsp);
//                        log.info(pChar.toString());
                    }

                    pChar = new PersonChar(gender, ageGroups.name(), relStatus);
                    pCharGroups.add(pChar);

                }

                if (mtwpRecord.lfsp != null) {

                    Double totalPersonCharacTrips = 0.;

                    if (!lfsp.equals("") && mtwpRecord.relStatus == null) {
                        calcMTWPProportion(pChar, lfsp);
//                        log.info(pChar.toString());

                    }

                    lfsp = mtwpRecord.lfsp;
                    pChar.sa2TransportMode.put(lfsp, new HashMap<>());

                }


                if (mtwpRecord.sa2Work != null) {

                    sa2Work = mtwpRecord.sa2Work;

                    pChar.sa2TransportMode.get(lfsp).put(sa2Work, new HashMap<>());

                }

                pChar.sa2TransportMode.get(lfsp).get(sa2Work).put(mtwpRecord.transportMode,
                        Double.parseDouble(mtwpRecord.workForce));


            }
        }


    }

    //Store the proportions in the mapped latcha data for the person characteristic grouping
    public void storeMTWPProportionsInLatch() {

        String sa2NameUR = "";
        log.info("Storing MTWP proportions in Latch Data");

        List<PersonChar> mtwpCharList = null;
        List<PersonChar> latchPCharList = null;
        boolean sa2NameFound = false;

        for (String sa2NameMTWP : sa2PersonCharGroupsMTWP.keySet()) {
            for (String sa2NameLatch : sa2PersonCharGroupsLatch.keySet()) {
                if (sa2NameMTWP.equals(sa2NameLatch)) {

//                    sa2NameFound = true;
                    mtwpCharList = sa2PersonCharGroupsMTWP.get(sa2NameMTWP);
                    latchPCharList = sa2PersonCharGroupsLatch.get(sa2NameLatch);

//                    if (sa2NameFound == true) {

                    Gbl.assertNotNull(mtwpCharList);
                    Gbl.assertNotNull(latchPCharList);

                    for (PersonChar pCharMTWP : mtwpCharList) {
                        for (PersonChar pCharLatch : latchPCharList) {

                            if (pCharMTWP.equals(pCharLatch)) {

                                for (String lfsp : pCharMTWP.sa2TransportMode.keySet()) {

                                    //Assigning the same work status
                                    pCharLatch.sa2TransportMode.put(lfsp, new HashMap<>());

                                    for (String sa2Work : pCharMTWP.sa2TransportMode.get(lfsp).keySet()) {

                                        //Assigning the same destination sa2
                                        pCharLatch.sa2TransportMode.get(lfsp).put(sa2Work, new HashMap<>());

                                        for (String mode : pCharMTWP.sa2TransportMode.get(lfsp).get(sa2Work)
                                                .keySet()) {

                                            if (!mode.equals("TotalMode")) {
                                                //Scaling the proportion from MTWP to Latch using the pre-existing

                                                // proportion and
                                                // total count
                                                if (lfsp.equals(EMP_PART_TIME))
                                                    pCharLatch.sa2TransportMode.get(lfsp).get(sa2Work).put(mode,
                                                            pCharMTWP
                                                                    .sa2TransportMode.get(lfsp).get(sa2Work).get
                                                                    (mode) *
                                                                    pCharLatch
                                                                            .pCharCount *
                                                                    pCharLatch.partTimeProportion);

                                                if (lfsp.equals(EMP_FULL_TIME))
                                                    pCharLatch.sa2TransportMode.get(lfsp).get(sa2Work).put(mode,
                                                            pCharMTWP
                                                                    .sa2TransportMode.get(lfsp).get(sa2Work).get
                                                                    (mode) *
                                                                    pCharLatch
                                                                            .pCharCount *

                                                                    pCharLatch.fullTimeProportion);

                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }
//        if (sa2NameFound == false) {
//            log.warn("Bad SA2 name or latch SA2 name not found in census data");
//            throw new RuntimeException("SA2 name not found");
//        }


        for (String sa : sa2PersonCharGroupsLatch.keySet()) {
            System.out.println("SA2 NAME : " + sa);
            System.out.println("-----+++++   +++++-------");

            for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa)) {
                System.out.println(pChar.toString());
            }
//            System.out.println("-----------------------");
        }

        System.out.println("-----+++++   +++++-------");

    }


//Check round-off

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
                //TO CHANGE
                return TransportMode.pt;
            }
            case "tram": {
                //TO CHANGE
                return TransportMode.pt;
            }
            case "bus": {

                //TO CHANGE
                return TransportMode.pt;
            }
            case "taxi": {
                //TO CHANGE
                return TransportMode.car;
            }
            case "car, as driver": {

                return TransportMode.car;
            }
            case "car, as passenger": {

                //TO CHANGE
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

            default: {

                return TransportMode.other;
            }
        }
    }

//Assign trips to population

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

                                    if (tMode.equals("TotalMode") || tMode.equals("Total")) {
                                        continue;
                                    }

                                    Double numTripsbyDestMode = personChar.sa2TransportMode.get(lfsp).get
                                            (sa2Dest).get
                                            (tMode);
                                    if (numTripsbyDestMode >= 1 && tripAssigned == false) {

                                        Gbl.assertNotNull(sa2Dest);

                                        // find a coordinate for the destination:
                                        SimpleFeature ft = this.featureMap.get(sa2Dest);

                                        //Gbl.assertNotNull(ft.getDefaultGeometry());

                                        if (ft == null) {
                                            //Null because there are some sa2 locations for which we cannot retrieve
                                            // a feature
//                                            log.warn("There is no feature for " + sa2Dest + ".  Possibly this means
// " +
//                                                    "that the destination is outside the area that we have covered
// by" +
//                                                    " shapefiles.  Ignoring the " +
//                                                    "person.");
                                            continue;
                                        }

                                        Activity homeActivity = (Activity) person.getSelectedPlan().getPlanElements()
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

                                        tripAssigned = true;
                                        personChar.sa2TransportMode.get(lfsp).get(sa2Dest).put(tMode,
                                                numTripsbyDestMode - 1);
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }

        //Write out the population to xml file
        PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
        writer.write(OUTPUT_TRIPS_FILE);

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
//                str.append(gender).append(" ").append(ageGroup).append(" ").append(relStatus).append("\n");
//                str.append(lfsp).append("\n");
//                str.append("----------------").append("\n");
                for (String sa2Name : sa2TransportMode.get(lfsp).keySet()) {
//                    str.append(sa2Name).append("\n");
//                    str.append("----------------").append("\n");
                    for (String mode : sa2TransportMode.get(lfsp).get(sa2Name).keySet()) {
                        if (sa2Name.equals("Preston")) {

                            str.append(gender).append(" ").append(ageGroup).append(" ").append(relStatus).append("\n");
                            str.append(lfsp).append("\n");
                            str.append("----------------").append("\n");
                            str.append(sa2Name).append("\n");
                            str.append("----------------").append("\n");

                            str.append(mode).append(" : ").append(sa2TransportMode.get(lfsp).get(sa2Name).get(mode))
                                    .append
                                            ("\n");
                        }
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
                    .relStatus.equals(relStatus))
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