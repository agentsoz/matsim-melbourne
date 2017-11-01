package demand;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import org.jdom2.Document;
import org.jdom2.Element;
import org.jdom2.JDOMException;
import org.jdom2.input.SAXBuilder;

public class CheckDemand {

	public static void main(String[] args) {
		// TODO Auto-generated method stub
		
		SAXBuilder builder = new SAXBuilder();
		  File xmlFile = new File("C:/Users/znavidikasha/WorkSpaceNew/UtilityModel/input-test/plans.xml");
		  int counter = 0;
		  int noActcounter = 0;
		  try {

			Document document = (Document) builder.build(xmlFile);
			Element rootNode = document.getRootElement();
			List personList = rootNode.getChildren("person");
			
			System.out.println(personList.size());

			for (int i = 0; i < personList.size() ; i++)
			{
			   Element eachPerson = (Element) personList.get(i);
//			   System.out.println(eachPerson.getAttributeValue("id"));
			   List planList = eachPerson.getChildren("plan");
			   if (planList.size()> 1)
				   System.out.println(planList.size());
			   
			   Element eachPlan = (Element) planList.get(0);
			   List actList = eachPlan.getChildren("act");
			   eachPlan.addContent((Element) actList.get(actList.size()-1));
			   if (actList.isEmpty() )
			   {
				   personList.remove(personList.get(i));
				   noActcounter++;
			   }
			   else
			   {
				   System.out.println ("before" + actList.size());
				   Element firstAct = (Element) actList.get(0);
				   Element lastAct = (Element) actList.get(actList.size()-1);
				   
				   
				   if (!(firstAct.getAttribute("type").toString().equals(lastAct.getAttribute("type").toString())))
				   {
					   actList.add(0, (Element) actList.get(actList.size()-1) );
//					   System.out.println(eachPerson.getAttributeValue("id"));
					   counter ++; 
				   }
				   System.out.println(actList.size());
			   }
			   
			   List legList = eachPlan.getChildren("leg");
 
			}
			System.out.println("number of people with different org & dest: " + counter);
			System.out.println("number of people with no act: " + noActcounter);
			
			System.out.println(personList.size());

		  } catch (IOException io) {
			System.out.println(io.getMessage());
		  } catch (JDOMException jdomex) {
			System.out.println(jdomex.getMessage());
		  }
		  
		  System.out.println("done");
	}

}
