package io.github.agentsoz.matsimmelbourne.demand.latch;


import io.github.agentsoz.matsimmelbourne.utils.MMUtils;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.locationtech.jts.geom.Point;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.DefaultActivityTypes;
import org.matsim.api.core.v01.Id;
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

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Scanner;
import java.util.Set;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

public class AssignTripsToPopulationDS {

    // Command line arguments and their default values
    private static final String HELP_OPT= "--help";
    private static final String MATSIM_POPULATION_FILE_OPT= "--matsim-population-file";
    private String MATSIM_POPULATION_FILE = "population-from-latch.xml.gz";
    private static final String OUTPUT_DIRECTORY_OPT = "--output-dir";
    private String OUTPUT_DIRECTORY = "./";
    private static final String MTWP_CSV_FILES_OPT = "--mtwp-csv-files";
    private String MTWP_CSV_FILES =
//            "BUNDOORA-EAST", "data/census/2011/mtwp/2018-02-16-mtwp-files/BUNDOORA-EAST_PCHAR_POW_MTWP.csv",
            "NORTHCOTE:data/census/2011/mtwp/2018-02-16-mtwp-files/NORTHCOTE_PCHAR_POW_MTWP.csv"
//            "IVANHOE-EAST", "data/census/2011/mtwp/2018-02-16-mtwp-files/IVANHOE-EAST_PCHAR_POW_MTWP.csv",
//            "ALPHINGTON", "data/census/2011/mtwp/2018-02-16-mtwp-files/ALPHINGTON_PCHAR_POW_MTWP.csv",
//            "IVANHOE", "data/census/2011/mtwp/2018-02-16-mtwp-files/IVANHOE_PCHAR_POW_MTWP.csv",
//            "HEIDELBERG-WEST", "data/census/2011/mtwp/2018-02-16-mtwp-files/HEIDELBERG-WEST_PCHAR_POW_MTWP.csv",
//            "HEIDELBERG-ROSANNA", "data/census/2011/mtwp/2018-02-16-mtwp-files/HEIDELBERG-ROSANNA_PCHAR_POW_MTWP.csv",
//            "GREENSBOROUGH", "data/census/2011/mtwp/2018-02-16-mtwp-files/GREENSBOROUGH_PCHAR_POW_MTWP.csv",
//            "THORNBURY", "data/census/2011/mtwp/2018-02-16-mtwp-files/THORNBURY_PCHAR_POW_MTWP.csv"
    ;
    private final static String CORRESPONDENCE_FILE =
            "data/census/2011/correspondences/2017-12-06-1270055001_sa2_sa1_2011_mapping_aust_shape/SA1_2011_AUST.csv";
    private final static String ZONES_FILE =
            "data/census/2011/shp/2017-12-06-1270055001_sa2_2011_aust_shape/SA2_2011_AUST" +
                    ".shp";

    private enum AgeGroups {u15, b15n24, b25n39, b40n54, b55n69, b70n84, b85n99, over100}
    private static final Map<String, String> ageCategoryToAgeRange;
    static {
        ageCategoryToAgeRange = new HashMap<>();
        ageCategoryToAgeRange.put("u15", "0-14");
        ageCategoryToAgeRange.put("b15n24", "15-24");
        ageCategoryToAgeRange.put("b25n39", "25-39");
        ageCategoryToAgeRange.put("b40n54", "40-54");
        ageCategoryToAgeRange.put("b55n69", "55-69");
        ageCategoryToAgeRange.put("b70n84", "70-84");
        ageCategoryToAgeRange.put("b85n99", "85-99");
        ageCategoryToAgeRange.put("over100", "100 years and over");
    }

