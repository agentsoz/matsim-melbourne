
import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.population.Person;
import org.matsim.api.core.v01.population.Population;
import org.matsim.api.core.v01.population.PopulationFactory;
import org.matsim.api.core.v01.population.PopulationWriter;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;

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
		
		Scenario scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig() ) ;
		final Population population = scenario.getPopulation();
		PopulationFactory populationFactory = population.getFactory();;
		
		try (final FileReader reader = new FileReader(pusTripsFile)) {
			// try-with-resources
			
			int cnt=0 ;
			
			final CsvToBeanBuilder<Visitors> builder = new CsvToBeanBuilder<>(reader);
			builder.withType(Visitors.class);
			builder.withSeparator(',');
			final CsvToBean<Visitors> reader2 = builder.build();
			for (Iterator<Visitors> it = reader2.iterator(); it.hasNext(); ) {
				Visitors record = it.next();
//				System.out.println( "AgentId=" + record.AgentId + "; rs=" + record.RelationshipStatus ) ;
				
				Person person = populationFactory.createPerson( Id.createPersonId(record.AgentId) );
				population.addPerson(person);
				
				person.getAttributes().putAttribute( "RelationshipStatus" , record.RelationshipStatus ) ;
				
				if (cnt>=30) {
					break ;
				}
				cnt++ ;
				
			}
			
		} // end of for loop
		
		PopulationWriter populationWriter = new PopulationWriter(scenario.getPopulation(), scenario.getNetwork());
		populationWriter.write("population-from-latch.xml.gz");
		
	}
	public final static class Visitors {
		// needs to be public, otherwise one gets some incomprehensible exception.  kai, nov'17
		
		@CsvBindByName private String AgentId ;
		@CsvBindByName private String RelationshipStatus ;

	}
	
}
