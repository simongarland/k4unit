/ k4 unit testing, loads tests from csv's, runs+logs to database
/ csv columns: action,ms,lang,code (csv with colheaders)
/ if your code contains commas enclose the whole code in "quotes"
/ usage: q k4unit.q -p 5001
/ KUT <-> KUnit Tests
KUit:{KUT::([]action:`symbol$();ms:`int$();lang:`symbol$();code:`symbol$();repeat:`int$();file:`symbol$();comment:());}
/ KUltd `:dirname and/or KUltf `:filename.csv
/ KUrt[] / run tests
/ KUTR <-> KUint Test Results
/ KUrtf`:filename.csv / refresh expected <ms> based on observed results in KUTR
KUitr:{KUTR::([]action:`symbol$();ms:`int$();lang:`symbol$();code:`symbol$();repeat:`int$();file:`symbol$();msx:`int$();ok:`boolean$();okms:`boolean$();valid:`boolean$();timestamp:`datetime$());}
/ look at KUTR in browser or q session
/ select from KUTR where not ok // KUerr
/ select from KUTR where not okms // KUslow
/ select count i by ok,okms,action from KUTR
/ select count i by ok,okms,action,file from KUTR
/ KUstr[] / save test results 
/ KUltr[] / reload previously saved test results
/ action:	
/     `beforeany - onetime, run before any tests
/			`beforeeach - run code before tests in every file
/			`before - run code before tests in this file ONLY
/			`run - run code, check execution time against ms
/			`true - run code, check if returns true(1b)
/			`fail - run code, it should fail (2+`two)
/			`after - run code after tests in this file ONLY
/			`aftereach - run code after tests in each file
/			`afterall - onetime, run code after all tests, use for cleanup/finalise
/ lang: k or q (or s if you really feel you must..), default q
/ code: code to be executed
/ repeat: number of repetitions (do[repeat;code]..)
/ ms: max milliseconds it should take to run, 0 => ignore
/ file: filename
/ action,ms,lang,code,file: from KUT
/ msx: milliseconds taken to eXecute code
/ ok: true if the test completes correctly (note: its correct for a fail task to fail)
/ okms: true if msx is not greater than ms, ie if performance is ok
/ valid: true if the code is valid (ie doesn't crash - note: `fail code is valid if it fails)
/ timestamp: when test was run
/ comment: description of the test if it's obscure.. 

KUstr:{save`:KUTR.csv} / save test results
KUltr:{`KUTR upsert("SISSISIBBBZ";enlist",")0:`:KUTR.csv} / reload previously saved test results 

KUit KUitr[];

KUltf:{ / (load test file) - load tests in csv file <x> into KUT
	before:count KUT;
	KUT,:update file:x,action:lower action,lang:`q^lower lang,ms:0^ms,repeat:1|repeat from `action`ms`lang`code`repeat`comment xcol("SISSI*";enlist",")0:x:hsym x;
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
		exec KUact'[action;lang;code;repeat;ms;file]from KUTI where action in`true`fail`run;
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

KUact:{[action;lang;code;repeat;ms;file]
		if[action=`run;
			failed:`FA1L~r:KUpexec["\\t ";lang;code;repeat;1b];ti:$[failed;0;r];
			`KUTR insert(action;ms;lang;code;repeat;file;ti;not failed;$[ms;not ti>ms;1b];not failed;.z.Z)];
		if[action=`true;
			failed:`FA1L~r:KUpexec["";lang;code;repeat;1b];
			`KUTR insert(action;0;lang;code;repeat;file;0;$[failed;0b;r~1b];1b;not failed;.z.Z)];
	 	if[action=`fail;
			failed:`FA1L~r:KUpexec["";lang;code;repeat;0b];
			`KUTR insert(action;0;lang;code;repeat;file;0;failed;1b;1b;.z.Z)];
	}
	
KUrtf:{ / (refresh test file) updates test file x with realistic <ms> based on seen values of msx from KUTR
	if[not x in exec file from KUTR;'"no test results found"];
	x 0: .h.cd select action,ms,lang,string code,repeat,comment from((`code xkey KUT)upsert select code,ms:floor 1.25*msx from KUTR)where file=x}

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
