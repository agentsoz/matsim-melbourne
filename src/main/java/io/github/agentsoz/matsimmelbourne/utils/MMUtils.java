package io.github.agentsoz.matsimmelbourne.utils;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.matsim.core.gbl.Gbl;
import org.matsim.core.utils.geometry.geotools.MGC;
import org.opengis.feature.simple.SimpleFeature;

import java.util.Random;

public class MMUtils {
    private MMUtils() {
    } // do not instantiate

	public static Point getRandomPointInFeature(Random rnd, SimpleFeature ft) {
		Gbl.assertNotNull(ft);
		Point p = null;
		double x, y;
		// generate a random point until a point inside the feature geometry is found
		do {
			x = ft.getBounds().getMinX() + rnd.nextDouble() * (ft.getBounds().getMaxX() - ft.getBounds().getMinX());
			y = ft.getBounds().getMinY() + rnd.nextDouble() * (ft.getBounds().getMaxY() - ft.getBounds().getMinY());
			p = MGC.xy2Point(x, y);
		} while ( ! (((Geometry) ft.getDefaultGeometry()).contains(p)) );
		return p;
	}
	
}
