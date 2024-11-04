/*
The model for real time systems with
the non-preemptive global fixed priority scheduler,
the preemptive global fixed priority scheduler, 
the non-preemptive earliest deadline priority scheduler, and 
the preemptive earliest deadline priority scheduler (P-EDF). 
@author Natalia Garanina natta.garanina@gmail.com https://www.researchgate.net/profile/Natalia-Garanina
@conference PSSV-2024
@license GNU GPL
*/

#deBADDe NumProc 3		// the number of processors 
#deBADDe NumTask 6		// the number of tasks -- max = 126
byte busy = 0

bool release[NumTask];	// list of released  
bool go[NumTask];		// list of active  
bool end[NumTask];		// just finished  

byte C_cur[NumTask];
byte D_cur[NumTask];
byte que[NumTask];
short Util = 0;


chan task_shed = [0] of { bool };

bool BADD = false;

byte j = 0;
byte old = 0;
byte tmp = 0;
bool ins = false;
bool plan = false;

init{ 

atomic{  
  run tasks(); 
//  run schedulerNPGPF();
//  run schedulerPGPF();
//  run schedulerNPEDF();
//  run schedulerPEDF();
}
}



inline insert_queEDF(k){

ins = false;

for (j : 0 .. NumTask-1){ 
	if
	:: que[j] == k -> break;
	:: else -> skip;
	fi
	if
	:: que[j] == 255 -> 
		if
		:: !ins -> que[j] = k; ins = true;
		:: else -> que[j] = old;
		fi	
		break;		
	:: else -> skip;
	fi
	if
	:: !ins ->
		if 
		:: D_cur[k] < D_cur[que[j]] -> 
			old = que[j];
			que[j] = k;
			ins = true;
		:: else -> skip
		fi
	:: else ->
		tmp = que[j];
		que[j] = old;
		old = tmp;
	fi 
}

}

inline delete_que(k){
for (j : 0 .. NumTask-1){ 
	if
	:: que[j] == k -> que[j] = 255; break;
	:: else -> skip
	fi
	}
}

inline rearrange_que(){

old = 0;
for (j : 0 .. NumTask-1){ 
	if
	:: que[j] != 255 && j == old -> old++;
	:: que[j] != 255 && j > old -> que[old] = que[j]; que[j] = 255; old++;
	:: else -> skip;
	fi
	}
}

inline task_plan(me, C, D){
	if 
	::  C_cur[me] == C && D_cur[me] == D && !release[me] -> // release
		if 
		:: release[me] = true; 
		   plan = true;
		:: skip; 
		fi
		
	:: C_cur[me] == 0 -> // finish 
			busy--;
			C_cur[me] = C;
			go[me] = false;
			if 
			:: D_cur[me] == 0 -> 
				D_cur[me] = D;
				if 
				:: release[me] = false; 
				:: skip; 
				fi			
			:: else -> release[me] = false; end[me] = true;
			fi
			plan = true;

	:: C_cur[me] > D_cur[me] && release[me] -> // fail deadline
			BADD = true; // point 6, 7
			tmp = me;
	:: else -> skip;
	fi
}

inline task_step(me, C, D){
	if 
	:: C_cur[me] > 0 && D_cur[me] > 0 && C_cur[me] <= D_cur[me] && release[me] ->  
			if 
			::  go[me] -> 
					C_cur[me]--; D_cur[me]--;  	// executing job
			:: else -> D_cur[me]--; 			// waiting execution
			fi		
		
	::  C_cur[me] == C && D_cur[me] > 0 && D_cur[me] < D && !release[me] -> // time till new release
			D_cur[me]--; 
			if 
			:: D_cur[me] == 0 -> 
				D_cur[me] = D;
			:: else -> skip;
			fi

	:: else -> skip;
	fi
}




proctype tasks () { 

byte i;

atomic{
	for (i : 0 .. NumTask-1){ 
		C_cur[i] = i+1;
		D_cur[i] = 2*(i+2); 
		Util = Util + (100*(i+1))/(2*(i+2)); 
		que[i] = 255;
	}
Util = Util/NumProc;
}

do 
  :: atomic{
		for (i : 0 .. NumTask-1){ task_plan(i, i+1, 2*(i+2)); }
		if
		:: BADD -> break;
		:: else ->
			if 
			:: plan ->
				task_shed ! true;
				task_shed ? false;
				plan = false;
			:: else -> skip;
			fi
			for (i : 0 .. NumTask-1){ task_step(i, i+1, 2*(i+2)); }
		fi
	}
od
}

proctype schedulerNPGPF(){ 

byte free = 0;
byte i = 0;

 do 
 :: task_shed ? true ->
	atomic{
		free = NumProc - busy;
		for (i : 0 .. NumTask - 1){ 
			if 
			:: free == 0 -> break;
			:: else -> 
				if 
				:: release[i] && !go[i] && free != 0 -> 				
					go[i] = true; // go!
					busy++;
					free--;
				:: else -> skip;
				fi							
			fi	
		}
		task_shed ! false;
	}
 ::	BADD -> break;
 od;
}



proctype schedulerPGPF(){ 

byte i = 0;

 do 
 :: task_shed ? true ->
	atomic{
		for (i : 0 .. NumTask - 1){ 
			if 
			:: release[i] && !go[i] -> 				
				go[i] = true; // go!
			:: else -> skip;
			fi	
		}
		busy = 0;		
		for (i : 0 .. NumTask - 1){ 
			if 
			:: busy == NumProc -> 				
				if 
				:: go[i] -> 				
					go[i] = false; // stop!
				:: else -> skip;
				fi				
			:: else -> 
				if 
				:: go[i] -> 				
					busy++; // go!
				:: else -> skip;
				fi
			fi	
		}
		task_shed ! false
	}
 ::	BADD -> break;
 od;
}


proctype schedulerNPEDF(){ 

byte free = 0;
byte i = 0;

 do 
 :: task_shed ? true ->
	atomic{
		for (i : 0 .. NumTask - 1){
			if 
			:: release[i] && !go[i] -> 	insert_queEDF(i)
			:: else -> skip;
			fi				
		}
		free = NumProc - busy;
		for (i : 0 .. NumTask - 1){ 
			if 
			:: free == 0 || que[i] == 255 -> break;
			:: else -> 
					go[que[i]] = true; // go!
					que[i] = 255;
					busy++;
					free--;
			fi	
		}
		rearrange_que()
		task_shed ! false	
	}
 ::	BADD -> break;
 od;
}

proctype schedulerPEDF(){ 

byte i = 0;

 do 
 :: task_shed ? true ->
	atomic{
		for (i : 0 .. NumTask - 1){
			if 
			:: end[i] -> 	
				delete_que(i); 
				end[i] = false;
			:: else -> skip;
			fi				
		}
		rearrange_que()
		for (i : 0 .. NumTask - 1){
			if 
			:: release[i] && !go[i] -> 	
				insert_queEDF(i) 
				go[i] = true;
			:: else -> skip;
			fi				
		}
		busy = 0;
		for (i : 0 .. NumTask - 1){ 
			if
			:: que[i] == 255 -> break;
			:: else -> skip;
			fi
			if 
			:: busy == NumProc -> 				
				if 
				:: go[que[i]] -> 				
					go[que[i]] = false; // stop!
				:: else -> skip;
				fi				
			:: else -> 
				if 
				:: go[que[i]] -> 
					busy++; 
				:: else -> skip;
				fi
			fi		
		}
		task_shed ! false	
	}
 ::	BADD -> break;
 od;
}


 ltl p1 {[]!BADD } 


 