    public static void main(String args[]) {

        // create a new worker
        AssignTripsToPopulationDS worker = new AssignTripsToPopulationDS();

        // parse the arguments--will abort with an exception if there are issues
        Map<String, String> config = worker.parse(args);

        // display the usage always
        worker.log(worker.usage());

        // check that the MATSim population file exists
        if (!new File(worker.MATSIM_POPULATION_FILE).exists()) {
            throw new RuntimeException("MATSim population file " + worker.MATSIM_POPULATION_FILE + " does not exist");
        }

        for(String keyvalue : worker.MTWP_CSV_FILES.split(",")) {
            worker.log("processing " + keyvalue);
            String[] sa2File = keyvalue.split(":");
            if (sa2File.length != 2) {
                throw new RuntimeException(keyvalue + " is not in format key:value");
            }

            // read the MTWP file and write it out as a compressed flat CSV with zero rows suppressed
            Path outFilePath = Paths.get(sa2File[0] + "-1-mtwp-flat.csv.gz");
            if (outFilePath.toFile().exists()) {
                worker.log(displayReuseWarningMessage(outFilePath));
            } else {
                worker.log("writing flat compressed CSV with zero rows suppressed to " + outFilePath);
                worker.writeFlatCompressedCSVFor(sa2File[1], outFilePath, false);
            }

            // read the compressed data and write out the mode share distributions
            Path inFilePath = outFilePath;
            outFilePath = Paths.get(sa2File[0] + "-2-mtwp-modeshare.csv.gz");
            if (outFilePath.toFile().exists()) {
                worker.log(displayReuseWarningMessage(outFilePath));
            } else {
                worker.log("writing mode share distributions to " + outFilePath);
                worker.writeModeShareDistributions(inFilePath, outFilePath);
            }

            // read the MATSim population and write out subset for this SA2
            inFilePath = Paths.get(worker.MATSIM_POPULATION_FILE);
            outFilePath = Paths.get(sa2File[0] + "-3-matsim-popn.xml.gz");
            if (outFilePath.toFile().exists()) {
                worker.log(displayReuseWarningMessage(outFilePath));
            } else {
                worker.log("writing MATSim population to " + outFilePath);
                worker.writeMATSimPopulationFor(sa2File[0], inFilePath, outFilePath);
            }

            // read the SA2 MATSim population and write out the work SA2
            inFilePath = Paths.get(sa2File[0] + "-3-matsim-popn.xml.gz");
            outFilePath = Paths.get(sa2File[0] + "-4-matsim-work-dest.xml.gz");
            Path noTripsMATSimFilePath = Paths.get(sa2File[0] + "-4-matsim-no-work-dest.csv.gz");
            Path noTripsMTWPFilePath = Paths.get(sa2File[0] + "-4-mtwp-unassigned-work-dest.csv.gz");
            if (outFilePath.toFile().exists()) {
                worker.log(displayReuseWarningMessage(outFilePath));
            } else {
                worker.log("writing MATSim population work destinations to " + outFilePath);
                worker.writeMATSimWorkDestinationsFor(sa2File[0], inFilePath, outFilePath, noTripsMATSimFilePath, noTripsMTWPFilePath);
            }

            // add trips to random coords in work SA2 areas
            inFilePath = Paths.get(sa2File[0] + "-4-matsim-work-dest.xml.gz");
            outFilePath = Paths.get(sa2File[0] + "-5-matsim-work-trips.xml.gz");
            if (outFilePath.toFile().exists()) {
                worker.log(displayReuseWarningMessage(outFilePath));
            } else {
                Map<String, SimpleFeature> zones = worker.readShapefile(Paths.get(ZONES_FILE));
                worker.writeMATSimWorkTripsFor(sa2File[0], zones, inFilePath, outFilePath);
            }
        }
    }

    private void writeMATSimWorkTripsFor(String sa2, Map<String, SimpleFeature> zones, Path inFilePath, Path outFilePath) {

        Random random = new Random(12345);

        final CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation
                (TransformationFactory.WGS84, "EPSG:28355");


        try {
            Config config = ConfigUtils.createConfig();
            config.plans().setInputFile(inFilePath.toString());
            Scenario scenario = ScenarioUtils.loadScenario(config);
            PopulationFactory pf = scenario.getPopulation().getFactory();

            for (Person person : scenario.getPopulation().getPersons().values()) {
                String sa2_work= (String)person.getAttributes().getAttribute("sa2_work");
                String tMode = (String)person.getAttributes().getAttribute("transport_mode");

                if (sa2_work == null || sa2_work.isEmpty() || tMode == null || tMode.isEmpty()) {
                    continue;
                }

                Activity homeActivity = (Activity) person.getSelectedPlan().getPlanElements().get(0);
                homeActivity.setEndTime(activityEndTime(DefaultActivityTypes.home));

                // --- add a leg:
                Leg leg = pf.createLeg(getTransportModeString(tMode));
                person.getSelectedPlan().addLeg(leg);

                // --- add work activity:
                SimpleFeature ft = zones.get(sa2_work.toLowerCase());
                Coord coordTransformed = homeActivity.getCoord(); // set default work coord same as home
                if (ft != null && !sa2_work.startsWith("POW ")) {
                    Point point = MMUtils.getRandomPointInFeature(random, ft);
                    Gbl.assertNotNull(point);
                    Coord coord = new Coord(point.getX(), point.getY());
                    coordTransformed = ct.transform(coord);
                }

                Activity actWork = pf.createActivityFromCoord(DefaultActivityTypes.work, coordTransformed);
                person.getSelectedPlan().addActivity(actWork);

                actWork.setEndTime(activityEndTime(DefaultActivityTypes.work));

                // --- add leg:
                person.getSelectedPlan().addLeg(leg);

                // --- add home activity:
                Activity actGoHome = pf.createActivityFromCoord(DefaultActivityTypes.home,
                        homeActivity.getCoord());
                person.getSelectedPlan().addActivity(actGoHome);
            }

            // Write out the population to xml file
            PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
            writer.write(outFilePath.toString());
            log("MATSim population with work trips for " + sa2 + " saved in " + outFilePath);
        } catch (Exception e) {
            throw new RuntimeException("Error during trips assignment", e);
        }

    }

