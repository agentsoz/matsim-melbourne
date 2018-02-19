package io.github.agentsoz.matsimmelbourne.demand.latch;

import com.opencsv.bean.CsvBindByName;
import com.opencsv.bean.CsvToBean;
import com.opencsv.bean.CsvToBeanBuilder;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.scenario.ScenarioUtils;
import org.matsim.households.Household;
import org.matsim.households.Households;
import org.matsim.households.HouseholdsFactory;
import org.matsim.households.HouseholdsWriterV10;

import java.io.FileReader;
import java.io.IOException;
import java.util.Iterator;

public class CreateHouseHoldFromLatch {
    
    private static final String LATCH_HOUSEHOLDS = "data/census/2011/latch/2017-11-30-files-from-bhagya/AllHouseholds" +
                                                           ".csv";
    public static final String DEFAULT_OFNAME = "households-from-latch";
    public static final String XML_OUT = ".xml";
    public static final String ZIPPED_OUT = ".xml.gz";
    
    private final Scenario scenario;
    private final HouseholdsFactory householdsFactory;
    private final Households households;
    private StringBuilder oFile = new StringBuilder();
    
    public CreateHouseHoldFromLatch(){
        
        scenario = ScenarioUtils.createScenario(ConfigUtils.createConfig());
        households = scenario.getHouseholds();
        householdsFactory = households.getFactory();
        
        oFile.append(DEFAULT_OFNAME+ZIPPED_OUT);
    }
    
    public static void main(String[] args) throws IOException{
        
        CreateHouseHoldFromLatch createHouseHoldFromLatch = new CreateHouseHoldFromLatch();
        createHouseHoldFromLatch.createHouseHolds();
        
    }
    
    /*Read household file and store attributes in MATSim household*/
    void createHouseHolds() throws IOException {
        
        try (final FileReader reader = new FileReader(LATCH_HOUSEHOLDS)) {
            
            final CsvToBeanBuilder<LatchHouseHoldRecord> builder = new CsvToBeanBuilder<>(reader);
            builder.withType(LatchHouseHoldRecord.class);
            builder.withSeparator(',');
            final CsvToBean<LatchHouseHoldRecord> reader2 = builder.build();
            for (Iterator<LatchHouseHoldRecord> it = reader2.iterator(); it.hasNext(); ) {
                LatchHouseHoldRecord record = it.next() ;
                
                Household household = householdsFactory.createHousehold(Id.create(record.HouseholdId,Household.class));
                
                household.getAttributes().putAttribute("PrimaryFamilyType",record.PrimaryFamilyType);
                household.getAttributes().putAttribute("Members",record.Members);
                household.getAttributes().putAttribute("FamilyIds",record.FamilyIds);
                household.getAttributes().putAttribute("CensusHouseholdSize",record.CensusHouseholdSize);
                household.getAttributes().putAttribute("sa2_maincode_2011",record.sa2_maincode_2011);
                
                
                households.getHouseholds().put(household.getId(),household);
                
            }
        }
        HouseholdsWriterV10 householdsWriterV10 = new HouseholdsWriterV10(scenario.getHouseholds());
        householdsWriterV10.writeFile(oFile.toString());
    }
    public final static class LatchHouseHoldRecord {
        @CsvBindByName
        private String HouseholdId;
        @CsvBindByName
        private String PrimaryFamilyType;
        @CsvBindByName
        private String Members;
        @CsvBindByName
        private String FamilyIds;
        @CsvBindByName
        private String CensusHouseholdSize;
        @CsvBindByName
        private String sa2_maincode_2011;
    }
    
}
