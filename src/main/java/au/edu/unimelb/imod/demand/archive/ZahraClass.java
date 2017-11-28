package au.edu.unimelb.imod.demand.archive;

import java.util.ArrayList;

import org.matsim.api.core.v01.Id;

public class ZahraClass {
	
	public static class Person
	{
		long personID;
		long gender;
		long age;
		long employmentStat;
		long mvOwnership;
		long frequency;
		long childrenNo;
		long carLicense;
		long assPersonID;
		ArrayList <Trip> trips;
		
		public Person(long personID, long gender, long age,
				long employmentStat, long mvOwnership, long frequency,
				long childrenNo, long carLicense, long assPersonID,
				ArrayList<Trip> trips) {
			super();
			this.personID = personID;
			this.gender = gender;
			this.age = age;
			this.employmentStat = employmentStat;
			this.mvOwnership = mvOwnership;
			this.frequency = frequency;
			this.childrenNo = childrenNo;
			this.carLicense = carLicense;
			this.assPersonID = assPersonID;
			this.trips = trips;
		}
		
		public Person(long personID, long gender, long age,
				long employmentStat, long mvOwnership, long frequency,
				long childrenNo, long carLicense, long assPersonID) {
			super();
			this.personID = personID;
			this.gender = gender;
			this.age = age;
			this.employmentStat = employmentStat;
			this.mvOwnership = mvOwnership;
			this.frequency = frequency;
			this.childrenNo = childrenNo;
			this.carLicense = carLicense;
			this.assPersonID = assPersonID;
			
			this.trips = new ArrayList<Trip>();
		}

		@Override
		public String toString() {
			return "Person [personID=" + personID + ", gender=" + gender
					+ ", age=" + age + ", employmentStat=" + employmentStat
					+ ", mvOwnership=" + mvOwnership + ", frequency="
					+ frequency + ", childrenNo=" + childrenNo
					+ ", carLicense=" + carLicense + ", assPersonID="
					+ assPersonID + ", trips=" + trips + "]";
		}
		
	}//end of Person
	
	public static class Trip
	{
		long tripPersonID;
		String tripId;
		long startTime;
		double originX;
		double originY;
		double destinationX;
		double destinationY;
		String originPlace;
		String destinationPlace;
		String tripPurpose;
		String mode;
		double duration;
		Double originSACode;
		Double destSACode;
		public Trip(long tripPersonID, String tripId, long startTime,
				double originX, double originY, double destinationX,
				double destinationY, String originPlace, String destinationPlace,
				String tripPurpose, String mode, double duration, double originSACode, double destSACode) {
			super();
			this.tripPersonID = tripPersonID;
			this.tripId = tripId;
			this.startTime = startTime;
			this.originX = originX;
			this.originY = originY;
			this.destinationX = destinationX;
			this.destinationY = destinationY;
			this.originPlace = originPlace;
			this.destinationPlace = destinationPlace;
			this.tripPurpose = tripPurpose;
			this.mode = mode;
			this.duration = duration;
			this.originSACode = originSACode;
			this.destSACode = destSACode;
		}
		@Override
		public String toString() {
			return "Trip [tripPersonID=" + tripPersonID + ", tripId=" + tripId
					+ ", startTime=" + startTime + ", originX=" + originX
					+ ", originY=" + originY + ", destinationX=" + destinationX
					+ ", destinationY=" + destinationY + ", originPlace="
					+ originPlace + ", destinationPlace=" + destinationPlace
					+ ", tripPurpose=" + tripPurpose + "]";
		}
		public double getOriginX() {
			return originX;
		}
		public void setOriginX(double originX) {
			this.originX = originX;
		}
		public double getOriginY() {
			return originY;
		}
		public void setOriginY(double originY) {
			this.originY = originY;
		}
		public double getDestinationX() {
			return destinationX;
		}
		public void setDestinationX(double destinationX) {
			this.destinationX = destinationX;
		}
		public double getDestinationY() {
			return destinationY;
		}
		public void setDestinationY(double destinationY) {
			this.destinationY = destinationY;
		}
		
	}//end of Trip
	
	
	public static class TripForAnalysis
	{
		String mode;
		double travelT;
		double waitingT;
		double walkingT;
		double transfers;
		double rideT;
		int tripNumber;
		