    private void writeRandomMATSimWorkDestinationsFor(String sa2, Path inFilePath, Path outFilePath, Path noTripsMATSimFilePath, Path noTripsMTWPFilePath) {

        Random random = new Random(12345);

        try {
            // read the MTWP stats
            log("reading unassigned MTWP trips for " + sa2);
            Map<String, Double> sa2DestTotals = readMTWPUnassignedTrips(sa2);

            Config config = ConfigUtils.createConfig();
            config.plans().setInputFile(inFilePath.toString());
            Scenario scenario = ScenarioUtils.loadScenario(config);

            // get the list of unassigned MATSIM persons
            List<Person> unassignedMATSimPersons = new ArrayList<>();
            for (Person person : scenario.getPopulation().getPersons().values()) {
                Object sa2_work= person.getAttributes().getAttribute("sa2_work");
                if (sa2_work == null) {
                    unassignedMATSimPersons.add(person);
                }
            }

            // randomly allocate those trips
            for (String sa2Dest : sa2DestTotals.keySet()) {
                double total = sa2DestTotals.get(sa2Dest);
                while (total >= 1) {
                    total--;
                    int index = random.nextInt(unassignedMATSimPersons.size());
                    Person person = unassignedMATSimPersons.get(index);
                    person.getAttributes().putAttribute("sa2_work", sa2Dest);
                    person.getAttributes().putAttribute("transport_mode", "?");
                    unassignedMATSimPersons.remove(index);
                }
                sa2DestTotals.put(sa2Dest, total);
            }
            // write out the unassigned MATSim persons
            FileOutputStream outputStream = new FileOutputStream(noTripsMATSimFilePath.toFile());
            GZIPOutputStream gzipOutputStream = new GZIPOutputStream(outputStream, true);
            for (Person person : scenario.getPopulation().getPersons().values()) {
                Object sa2_work= person.getAttributes().getAttribute("sa2_work");
                if (sa2_work == null) {
                    String gender = (String) person.getAttributes().getAttribute("Gender");
                    String age = (String) person.getAttributes().getAttribute("Age");
                    AgeGroups ageGroups = binAgeIntoCategory(age);
                    String relStatus = (String) person.getAttributes().getAttribute("RelationshipStatus");
                    String sa1_7digitcode_2011 = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");
                    gzipOutputStream.write(
                            (person.getId()
                                    + "|" + gender
                                    + "|" + age
                                    + "|" + ageGroups.name()
                                    + "|" + relStatus
                                    + "|" + sa1_7digitcode_2011
                                    + "\n").getBytes()
                    );
                }
            }
            log("MATSim persons in " + sa2 + " with unassigned work destinations saved in " + noTripsMATSimFilePath);
            gzipOutputStream.close();

            // write out the unassigned MTWP trips
            outputStream = new FileOutputStream(noTripsMTWPFilePath.toFile());
            gzipOutputStream = new GZIPOutputStream(outputStream, true);
            for (String sa2Dest : sa2DestTotals.keySet()) {
                double unassigned = sa2DestTotals.get(sa2Dest);
                gzipOutputStream.write((sa2Dest + "|" + unassigned + "\n").getBytes());
            }
            log("MTWP unassigned work destinations from " + sa2 + " saved to " + noTripsMTWPFilePath);
            gzipOutputStream.close();

            // Write out the population to xml file
            PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
            writer.write(outFilePath.toString());
            log("MATSim population with work destinations for " + sa2 + " saved in " + outFilePath);
        } catch (Exception e) {
            throw new RuntimeException("Error during work SA2 assignment", e);
        }

    }

