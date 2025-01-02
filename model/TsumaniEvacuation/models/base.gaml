/**
* Name: base
* Based on the internal empty template. 
* Author: dung
* Tags: 
*/


model base


global{
	shape_file shapefile_buildings  <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads 		<- shape_file("../includes/clean_roads.shp");
	shape_file shapefile_evacuation <- shape_file("../includes/evacuation.shp");
	shape_file shapefile_river		<- shape_file("../includes/RedRiver_scnr1.shp");
		
	geometry shape <- envelope(shapefile_roads);
	
	graph road_network;
	
	// State
	bool flooding_is_informed <- false;
	map<road,float> road_weights;
	list<building> evacuations;
	
	
	// Monitor
	int number_of_unknown -> inhabitant count !each.is_evacuating;
	int number_evacuted_people <- 0;
	
	float step <- 10#s;
	
	// Param
	string initial_inform_strategy <- "random";
	
	int max_n_inhabitants_in_building <- 5;
	date starting_date <- date([1980,1,2,8,0,0]);
	
	date flooding_date <- date([1980,1,2,8,30,0]);
	
	date flooding_inform_date <- date([1980,1,2,8,0,0]);
	
	int nb_of_people <- 1000;
	
	float percentage_of_people_are_informed <- 0.1;
	float percentage_of_people_known_shelter <- 0.1;
	float percentage_of_following_evaculating <- 0.1;
	float percentage_of_share_shelter <- 0.1;
	float percentage_of_car <- 0.2;
	float percentage_of_bike <- 0.7;
	float percentage_of_walking <- 0.1;
	float pedestrians_speed <- 5 #km/#h; 
	float traffic_weight_factor <- 1.0;
	
	
	init {
		create building from: shapefile_buildings with:[height::int(read("height"))];
		
		create road from: shapefile_roads;
      	
		road_network <- as_edge_graph(road);
		
//		create evacuation from:shapefile_evacuation;
		
		create red_river from:shapefile_river;
		
		evacuations <- 8 first (building sort_by -each.shape.area);
		ask evacuations {
			self.is_evacuation <- true;
		}
		
		int count <- 0;
		create inhabitant number: nb_of_people {
			count <- count + 1;
			if count < nb_of_people * percentage_of_car {
				traffic_weight <- traffic_weight_factor * 5;
				speed <- 10 * pedestrians_speed;
				mobility <- "car";
//				write("car " + count);
			} else if count < nb_of_people * (percentage_of_car + percentage_of_bike) {
				traffic_weight <- traffic_weight_factor * 2.5;
				speed <- 8.5 * pedestrians_speed;
				mobility <- "bike";
//				write("bike " + count);
			} else {
				traffic_weight <- traffic_weight_factor;
				speed <- pedestrians_speed;
				mobility <- "foot";
//				write("foot " + count);
			}
			 
       		location <- any_location_in(one_of(building));
       		
       		ask any(building where (!each.is_evacuation and length(each.inhabitants) < max_n_inhabitants_in_building)) {
				self.inhabitants << myself;
				myself.location <- any_location_in(self);
			}
      	}
      	
      	ask (int(percentage_of_people_known_shelter * length(inhabitant))) among inhabitant {
      		target_shelter <- evacuations closest_to self;
      	}
	}
	
	reflex flooding_announce when: flooding_inform_date <= current_date and !flooding_is_informed {		
		flooding_is_informed <- true;
		
		int nb_informing_people <- int(percentage_of_people_are_informed * length(inhabitant));
		
		if (initial_inform_strategy = "random") {
			ask nb_informing_people among inhabitant {
	      		do evacuate();
	      	}
      	} else if (initial_inform_strategy = "furthest") {
      		ask inhabitant {
      			distance_to_shelter <- max(evacuations collect distance_to(self, each));
      		}
      		ask nb_informing_people first (inhabitant sort_by -each.distance_to_shelter) {
      			do evacuate();
      		}
      	} else {
      		ask inhabitant {
      			distance_to_shelter <- min(evacuations collect distance_to(self, each));
      		}
      		ask nb_informing_people first (inhabitant sort_by each.distance_to_shelter) {
      			do evacuate();
      		}
      	}
	} 
	
	reflex update_speed {
		road_weights <- road as_map (each::each.shape.perimeter / each.speed_rate);
	}
	
	reflex stop {
		if length(inhabitant) = 0 {
			do pause;
		}
	}
	
}



