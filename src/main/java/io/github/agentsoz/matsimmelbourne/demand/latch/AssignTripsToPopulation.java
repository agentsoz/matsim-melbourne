package io.github.agentsoz.matsimmelbourne.demand.latch;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvBindByPosition;
import com.opencsv.bean.CsvToBean;
import org.matsim.core.gbl.Gbl;
import com.opencsv.bean.CsvToBeanBuilder;
import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;

import java.io.*;
import java.util.*;

public class AssignTripsToPopulation {

    private static final Logger log = Logger.getLogger(AssignTripsToPopulation.class);
    public static final String[] INIT_POPULATION = {

            "--output-dir", ".",
            "--run-mode", "f",
            "--file-format", "x",

    };

    private Record record;
    private final Config config;
    private final Scenario scenario;
    private final PopulationFactory pf;

    Map<String, String> sa2NameFromSa1Id;
    Map<String, List<PersonChar>> sa2PersonCharGroupsLatch;
    Map<String, List<PersonChar>> sa2PersonCharGroupsCensus;


    //2016 correspondence file below
    //    private final static String CORRESPONDENCE_FILE =
//            "data/census/2016/correspondences/2018-01-24-1270055001_sa2_sa1_2016_mapping_aust_shape/SA1_2016_AUST
// .csv";

    //Still using 2011 correspondence as the latch data and households have been mapped using 2011 data
    //2016 data is available in the respective folder
    private final static String CORRESPONDENCE_FILE =
            "data/census/2011/correspondences/2017-12-06-1270055001_sa2_sa1_2011_mapping_aust_shape/SA1_2011_AUST.csv";
    private final static String INPUT_CONFIG_FILE = "population-from-latch.xml";
    private final static String SA2_EMPSTATS_FILE = "data/census/2011/population/VIC - SEXP_AGE5P_LFSP_UR_2011.csv";

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

    private final static String EMP_PART_TIME = "Employed, worked part-time";
    private final static String EMP_FULL_TIME = "Employed, worked full-time";
    private final static String TOTAL_POP = "Total";

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

        AssignTripsToPopulation atp = new AssignTripsToPopulation();

        createPopulationFromLatch();
        atp.readCorrespondences();
        atp.storeSyntheticPersonCharGroups();

        try {
            atp.readSA2EmploymentStatusCensusFile();
        } catch (IOException ii) {
            log.warn("readSA2EmploymentStatusCensusFile() : " + ii.getLocalizedMessage());
        }
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

        for (String sa2Name : sa2PersonCharGroupsLatch.keySet()) {
            System.out.println("SA2 NAME : " + sa2Name);
            System.out.println("......................");

            for (PersonChar pChar : sa2PersonCharGroupsLatch.get(sa2Name)) {
                StringBuilder str = new StringBuilder();
                str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
                        pChar.pCharCount);
                System.out.println(str);

            }
            System.out.println("......................");
        }
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

        for (String sa : sa2PersonCharGroupsCensus.keySet()) {
            System.out.println("SA2 NAME : " + sa);
            System.out.println("-----------------------");

            for (PersonChar pChar : sa2PersonCharGroupsCensus.get(sa)) {
                StringBuilder str = new StringBuilder();
                str.append(pChar.ageGroup).append(" " + pChar.gender).append(" " + pChar.relStatus).append(" " +
                        pChar.partTimeProportion + " " + pChar.fullTimeProportion);
                System.out.println(str);

            }
            System.out.println("-----------------------");
        }
    }


//Read shape file to store the features for a given sa2
//Read correspondence file for sa1 7 digit codes to get sa2 names from 2016 census correspondence
//Find proportion of trips from the total number of people with those characteristics in the mtwp file and apply it
// to the proportion of synthetic population with that characteristic
//Check round-off


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

}