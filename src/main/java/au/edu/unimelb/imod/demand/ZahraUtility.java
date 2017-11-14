package au.edu.unimelb.imod.demand;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Scanner;

import org.matsim.api.core.v01.Coord;


public class ZahraUtility<T> {

	//reading csv file and putting everything in a matrix  
	public static String[][] Data (int m, int n, String filePath){
		String eachLine = "";
		String[] splitted;
		String [][] AllData = new String [m][n];
		
		//this part tries to see if the name of the file is correct and if it exist and if not it catches the error and print it====
		try ( Scanner scanner = new Scanner(new File(filePath)) ) {
//				Scanner scanner = null;
//				try {
//				}
//				catch (FileNotFoundException e) {
//					// TODO Auto-generated catch block
//					e.printStackTrace();
//				}
				
				scanner.useDelimiter("\n");
//				int ii = 0 ;
//			    while(scanner.hasNext())
//			    {
			    	for (int ii = 0 ; ii < m ; ii++)
			    	{
			    		//first we read each line and put it aside
				    	eachLine = scanner.next();
				    	//then each line is splitted into two words it has and put into an array
				    	splitted = eachLine.split(",");
			    		//each item of the array is one part of the Unit, which is added to the units
						for (int jj = 0; jj < n; jj++)
						{
							AllData[ii][jj] = splitted[jj].trim();
						}
						ii++;
//			    	}	        	
		        }
			        scanner.close();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		        
		        return AllData;
	}
	
	//checking existence of a datum in an array
	public static boolean containsKey(int[] intArray, int key) {
    	for (int i = 0 ; i < intArray.length; ++i)
    	{
    		if(intArray[i] == key)
    			return true;
    	}
    	
    	return false;
    }
	
	
	//Random Time Generator
	public static ArrayList<String> RandomTime (int startTime, int endTime, int number) {
		ArrayList<String> timeArray = new ArrayList<String>(number);
		String time;
		
		for (int i = 0; i < number; i++)
		{
			Random r = new Random();
			int hour = r.nextInt(endTime+1 - startTime)+startTime;
			int min = r.nextInt(59 - 0);
			int sec = r.nextInt(59 - 0);
			time = ((hour < 10)?("0"+hour):hour)+":"+((min < 10)?("0"+min):min)+":"+((sec < 10)?("0"+sec):sec);
			timeArray.add(time);
		}

		return timeArray;
	}
	
	
	//Array List printer
	public void arrayPrinter (ArrayList<T> inputArray){
		for (int i = 0 ; i < inputArray.size(); ++i)
			System.out.println(inputArray.get(i));
	}
	
	public static ArrayList<String> listAllFilesInFolderRecursively(final File folder) 
	{
		ArrayList<String> list = new ArrayList<String>();
		
		listAllFilesInFolder(folder, list);
		
		return list;
	}
	
	private static void listAllFilesInFolder(final File folder, ArrayList<String> listSoFar) 
	{
	    for (final File fileEntry : folder.listFiles()) {
	        if (fileEntry.isDirectory()) 
	        {
	        	listAllFilesInFolder(fileEntry, listSoFar);
	        } else 
	        {
	        	listSoFar.add(fileEntry.getName());
	        }
	    }
	}
	
	public static ArrayList<String> listAllFilesInFolder(final String folderName) 
	{
		File folder = new File(folderName);
		ArrayList<String> list = new ArrayList<String>();
		
		for (final File fileEntry : folder.listFiles())
			 list.add(fileEntry.getName());
		
		return list;
	}
	
	public static <T> void printList(ArrayList<T> list)
	{
		for (T element : list) {
			System.out.println(element);
		}
	}
	
	public static <K , V> void printMap(Map<K , V> inputMap)
	{
		for (Map.Entry<K, V> entry : inputMap.entrySet()) 
		{
			System.out.println(entry.getKey() + " -> " + entry.getValue());
		}
	}
	
	public static void write2File(String fileCOntent, String fileName)
	{
		PrintWriter writer;
		try 
		{
			writer = new PrintWriter(fileName, "UTF-8");
			
			writer.println(fileCOntent);

			writer.close();
			
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	
	public static String readFile(String fileName)
	{
		String everything = "";
		BufferedReader br = null;
		
		try {
			br = new BufferedReader(new FileReader(fileName));
			StringBuilder sb = new StringBuilder();
		    String line = br.readLine();

		    while (line != null) {
		        sb.append(line);
		        sb.append(System.lineSeparator());
		        line = br.readLine();
		    }
		    everything = sb.toString();
		    
		    br.close();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return everything;
	}
	
	
	public static boolean doesArrayContain(String[] array, String element)
	{
		for (int i = 0; i < array.length; i++) {
			if (array[i].equals(element))
				return true;
		}
		
		return false;
	}
	
	public static int mapElementWiseSize(HashMap<String, Integer> inputMap)
	{
		int size = 0;
		
		for (Object value : inputMap.values()) 
		{
			size += Integer.parseInt(value.toString());
		}
	    
	    return size;
	}
	
	public static int maxMapValue(HashMap<String, Integer> inputMap)
	{
		int max = 0;
				
		for (Object value : inputMap.values()) 
		{
			if (Integer.parseInt(value.toString()) > max)
				max = Integer.parseInt(value.toString());
		}
		
		return max;
	}
	
	public static <V extends Number> double getAverageOfArrayElements(List<V> input)
	{
		double sum;
		
		if (!input.isEmpty())
			sum = input.get(0).doubleValue();
		else
			return 0.0;
		
		for (V v : input) 
		{
			sum += v.doubleValue();
		}
		
		return sum / input.size();
	}
	
	public static <K, V extends Comparable<? super V>> Map<K, V> sortByValue( Map<K, V> map )
	{
	    List<Map.Entry<K, V>> list = new LinkedList<Map.Entry<K, V>>( map.entrySet() );
	    Collections.sort( list, new Comparator<Map.Entry<K, V>>()
	    {
	        public int compare( Map.Entry<K, V> o1, Map.Entry<K, V> o2 )
	        {
	            return (o1.getValue()).compareTo( o2.getValue() );
	        }
	    } );
	
	    Map<K, V> result = new LinkedHashMap<K, V>();
	    for (Map.Entry<K, V> entry : list)
	    {
	        result.put( entry.getKey(), entry.getValue() );
	    }
	    return result;
	}
	
	public static <T> boolean doesArrayContain(ArrayList<T> array, String element)
	{
		for (int i = 0; i < array.size(); i++) {
			if (array.get(i).equals(element))
				return true;
		}
		
		return false;
	}
	
	public static <T> boolean allArrayElementsEqualTo(T[] array, T element)
	{
		for (int i = 0; i < array.length; i++) {
			if (!array[i].equals(element))
				return false;
		}
		
		return true;
	}
	
	public static double prob2ml (double prob)
	{
		return -1 * (Math.log(prob)/Math.log(2));
	}
	
	public static double ml2prob (double ml)
	{
		return Math.pow(2, -ml);
	}
	
	public static boolean intContains(final int[] array, final int value)
	{
	    for (int e : array)
	        if (e == value)
	            return true;

	    return false;
	}
	
	public static <K, V> void printMap2file (Map <K , V> inputMap, String filePath)
	{
		String fileContent = "";
		Iterator<Map.Entry<K, V>> iterator = inputMap.entrySet().iterator();
		while(iterator.hasNext())
		{
		    K key = iterator.next().getKey();
		    fileContent += key + ", " + (inputMap.get(key)) +"\n";
		}
		ZahraUtility.write2File(fileContent, filePath);
	}
	
	public static Coord createRamdonCoord(Coord coord)
	{
		Coord coordOut;
		double x,y;
		double randR,randAlpha;
		double newX, newY;
		
		x = coord.getX();
		y = coord.getY();
		
		randR = Math.random()*500;
		randAlpha = Math.random()*360;
		
		newX = x + randR * Math.sin(Math.toRadians(randAlpha));
		newY = y + randR * Math.cos(Math.toRadians(randAlpha));
		
		coordOut = new Coord(newX,newY);				
		
		return coordOut;
	}
	
	public static Map<String, HashMap<String, ArrayList<Coord>>> fillMapWithPoints (int m, int n, String filePath)
	{
		String[][] pointString = ZahraUtility.Data(m, n, filePath);
		Map<String, HashMap<String, ArrayList<Coord>>> pointsMap = new HashMap<String, HashMap<String,ArrayList<Coord>>>();
		
		for (int i = 1 ; i < pointString.length ; i++)
		{
			ArrayList<Coord> points = new ArrayList<Coord>();
			Coord temCoord = new Coord(Double.parseDouble(pointString[i][4]), Double.parseDouble(pointString[i][3]));
			points.add(temCoord);
			String LU = pointString[i][1];
			String SA = pointString[i][2];
		
			
			if (pointsMap.containsKey(SA))
			{
				if (pointsMap.get(SA).containsKey(LU))
				{
					pointsMap.get(SA).get(LU).add(temCoord);
				}
				else
				{
					pointsMap.get(SA).put(LU, points);
				}
			}
			else
			{
				pointsMap.put(SA, new HashMap<String, ArrayList<Coord>>() {{put(LU, points);}});
			}
		}
		
		return pointsMap;
	}// end of fillMapWithPoints
	
	public static Map<String, ArrayList<Coord>> fillMapWithPointsSA (int m, int n, String filePath)
	{
		String[][] pointString = ZahraUtility.Data(m, n, filePath);
		
		
		Map<String, ArrayList<Coord>> pointsMap = new HashMap<String,ArrayList<Coord>>();
		
		
		for (int i = 1 ; i < pointString.length ; i++)
		{
			ArrayList<Coord> points = new ArrayList<Coord>();
			Coord temCoord = new Coord(Double.parseDouble(pointString[i][4]), Double.parseDouble(pointString[i][3]));
			points.add(temCoord);
			String SA = pointString[i][2];
			String LU = pointString[i][1];
			
			if (pointsMap.containsKey(SA))
			{
				pointsMap.get(SA).add(temCoord);
			}
			else
			{
				pointsMap.put(SA, points);
			}
			}
		
		return pointsMap;
	}// end of fillMapWithPointsSA
	
	public static ArrayList<ArrayList<String>> DataArray (int columns, String filePath){
		String eachLine = "";
		String[] splitted;
		ArrayList<ArrayList<String>> allData = new ArrayList<ArrayList<String>>();
		ArrayList<String> oneLineData = new ArrayList<String>();
		
		//this part tries to see if the name of the file is correct and if it exist and if not it catches the error and print it====
				Scanner scanner = null;
				try {
					scanner = new Scanner(new File(filePath));
				} catch (FileNotFoundException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
				scanner.useDelimiter("\n");
			    while(scanner.hasNext()){
			    	//first we read each line and put it aside
			    	eachLine = scanner.next();
			    	//then each line is splitted into two words it has and put into an array
			    	splitted = eachLine.split(",");
			    	//each item of the array is one part of the Unit, which is added to the units			    	
					for (int j = 0; j < columns ; j++)
						oneLineData.add(splitted[j]);
					allData.add(oneLineData);

		        }
		        scanner.close();
		        return allData;
	}
	

}//end of class