    private Map<String,Double> readMTWPUnassignedTrips(String sa2) {
        Path inFilePath = Paths.get(sa2 + "-4-mtwp-unassigned-work-dest.csv.gz");
        Map<String,Double> map = new HashMap<>();
        try {
            InputStream inputStream = new GZIPInputStream(new FileInputStream(inFilePath.toFile()));
            Scanner sc = new Scanner(inputStream, "UTF-8");
            while (sc.hasNextLine()) {
                String[] keyval = sc.nextLine().split("\\|");
                map.put(keyval[0], Double.parseDouble(keyval[1]));
            }
            // close the streams
            sc.close();
        } catch (IOException e) {
            throw new RuntimeException("Error while parsing " + inFilePath, e);
        }
        return map;
    }

    private void writeMATSimWorkDestinationsFor(String sa2, Path inFilePath, Path outFilePath, Path noTripsMATSimFilePath, Path noTripsMTWPFilePath) {

        try {
            FileOutputStream outputStream = new FileOutputStream(noTripsMATSimFilePath.toFile());
            GZIPOutputStream gzipOutputStream = new GZIPOutputStream(outputStream, true);

            // read the MTWP stats
            log("reading MTWP mode share distributions for " + sa2);
            HashSet<MTWPRecord> modeshare = readMTWPModeShareFor(sa2);

            // calculate dest sa2 distribution
            double totalMTWPPopulation = 0;
            Map<String, Double> sa2DestTotals = new HashMap<>();
            for (MTWPRecord mtwpRecord : modeshare) {
                if ("Total".equals(mtwpRecord.transportMode)) {
                    continue;
                }
                double workForce = Double.parseDouble(mtwpRecord.workForce);
                totalMTWPPopulation += workForce;
                String key = mtwpRecord.sa2Work + "|" + mtwpRecord.transportMode;
                sa2DestTotals.put(key,
                        sa2DestTotals.containsKey(key) ?
                                sa2DestTotals.get(key) + workForce
                                : workForce);
            }

            Config config = ConfigUtils.createConfig();
            config.plans().setInputFile(inFilePath.toString());
            Scenario scenario = ScenarioUtils.loadScenario(config);

            int totalMATSimPersons = scenario.getPopulation().getPersons().size();

            Gbl.assertIf(totalMATSimPersons > totalMTWPPopulation);

            // now write out the sa2dests for each person in the MATSim popn
            for (Person person : scenario.getPopulation().getPersons().values()) {
                // stop if there are no more mtwp persons to allocate
                if (sa2DestTotals.isEmpty()) {
                    break;
                }
                MTWPRecord mtwpRecord = matchPerson(person, modeshare, sa2DestTotals, gzipOutputStream);
                if (mtwpRecord != null) {
                    // decrement the respective mtwp persons counter
                    String key = mtwpRecord.sa2Work + "|" + mtwpRecord.transportMode;
                    double newTotal = sa2DestTotals.get(key) - 1; // guaranteed to be >1 by match
                    sa2DestTotals.put(key, newTotal);
                    if (newTotal < 1) {
                        sa2DestTotals.remove(key);
                    }
                    // write the SA2 work and mode attributes from MTWP to the MATSim person
                    person.getAttributes().putAttribute("sa2_work", mtwpRecord.sa2Work);
                    person.getAttributes().putAttribute("transport_mode", mtwpRecord.transportMode);
                }
            }

            // close the streams
            log("MATSim persons in " + sa2 + " with unassigned work destinations saved in " + noTripsMATSimFilePath);
            gzipOutputStream.close();

            // write out the unassigned MTWP trips
            outputStream = new FileOutputStream(noTripsMTWPFilePath.toFile());
            gzipOutputStream = new GZIPOutputStream(outputStream, true);
            for (String sa2Dest : sa2DestTotals.keySet()) {
                double unassigned = sa2DestTotals.get(sa2Dest);
                gzipOutputStream.write((sa2Dest + "|" + unassigned + "\n").getBytes());
            }
            log("MTWP unassigned work destinations from " + sa2 + " saved to " + noTripsMTWPFilePath);
            gzipOutputStream.close();

            // Write out the population to xml file
            PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
            writer.write(outFilePath.toString());
            log("MATSim population with work destinations for " + sa2 + " saved in " + outFilePath);
        } catch (Exception e) {
            throw new RuntimeException("Error during work SA2 assignment", e);
        }
    }