		public TripForAnalysis(int tripNumber, String mode, double travelT, double waitingT,
				double walkingT, double transfers, double rideT)
		{
			super();
			this.tripNumber = tripNumber;
			this.mode = mode;
			this.travelT = travelT;
			this.waitingT = waitingT;
			this.walkingT = walkingT;
			this.transfers = transfers;
			this.rideT = rideT;
		}

		@Override
		public String toString()
		{
			return tripNumber + "," + mode + "," + travelT + "," + waitingT + "," + walkingT	+ "," + transfers + "," + rideT + "\n";
		}

		public int getTripNumber() {
			return tripNumber;
		}

		public void setTripNumber(int tripNumber) {
			this.tripNumber = tripNumber;
		}

		public String getMode() {
			return mode;
		}

		public void setMode(String mode) {
			this.mode = mode;
		}

		public double getTravelT() {
			return travelT;
		}

		public void setTravelT(double travelT) {
			this.travelT = travelT;
		}

		public double getWaitingT() {
			return waitingT;
		}

		public void setWaitingT(double waitingT) {
			this.waitingT = waitingT;
		}

		public double getWalkingT() {
			return walkingT;
		}

		public void setWalkingT(double walkingT) {
			this.walkingT = walkingT;
		}

		public double getTransfers() {
			return transfers;
		}

		public void setTransfers(double transfers) {
			this.transfers = transfers;
		}

		public double getRideT() {
			return rideT;
		}

		public void setRideT(double rideT) {
			this.rideT = rideT;
		}
		
	}
	
	public static class DataSetForBiogeme
	{
		public String id;
		public String age;
		public String male;
		public String worker;
		public String carOption;//if the person has a license or lives in a household with a vehicle
		public String rideTimeCar;
		public String walkTimeCar;
		public String waitTimeCar;
		public String transferCar;
		public String carAvail;
		public String carCost;
		public String rideTimePt;
		public String walkTimePt;
		public String waitTimePt;
		public String transferPt;
		public String ptAvail;
		public String ptCost;
		public String choice; // 1 : car , 2: pt
		
		public DataSetForBiogeme(String id, String age, String male,
				String worker, String carOption, String rideTimeCar,
				String walkTimeCar, String waitTimeCar, String transferCar,
				String carAvail, String carCost, String rideTimePt,
				String walkTimePt, String waitTimePt, String transferPt,
				String ptAvail, String ptCost, String choice) {
			super();
			this.id = id;
			this.age = age;
			this.male = male;
			this.worker = worker;
			this.carOption = carOption;
			this.rideTimeCar = rideTimeCar;
			this.walkTimeCar = walkTimeCar;
			this.waitTimeCar = waitTimeCar;
			this.transferCar = transferCar;
			this.carAvail = carAvail;
			this.carCost = carCost;
			this.rideTimePt = rideTimePt;
			this.walkTimePt = walkTimePt;
			this.waitTimePt = waitTimePt;
			this.transferPt = transferPt;
			this.ptAvail = ptAvail;
			this.ptCost = ptCost;
			this.choice = choice;
		}
		public String getRideTimeCar() {
			return rideTimeCar;
		}
		public void setRideTimeCar(String rideTimeCar) {
			this.rideTimeCar = rideTimeCar;
		}
		public String getWalkTimeCar() {
			return walkTimeCar;
		}
		public void setWalkTimeCar(String walkTimeCar) {
			this.walkTimeCar = walkTimeCar;
		}
		public String getWaitTimeCar() {
			return waitTimeCar;
		}
		public void setWaitTimeCar(String waitTimeCar) {
			this.waitTimeCar = waitTimeCar;
		}
		public String getTransferCar() {
			return transferCar;
		}
		public void setTransferCar(String transferCar) {
			this.transferCar = transferCar;
		}
		public String getRideTimePt() {
			return rideTimePt;
		}
		public void setRideTimePt(String rideTimePt) {
			this.rideTimePt = rideTimePt;
		}
		public String getWalkTimePt() {
			return walkTimePt;
		}
		public void setWalkTimePt(String walkTimePt) {
			this.walkTimePt = walkTimePt;
		}
		public String getWaitTimePt() {
			return waitTimePt;
		}
		public void setWaitTimePt(String waitTimePt) {
			this.waitTimePt = waitTimePt;
		}
		public String getTransferPt() {
			return transferPt;
		}
		public void setTransferPt(String transferPt) {
			this.transferPt = transferPt;
		}
		public String getChoice() {
			return choice;
		}
		public void setChoice(String choice) {
			this.choice = choice;
		}
		public String getCarAvail() {
			return carAvail;
		}
		public void setCarAvail(String carAvail) {
			this.carAvail = carAvail;
		}
		public String getPtAvail() {
			return ptAvail;
		}
		public void setPtAvail(String ptAvail) {
			this.ptAvail = ptAvail;
		}
		public String getCarCost() {
			return carCost;
		}
		public void setCarCost(String carCost) {
			this.carCost = carCost;
		}
		public String getPtCost() {
			return ptCost;
		}
		public void setPtCost(String ptCost) {
			this.ptCost = ptCost;
		}
		@Override
		public String toString() {
			return  id + "	" + age + "	" + male	+ "	" + worker + "	" + carOption + "	" + rideTimeCar
					+ "	" + walkTimeCar + "	" + waitTimeCar + "	" + transferCar + "	" + carAvail + "	" + carCost
					+ "	" + rideTimePt + "	" + walkTimePt + "	" + waitTimePt
					+ "	" + transferPt + "	" + ptAvail + "	" + ptCost  + "	" + choice;
		}
		
	}//end of Datasetforbiogeme

