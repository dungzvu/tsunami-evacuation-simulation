/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: dung
* Tags: 
*/


model gui

import "base.gaml"

global {
	string file_csv_name -> "../results/evacuees_" + nb_of_people + "_" + initial_inform_strategy + ".csv";
}

experiment single type: gui{
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "Inform Strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "Number of People" category: "Base Parameters" var: nb_of_people init: 2000 among: [500, 1000, 2000, 3000, 4000];
	parameter "Alert Time" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [30, 60, 90, 120, 180];

	permanent {
		display "Visualization" background: #white {
			chart "Evacuees over time" type: series {
				data "Number of evacuees" value: number_evacuted_people marker: false style: line thickness: 5;
			}
		}
		display "Efficiency over time" background: #white {
			chart "Efficiency over time" type: series {
				data "Efficiency" value: efficiency marker: false style: line thickness: 5;
			}
		}
	}
	
	reflex save_csv when: every(20#s) {
		save [cycle,number_evacuted_people] to: file_csv_name 
					format:"csv" rewrite: false;
	}
	
	output {
		layout #split editors: false consoles: false toolbars: true tabs: true tray: true parameters: true;
		
		monitor "Number of Evacuated People" value: number_evacuted_people;
		monitor "Total Evacuation Time" value: total_evacuation_time;
		monitor "Total Time in Roads" value: total_time_in_roads;
		monitor "Efficiency" value: efficiency;
		
		display map {	
			species building;
			species road;
			species inhabitant;
		}
	}
}

experiment "3 Simulations" type: gui record: every(10#cycle) {
	float minimum_cycle_duration <- 0.05;
	
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 2000 among: [500, 1000, 2000, 3000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [30, 60, 90, 120];
	
	init {
		float seedValue <- 10.0;
		float seed <- seedValue; // force the value of the seed.
	
		create simulation with: [initial_inform_strategy::"furthest", seed::seedValue];
		create simulation with: [initial_inform_strategy::"closest", seed::seedValue];
	}
	
	permanent {
		display Evacuees background: #white refresh: every(1#cycle) {
			chart "Evacuees over time" type: series {
				loop s over: simulations {
					if (!dead(s)) {
					data "Evacuees " + s.initial_inform_strategy value: s.number_evacuted_people 
						 marker: false style: line thickness: 2;
				}}

			}
		}
	}
	
	output {
		layout #split editors: false consoles: false toolbars: true tabs: false tray: false parameters: true;
		display map {		
			species building;
			species road;
			species inhabitant;
		}
	}
}