    private MTWPRecord matchPerson(Person person, Set<MTWPRecord> mtwpRecords, Map<String, Double> sa2DestTotals, OutputStream noMatchOutputStream) throws IOException {
        if (person == null || mtwpRecords == null || mtwpRecords.isEmpty()) {
            return null;
        }
        String gender = (String) person.getAttributes().getAttribute("Gender");
        String age = (String) person.getAttributes().getAttribute("Age");
        AgeGroups ageGroups = binAgeIntoCategory(age);
        String relStatus = (String) person.getAttributes().getAttribute("RelationshipStatus");
        String sa1_7digitcode_2011 = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");

        MTWPRecord match = null;
        for (MTWPRecord mtwpRecord : mtwpRecords) {
            String key = mtwpRecord.sa2Work + "|" + mtwpRecord.transportMode;
            if (!"Total".equals(mtwpRecord.transportMode)
                    && sa2DestTotals.containsKey(key) // exists in the list of totals
                    &&  (sa2DestTotals.get(key) >= 1) // has at least one to assign
                    && gender.equals(mtwpRecord.sex)
                    && (ageGroups == binAgeRangeIntoCategory(mtwpRecord.age))
                    && relStatus.equals(mtwpRecord.relStatus)
                    ) {
                // return the first satisfactory match
                match = mtwpRecord;
                break;
            }

        }
        if (match == null) {
            noMatchOutputStream.write((person.getId()
                    + "|" + gender
                    + "|" + age
                    + "|" + ageGroups.name()
                    + "|" + relStatus
                    + "|" + sa1_7digitcode_2011
                    + "\n").getBytes()
            );
        }
        return match;
    }

    private HashSet<MTWPRecord> readMTWPModeShareFor(String sa2) {
        Path inFilePath = Paths.get(sa2 + "-2-mtwp-modeshare.csv.gz");
        HashSet<MTWPRecord> set = new HashSet<>();
        try {
            InputStream inputStream = new GZIPInputStream(new FileInputStream(inFilePath.toFile()));
            Scanner sc = new Scanner(inputStream, "UTF-8");
            while (sc.hasNextLine()) {
                MTWPRecord mtwpRecord = new MTWPRecord(sc.nextLine().split("\\|"));
                set.add(mtwpRecord);
            }
            // close the streams
            sc.close();
        } catch (IOException e) {
            throw new RuntimeException("Error while parsing " + inFilePath, e);
        }
        return set;
    }

    private void writeMATSimPopulationFor(String sa2, Path inFilePath, Path outFilePath) {

        // read SA1s for given SA2
        log("reading SA1s for " + sa2);
        Set<String> sa1s = readSA1sFor(sa2, CORRESPONDENCE_FILE);


        // write out the subset for this SA2
        log("filtering MATSim population for " + sa2);
        Config config = ConfigUtils.createConfig();
        config.plans().setInputFile(inFilePath.toString());
        Scenario scenario = ScenarioUtils.loadScenario(config);


        // get the counts of various person characteristic types
        List<Id> toRemove = new ArrayList<>();
        for (Person person : scenario.getPopulation().getPersons().values()) {
            String sa1 = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");
            if (sa1 != null && sa1s.contains(sa1)) {
                person.getAttributes().putAttribute("sa2_name_2011", sa2);
            } else {
                toRemove.add(person.getId());
            }
        }

        // remove persons not in this SA2
        for (Id personId : toRemove) {
            scenario.getPopulation().removePerson(personId);
        }

        //Write out the population to xml file
        PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
        writer.write(outFilePath.toString());
        log("MATSim population for " + sa2 + " saved in " + outFilePath);
    }

