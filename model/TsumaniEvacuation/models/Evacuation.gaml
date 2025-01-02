/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: dung
* Tags: 
*/


model Evacuation

import "base.gaml"

experiment single type: gui{
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "initial_inform_strategy" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" var: nb_of_people init: 1000 min: 100 max: 10000 step: 100;
	
	permanent {
		display Comparison background: #white {
			chart "Evacuees over time" type: series {
				data "Number of evacuees" value: number_evacuted_people marker: false style: line thickness: 5;
			}
		}
	}
	
	output {
		monitor number_of_unknown value: number_of_unknown;
		monitor number_evacuted_people value: number_evacuted_people;
		
		display map {	
			species building;
			species road;
			species inhabitant;
			species red_river;
		}
	}
}

experiment "3 Simulations" type: gui record: every(10#cycle) {
//	float minimum_cycle_duration <- 0.05;
	
	parameter "flooding_inform_before_minutes" var: flooding_inform_before_minutes min: 30 max: 1200 step: 15;
	parameter "nb_of_people" var: nb_of_people min: 100 max: 10000 step: 100;
	
	init {
		float seedValue <- 10.0;
		float seed <- seedValue; // force the value of the seed.
	
		create simulation with: [initial_inform_strategy::"furthest", seed::seedValue];
		create simulation with: [initial_inform_strategy::"closest", seed::seedValue];
	}
	
	permanent {
		display Comparison background: #white {
			chart "Evacuees over time" type: series {
				loop s over: simulations {
					if (!dead(s)) {
					data "Evacuees " + s.initial_inform_strategy value: s.number_evacuted_people color: s.color marker: false style: line thickness: 3;
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
			species red_river;
		}
	}
}