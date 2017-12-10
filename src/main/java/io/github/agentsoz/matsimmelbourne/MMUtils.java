package io.github.agentsoz.matsimmelbourne;

import java.util.HashMap;
import java.util.Map;

class MMUtils {
	private MMUtils() {
	} // do not instantiate
	
	public static final String OUTPUT_DIRECTORY_INDICATOR = "--output-dir";
	public static final String RUN_MODE = "--run-mode";
	
	/**
	 * Parse the command line arguments
	 */
	public static Map<String, String> parse(String[] args) {
		Map<String, String> map = new HashMap<>();
		for (int i = 0; i < args.length; i++) {
			switch (args[i]) {
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
						map.put(RUN_MODE, args[i]);
					} else {
						throw new RuntimeException("argument missing");
					}
					break;
				default:
					throw new RuntimeException("unknown config option: " + args[i]);
			}
		}
		return map ;
	}
	
}
