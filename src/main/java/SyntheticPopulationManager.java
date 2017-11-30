import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

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

    private final static String SYNTHETIC_PERSONS_FILE_PATH = "data/matsim-melbourne/data/latch";

    private static class HouseHold{


    }

    //Read files - convert to  vista format
    public void convertSyntheticToVista(){

        int lineCount = 0;
        BufferedReader bf;

        try {
            bf = new BufferedReader(new FileReader(SYNTHETIC_PERSONS_FILE_PATH));

            String line = bf.readLine();
            String[] headers = line.split(",");

            while (line != null) {

                if (lineCount == 0) {
                    lineCount++;
                    continue;

                }
                String[] entries = line.split(",");

                for (int ii = 1; ii < entries.length; ii++) {

                    System.out.println(entries[0] + "," + headers[ii] + "," + entries[ii]);
                }
                line = bf.readLine();

            }
            bf.close();
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
    //use CreateVistaDemand to parse new file to convert to MatSIM format


}

