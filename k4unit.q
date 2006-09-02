/ k4 unit testing, loads tests from csv's, runs+logs to database
/ csv columns: action,ms,lang,code (csv with colheaders)
/ if your code contains commas enclose the whole code in "quotes"
/ usage: q k4unit.q -p 5001
/ KUT <-> KUnit Tests
KUit:{KUT::([]action:`symbol$();ms:`int$();lang:`symbol$();code:`symbol$();file:`symbol$());}
/ KUltd `:dirname and/or KUltf `:filename.csv
/ KUrt[] / run tests
/ KUTR <-> KUint Test Results
KUitr:{KUTR::([]action:`symbol$();ms:`int$();lang:`symbol$();code:`symbol$();file:`symbol$();msx:`int$();ok:`boolean$();okms:`boolean$();valid:`boolean$();timestamp:`datetime$());}
/ look at KUTR in browser or using <show>
/ show select from KUTR where not ok
/ show select from KUTR where not okms
/ show select count i by ok,okms,action from KUTR
/ show select count i by ok,okms,action,file from KUTR
/ KUstr[] / save test results 
/ action:	`beforeany - onetime, run before any tests
/			`beforeeach - run code before tests in every file
/			`before - run code before tests in this file
/			`run - run code, check execution time against ms
/			`true - run code, check if returns true(1b)
/			`fail - run code, it should fail (2+`two)
/			`after - run code after tests in this file
/			`aftereach - run code after tests in each file
/			`afterall - onetime, run code after all tests
/ lang: k or q, default q
/ code: code to be executed
/ ms: max milliseconds it should take to run, 0 => ignore
/ file: filename
/ action,ms,lang,code,file: from KUT
/ msx: milliseconds taken to eXecute code
/ ok: true if the test completes correctly (note: its correct for a fail task to fail)
/ okms: true if msx is not greater than ms, ie if performance is ok
/ valid: true if the code is valid (ie doesn't crash - fail code is valid if it fails)
/ timestamp: when test was run

KUstr:{save`:KUTR.csv} / save test results
KUit KUitr[] 

KUltf:{ / (load test file) - load tests in file <x> into KUT
	before:count KUT;
	KUT,:update file:x,action:lower action,lang:`q^lower lang,ms:0^ms from `action`ms`lang`code xcol("SISS";enlist",")0:x:hsym x;
	neg before-count KUT}

KUltd:{ / (load test dir) - load all *.csv files in directory <x> into KUT
	before:count KUT;
	files:(` sv)each(x,'key x);KUltf each files where(lower files)like"*.csv";
	neg before-count KUT}                   

KUrt:{ / (run tests) - run contents of KUT, save results to KUTR
	before:count KUTR;uf:exec asc distinct file from KUT;i:0;
	if[.KU.VERBOSE;-1(string .z.Z)," start"];
	exec KUexec'[lang;code] from KUT where action=`beforeany;
	do[count uf;
		ufi:uf[i];KUTI:select from KUT where file=ufi;
		if[.KU.VERBOSE;
			-1(string .z.Z)," ",(string ufi)," ",(string exec count i from KUTI where action in `run`true`fail)," test(s)"];
		exec KUexec'[lang;code] from KUT where action=`beforeeach;
		exec KUexec'[lang;code] from KUTI where action=`before;
		exec KUexecrun'[lang;code;ms;file] from KUTI where action=`run;
		exec KUexectrue'[lang;code;file] from KUTI where action=`true;
		exec KUexecfail'[lang;code;file] from KUTI where action=`fail;
		exec KUexec'[lang;code] from KUTI where action=`after;
		exec KUexec'[lang;code] from KUT where action=`aftereach;
		i+:1];
	exec KUexec'[lang;code] from KUT where action=`afterall;
	if[.KU.VERBOSE;-1(string .z.Z)," end"];
	neg before-count KUTR}

KUpexec:{[prefix;lang;code;allowfail] 
	s:prefix,(string lang),")",string code;
	if[1<.KU.VERBOSE;-1 s];$[.KU.DEBUG&allowfail;value s;@[value;s;`FA1L]]}

KUexec:{[lang;code]
	value(string lang),")",string code}

KUexecrun:{[lang;code;ms;file]
	failed:`FA1L~r:KUpexec["\\t ";lang;code;1b];ti:$[failed;0;r];
	`KUTR insert(`run;ms;lang;code;file;ti;not failed;$[ms;not ti>ms;1b];not failed;.z.Z)}

KUexectrue:{[lang;code;file]
	failed:`FA1L~r:KUpexec["";lang;code;1b];
	`KUTR insert(`true;0;lang;code;file;0;$[failed;0b;r~1b];1b;not failed;.z.Z)}

KUexecfail:{[lang;code;file]
	failed:`FA1L~r:KUpexec["";lang;code;0b];
	`KUTR insert(`fail;0;lang;code;file;0;failed;1b;1b;.z.Z)}       

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
