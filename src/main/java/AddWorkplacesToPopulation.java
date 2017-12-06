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

class AddWorkplacesToPopulation {

    private final static String INPUT_CONFIG_FILE = "population-from-latch.xml";
    private final static String ZONES_FILE = "data/shp/2017-11-24-1270055001_sa2_2016_aust_shape/SA2_2016_AUST.shp";
    private final static String OD_MATRIX_FILE = "data/mtwp/2017-11-24-Victoria/UR and POW by MTWP.csv";
    private final Config config;
    private final Scenario scenario;
    private final PopulationFactory pf ;
	Map<String, SimpleFeature> featureMap ;
	Map<String,String> sa2NameFromSa1Id ;
	Map<String,Map<String,Map<String,Double>>> odMatrix ;

    public AddWorkplacesToPopulation() {

        config = ConfigUtils.createConfig();
        config.plans().setInputFile(INPUT_CONFIG_FILE);  // add gz after debugging

        scenario = ScenarioUtils.loadScenario(config);
        // (this will read the population file)
		
		pf = scenario.getPopulation().getFactory() ;

    }


    public static void main(String[] args) {
        AddWorkplacesToPopulation abc = new AddWorkplacesToPopulation();
        abc.readShapefile(); // zones as used in the OD matrix.  ASGS
		abc.readCorrespondences() ;
        abc.readODMatrix();
        abc.parsePopulation();
    }
	
	private void readCorrespondences() {
    	// this reads the table that allows to look up SA2 names from the SA1 IDs from latch.
		
		// you will need something like
		String sa1Id = null ;
		String sa2Name = null ;
		sa2NameFromSa1Id.put(sa1Id, sa2Name) ;
		
		
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

                // store the feature by SA2 name (because that is the way in which we will need it later)
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
        
        // TODO I think that this so far only reads the summary.

        try (final BufferedReader reader = new BufferedReader(new FileReader(OD_MATRIX_FILE))) {
            // try-with-resources

            System.out.println("Parsing Matrix file..");

            while(++cnt < 15)
            reader.readLine();

            final CsvToBeanBuilder<Record> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(Record.class);
            builder.withSeparator(',');

            final CsvToBean<Record> reader2 = builder.build();

//            Map<String,Integer> mainStateAreaURCarDriveCount = new HashMap<>();
//            Map<String,Integer> mainStateAreaURCarPassCount = new HashMap<>();
//
//            int carDrivingWorkPopulation = 0;
//            int carPassWorkPopulation = 0;

            long cnt2 = 0 ;
            
            String currentOrigin = null ;
            
            for (Iterator<Record> it = reader2.iterator(); it.hasNext(); ) {
                Record record = it.next();

                if(record.mainStatAreaUR != null) {
                    //if the file read reaches a new UR
	
					cnt2++ ;
					System.out.print(".") ;
					if ( cnt2 % 80 == 0 ) {
						System.out.println() ;
					}
	
					// memorize the origin name:
					currentOrigin = record.mainStatAreaUR ;
					// start new table for all destinations from this new origin ...
					Map<String,Map<String,Double>> destinations = new HashMap<>() ;
					// ... and put it into the OD matrix:
					odMatrix.put( record.mainStatAreaUR, destinations ) ;
					
                    if(record.mainStatAreaUR.toLowerCase().equals("total")) {

                        System.out.println("Parsing matrix finished..");
                        break;
                    }
//                    mainStateAreaURCarDriveCount.put(previousUR,carDrivingWorkPopulation);
//                    mainStateAreaURCarPassCount.put(previousUR,carPassWorkPopulation);
//
//                    previousUR = record.mainStatAreaUR;
//
//                    carDrivingWorkPopulation = 0;
//                    carPassWorkPopulation = 0;

                }
//                else {
//                    //if the file is still currently in the same UR
//
//					// somehow I don't think that we need the following:
//                    carDrivingWorkPopulation += Integer.parseInt(record.carAsDriver);
//
//                    carPassWorkPopulation += Integer.parseInt(record.carAsPassenger);
//
//                    record.mainStatAreaUR = new String(previousUR);
//
//                    record.carAsDriverCumulative = carDrivingWorkPopulation;
//                    record.carAsPassengerCumulative = carPassWorkPopulation;
//                }
                
                // this is what we need to do for every record:

				// start new table for the specific destination in current row ...
				Map<String,Double> nTripsByMode = new HashMap<>() ;
				// .. and put in the od matrix:
				odMatrix.get(currentOrigin).put( record.mainStatAreaPOW, nTripsByMode ) ;
				// memorize the car value (we forget all others for the time being):
				nTripsByMode.put( TransportMode.car, Double.parseDouble(record.carAsDriver ) ) ;



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
	
			// get sa1Id (which comes from latch):
			String sa1Id = (String) person.getAttributes().getAttribute("sa1Id");
			Gbl.assertNotNull(sa1Id);
	
			// get corresponding sa2name (which comes from the correspondences file):
			String sa2name = this.sa2NameFromSa1Id.get(sa1Id);
			Gbl.assertNotNull(sa2name);
			
			// find corresponding destinations from the OD matrix:
			Map<String, Map<String, Double>> destinations = odMatrix.get(sa2name);
			
			// sum over all destinations (yes, agreed, we could have done this earlier; at this point I prefer better being safe than sorry)
			double sum = 0. ;
			for ( Map<String,Double> nTripsByMode : destinations.values() ) {
				sum += nTripsByMode.get(TransportMode.car ) ;
			}
			
			// throw random number
			int tripToTake = rnd.nextInt((int) sum);
			// variable to store destination name:
			String destinationSa2Name=null ;
			double sum2 = 0. ;
			for ( Map.Entry<String,Map<String,Double>> entry : destinations.entrySet() ) {
				Map<String, Double> nTripsByMode = entry.getValue();;
				sum2 += nTripsByMode.get(TransportMode.car ) ;
				if ( sum2 > tripToTake ) {
					// this our trip!
					destinationSa2Name = entry.getKey() ;
					break ;
				}
			}
			Gbl.assertNotNull(destinationSa2Name);
			
			// find a coordinate for the destination:
			SimpleFeature ft = this.featureMap.get( destinationSa2Name ) ;
			Point point = CreateDemandFromVISTA.getRandomPointInFeature(rnd, ft);
			Gbl.assertNotNull(point);
	
			// add the leg and act (only if the above has not failed!)
			Leg leg = pf.createLeg( TransportMode.car ) ; // yyyy needs to be fixed; currently only looking at car
			person.getSelectedPlan().addLeg(leg);
	
			Coord coord = new Coord( point.getX(), point.getY() ) ;
			Activity act = pf.createActivityFromCoord("work", coord) ;
			person.getSelectedPlan().addActivity(act);
			
			// check what we have:
			System.out.println( "plan=" + person.getSelectedPlan() );
			for ( PlanElement pe : person.getSelectedPlan().getPlanElements() ) {
				System.out.println( "pe=" + pe ) ;
			}
			
			// we leave it at this; the trip back home we do later.
		}

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

        private int carAsDriverCumulative;

        @CsvBindByPosition(position = 7)
        private String carAsPassenger;

        private int carAsPassengerCumulative;



    }

}
