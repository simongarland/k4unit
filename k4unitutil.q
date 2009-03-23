/ utilities to build test files from strings of code 
hdr:1_raze .KU.DELIM,'("action";"ms";"lang";"code";"repeat";"comment")
chktype:{1_raze .KU.DELIM,'("true";"0";"q";-3!(-3!type value x),"=type ",x)} 
chkvalue:{1_raze .KU.DELIM,'("true";"0";"q";-3!(-3!value x),"~",x)} 
chkcost:{[repeat;code] 1_raze .KU.DELIM,'("run";"000";"q";-3!code;string repeat)}  / run once then use KUrtf to fill with estimates 