    /**
     * Writes normalised transport mode share distributions per row
     * @param inFilePath gzipped input file coming from {@link #writeFlatCompressedCSVFor(String, Path, boolean)}
     * @param outFilePath gzipped outout file
     */
    private void writeModeShareDistributions(Path inFilePath, Path outFilePath) {
        try {
            // output flattened CSV while we are at it
            FileOutputStream outputStream = new FileOutputStream(outFilePath.toFile());
            GZIPOutputStream gzipOutputStream = new GZIPOutputStream(outputStream, true);

            // start reading the records
            double totalMode = 0;
            List<MTWPRecord> longRecord = new ArrayList<>();
            InputStream inputStream = new GZIPInputStream(new FileInputStream(inFilePath.toFile()));
            Scanner sc = new Scanner(inputStream, "UTF-8");
            String thisRecord = "";
            while (sc.hasNextLine()) {
                // read the record
                MTWPRecord mtwpRecord = new MTWPRecord(sc.nextLine().split("\\|"));
                if (!thisRecord.equals(mtwpRecord.sa2Work)  && "TotalMode".equals(mtwpRecord.transportMode)) {
                    // new record
                    thisRecord = mtwpRecord.sa2Work;
                    longRecord.clear();
                    totalMode = 0;
                } else if (!thisRecord.equals(mtwpRecord.sa2Work)  && "Multi-mode".equals(mtwpRecord.transportMode)) {
                    // new record + multi-mode
                    thisRecord = mtwpRecord.sa2Work;
                    longRecord.clear();
                    totalMode = 0;
                    longRecord.add(mtwpRecord);
                    totalMode += Double.parseDouble(mtwpRecord.workForce);
                } else if (!"Total".equals(mtwpRecord.transportMode) && !"TotalMode".equals(mtwpRecord.transportMode)) {
                    // mid record
                    longRecord.add(mtwpRecord);
                    totalMode += Double.parseDouble(mtwpRecord.workForce);
                } else if ("Total".equals(mtwpRecord.transportMode) && totalMode > 0) {
                    // long records end in "Total" row
                    for (MTWPRecord record : longRecord) {
                        // calculate the mode share
                        record.modeShare = String.format("%.4f",Double.parseDouble(record.workForce)/totalMode);
                        // write out the row in gzip compressed format
                        gzipOutputStream.write((record.toString()+record.modeShare+"\n").getBytes());
                    }
                    mtwpRecord.workForce = String.format("%.0f",totalMode); // fix Total that has been fuzzified by ABS
                    mtwpRecord.modeShare = String.format("%.4f",Double.parseDouble(mtwpRecord.workForce)/totalMode);
                    gzipOutputStream.write((mtwpRecord.toString()+mtwpRecord.modeShare+"\n").getBytes());

                }
            }

            // close the streams
            gzipOutputStream.close();
            sc.close();

        } catch (IOException e) {
            throw new RuntimeException("Error while parsing " + inFilePath, e);
        }
    }

