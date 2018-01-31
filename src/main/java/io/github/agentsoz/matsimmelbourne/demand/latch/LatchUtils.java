package io.github.agentsoz.matsimmelbourne.demand.latch;

import java.util.HashMap;
import java.util.Map;

public class LatchUtils {
	public static final String OUTPUT_DIRECTORY_INDICATOR = "--output-dir";
	public static final String RUN_MODE = "--run-mode";
	public static final String FILE_NAME = "--file-name";
	public static final String FILE_FORMAT = "--file-format";
	public static final String SAMPLE_POPULATION = "--sample-population";
	public static final String HELP = "--help";
	
	private LatchUtils(){} // do not instantiate
	
	public static String usage() {
		return "\n\n" +
					   "\tusage: " + CreatePopulationFromLatch.class.getName()+
					   "  [options] " + "\n\n" +
					   "\t--file-name <filename>                     sets output file name" + "\n" +
					   "\t--output-dir <outputdirectory>             sets output directory (.,..,<complete path>)" + "\n" +
					   "\t--run-mode <runMode>              		  sets run mode (d/f) [debugging,full]" + "\n" +
					   "\t--file-format <fileformat>          	      sets the output file format (x,z) [xml,zip]" + "\n" +
					   "\t--sample-population <inputNumber>          sets the sample population for debgugging mode" + "\n" +
					   "\t--help 									  Displays usage" +
					   "\n\n";
	}
	
	/**
	 * Parse the command line arguments
	 */
	public static Map<String, String> parse(String[] args) {
		Map<String, String> map = new HashMap<>();
		for (int i = 0; i < args.length; i++) {
			switch (args[i]) {
				case FILE_NAME:
					if (i + 1 < args.length) {
						i++;
						map.put(FILE_NAME, args[i]);
					} else {
						throw new RuntimeException("argument missing");
					}
					break;
				case OUTPUT_DIRECTORY_INDICATOR:
					if (i + 1 < args.length) {
						i++;
						map.put(OUTPUT_DIRECTORY_INDICATOR, args[i]);
					} else {
						throw new RuntimeException("argument missing");
					}
					break;
				case RUN_MODE:
					if (i + 1 < args.length) {
						i++;

						if (!args[i].equals("d") && !args[i].equals("f"))
							throw new IllegalArgumentException("Invalid Argument: " +args[i-1] + " '"+ args[i] + "'" +
									usage());

						map.put(RUN_MODE, args[i]);

					} else {
						throw new RuntimeException("argument missing");
					}
					break;

					case SAMPLE_POPULATION:
					if (i + 1 < args.length) {
						i++;
						try {

							Integer.parseInt(args[i]);

						} catch (NumberFormatException n){

							System.out.println("Number Expected: "+n.getCause() + usage());
						}
						map.put(SAMPLE_POPULATION, args[i]);

					} else {
						throw new RuntimeException("argument missing");
					}
					break;

				case FILE_FORMAT:
					if (i + 1 < args.length) {
						i++;

						if (!args[i].equals("x") && !args[i].equals("z"))
							throw new IllegalArgumentException("Invalid Argument: " +args[i-1] + " '"+ args[i] + "'"
									+ usage());

						map.put(FILE_FORMAT, args[i]);


					} else {
						throw new RuntimeException("argument missing");
					}
					break;
				case HELP:
					usage();
					break;

				default:
					throw new RuntimeException("unknown config option: " + usage());
			}
		}
		return map;
	}
}
