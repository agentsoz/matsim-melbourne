package au.edu.unimelb.imod.population;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Random;
import org.apache.log4j.Logger;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.locationtech.jts.geom.Point;
import org.matsim.api.core.v01.Coord;
import org.matsim.core.utils.geometry.CoordUtils;
import org.matsim.core.utils.geometry.CoordinateTransformation;
import org.matsim.core.utils.geometry.transformations.TransformationFactory;
import org.matsim.core.utils.gis.ShapeFileReader;
import org.opengis.feature.simple.SimpleFeature;

import au.edu.unimelb.imod.demand.archive.ZahraUtility;
import io.github.agentsoz.matsimmelbourne.utils.MMUtils;

public class RandomPopulation
{
	
	private static final String zonesFile = "G:\\My Drive\\1-PhDProject\\CriticalMass\\GM-MB\\GreaterMelbourne_MeshBlocks16.shp";
	private static final String meshBlockFile = "G:\\My Drive\\1-PhDProject\\CriticalMass\\GM-MB\\GreaterMelbourne_MeshBlocks16.csv";//2016_YarraRanges_SACodes_MeshBlock.csv";//data/census/2016/population/Melbourne_GCCSA_MB(UR)_by_SEXP_and_AGE5P_and_LFSP.csv";
	
	private static final Logger log = Logger.getLogger( RandomPopulation.class ) ;

	public static Coord createRandomCoordinateInCcdZone(Random rnd, Map<String, SimpleFeature> featureMap,
			String meshBlockCode, CoordinateTransformation ct)
	{

		// get corresponding feature:
		SimpleFeature ft = featureMap.get(meshBlockCode) ;
//		if ( ft==null )
//		{
//			log.error("unknown meshBlockCode=" + meshBlockCode ); // yyyyyy look at this again
//			double xmin = 271704. ; double xmax = 421000. ;
//			double xx = xmin + rnd.nextDouble()*(xmax-xmin) ;
//			double ymin = 5784843. ; double ymax = 5866000. ;
//			double yy =ymin + rnd.nextDouble()*(ymax-ymin) ;
//			return CoordUtils.createCoord( xx, yy) ;
//		
//		}
		
		// get random coordinate in feature:
		Point point = MMUtils.getRandomPointInFeature(rnd, ft) ;
		
		Coord coordInOrigCRS = CoordUtils.createCoord( point.getX(), point.getY() ) ;
		
		Coord coordOrigin = ct.transform(coordInOrigCRS) ;
		return coordOrigin;
	}
	
	
	
//	Coord coordOrigin = createRandomCoordinateInCcdZone(rndOD, featureMap, meshBlockCode, ct );

	public static void main(String[] args) throws IOException
	{
		Random rndOD = new Random();
		CoordinateTransformation ct = TransformationFactory.getCoordinateTransformation(TransformationFactory.WGS84,"EPSG:28355");
		
		Map<String,Integer> meshBlocksPop = new HashMap<>();
		try ( BufferedReader bufferedReader = new BufferedReader(new FileReader(meshBlockFile)) )
		{
			bufferedReader.readLine(); //skip header

			int index_meshBlockID = 0;
			int index_populationSize = 16;
			int index_SA3_NAME16 = 8;

			String line;
			while ((line = bufferedReader.readLine()) != null)
			{
				String parts[] = line.split(",");
				/*
				 * fill the map with mesh block ids and population size
				 */
				if (parts[index_SA3_NAME16].trim().equals("Yarra Ranges"))
					meshBlocksPop.put(parts[index_meshBlockID].trim(), Integer.parseInt(parts[index_populationSize].trim()));
			}
			bufferedReader.close();
		} // end try
		catch (IOException e)
		{
			e.printStackTrace();
		}
		
		
		/*
		 * read the shape file
		 */
		SimpleFeatureSource fts = ShapeFileReader.readDataFile(zonesFile); //reads the shape file in

		Map<String,SimpleFeature> featureMap = new LinkedHashMap<>();
		{
		//Iterator to iterate over the features from the shape file
		try ( SimpleFeatureIterator it = fts.getFeatures().features() )
		{
			while (it.hasNext())
			{
				// get feature
				SimpleFeature ft = it.next(); //A feature contains a geometry (in this case a polygon) and an arbitrary number
				featureMap.put( (String) ft.getAttribute("MB_CODE16") , ft ) ;
//				System.out.println(featureMap.get("MB_CODE16").toString());
			}
			it.close();

		}
		catch ( Exception ee )
		{
			throw new RuntimeException(ee) ;
		}
		}
		
		
		/*
		 * create random points and write them in a file
		 */
		StringBuilder fileContent = new StringBuilder();
		fileContent.append("point_ID,X,Y");
		Iterator <String> itr = meshBlocksPop.keySet().iterator();
		while (itr.hasNext())
		{
			// get feature
			String meshBlockCode = itr.next();
			int populationSize = meshBlocksPop.get(meshBlockCode);
//			System.out.println(populationSize);
			Integer pointCounter = 1;
			for (int i = 0 ; i < populationSize ; i++)
			{
				Coord originCoord = createRandomCoordinateInCcdZone (rndOD,featureMap ,meshBlockCode, ct);
//				System.out.println(originCoord);
				fileContent.append(meshBlockCode + "PO" + pointCounter.toString() + "," + originCoord.getX() + "," + originCoord.getY() + "\n");
				pointCounter++;
			}
		
		}
		ZahraUtility.write2File(fileContent.toString(),"G:\\My Drive\\1-PhDProject\\CriticalMass\\GM_MB\\test.csv");//RandomPointsinMeshBlocks.csv");
		

		System.out.println("DONE");

	}
	
	
}// RandomPopulation

