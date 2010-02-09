/ k4 unit testing, loads tests from csv's, runs+logs to database
/ csv columns: action,ms,space,lang,code (csv with colheaders)
/ if your code contains commas enclose the whole code in "quotes"
/ usage: q k4unit.q -p 5001
/ KUT <-> KUnit Tests
KUT:([]action:`symbol$();ms:`int$();space:`long$();lang:`symbol$();code:`symbol$();repeat:`int$();file:`symbol$();comment:())
/ KUltd `:dirname and/or KUltf `:filename.csv
/ KUrt[] / run tests
/ KUTR <-> KUnit Test Results
/ KUrtf`:filename.csv / refresh expected <ms> and <space> based on observed results in KUTR
KUTR:([]action:`symbol$();ms:`int$();space:`long$();lang:`symbol$();code:`symbol$();repeat:`int$();file:`symbol$();msx:`int$();spacex:`long$();ok:`boolean$();okms:`boolean$();okspace:`boolean$();valid:`boolean$();timestamp:`datetime$())
/ look at KUTR in browser or q session
/ select from KUTR where not ok // KUerr
/ select from KUTR where not okms // KUslow
/ select count i by ok,okms,action from KUTR
/ select count i by ok,okms,action,file from KUTR
/ KUstr[] / save test results 
/ KUltr[] / reload previously saved test results
/ action:	
/ `beforeany - onetime, run before any tests
/		`beforeeach - run code before tests in every file
/			`before - run code before tests in this file ONLY
/			`run - run code, check execution time against ms
/			`true - run code, check if returns true(1b)
/			`fail - run code, it should fail (2+`two)
/			`after - run code after tests in this file ONLY
/		`aftereach - run code after tests in each file
/	`afterall - onetime, run code after all tests, use for cleanup/finalise
/ lang: k or q (or s if you really feel you must..), default q
/ code: code to be executed
/ repeat: number of repetitions (do[repeat;code]..), default 1
/ ms: max milliseconds it should take to run, 0 => ignore
/ space: bytes it should take to run, 0 => ignore
/ file: filename
/ action,ms,space,lang,code,file: from KUT
/ msx: milliseconds taken to eXecute code
/ spacex: bytes used to eXecute code 
/ ok: true if the test completes correctly (note: its correct for a fail task to fail)
/ okms: true if msx is not greater than ms, ie if performance is ok
/ okspace: true if spacex is not greater than space, ie if memory usage is ok
/ valid: true if the code is valid (ie doesn't crash - note: `fail code is valid if it fails)
/ timestamp: when test was run
/ comment: description of the test if it's obscure.. 

KUstr:{.KU.SAVEFILE 0:.KU.DELIM 0:update code:string code from KUTR} / save test results
KUltr:{`KUTR upsert("SIJSSIJSIBBBBZ";enlist .KU.DELIM)0:.KU.SAVEFILE} / reload previously saved test results 

KUltf:{ / (load test file) - load tests in csv file <x> into KUT
	before:count KUT;
	KUT,:update file:x,action:lower action,lang:`q^lower lang,ms:0^ms,space:0j^space,repeat:1|repeat from `action`ms`space`lang`code`repeat`comment xcol("SIJSSI*";enlist .KU.DELIM)0:x:hsym x;
	/KUT,:update file:x,action:lower action,lang:`q^lower lang,ms:0^ms,space:0j,repeat:1|repeat from `action`ms`lang`code`repeat`comment xcol("SISSI*";enlist .KU.DELIM)0:x:hsym x;
	neg before-count KUT}

KUltd:{ / (load test dir) - load all *.csv files in directory <x> into KUT
	before:count KUT;
	files:(` sv)each(x,'key x);KUltf each files where(lower files)like"*.csv";
	neg before-count KUT}                   

KUrt:{ / (run tests) - run contents of KUT, save results to KUTR
	before:count KUTR;uf:exec asc distinct file from KUT;i:0;
	if[.KU.VERBOSE;-1(string .z.Z)," start"];
	exec KUexec'[lang;code;repeat] from KUT where action=`beforeany;
	do[count uf;
		ufi:uf[i];KUTI:select from KUT where file=ufi;
		if[.KU.VERBOSE;
			-1(string .z.Z)," ",(string ufi)," ",(string exec count i from KUTI where action in `run`true`fail)," test(s)"];
		exec KUexec'[lang;code;repeat] from KUT where action=`beforeeach;
		exec KUexec'[lang;code;repeat] from KUTI where action=`before;
		/ preserve run,true,fail order
		exec KUact'[action;lang;code;repeat;ms;space;file]from KUTI where action in`true`fail`run;
		exec KUexec'[lang;code;repeat] from KUTI where action=`after;
		exec KUexec'[lang;code;repeat] from KUT where action=`aftereach;
		i+:1];
	exec KUexec'[lang;code;repeat] from KUT where action=`afterall;
	if[.KU.VERBOSE;-1(string .z.Z)," end"];
	neg before-count KUTR}

KUpexec:{[prefix;lang;code;repeat;allowfail] 
	s:prefix,(string lang),")",$[1=repeat;string code;"do[",(string repeat),";",(string code),"]"];
	if[1<.KU.VERBOSE;-1 s];$[.KU.DEBUG&allowfail;value s;@[value;s;`FA1L]]}

KUexec:{[lang;code;repeat]
	value(string lang),")",$[1=repeat;string code;"do[",(string repeat),";",(string code),"]"]}

KUact:{[action;lang;code;repeat;ms;space;file]
	msx:0;spacex:0j;ok:okms:okspace:valid:0b;
	if[action=`run;
		failed:`FA1L~r:KUpexec["\\ts ";lang;code;repeat;1b];msx:`int$$[failed;0;r 0];spacex:`long$$[failed;0;r 1];
		ok:not failed;okms:$[ms;not msx>ms;1b];okspace:$[space;not spacex>space;1b];valid:not failed];
	if[action=`true;
		failed:`FA1L~r:KUpexec["";lang;code;repeat;1b];
		ok:$[failed;0b;r~1b];okms:okspace:1b;valid:not failed];
	if[action=`fail;
		failed:`FA1L~r:KUpexec["";lang;code;repeat;0b];
		ok:failed;okms:okspace:valid:1b];
	`KUTR insert(action;ms;space;lang;code;repeat;file;msx;spacex;ok;okms;okspace;valid;.z.Z);
	}
	
KUrtf:{ / (refresh test file) updates test file x with realistic <ms> based on seen values of msx from KUTR
	if[not x in exec file from KUTR;'"no test results found"];
	/x 0:.KU.DELIM 0:select action,ms,lang,string code,repeat,comment from((`code xkey KUT)upsert select code,ms:floor 1.25*msx from KUTR)where file=x}
	kut:`code xkey select from KUT where file=x;kutr:select from KUTR where file=x,action=`run;
	x 0:.KU.DELIM 0:select action,ms,space,lang,string code,repeat,comment from kut upsert select code,space:`long$floor 1.5*spacex,ms:75|floor 1.5*msx,repeat:500000&floor repeat*50%1|msx from kutr}

KUf::distinct exec file from KUTR / fristance: KUrtf each KUf
KUslow::delete okms from select from KUTR where not okms
KUslowf::distinct exec file from KUslow
KUerr::delete ok from select from KUTR where not ok
KUerrf::distinct exec file from KUerr
KUinvalid::delete ok,valid from select from KUTR where not valid
KUinvalidf::distinct exec file from KUinvalid

\d .KU
/ VERBOSE:
/ 0 - no logging to console
/ 1 - log filenames
/>1 - log tests
VERBOSE:1
/ DEBUG:
/0 - trap errors, press on regardless
/1 - suspend if errors (except if action=`fail of course)
DEBUG:0
/ DELIM, csv delimiter
DELIM:","
/ Test Results SAVEFILE
SAVEFILE:`:KUTR.csv
