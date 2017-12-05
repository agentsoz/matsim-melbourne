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
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.*;

class AddWorkplacesToPopulation {

    private final static String INPUT_CONFIG_FILE = "population-from-latch.xml";
    private final static String ZONES_FILE = "data/shp/2017-11-24-1270055001_sa2_2016_aust_shape/SA2_2016_AUST.shp";
    private final static String OD_MATRIX_FILE = "data/mtwp/2017-11-24-Victoria/UR and POW by MTWP.csv";
    private final Config config;
    private final Scenario scenario;
	Map<String, SimpleFeature> featureMap ;

    public AddWorkplacesToPopulation() {

        config = ConfigUtils.createConfig();
        config.plans().setInputFile(INPUT_CONFIG_FILE);  // add gz after debugging

        scenario = ScenarioUtils.loadScenario(config);
        // (this will read the population file)

    }


    public static void main(String[] args) {
        AddWorkplacesToPopulation abc = new AddWorkplacesToPopulation();
        abc.readShapefile(); // zones as used in the OD matrix.  ASGS
        abc.readODMatrix();
        abc.parsePopulation();
    }

    private void readShapefile() {

        // read shapefile; see CreateDemandFromVISTA for example.
        Population population = this.scenario.getPopulation();
        PopulationFactory pf = population.getFactory();

        //reads the shape file in
        SimpleFeatureSource fts = ShapeFileReader.readDataFile(ZONES_FILE);
        Random rnd = new Random();

        featureMap = new LinkedHashMap<>();

        //Iterator to iterate over the features from the shape file
        try (SimpleFeatureIterator it = fts.getFeatures().features()) {
            while (it.hasNext()) {

                // get feature
                SimpleFeature ft = it.next();

                //A feature contains a geometry (in this case a polygon) and an arbitrary number
                featureMap.put((String) ft.getAttribute("SA2_NAME16"), ft);
            }
            it.close();
        } catch (Exception ee) {
            throw new RuntimeException(ee);
        }

    }

    private void readODMatrix() {

        // csv reader; start at line 12 (or 13); read only car to get started.

        int cnt = 0;
        String previousUR = "";

        try (final BufferedReader reader = new BufferedReader(new FileReader(OD_MATRIX_FILE))) {
            // try-with-resources

            System.out.println("Parsing Matrix file..");

            while(++cnt < 15)
            reader.readLine();

            final CsvToBeanBuilder<Mode> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(Mode.class);
            builder.withSeparator(',');

            final CsvToBean<Mode> reader2 = builder.build();

            Map<String,Integer> mainStateAreaURCarDriveCount = new HashMap<>();
            Map<String,Integer> mainStateAreaURCarPassCount = new HashMap<>();

            int carDrivingWorkPopulation = 0;
            int carPassWorkPopulation = 0;

            long cnt2 = 0 ;
            for (Iterator<Mode> it = reader2.iterator(); it.hasNext(); ) {
                Mode record = it.next();

                if(record.mainStatAreaUR != null) {
                    //if the file read reaches a new UR

					cnt2++ ;
					System.out.print(".") ;
					if ( cnt2 % 80 == 0 ) {
						System.out.println() ;
					}

                    if(record.mainStatAreaUR.toLowerCase().equals("total")) {

                        System.out.println("Parsing matrix finished..");
                        break;
                    }
                    mainStateAreaURCarDriveCount.put(previousUR,carDrivingWorkPopulation);
                    mainStateAreaURCarPassCount.put(previousUR,carPassWorkPopulation);

                    previousUR = record.mainStatAreaUR;

                    carDrivingWorkPopulation = 0;
                    carPassWorkPopulation = 0;

                }else {
                    //if the file is still currently in the same UR

                    carDrivingWorkPopulation += Integer.parseInt(record.carAsDriver);

                    carPassWorkPopulation += Integer.parseInt(record.carAsPassenger);

                    record.mainStatAreaUR = new String(previousUR);

                    record.carAsDriverCumulative = carDrivingWorkPopulation;
                    record.carAsPassengerCumulative = carPassWorkPopulation;
                }
//                System.out.print("UR :"+record.mainStatAreaUR+" ");
//                System.out.print("POW :"+record.mainStatAreaPOW+" "+"\n");
//                System.out.print("carD :"+record.carAsDriver+" ");
//                System.out.println("carDrCumulative :"+record.carAsDriverCumulative);
//                System.out.println("carP :"+record.carAsPassenger);
//                System.out.println("carPassCumulative :"+record.carAsPassengerCumulative);


            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void pickRandomWorkdestination(){

        Random rnd = new Random();

    }

    private void parsePopulation() {
        Random rnd = new Random(4711);

        for (Person person : scenario.getPopulation().getPersons().values()) {

            String homeCoordString = (String)person.getAttributes().getAttribute("homeCoords"); // add home coordinates into attributes!

            Coord homeCoord = new Coord(Double.parseDouble(homeCoordString.split(",")[0]),Double.parseDouble(homeCoordString.split(",")[1]));

			Coordinate coordinate = CoordUtils.createGeotoolsCoordinate(homeCoord) ;
			Point point = new GeometryFactory().createPoint( coordinate ) ;
   
			String origin = null ;


//			int count = 0;
//			for(String sa2Name : this.featureMap.keySet()) {
//                System.out.println(count);
//                count++;
//				final Geometry geometry = (Geometry) (this.featureMap.get(sa2Name)).getDefaultGeometry();
//				if(geometry !=null)
//					if (geometry.contains(point)) {
//
//						origin = sa2Name;
//						break;
//
//					}
//			}
			
			
            for ( SimpleFeature ft1 : this.featureMap.values() ) {
				Gbl.assertNotNull(ft1) ;
				final Geometry geometry = (Geometry) ft1.getDefaultGeometry();
				if ( geometry != null ) {
					if (geometry.contains(point)) {
						origin = (String) ft1.getAttribute("SA2_NAME16");
						Gbl.assertNotNull(origin);
						break;
					}
				} else {
					System.out.println( "geometry is null; to check; feature=" + ft1.toString() ) ;
				}
            }
            System.out.println(origin);
	
			System.exit(-1) ;

            String destination = null; // draw destination from OD Matrix.   Start with car only.

            SimpleFeature ft = null; // get this from the shp file

//			Point point = CreateDemandFromVISTA.getRandomPointInFeature(rnd, ft);
//			final Coord coord = new Coord(point.getX(), point.getY());
            final Coord coord = new Coord(50000., 50000.);

            Leg leg = scenario.getPopulation().getFactory().createLeg(TransportMode.car);
            person.getSelectedPlan().addLeg(leg);

            Activity act = scenario.getPopulation().getFactory().createActivityFromCoord("work", coord);
            person.getSelectedPlan().addActivity(act);

            // todo: add trip back home

        }

        PopulationWriter writer = new PopulationWriter(scenario.getPopulation());
        writer.write("population-with-home-work-trips.xml");

    }

    /**
     * Class to build the records bound by the column header found in the csv file
     */
    public final static class Mode {
        // needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17

        @CsvBindByPosition(position = 0)
        private String mainStatAreaUR;

        @CsvBindByPosition(position = 1)
        private String mainStatAreaPOW;

        @CsvBindByPosition(position = 6)
        private String carAsDriver;

        private int carAsDriverCumulative;

        @CsvBindByPosition(position = 7)
        private String carAsPassenger;

        private int carAsPassengerCumulative;



    }

}
