/**
* Name: batch
* Based on the internal empty template. 
* Author: dung
* Tags: 
*/


model batch

import "base.gaml"


global {
	string file_csv_name -> "../results/batch.csv";
}

experiment best_effective type: batch repeat: 5 keep_seed: true until: is_finished or (time > flooding_alert_time_minutes#minute) {	
	parameter "initial_inform_strategy" category: "Base Parameters" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	parameter "nb_of_people" category: "Base Parameters" var: nb_of_people init: 1500 among: [1500, 2000, 3000, 4000];
	parameter "flooding_alert_time_minutes" category: "Base Parameters" var: flooding_alert_time_minutes init: 120 among: [60, 90, 120];

	reflex t {
		write("Write result");
		save [
			first(simulations).nb_of_people,
			first(simulations).initial_inform_strategy,
			simulations mean_of each.flooding_alert_time_minutes,
			simulations mean_of each.number_evacuted_people,
			simulations mean_of each.total_time_in_roads,
			simulations mean_of each.efficiency
		] to: file_csv_name 
					format:"csv" rewrite: false;
	}

	method exploration;
	
}
