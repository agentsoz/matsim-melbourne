import com.google.gson.Gson;
import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.Plan;
import org.matsim.api.core.v01.population.Population;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;

import java.io.*;
import java.util.List;

public class SyntheticPopulationManager {

    private final static String SYNTHETIC_PERSONS_FILE_PATH = "data/latch/AllAgents.csv";
    private final static String SYNTHETIC_GENERATED_PERSONS_FILE_PATH = "data/Synthetic_Persons.csv";
    private final static String SYNTHETIC_HMAP_FILE_PATH = "data/latch/Hh-mapped-address.json";
    private final Scenario scenario;

    SyntheticPopulationManager() {

        this.scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig());
        //do nothing

    }

    /*Read files - convert to  vista format*/
    public void convertSyntheticPersonsToVista() {

        int lineCount = 0;
        BufferedReader bfr;
        FileWriter fw;

        try {
            bfr = new BufferedReader(new FileReader(SYNTHETIC_PERSONS_FILE_PATH));
            fw = new FileWriter("data/Synthetic_Persons.csv");

            String headerline = bfr.readLine();
            String line = headerline;

            while (line != null) {

                if (lineCount == 0) {
                    lineCount++;
                    line = bfr.readLine();

                    fw.write("PERSID,HHID,AGE,SEX,MAINACT,STUDYING,ADPERSWGT,WDPERSWGT,WEPERSWGT\n");
                    continue;

                }
                String[] entries = line.split(",");

                //System.out.println(headerline);

                String[] synFileLine = new String[5];
                for (int ii = 0; ii < entries.length; ii++) {

                    if (ii < 5)
                        synFileLine[ii] = entries[ii];

                    //System.out.print(entries[ii] + ",");

                }

                fw.write(synFileLine[0] + "," + synFileLine[3] + "," + synFileLine[1] + "," + synFileLine[2] + ",,,,,\n");

                //System.out.println();
                line = bfr.readLine();

            }
            bfr.close();
            fw.close();

        } catch (FileNotFoundException e) {

            e.printStackTrace();

        } catch (IOException e) {

            e.printStackTrace();
        }
    }

    /*Gets JSON file for the House Hold Mapped Address File and stores it in Java objects
    using the GSON converter
    * */
    public void convertJSONHMap() {
        BufferedReader fr;
        String json = "";
        String line;

        try {


            fr = new BufferedReader(new FileReader(SYNTHETIC_HMAP_FILE_PATH));

            while ((line = fr.readLine()) != null)
                json += line;

            fr.close();

            //System.out.println(json);

            //Testing String for JSON file storage as Java Object
            //Original file is large about 43 MB takes considerable time
            json = "{\"features\":[{\"properties\":{\"EZI_ADD\":\"12 WATERLOO ROAD NORTHCOTE 3070\",\"STATE\":\"VIC\",\"POSTCODE\":\"3070\",\"LGA_CODE\":\"316\",\"LOCALITY\":\"NORTHCOTE\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2111138\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[324058.8753037447,5817187.2590698935]},\"HOUSEHOLD_ID\":\"11604\"},{\"properties\":{\"EZI_ADD\":\"38 MACORNA STREET WATSONIA NORTH 3087\",\"STATE\":\"VIC\",\"POSTCODE\":\"3087\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"WATSONIA NORTH\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120407\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[331160.92976421374,5825765.298372125]},\"HOUSEHOLD_ID\":\"64297\"},{\"properties\":{\"EZI_ADD\":\"27 DURHAM STREET EAGLEMONT 3084\",\"STATE\":\"VIC\",\"POSTCODE\":\"3084\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"EAGLEMONT\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120112\",\"BEDD\":\"4 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[329627.89563218964,5818811.241577283]},\"HOUSEHOLD_ID\":\"49237\"},{\"properties\":{\"EZI_ADD\":\"30 KILLERTON CRESCENT HEIDELBERG WEST 3081\",\"STATE\":\"VIC\",\"POSTCODE\":\"3081\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"HEIDELBERG WEST\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2119902\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[327226.127194053,5821253.361783082]},\"HOUSEHOLD_ID\":\"38295\"},{\"properties\":{\"EZI_ADD\":\"5/68 YARRA STREET HEIDELBERG 3084\",\"STATE\":\"VIC\",\"POSTCODE\":\"3084\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"HEIDELBERG\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2119810\",\"BEDD\":\"2 bedroom\",\"STRD\":\"Flats or units (3 storeys or less)\",\"TENLLD\":\"Private Renter\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[329383.2924766755,5819340.600254489]},\"HOUSEHOLD_ID\":\"34846\"},{\"properties\":{\"EZI_ADD\":\"35A CAMERON STREET RESERVOIR 3073\",\"STATE\":\"VIC\",\"POSTCODE\":\"3073\",\"LGA_CODE\":\"316\",\"LOCALITY\":\"RESERVOIR\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120829\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"},\"geometry\":{\"coordinates\":[323503.89143659646,5822569.286676848]},\"HOUSEHOLD_ID\":\"100800\"}]}";

            Gson gson = new Gson();
            HMAP data = gson.fromJson(json, HMAP.class);


            System.out.println(data.toString());
        } catch (FileNotFoundException e) {

            e.printStackTrace();

        } catch (IOException e) {

            e.printStackTrace();
        }

    }

    public void addSyntheticPersonToPopulation() {

		/*
         * Code below taken from the createPUSPersons in CreateDemandFromVISTA file
		 *
		 * Could explore using the createPUSPersons method by adding a filename parameter to enable code re-use
		 *
		 * Uncertain of the parameter "scenario" how it interacts with the population in VISTA population
		 * compared to this synthetic population
		 *
		 * For convenience and code readability store population and population factory in a local variable
		 *
		 */

        Population population = this.scenario.getPopulation();
        PopulationFactory populationFactory = population.getFactory();

		/*
         * Read the PUS file
		 */
        try (BufferedReader bufferedReader = new BufferedReader(new FileReader(SYNTHETIC_GENERATED_PERSONS_FILE_PATH))) {
            bufferedReader.readLine(); //skip header

            int index_personId = 0;

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
            System.out.println("population done" + "\n" + population);

        } catch (FileNotFoundException e) {

            System.err.println("File : " + SYNTHETIC_GENERATED_PERSONS_FILE_PATH + "not created");

            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    /*
    * Class to store data from the house hold mapped address JSON file created from the LATCH algorithm
    * */
    public static class HMAP {

        @SerializedName("features")
        @Expose
        private List<HFeature> features;

        @Override
        public String toString() {

            String s = "";

            for (HFeature hf : features)
                s += hf.toString() + "\n";

            return s;
        }
    }

    /*Class to store different features from the House hold mapped address JSON file
    * */
    private static class HFeature {

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

            String s = "";
            for (Float hc : coordinates)
                s += Float.toString(hc) + ",";

            return s;
        }
    }


}