species building {
	bool is_evacuation;
	bool is_safe <- true;
	
	list<inhabitant> inhabitants;
	
	int height;
	aspect default {
		draw shape color: (is_evacuation) ? #red: #gray;
	}
	
	reflex evacuating_people when: is_evacuation every(5#s) {
		ask (inhabitant at_distance 20#m) {
			target_shelter <- myself;
			target <- any_location_in(target_shelter);
		}
		ask (inhabitant at_distance 0.5#m) {
			number_evacuted_people <- number_evacuted_people + 1;
			do die;
		}
	}
}

species road {
	
	float capacity 	<- 1 + shape.perimeter/10;
	float total_traffic_weight 	<- 0.0 update: sum((inhabitant at_distance 1) collect each.traffic_weight);
	float speed_rate <- 1.0 update:  exp(-total_traffic_weight/capacity) min: 0.1;
	
	aspect default {
		draw (shape + 3 * speed_rate) color: #brown;
	}

//	aspect default {
//		draw (shape) color: #black;
//	}
}


species inhabitant skills: [moving]{
	float distance_to_shelter;
	
	list<building> visited_buildings <- [];
	date start_evacuating_date;
	
	building target_shelter;
	bool is_evacuating <- false;
	point target;
	
	rgb color 			<- rnd_color(255);
	float speed 		<- 5 #km/#h;
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
		if(!is_evacuating) {
			start_evacuating_date <- current_date;
		}
		is_evacuating <- true;
	}
	
	
//	 if a target is defined we try to reach it via the road network
	reflex move when: target != nil {
		do goto target: target on: road_network move_weights:road_weights;
		if (location distance_to target < 1#m) {
			location <- target;
			target <- nil;
		}		
	}
	
//	reflex move when: target != nil {
//		do goto target: target on: road_network;
//		if (location distance_to target < 1#m) {
//			location <- target;
//			target <- nil;
//		}		
//	}
	
	reflex observe_evaculating when: !is_evacuating and flip(percentage_of_following_evaculating) every(5#s) {
		if !empty((inhabitant where each.is_evacuating) at_distance 20#m)  {
			do evacuate();
			write("observe evaculating");
		}
	}
	
	reflex share_shelter when: is_evacuating and every(5#s) and flip(percentage_of_share_shelter) {
		ask inhabitant at_distance 10#m {
			building shelter <- [myself.target_shelter, self.target_shelter] closest_to myself;
			if (shelter != nil) {
				target_shelter <- shelter;
				target <- any_location_in(shelter);
				myself.target_shelter <- shelter;
				myself.target <- any_location_in(shelter);
				
				write("Share the shelter");
			}
		}
	}
	
	reflex find_shelter when: target = nil and is_evacuating every(5#s) {
		building target_building <- target_shelter;
		if (target_building = nil) {
			write("randomly find another shelter");
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

// Represents the red river
species red_river{
	
	float grow_rate <- 0.5;
	float flooding_speed <- 0.1;
	
	reflex expand when: flooding_date <= current_date and every(1#m) 
	{
		grow_rate <- grow_rate + flooding_speed;
		shape <- shape + grow_rate;
	}
	
	reflex kill {
		bool destroyedRoad;
		
		ask (inhabitant overlapping self.shape) {
			do die;
		}
		
		ask (building overlapping self.shape) {
			is_safe <- false;
		}
		
		ask (road overlapping self.shape) {
			destroyedRoad <- true;
			do die;
		}
		if (destroyedRoad) {
			road_network <- as_edge_graph(road);
			road_weights <- road as_map (each::each.shape.perimeter / each.speed_rate);
		}
	}
	
	aspect default {
		draw shape color:#blue;
	}
}


experiment evacuation_exp type: gui virtual: true {
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "initial_inform_strategy" var: initial_inform_strategy <- "random" among: ["random","furthest","closest"]; 
	
	output {
		monitor number_of_unknown value: number_of_unknown;
		monitor number_evacuted_people value: number_evacuted_people;
		
		display map {
//			image "../includes/satellite.png" refresh: false transparency: 0.9;			
			species building;
			species road;
			species inhabitant;
//			species evacuation;
			species red_river;
		}
	}
}
