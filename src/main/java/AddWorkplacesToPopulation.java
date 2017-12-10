import au.edu.unimelb.imod.demand.CreateDemandFromVISTA;
import com.opencsv.bean.*;
import com.vividsolutions.jts.geom.Coordinate;
import com.vividsolutions.jts.geom.Geometry;
import com.vividsolutions.jts.geom.GeometryFactory;
import com.vividsolutions.jts.geom.Point;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.api.core.v01.population.*;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.core.utils.geometry.CoordUtils;
import org.matsim.core.utils.geometry.GeometryUtils;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.*;

/**
 * Class to add working places to the synthetic population
 */
class AddWorkplacesToPopulation {

    private final static String INPUT_CONFIG_FILE = "population-from-latch.xml";
    private final static String ZONES_FILE =
            "data/census/2011/shp/2017-12-06-1270055001_sa2_2011_aust_shape/SA2_2011_AUST" +
                    ".shp";
    private final static String OD_MATRIX_FILE = "data/census/2011/mtwp/2017-11-24-Victoria/UR and POW by MTWP.csv";
    private final static String CORRESPONDENCE_FILE =
            "data/census/2011/correspondences/2017-12-06-1270055001_sa2_sa1_2011_mapping_aust_shape/SA1_2011_AUST.csv";

    private final Config config;
    private final Scenario scenario;
    private final PopulationFactory pf;
    Map<String, SimpleFeature> featureMap;
    Map<String, String> sa2NameFromSa1Id;
    Map<String, Map<String, Map<String, Double>>> odMatrix;
    // something like odMatrix.get(origin).get(destination).get(mode)

/**
 * Constructor
 * */
    public AddWorkplacesToPopulation() {

        config = ConfigUtils.createConfig();

        config.plans().setInputFile(INPUT_CONFIG_FILE);
        // currently generates add gz after debugging

        scenario = ScenarioUtils.loadScenario(config);
        // (this will read the population file)

        pf = scenario.getPopulation().getFactory();

    }

    /**
     * Main method
     *
     * @param args
     */
    public static void main(String[] args) {
        AddWorkplacesToPopulation abc = new AddWorkplacesToPopulation();
        abc.readShapefile(); // zones as used in the OD matrix.  ASGS
        abc.readCorrespondences();
        abc.readODMatrix();
        abc.parsePopulation();
    }

