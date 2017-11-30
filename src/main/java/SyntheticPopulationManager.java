import com.google.gson.Gson;
import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;

import java.io.*;
import java.lang.reflect.Type;
import java.util.List;

public class SyntheticPopulationManager {
//
//    private static class Person{
//
//        String personID;
//        String householdID;
//        int age;
//        String sex;
//
//
//    }

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

            return hproperty.toString() + "," + hgeometry.toString() + "," + householdID;
        }
    }

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


    private final static String SYNTHETIC_PERSONS_FILE_PATH = "data/latch/AllAgents.csv";
    private final static String SYNTHETIC_HMAP_FILE_PATH = "data/latch/Hh-mapped-address.json";

    //Read files - convert to  vista format
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
            json = "{\"features\":[" +
                    "{\"properties\":" +
                    "{\"EZI_ADD\":\"12 WATERLOO ROAD NORTHCOTE 3070\",\"STATE\":\"VIC\",\"POSTCODE\":\"3070\",\"LGA_CODE\":\"316\",\"LOCALITY\":\"NORTHCOTE\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2111138\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"}," +
                    "\"geometry\":{\"coordinates\":[324058.8753037447,5817187.2590698935]}," +
                    "\"HOUSEHOLD_ID\":\"11604\"}," +
                    "{\"properties\":{\"EZI_ADD\":\"38 MACORNA STREET WATSONIA NORTH 3087\",\"STATE\":\"VIC\",\"POSTCODE\":\"3087\",\"LGA_CODE\":\"303\",\"LOCALITY\":\"WATSONIA NORTH\",\"ADD_CLASS\":\"S\",\"SA1_7DIG11\":\"2120407\",\"BEDD\":\"3 bedroom\",\"STRD\":\"Detached House\",\"TENLLD\":\"Owner\",\"TYPE\":\"RESIDENTIAL\"}," +
                    "\"geometry\":{\"coordinates\":[331160.92976421374,5825765.298372125]}," +
                    "\"HOUSEHOLD_ID\":\"64297\"}]}";

            Gson gson = new Gson();
            HMAP data = gson.fromJson(json,HMAP.class);


            System.out.println(data.toString());
        } catch (FileNotFoundException e) {

            e.printStackTrace();

        } catch (IOException e) {

            e.printStackTrace();
        }

    }
    //use CreateVistaDemand to parse new file to convert to MatSIM format


}

