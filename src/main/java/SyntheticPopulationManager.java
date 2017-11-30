import com.google.gson.Gson;
import com.vividsolutions.jts.algorithm.HCoordinate;
import jdk.nashorn.internal.parser.JSONParser;

import java.io.*;
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

    private static class HMAP{

        private List<HFeature> features;

    }

    private static class HFeature{

        private HProperty hproperty;
        private HGeometry hgeometry;
        private String householdID;

    }

    private static class HProperty{

        private String EZI_ADD;
        private String state;
        private String postCode;
        private String LGA_Code;
        private String Locality;
        private String SA1_7DIG11;
        private String bedd;
        private String strd;
        private String tenlld;
        private String type;


    }

    private static class HGeometry {

        List<HHCoordinate> coordinates;
    }

    private static class HHCoordinate{

        private float lat;
        private float longit;
    }

        private final static String SYNTHETIC_PERSONS_FILE_PATH = "C:\\Users\\persnal\\git\\matsim-melbourne\\data\\latch\\AllAgents.csv";
    private final static String SYNTHETIC_HMAP_FILE_PATH = "C:\\Users\\persnal\\git\\matsim-melbourne\\data\\latch\\Hh-mapped-address.json";

    private static class HouseHold{


    }

    //Read files - convert to  vista format
    public void convertSyntheticPersonsToVista(){

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

                System.out.println(headerline);

                String[] synFileLine = new String[5];
                for (int ii = 0; ii < entries.length; ii++) {

                    if (ii < 5)
                        synFileLine[ii] = entries[ii];

                    System.out.print(entries[ii] + ",");

                }

                fw.write(synFileLine[0] + "," + synFileLine[3] + "," + synFileLine[1] + "," + synFileLine[2] + ",,,,,\n");

                System.out.println();
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

    public static void convertJSONHMap(){

        BufferedReader fr;
        String json = "";
        String line;

        try {


            fr = new BufferedReader( new FileReader(SYNTHETIC_HMAP_FILE_PATH));

            while((line=fr.readLine())!=null)
                json += line;

            HFeature data = new Gson().fromJson(json, HFeature.class);

            fr.close();

            System.out.println(data);
        } catch (FileNotFoundException e) {

            e.printStackTrace();

        } catch (IOException e) {

            e.printStackTrace();
        }

    }
    //use CreateVistaDemand to parse new file to convert to MatSIM format


}

