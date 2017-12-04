
import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;

import java.io.FileReader;
import java.io.IOException;
import java.util.Iterator;

class CreatePopulationFromLatch2 {
	
	private static final String pusTripsFile = "data/latch/2017-11-30-files-from-bhagya/AllAgents.csv" ;
	
	public static void main( String[] args ) throws IOException {
		CreatePopulationFromLatch2 createPop = new CreatePopulationFromLatch2() ;
		createPop.run() ;
	}
	
	void run() throws IOException {
		
		try (final FileReader reader = new FileReader(pusTripsFile)) {
			// try-with-resources
			
			final CsvToBeanBuilder<Visitors> builder = new CsvToBeanBuilder<>(reader);
			builder.withType(Visitors.class);
			builder.withSeparator(',');
			final CsvToBean<Visitors> reader2 = builder.build();
			for (Iterator<Visitors> it = reader2.iterator(); it.hasNext(); ) {
				Visitors record = it.next();
				System.out.println( "AgentId=" + record.AgentId + "; rs=" + record.RelationshipStatus ) ;
			}
		} // end of for loop
		
	}
	public final static class Visitors {
		// needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17
		
		@CsvBindByName private String AgentId ;
		@CsvBindByName private String RelationshipStatus ;

	}
	
}