    /**
     * Method to read the mapping correspondence file
     * to map the sa1 7 digit codes (2011) to the sa2 names (2011)
     */
    private void readCorrespondences() {
        // this reads the table that allows to look up SA2 names from the SA1 IDs from latch.

        sa2NameFromSa1Id = new HashMap<String, String>();

        try (final BufferedReader reader = new BufferedReader(new FileReader(CORRESPONDENCE_FILE))) {
            // try-with-resources

            System.out.println("Parsing Correspondences file..");

            final CsvToBeanBuilder<SAMap> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(SAMap.class);
            builder.withSeparator(',');

            final CsvToBean<SAMap> reader2 = builder.build();

            for (Iterator<SAMap> it = reader2.iterator(); it.hasNext(); ) {
                SAMap saMap = it.next();

                sa2NameFromSa1Id.put(saMap.SA1_7DIGITCODE_2011, saMap.SA2_NAME_2011);
            }

        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * Method to read the shape file and store all the features associated with a given sa2 name (2011)
     */
    private void readShapefile() {

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
            throw new RuntimeException(ee);
        }

    }

    /**
     * Method to read the OD matrix which stores the home-work place journeys Victoria(??) (2011)
     *
     */
    private void readODMatrix() {

        // csv reader; start at line 12 (or 13); read only car to get started.

        int cnt = 0;

        Map<String, Double> mode = new HashMap<>();
        Map<String, Map<String, Double>> destinations = new LinkedHashMap<>();
        odMatrix = new HashMap<>();

        // TODO I think that this so far only reads the summary.

        try (final BufferedReader reader = new BufferedReader(new FileReader(OD_MATRIX_FILE))) {
            // try-with-resources

            System.out.println("Parsing Matrix file..");

            while (++cnt < 15)

                reader.readLine();

            final CsvToBeanBuilder<Record> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(Record.class);
            builder.withSeparator(',');

            final CsvToBean<Record> reader2 = builder.build();


            long cnt2 = 0;

            String currentOrigin = "";


            for (Iterator<Record> it = reader2.iterator(); it.hasNext(); ) {
                Record record = it.next();

                if (record.mainStatAreaUR != null) {
                    //if the file read reaches a new UR

                    cnt2++;
                    System.out.print(".");
                    if (cnt2 % 80 == 0) {
                        System.out.println();
                    }


                    // memorize the origin name:
                    currentOrigin = record.mainStatAreaUR;

                    if (currentOrigin.equals("Main Statistical Area Structure (Main ASGS) (UR)"))
                        continue;

                    mode = new HashMap<>();

                    // start new table for all destinations from this new origin ...
                    destinations = new LinkedHashMap<>();

                    // ... and put it into the OD matrix:
                    odMatrix.put(currentOrigin, destinations);

                    if (record.mainStatAreaUR.toLowerCase().equals("total")) {

                        System.out.println("Parsing matrix finished..");
                        break;
                    }


                }

                // this is what we need to do for every record:

                //Using only car as driver for now as the TransportMode class contains a singular mode for car
                //???????????????????????????????????????
                mode.put(TransportMode.car, Double.parseDouble(record.carAsDriver));
//                mode.put("carPassenger", Double.parseDouble(record.carAsPassenger));
                destinations.put(record.mainStatAreaPOW, mode);

                // .. and put in the od matrix:
                odMatrix.get(currentOrigin).put(record.mainStatAreaPOW, mode);


            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * Method to retrieve the population and add the home-work trip to each person
     * using the home starting coordinates, and random selection of work trip destination
     * scaled from the OD matrix file
     */
    private void parsePopulation() {
        Random rnd = new Random(4711);

        for (Person person : scenario.getPopulation().getPersons().values()) {

            String sa1Id = (String) person.getAttributes().getAttribute("sa1_7digitcode_2011");
            Gbl.assertNotNull(sa1Id);

            // get corresponding sa2name (which comes from the correspondences file):
            String sa2name = this.sa2NameFromSa1Id.get(sa1Id);
            Gbl.assertNotNull(sa2name);

            // find corresponding destinations from the OD matrix:
            Map<String, Map<String, Double>> destinations = odMatrix.get(sa2name);

            // sum over all destinations
            double sum = 0.;
            for (Map<String, Double> nTripsByMode : destinations.values()) {
                sum += nTripsByMode.get(TransportMode.car);
            }

            // throw random number
            int tripToTake = rnd.nextInt((int) sum + 1);

            // variable to store destination name:
            String destinationSa2Name = null;
            double sum2 = 0.;

            for (Map.Entry<String, Map<String, Double>> entry : destinations.entrySet()) {
                Map<String, Double> nTripsByMode = entry.getValue();

                sum2 += nTripsByMode.get(TransportMode.car);
                if (sum2 > tripToTake) {

                    // this our trip!
                    destinationSa2Name = entry.getKey();
                    break;
                }
            }
            Gbl.assertNotNull(destinationSa2Name);

            // find a coordinate for the destination:
            SimpleFeature ft = this.featureMap.get(destinationSa2Name);
            Gbl.assertNotNull(ft);

            Gbl.assertNotNull(ft.getDefaultGeometry()); // otherwise no polygon, cannot get a point.

            Point point = CreateDemandFromVISTA.getRandomPointInFeature(rnd, ft);
            Gbl.assertNotNull(point);

            // add the leg and act (only if the above has not failed!)
            Leg leg = pf.createLeg(TransportMode.car); // yyyy needs to be fixed; currently only looking at car
            person.getSelectedPlan().addLeg(leg);

            Coord coord = new Coord(point.getX(), point.getY());
            Activity act = pf.createActivityFromCoord("work", coord);
            person.getSelectedPlan().addActivity(act);

            // check what we have:
            System.out.println("plan=" + person.getSelectedPlan());
            for (PlanElement pe : person.getSelectedPlan().getPlanElements()) {
                System.out.println("pe=" + pe);
            }

            // we leave it at this; the trip back home we do later.
        }

        //Write out the population to xml file
        PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
        writer.write("population-with-home-work-trips.xml");

    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    public final static class Record {
        // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

        @CsvBindByPosition(position = 0)
        private String mainStatAreaUR;

        @CsvBindByPosition(position = 1)
        private String mainStatAreaPOW;

        @CsvBindByPosition(position = 6)
        private String carAsDriver;

        //private int carAsDriverCumulative;

//        @CsvBindByPosition(position = 7)
//        private String carAsPassenger;

        //private int carAsPassengerCumulative;

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


}