    /**
     * Reads the MTWP CSV file and writes it back out as a flat CSV file with zero rows suppressed
     * if needed, to an output file in comressed GZip format.
     * <p><b>WARNING:</b> will break if the input MTWP file format changes in any way!<p/>
     * @param file MTWP CSV file
     * @param flatFilePath output file
     * @param includeZeroCountRows whether to include or exclude zero rows
     */
    private void writeFlatCompressedCSVFor(String file, Path flatFilePath, boolean includeZeroCountRows) {
        final int HEADED_ROWS = 11;
        final int FOOTER_ROWS = 7;
        final char PROGRESS_INDICATOR = '.';

        try {
            // get the size of the file so we can show progress
            Path path = Paths.get(file);
            long totalLines = Files.lines(path).count();
            long lastLine = totalLines - FOOTER_ROWS;
            //totalLines = 100000; // or enable this for quick testing

            long lineCount = 0;

            // output flattened CSV while we are at it
            FileOutputStream outputStream     = new FileOutputStream(flatFilePath.toFile());
            GZIPOutputStream gzipOutputStream = new GZIPOutputStream(outputStream,true);

            // start reading the records
            MTWPRecord longRecord = new MTWPRecord();
            MTWPRecord mtwpRecord;
            FileInputStream inputStream = new FileInputStream(file);
            Scanner sc = new Scanner(inputStream, "UTF-8");
            while (sc.hasNextLine()) {
                // read the row
                String line = sc.nextLine();

                // keep count of line read
                lineCount++;

                // show progress as we may be here for a while with super large CSV files
                showProgress(lineCount, totalLines, PROGRESS_INDICATOR);

                // skip the header rows
                if (lineCount <= HEADED_ROWS) {
                    continue;
                }

                // stop if we are into the footer rows
                if (lineCount > lastLine) {
                    break;
                }

                // else read the record
                mtwpRecord = new MTWPRecord(line.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", -1));

                // long records start with the "Multi-mode" row; save them as we go
                if ("Multi-mode".equals(mtwpRecord.transportMode)) {
                    copyFromNonNullFields(mtwpRecord, longRecord);
                }

                // skip if workForce is zero and option to skip is set
                if (!includeZeroCountRows && "0".equals(mtwpRecord.workForce)) {
                    continue;
                }

                // fill empty fields with information from the long record
                copyToNonNullFields(longRecord,mtwpRecord);

                // write out the row in gzip compressed format
                gzipOutputStream.write((mtwpRecord.toString()+"\n").getBytes());
                //gzipOutputStream.flush();
            }

            // close the streams
            gzipOutputStream.close();
            sc.close();

        } catch (IOException e) {
            throw new RuntimeException("Error while parsing " + file, e);
        }
    }


    /**
     * Method to read the shape file and store all the features associated with a given sa2 name (2011)
     */
    private Map<String, SimpleFeature> readShapefile(Path inFile) {
        //reads the shape file in
        SimpleFeatureSource fts = ShapeFileReader.readDataFile(inFile.toString());
        Map<String, SimpleFeature> featureMap = new LinkedHashMap<>();

        //Iterator to iterate over the features from the shape file
        try (SimpleFeatureIterator it = fts.getFeatures().features()) {
            while (it.hasNext()) {

                // get feature
                SimpleFeature ft = it.next();

                // store the feature by SA2 name (because that is the way in which we will need it later)
                featureMap.put(((String)ft.getAttribute("SA2_NAME11")).toLowerCase(), ft);
            }
            it.close();
        } catch (Exception ee) {
            throw new RuntimeException("Error reading shape file features. File : " + inFile, ee);
        }
        return featureMap;
    }

    /**
     * Method to bin age into enum age-range groups
     * @param age
     * @return
     */
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

                return TransportMode.other;
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
    * Method to bin age range strings from the mtwp files into the enum age-range groups
    * */
    public AgeGroups binAgeRangeIntoCategory(String ageRange) {

        switch (ageRange) {
            case "0-14":
                return AgeGroups.u15;
            case "15-24":
                return AgeGroups.b15n24;
            case "25-39":
                return AgeGroups.b25n39;
            case "40-54":
                return AgeGroups.b40n54;
            case "55-69":
                return AgeGroups.b55n69;
            case "70-84":
                return AgeGroups.b70n84;
            case "85-99":
                return AgeGroups.b85n99;
            case "100 years and over":
                return AgeGroups.over100;
            default:
                throw new RuntimeException("unknown age range: " + ageRange);
        }
    }

    /**
     * Copies fields in {@code from} record to the {@code to} record,
     * for all cases where the corresponding field in the {@code to} record is NULL.
     * @param from record to copy from
     * @param to record to copy to
     */
    private void copyToNonNullFields(MTWPRecord from, MTWPRecord to) {
        if (to.sa2Name == null) {
            to.sa2Name = from.sa2Name;
        }
        if (to.sex == null) {
            to.sex = from.sex;
        }
        if (to.age == null) {
            to.age = from.age;
        }
        if (to.relStatus == null) {
            to.relStatus = from.relStatus;
        }
        if (to.lfsp == null) {
            to.lfsp = from.lfsp;
        }
        if (to.sa2Work == null) {
            to.sa2Work = from.sa2Work;
        }
        if (to.transportMode == null) {
            to.transportMode = from.transportMode;
        }
        if (to.workForce == null) {
            to.workForce = from.workForce;
        }
    }

    /**
     * Copies all non-null fields in {@code from} record to the {@code to} record
     * @param from record to copy from
     * @param to record to copy to
     */
    private void copyFromNonNullFields(MTWPRecord from, MTWPRecord to) {
        if (from.sa2Name != null) {
            to.sa2Name = from.sa2Name;
        }
        if (from.sex != null) {
            to.sex = from.sex;
        }
        if (from.age != null) {
            to.age = from.age;
        }
        if (from.relStatus != null) {
            to.relStatus = from.relStatus;
        }
        if (from.lfsp != null) {
            to.lfsp = from.lfsp;
        }
        if (from.sa2Work != null) {
            to.sa2Work = from.sa2Work;
        }
        if (from.transportMode != null) {
            to.transportMode = from.transportMode;
        }
        if (from.workForce != null) {
            to.workForce = from.workForce;
        }
    }

    /**
     * Method to read the look up correspondence file
     * and maps the sa1 7 digit codes (2011) to the corresponding sa2 names (2016)
     */
    private Set<String> readSA1sFor(String sa2, String file) {
        Set<String> sa1s = new HashSet<>();
        String sa2Lower = sa2.toLowerCase();
        try {
            InputStream inputStream = new FileInputStream(file);
            Scanner sc = new Scanner(inputStream, "UTF-8");
            while (sc.hasNextLine()) {
                String[] record = sc.nextLine().split(",");
                if (record.length >= 5 && sa2Lower.equals(record[4].toLowerCase())) {
                    sa1s.add(record[1]);
                }
            }
            // close the streams
            sc.close();
        } catch (IOException e) {
            throw new RuntimeException("Error while parsing " + file, e);
        }
        return sa1s;
    }

    /**
     * Prints out the progress indicator for every percept of progress towards a total
     * @param portion count towards total
     * @param total represents 100%
     * @param PROGRESS_INDICATOR char to use to indicate progress
     */
    private void showProgress(long portion, long total, char PROGRESS_INDICATOR) {
        if (portion % (total / 100) == 0) {
            long percent = portion / (total / 100);
            if (percent % 10 == 0) {
                System.out.println(" " + percent + "%");
            } else {
                System.out.print(PROGRESS_INDICATOR);
            }
        }
    }


    private String usage() {
        return "\n\n" +
                "usage: " + AssignTripsToPopulationDS.class.getName()+
                "  [options] " + "\n\n" +
                "\t"+HELP_OPT+"\t\t\t\tDisplay this usage message and exit\n" +
                "\t"+MATSIM_POPULATION_FILE_OPT+" FILE\tinput MATSim population file (default is "+MATSIM_POPULATION_FILE+")" + "\n" +
                "\t"+MTWP_CSV_FILES_OPT+" SA2:FILE,..\tlist of input MTWP files per SA2 (default is "+MTWP_CSV_FILES+")" + "\n" +
                "\t"+OUTPUT_DIRECTORY_OPT+" DIR\t\toutput directory for generated files (default is "+OUTPUT_DIRECTORY+")" + "\n" +
                "\n\n";
    }

    /**
     * Displays a warning message regarding reuse of interim output file from a previous run
     * @param outFilePath the file in question
     */
    private static String displayReuseWarningMessage(Path outFilePath) {
        return ("found " + outFilePath + " from a earlier run and will re-use that");
    }


    /**
     * Parse the command line arguments
     * @param args command line args
     * @return a valid arg:value map
     */
    private Map<String, String> parse(String[] args) {
        Map<String, String> map = new HashMap<>();
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case HELP_OPT:
                    log(usage());
                    break;
                case MATSIM_POPULATION_FILE_OPT:
                    if (i + 1 < args.length) {
                        i++;
                        map.put(MATSIM_POPULATION_FILE_OPT, args[i]);
                    } else {
                        throw new RuntimeException("argument for "+args[i]+" is missing");
                    }
                    break;
                case MTWP_CSV_FILES_OPT:
                    if (i + 1 < args.length) {
                        i++;
                        map.put(MTWP_CSV_FILES_OPT, args[i]);
                    } else {
                        throw new RuntimeException("argument for "+args[i]+" is missing");
                    }
                    break;
                case OUTPUT_DIRECTORY_OPT:
                    if (i + 1 < args.length) {
                        i++;
                        map.put(OUTPUT_DIRECTORY_OPT, args[i]);
                    } else {
                        throw new RuntimeException("argument for "+args[i]+" is missing");
                    }
                    break;
                default:
                    throw new RuntimeException("unknown config option: " + args[i] + "\n" + usage());
            }
        }
        return map;
    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    public final static class MTWPRecord {
        private String sa2Name;
        private String sex;
        private String age;
        private String relStatus;
        private String lfsp;
        private String sa2Work;
        private String transportMode;
        private String workForce;
        private String modeShare;

        MTWPRecord() {}

        MTWPRecord(String[] fields) {
            if (fields == null) {
                return;
            }
            int index = 0;
            sa2Name = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            sex = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            age = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            relStatus = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            lfsp = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            sa2Work = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            transportMode = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
            workForce = (fields.length > index++ && !fields[index-1].isEmpty()) ? fields[index-1].replace("\"", "") : null;
        }

        @Override
        public String toString() {
            return sa2Name + '|' +
                    sex + '|' +
                    age + '|' +
                    relStatus + '|' +
                    lfsp + '|' +
                    sa2Work + '|' +
                    transportMode + '|' +
                    workForce + '|';
        }
    }

    private void log(String msg) {
        System.out.println(new java.util.Date() + " : " + msg);
    }
}
