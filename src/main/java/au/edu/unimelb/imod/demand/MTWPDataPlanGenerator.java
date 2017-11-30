package au.edu.unimelb.imod.demand;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

public class MTWPDataPlanGenerator {

    private final static String FILE_PATH = "data/mtwp/Victoria_SA2_UR_by_SA2_POW.csv";

    public void convertToFlat() {

        int lineCount = 0;
        BufferedReader bf;


        try {
            bf = new BufferedReader(new FileReader(FILE_PATH));

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

    public static void main(String args[]) {

        MTWPDataPlanGenerator mt = new MTWPDataPlanGenerator();
        mt.convertToFlat();
    }
}