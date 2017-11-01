package demand;

public class MatchingVariatedXY {

	public static void main(String[] args) {
		String[][] oldXY = ZahraUtility.Data(194820,21, "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/personsTripsAllLimited.csv");
		String[][] newXY = ZahraUtility.Data(420408,11, "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/variatedxandY/variatedxandy.csv");
		StringBuilder str = new StringBuilder();
		
		for (int i = 1; i < oldXY.length ; i++)
		{
			oldXY[i][12] = newXY[i][8];
			oldXY[i][13] = newXY[i][7];
			oldXY[i][14] = newXY[i][10];
			oldXY[i][15] = newXY[i][9];
		}
		
		for (int i = 0 ; i < oldXY.length ; i++ )
		{
			for (int j = 0 ; j <20 ; j++)
			{
				str.append(oldXY[i][j] + ",");
			}
			str.append(oldXY[i][20] + "\n");
		}
		
		ZahraUtility.write2File(str.toString(), "C:/Users/znavidikasha/Dropbox/1-PhDProject/YarraRanges/demand/zahra's/PersonTripsAllVariatedLimited.csv");
		System.out.println("done");
	}

}
