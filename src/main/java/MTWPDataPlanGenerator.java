//package au.edu.unimelb.imod.demand;

import java.io.*;

public class MTWPDataPlanGenerator {

    private final static String MATRIX_FILE_PATH = "data/mtwp/Victoria_SA2_UR_by_SA2_POW.csv";


    public static void main(String args[]) {


        MTWPDataPlanGenerator mt = new MTWPDataPlanGenerator();

        //Converts file Format from a matrix to a flat comma-separated format
        mt.convertToFlat();


        SyntheticPopulationManager syn = new SyntheticPopulationManager();
        syn.convertSyntheticPersonsToVista();
        syn.convertJSONHMap();
        syn.addSyntheticPersonToPopulation();


    }

    private void convertToFlat() {

        int lineCount = 0;
        BufferedReader bf;


        try {
            bf = new BufferedReader(new FileReader(MATRIX_FILE_PATH));

            String line = bf.readLine();
            String[] headers = line.split(",");

            while (line != null) {

                if (lineCount == 0) {
                    lineCount++;
                    line = bf.readLine();
                    continue;

                }

                String[] entries = line.split(",");

                for (int ii = 1; ii < entries.length-1; ii++) {

                    if(entries[0].equals("Total"))
                    continue;

//                    System.out.println(entries[0] + "," + headers[ii] + "," + entries[ii]);
                }
                line = bf.readLine();

            }
            System.out.println("Matrix file conversion complete..");
            bf.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}