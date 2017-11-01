package au.edu.unimelb.imod.demand;

import java.util.ArrayList;

import au.edu.unimelb.imod.demand.ZahraClass.SAs;

public class VarriatingXAndY {

	public static void main(String[] args) {
		
		String [][] personString = ZahraUtility.Data(420408, 11, "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/variatedxandY/personsTripAllWithDiff.csv");
		String[][] saString = ZahraUtility.Data(840808, 22, "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/Random_ODs_zahra.txt");
		
		int originSATrip_index = 5;
		int destinationSATrip_index = 6;
		int sa_index = 5;
		int originXTrip_index = 7;
		int originYTrip_index = 8;
		int destinationXTrip_index = 9;
		int destinationYTrip_index = 10;
		int X_index = 20;
		int Y_index = 21;
		ArrayList <SAs> saData = new ArrayList<SAs>();
		
		for (int i = 1 ; i <saString.length ; i++)
		{
			saData.add(new SAs(saString[i][sa_index].trim(),saString[i][X_index].trim(),saString[i][Y_index].trim()));
		}
		
		System.out.println("reading done");
		System.out.println("saData: " + saData.size());
		
		String fileContent = "";
		StringBuilder strb = new StringBuilder();
		for (int i = 1 ; i < personString.length ; i++)
		{
			String originSA = personString[i][originSATrip_index];
			for (int j = 0 ; j < saData.size() ; j++)
			{

				if (saData.get(j).saCode.equals(originSA))
				{
					personString[i][originXTrip_index] = saData.get(j).xCoord.toString();
					personString[i][originYTrip_index] = saData.get(j).yCoord.toString();
					saData.remove(j);
					break;
				}
			}
			
			for (int j = 0 ; j < 11 ; j++)
			{
				strb.append(personString[i][j] + ",");
			}
			strb.append("\n");
			
			if(i%1000 == 0)
				System.out.println(i + ", saData: " + saData.size());
		}
				
		System.out.println("origins done");
			
		ZahraUtility.write2File(strb.toString(), "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/variatedxandY/origins.csv");
		System.out.println("writing origins done");
		
		StringBuilder fileContentD = new StringBuilder();
		for (int i = 1 ; i < personString.length ; i++)
		{
			String destinationSA = personString[i][destinationSATrip_index];
			for (int j = 0 ; j < saData.size() ; j++)
			{
				if (saData.get(j).saCode.equals(destinationSA))
				{
					personString[i][destinationXTrip_index] = saData.get(j).xCoord.toString();
					personString[i][destinationYTrip_index] = saData.get(j).yCoord.toString();
					saData.remove(j);
					break;
				}
			}
			
			for (int j = 0 ; j < 11 ; j++)
			{
				fileContentD.append(personString[i][j] + ",");
			}
			fileContentD.append("\n");
			
			if(i%1000 == 0)
				System.out.println(i + ", saData: " + saData.size());
		}
		System.out.println("destinations done");
		
		ZahraUtility.write2File(fileContentD.toString(), "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/variatedxandY/destinations.csv");
		System.out.println("writing destinations done");
		
		System.out.println("done");

	}

}