	public static class MATSimOutputPeople {
		Id personId;
		int tripId;
		double rideTime;
		double walkTime;
		double waitTime;
		String mode;
		public MATSimOutputPeople(Id personId, int tripId, double rideTime,
				double walkTime, double waitTime, String mode) {
			super();
			this.personId = personId;
			this.tripId = tripId;
			this.rideTime = rideTime;
			this.walkTime = walkTime;
			this.waitTime = waitTime;
			this.mode = mode;
		}
		@Override
		public String toString() {
			return personId + "," + tripId + "," + rideTime/60 + "," + walkTime/60 + "," + waitTime/60 + "," + mode;
		}
		public Id getPersonId() {
			return personId;
		}
		public void setPersonId(Id personId) {
			this.personId = personId;
		}
		public int getTripId() {
			return tripId;
		}
		public void setTripId(int tripId) {
			this.tripId = tripId;
		}
		public double getRideTime() {
			return rideTime;
		}
		public void setRideTime(double rideTime) {
			this.rideTime = rideTime;
		}
		public double getWalkTime() {
			return walkTime;
		}
		public void setWalkTime(double walkTime) {
			this.walkTime = walkTime;
		}
		public double getWaitTime() {
			return waitTime;
		}
		public void setWaitTime(double waitTime) {
			this.waitTime = waitTime;
		}
		public String getMode() {
			return mode;
		}
		public void setMode(String mode) {
			this.mode = mode;
		}
		
	}
	
	public static class MATSimActivity{
		String Type;
		double time;
		String otherAttribute;
		public MATSimActivity(String type, double time, String otherAttribute) {
			super();
			Type = type;
			this.time = time;
			this.otherAttribute = otherAttribute;
		}
		
		@Override
		public String toString() {
			return Type + "," + time + "," + otherAttribute;
		}

		public String getType() {
			return Type;
		}
		public void setType(String type) {
			Type = type;
		}
		public double getTime() {
			return time;
		}
		public void setTime(double time) {
			this.time = time;
		}
		public String getOtherAttribute() {
			return otherAttribute;
		}
		public void setOtherAttribute(String otherAttribute) {
			this.otherAttribute = otherAttribute;
		}	
	}
	
	public static class SAs
	{
		public String saCode;
		public String xCoord;
		public String yCoord;
		
		public SAs(String saCode, String xCoord, String yCoord) {
			super();
			this.saCode = saCode;
			this.xCoord = xCoord;
			this.yCoord = yCoord;
		}

		public String getSaCode() {
			return saCode;
		}

		public void setSaCode(String saCode) {
			this.saCode = saCode;
		}

		public String getxCoord() {
			return xCoord;
		}

		public void setxCoord(String xCoord) {
			this.xCoord = xCoord;
		}

		public String getyCoord() {
			return yCoord;
		}

		public void setyCoord(String yCoord) {
			this.yCoord = yCoord;
		}
	}
	
	
}
