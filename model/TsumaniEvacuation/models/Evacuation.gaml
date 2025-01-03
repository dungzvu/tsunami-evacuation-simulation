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
	
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 1000 among: [500, 1000, 2000, 3000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [30, 60, 90, 120];
	parameter "share_shelter_knowledge" category: "Extended" var: _can_share_shelter_knowledge init: false;
	
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
	
	output {
		layout #split editors: false consoles: false toolbars: true tabs: true tray: true parameters: true;
		
		monitor number_evacuted_people value: number_evacuted_people;
		monitor total_evacuation_time value: total_evacuation_time;
		monitor total_time_in_roads value: total_time_in_roads;
		monitor efficiency value: efficiency;
		
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
	
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 2000 among: [500, 1000, 2000, 3000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [30, 60, 90, 120];
	parameter "share_shelter_knowledge" category: "Extended" var: _can_share_shelter_knowledge init: false;
	
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
		
		display Efficiency background: #white {
			chart "Efficiency over time" type: series {
				loop s over: simulations {
					if (!dead(s)) {
					data "Efficiency " + s.initial_inform_strategy value: s.efficiency 
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
			species red_river;
		}
	}
}

experiment batch_share_knowledge type: batch repeat: 12 keep_seed: true until: world.is_finished or cycle*step > 60#minute {
	method exploration;
	
	parameter "share_shelter_knowledge" category: "Extended" var: _can_share_shelter_knowledge init: false among: [true, false];
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 1000 among: [500, 1000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 60;
	
	
	permanent {
		display Comparison type: 2d {
			chart "Efficiency" type: series {
				data "no share" style: spline color: #blue 
					value: mean((simulations where !each._can_share_shelter_knowledge) collect each.efficiency)
					y_err_values: [
						min((simulations where !each._can_share_shelter_knowledge) collect each.efficiency),
						max((simulations where !each._can_share_shelter_knowledge) collect each.efficiency)
					];
				data "share" style: spline color: #darkgreen
					value: mean((simulations where each._can_share_shelter_knowledge) collect each.efficiency)
					y_err_values: [
						min((simulations where each._can_share_shelter_knowledge) collect each.efficiency),
						max((simulations where each._can_share_shelter_knowledge) collect each.efficiency)
					]; 
			}
		}	
	}
}

experiment best_effective type: batch repeat: 5 keep_seed: true until: is_finished or (time > flooding_alert_time_minutes#minute) {
    method exploration;
	
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 1000 among: [500, 1000, 1500, 2000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [30, 60, 90, 120];
	parameter "share_shelter_knowledge" category: "Extended" var: _can_share_shelter_knowledge init: true;

    permanent {
        display BestEffectiveChart {
        	// Chart 1: Efficiency by Strategy
            chart "Efficiency by Strategy" type: series {
                data "Random" value: mean(simulations where (each.initial_inform_strategy = "random") collect 
                    (each.efficiency)) color: #red;
                data "Furthest" value: mean(simulations where (each.initial_inform_strategy = "furthest") collect 
                    (each.efficiency)) color: #green;
                data "Closest" value: mean(simulations where (each.initial_inform_strategy = "closest") collect 
                    (each.efficiency)) color: #blue;
            }
        }
    }
}
