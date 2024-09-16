
#define MAX 21			// the number of processors
#define NumPrc 40		// the number of tasks
byte work = 0;	// the number of working tasks
byte busy = 0;


bool req_prc[NumPrc];				// list of requests  
chan request = [1] of { byte };
chan responce[NumPrc] = [0] of { bool };

bool FIN = false;

init{ 

 byte i;
  
atomic{  
  for (i : 0 .. NumPrc-1){ run task(i, i+1, 2*(i+2)); }
  run scheduler();
}
}


proctype task (byte me; byte C; byte D) { 

bool go = false;
bool release = false;


byte C_cur = C;
byte D_cur = D;

do 
	::  atomic{	C_cur == C && D_cur == D && !release -> // release
		if 
		:: release = true;
			request ! me
			work++;
			responce[me] ? go
			if 
			::  go -> 
					C_cur--; D_cur--; busy++; // point 2.c
			:: else -> D_cur--; // point 2.b
			fi 
		:: work++; // point 2.a
		fi
		responce[me] ? _
		}
		
	:: atomic{ C_cur == C && D_cur > 0 && D_cur < D && C_cur <= D_cur && release -> // release and not started
			request ! me
			work++;
			responce[me] ? go
			if 
			::  go -> 
					C_cur--; D_cur--; busy++; // point 4
			:: else -> D_cur--; // point 3
			fi		
//			assert (C_cur <= D_cur)
			responce[me] ? _
		}
		
	:: atomic{ C_cur > 0 && C_cur < C && D_cur > 0 && D_cur < D && C_cur <= D_cur && release -> // executing job
			work++; C_cur--; D_cur--; // point 4
			responce[me] ? _
		}
	
	:: 	atomic{ C_cur == 0 -> // finish
//			busy--;
			if 
			:: D_cur > 0 -> // point 5.b and 5.c
				work++;
				busy--;
				C_cur = C;
				release = false;
				D_cur--;
			:: else -> 
				if
				::  true -> 
					request ! me
					work++;
					busy--;
					responce[me] ? go
					if 
					::  go -> 
							C_cur = C - 1; D_cur = D - 1; busy++; // point 5.a.i
					:: else -> D_cur = D - 1; // point 5.a.ii
					fi 			
				:: work++; // point 5.a.iii
				   busy--;
				   C_cur = C;
				   D_cur = D;
				   release = false;
				fi			
			fi
			responce[me] ? _
		}

	:: 	atomic{ C_cur == C && D_cur > 0 && D_cur < D && !release -> // time till release
			work++; //  point 5.b and 5.c
			D_cur--; 
			responce[me] ? _
		}
	
	:: 	atomic{ C_cur == C && D_cur == 0 && !release -> // may release again
			if
			::  release = true;
				request ! me
				work++;
				responce[me] ? go
				if 
				::  go -> 
						C_cur = C - 1; D_cur = D - 1; busy++; // point 5.a.i
				:: else -> D_cur = D - 1; // point point 5.a.ii
				fi 			
			:: work++; D_cur = D; // point 5.a.iii
			fi
			responce[me] ? _
		}

	:: atomic{ C_cur > D_cur && release -> // fail deadline
			FIN = true; // point 6, 7
			break;
		}
	:: FIN -> break;
od

}

proctype scheduler(){ 

byte num = 0;
byte i = 0;
bool end = false;

 do 
 :: atomic{ work > 0 && !end -> 
	if // 
	::  nempty(request) -> 
		request ? num;
		req_prc[num] = true; 
		i++;
	::  work == NumPrc && empty(request) -> end = true;
	fi
	} 
 :: atomic{ work == NumPrc && empty(request) -> 	
		end = false;
		if 
		:: i > 0 ->
			num = MAX - busy;
			i = 0;
			for (i : 0 .. NumPrc - 1){ 
				if 
				:: req_prc[i] && num != 0 -> 				
					responce[i] ! true; // go!
					req_prc[i] = 0;
					num--;
				:: req_prc[i] && num == 0 -> 				
					responce[i] ! false; // not go!
					req_prc[i] = 0;
				:: else -> skip;
				fi				
			}	
			num = 0;
		:: else -> skip;
		fi
		work = 0;		
		for (i : 0 .. NumPrc - 1){ responce[i] ! true }
		i = 0;
	}
 ::	FIN -> break;
 od;
}


 ltl p1 {[]!FIN } 


 
