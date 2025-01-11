/**
* Name: base
* Based on the internal empty template. 
* Author: dung
* Tags: 
*/


model base


global{
	// SHAPE definitions
	shape_file shapefile_buildings  <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads 		<- shape_file("../includes/clean_roads.shp");
	shape_file shapefile_evacuation <- shape_file("../includes/evacuation.shp");
	shape_file shapefile_river		<- shape_file("../includes/RedRiver_scnr1.shp");
	geometry shape <- envelope(shapefile_roads);
	
	// STATE of the model
	map<road,float> road_weights;
	building shelter;
	graph road_network;
	bool is_finished;
	
	
	// MONITOR metrics
	int number_evacuted_people <- 0;
	int total_evacuation_time <- 0;
	int total_time_in_roads <- 0;
	float efficiency -> number_evacuted_people * flooding_alert_time_minutes#m / (total_time_in_roads+1);
	
	float step <- 10#s;
	
	// PARAMETERS
	int flooding_alert_time_minutes <- 120;
	string initial_inform_strategy <- "random";
	int nb_of_people <- 1000;
	
	// fixed parameters
	int max_n_inhabitants_in_building <- 5;
	float percentage_of_people_are_informed <- 0.1;
	float percentage_of_people_known_shelter <- 0.1;
	float percentage_of_following_evaculating <- 0.1;
	float percentage_of_car <- 0.2;
	float percentage_of_bike <- 0.7;
	float percentage_of_walking <- 0.1;
	float pedestrians_speed <- 5 #km/#h; 
	float traffic_weight_factor <- 1.0;
	
	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
      	
		road_network <- as_edge_graph(road);
//		shelter <- building with_max_of each.shape.area;
		shelter <- first_with(building, each.index = 1106);
		shelter.is_shelter <- true;
		
		// initialize the people mobilities. For each inhabitant, we assign .mobility for displaying,
		// .speed for moving and .traffic_weight for calculating the road's weight.
		int count <- 0;
		create inhabitant number: nb_of_people {
			count <- count + 1;
			if count < nb_of_people * percentage_of_car {
				traffic_weight <- traffic_weight_factor * 5;
				speed <- 10 * pedestrians_speed;
				mobility <- "car";
			} else if count < nb_of_people * (percentage_of_car + percentage_of_bike) {
				traffic_weight <- traffic_weight_factor * 2.5;
				speed <- 8.5 * pedestrians_speed;
				mobility <- "bike";
			} else {
				traffic_weight <- traffic_weight_factor;
				speed <- pedestrians_speed;
				mobility <- "foot";
			}
       		
       		// each people is placed to the random building, each building includes no more than 5 people.
       		ask any(building where (!each.is_shelter and length(each.inhabitants) < max_n_inhabitants_in_building)) {
				self.inhabitants << myself;
				myself.location <- any_location_in(self);
			}
      	}
      	
      	// announce the flooding/tsumani at the beginning of the simulation.
      	// the simulation then will finish within the alert time (which represented by flooding_alert_time_minutes parameter)
      	do flooding_announce();
	}
	
	action flooding_announce {		
		int nb_informing_people <- int(percentage_of_people_are_informed * length(inhabitant));
		
		// initialize the different informing strategies at the begining.
		if (initial_inform_strategy = "random") {
			write("Strategy: Random");
			ask nb_informing_people among inhabitant {
	      		do evacuate();
	      	}
      	} else if (initial_inform_strategy = "furthest") {
      		write("Strategy: Furthest");
      		ask nb_informing_people first (inhabitant sort_by -distance_to(shelter, each)) {
      			do evacuate();
      		}
      	} else {
      		write("Strategy: Closest");
      		ask nb_informing_people first (inhabitant sort_by distance_to(shelter, each)) {
      			do evacuate();
      		}
      	}
	} 
	
	reflex update_speed {
		road_weights <- road as_map (each::each.shape.perimeter / each.speed_rate);
	}
	
	// the simulation ends if the people are all evacuated or the time is up.
	reflex check_end_simulation when: !is_finished and (length(inhabitant) = 0 or (time > flooding_alert_time_minutes#minute)) {		
		ask inhabitant {
			do die;
		}
		
		is_finished <- true;
	}
	
}


species building {
	bool is_shelter;
	bool is_safe <- true;
	
	list<inhabitant> inhabitants;
	
	aspect default {
		draw shape color: (is_shelter) ? #red: #gray;
	}
}

species road {
	
	float capacity 	<- 1 + shape.perimeter/10;
	// calculate the total traffic weight of each road by the mobility traffic weight of all people on road.
	float total_traffic_weight 	<- 0.0 update: sum((inhabitant at_distance 1) collect each.traffic_weight);
	float speed_rate <- 1.0 update:  exp(-total_traffic_weight/capacity) min: 0.1;
	
	aspect default {
		draw (shape + 3 * speed_rate) color: #brown;
	}
}


species inhabitant skills: [moving]{	
	// I keep a list of visited buildings to prevent people continue visiting the same place.
	list<building> visited_buildings <- [];
	
	// Whether this person known about the shelter at the beginning.
	bool known_shelter;
	
	// Evacuation status
	bool is_evacuating <- false;

	point target;
	
	rgb color -> is_evacuating ? #blue : #yellow;
	
	// The moving attributes
	float speed <- 5 #km/#h;
	float traffic_weight;
	string mobility;

	aspect default {
		if mobility = "car" {
			draw rectangle(8, 8) color: color;
		} else if mobility = "bike" {
			draw triangle(8) color: color;
		} else {
			draw circle(3) color: color;
		}
	}
	
	action evacuate {
		is_evacuating <- true;
	}
	
	reflex move when: target != nil {
		do goto target: target on: road_network move_weights:road_weights;
		if (location distance_to target < 1#m) {
			location <- target;
			target <- nil;
		}		
		
		// Calculate the total time in roads by continuously increase the total in global
		// The inhabitant agent will be killed after evacuated, so don't worry about the correctness of this formula.
		total_time_in_roads <- total_time_in_roads + step;
	}
	
	// Trigger when people see any evacuating people at distance of 20m.
	reflex observe_evaculating when: !is_evacuating and flip(percentage_of_following_evaculating) {
		list evacuation_in_range <- (inhabitant where each.is_evacuating) at_distance 20#m;
		if !empty(evacuation_in_range) {
			do evacuate();
			if (flip(percentage_of_people_known_shelter)) {
				known_shelter <- true;
			}
		}
	}
	
	// continously find the shelter or go directly to the shelter if it at 20m distance.
	reflex find_shelter when: is_evacuating {
		if (shelter distance_to self < 1#m) {
			number_evacuted_people <- number_evacuted_people + 1;
			total_evacuation_time <- total_evacuation_time + time;
			do die;
			return;
		}
		
		building target_building <- known_shelter ? shelter : nil;
		if (target_building = nil) {
			if (shelter distance_to self < 20#m) {
				target_building <- shelter;
			}
			target_building <- one_of((building - visited_buildings) where each.is_safe);
		}
		visited_buildings << target_building;
		target <- any_location_in(target_building);
	}
	
}

// Represents a point of evacuation
species evacuation{
	
	aspect default {
		draw triangle(50) color:#red;
	}
}

experiment evacuation_exp type: gui virtual: true {
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "initial_inform_strategy" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	
	output {
		monitor number_evacuted_people value: number_evacuted_people;
		
		display map {		
			species building;
			species road;
			species inhabitant;
		}
	}
}
