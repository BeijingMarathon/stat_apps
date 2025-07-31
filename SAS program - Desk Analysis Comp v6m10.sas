*********************************************************************************;
* PROGRAM: Compensation Analysis Summary.sas                                     ;
* VERSION: version 6, mod 10 - November 16, 2022                                 ;
* BUILD:   based on build 12 of v6m0 builds                                      ;
* AUTHOR:  Bogong Li                                             		 ;
* PURPOSE: This program performs regression analysis of compensation data        ;
*          by pay analysis group and populates the Compensation Analysis Summary ;
*          (CAS) spreadsheet to report the results to the field                  ;
*********************************************************************************;

* STEP 1 - PREPARE DATA  **************************************************;
* Referring to the BES Multiple Regression  Analysis (MRA) request sheet,  ;
* code and format the needed variables from Item 19 or other comp          ;
* data in Excel, including dummy variables, and save your revised database ;
* in the BES SharePoint folder.  This is now your "source" database, so    ;
* make sure the data are properly formatted for SAS, and there should be   ;
* only one worksheet.                                                      ;
***************************************************************************;

*NOTE - if you don't want to see pages and pages of log you can take out
mprint mlogic and symbolgen out of the options statement;
options nosleepwindow mprint mlogic symbolgen pagesize=45 linesize=130; /*Control SAS output */

/* Direct output to listing destination instead of HTML */
ods graphics off;
ods html close;
ods listing;
/* if you want the default HTMLBlue graphics that are produced by SAS 9.4, comment out the above 3 lines */

%let plots = 1; /* Predicted vs Residual Plots generated 1 = Yes, 0 = No, DEFAULT IS YES */

*In the code that follows, you must enter the path and name of the Excel "source" database
that contains the employee data;

* Specify the path for the Excel "source" file that you created and saved above ;
* Note: leave off last \ on the path name ;
%let Excel_Path= ;
* Note: leave off database file extension (.xlsx);
%let Database_Name = ;

ods listing gpath = "&Excel_Path"; /* direct SGPLOT output to folder */

* Specify the path for main database;
* File location and name;
%let fileloc = "&Excel_Path\&Database_Name..xlsx";
*NOTE: The program now uses .xlsx as the default extension.  You can go back to Excel 97-2003 format. If your database is 
in that format just replace ..xlsx in the line above with ..xls;

* STEP 2 READ IN DATA AND PREPARE OUTPUT FILE - Please open a blank CAS  ;
*          (v6m0) in Excel before running the SAS job                    ;
*          Otherwise, DDE output won't go anywhere                       ;
*          Also, please be sure that all other Excel files (incl. your   ;
*          "source" database) are CLOSED before you run the program      ;
*          - if another workbook is open the program may not know into   ;
*          which Excel file to write output.                             ;
*************************************************************************;

* The following code reads in the Excel file, converts it to a SAS database ;
* and prints out the data contents and the first five records.              ;
* (If you must have more than one worksheet in your Excel file, add         ;
* sheet="worksheet name" under the PROC IMPORT line below.                  ;

/* Changed to eliminate reference to Jet database engine (dbms=excel) */
proc import datafile=&fileloc out=inputdata dbms=xlsx replace;
run;

proc contents data=inputdata varnum out=fcontent;
run;

* Please insert the relevant Case Identification Information that will   ;
* appear on the CAS output file.                                         ;

%let Case_Name     = ;
%let Batch_Number  = ;
%let CRIS_Number   = ;
%let Region        = ;
%let Analyst_Name  = ;
%let Contact_Name  = ;
%let Analysis_Date = %sysfunc(today(),worddate.) ; /* Do not alter this line */

Title "Compensation Regression Screening Review of &Case_Name";

* Direct log and listing to destination files;
proc printto log="&Excel_Path\&Case_Name batch &Batch_Number &Analysis_Date..log" print="&Excel_Path\&Case_Name batch &Batch_Number &Analysis_Date..lst";
* NOTE: SG Plots will be written to your C:\Users\[username] folder;

* STEP 3 - VARIABLE DEFINITION   **************;
* If the variable is missing or you want it left out of the analysis, set macro variable to zero;

%let empid = empid;
%let salary = salary;
%let uselogsal = 1;        /* Convert salary to natural log for analysis: 0 = No, 1 = Yes DEFAULT IS YES */
%let female = female;
%let ethnicity = race;  /* Now accepts a polychotomous race variable, see next line */;
%let nonmincat = White;   /* Type in ethnic category that corresponds to White/nonminority -- you must type it EXACTLY as it appears in the database */
                      /* NOTE: this is NOT the same thing as the reference category in the regression analysis (see below) -- this variable is used primarily to make the counts on tab A come out right */
%let ethrefcat = -1; /* User-defined reference category for race variable */ 
                     /* -1 = highest-paid ethnicity as reference (DEFAULT) */
                     /*  0 = use non-minority category as reference */
                     /* or, can type in the ethnic category you want to use as reference -- you must type it EXACTLY as it appears in the database */
* NOTE REGARDING ETHNICITY ********************************************************;
* If the reference category is allowed to vary from PAG to PAG, the results of the ;
* race group meta-analyses on Tab F are not likely to be meaningful.  You may wish ;
* to force the reference category into the largest overall race group to ensure    ;
* interpretable results.                                                           ;
* TENURE VARIABLES ****************************************************************;
* You can use Time in Current Position (TIJ) in combination with Other Time in     ;
* Company (OTIC), or you can use Time in Company (TIC) alone.                      ;
%let usequadtenure = 0; * set = 1 use quadratic tenure vars DEFAULT IS 0 = NO      ;
%let Time_In_Current_Pos = tij; * the period between snapshot date and job date    ;
%let Other_Time_In_Company = otic; * the period between job date and hire date     ;
%let Time_In_Company = 0;  * the period between snapshot date and hire date        ;
* NOTE - use TIJ and OTIC if possible, otherwise set to 0 and use TIC.  The        ;
* program will not allow TIC to enter the regression if TIJ and OTIC are not set   ;
* to zero. Be sure to not over-control (ie, double-count) tenure.                  ;
***********************************************************************************;
* PRIOR EXPERIENCE VARIABLES ***********************************************************;
* NOTE - use actual prior experience if available, otherwise use age at hire (AAH) as   ;
* a proxy - DO NOT USE BOTH!!!!                                                         ;
%let Prior_experience = 0;  * Years of actual experience before hire date, if available ;
%let Age_at_Hire = 0;       * Age at Hire as a proxy for prior experience               ;
****************************************************************************************;
%let pay_analysis_group = pag;  /* could use grade or band if title is not available, use job group if groups seem reasonable */;
%let exempt = exempt;  /* FLSA Exempt Status, set to 0 if not available */;
%let part_time = parttime;  /* Part-time status, set to 0 if not available */;
* OTHER (CATEGORICAL) VARIABLES******************************************************;
* Use the following variables for other categorical variables of interest            ;
* shift, or location. The program will create dummies from the categorical variables ;
* using the dummyout process and put the dummies through the refine process.         ;
* IMPORTANT: Variable names for other1-10 must not exceed 25 characters!!!           ;
*************************************************************************************;
%let other1=0;    %let other1label = ;
%let other2=0;    %let other2label = ;
%let other3=0;    %let other3label = ;
%let other4=0;    %let other4label = ;
%let other5=0;    %let other5label = ;
%let other6=0;    %let other6label = ;
%let other7=0;    %let other7label = ;
%let other8=0;    %let other8label = ;
%let other9=0;    %let other9label = ;
%let other10=0;   %let other10label = ;

/* IF YOU NEED MORE VARIABLES THAN THOSE LISTED ABOVE, LIST THEM ON LINE BELOW */
%let User_Defined_Factors = 0;
* Note - user-defined factors on line above will enter the regression as-is;

%let Subsetting_If = %bquote(0);
* Insert subsetting condition inside %bquote function above;
* Examples: if you want only full-time employees, say %bquote(part_time = 0);
*           if you want only exempt employees say %bquote(exempt = 1);
*           if you want full-time, nonexempt employees say %bquote(part_time = 1 and exempt = 0);
*           if you want to exclude a certain race group say %bquote(minority ne 'insert race name here');
*           to exclude certain specific employees by id say %bquote(id not in(1,2,...,n)) where 1,2,...,n are the specific ids to be excluded; 
*           if you want to include everybody, say %bquote(0);
* basically, use any syntax valid for a data step's subsetting if statement without the word if;

**************************************************************************************************;
* STEP 4 - SAVE YOUR SAS program in the BES SharePoint compensation folders with a new name.      ;
* Code runs automatically from this point forward - do not alter any lines beyond here.           ;
**************************************************************************************************;

* SET UP STARTING FILE ;
proc sql noprint;
	select type into :paytype                              
  	from fcontent                                            
  	where upcase(compress(name))=upcase(compress("&salary"));
quit;

%macro center(ctrvar, ctrlbl);
	/* mean-center tenure var */
	proc sort data=New_Data;
		by pay_analysis_group;
	run;

	proc summary data=New_Data;
		by pay_analysis_group;
		var &ctrvar;
		output out=center mean=&ctrvar._mean;
	run;

	data New_Data (drop=&ctrvar._mean);
		merge New_Data (in=a)
		      center;
		by pay_analysis_group;
		if a;
		&ctrvar._ctr = &ctrvar - &ctrvar._mean;
		&ctrvar._sq = &ctrvar._ctr**2;
		label &ctrvar._ctr="&ctrlbl Centered";
		label &ctrvar._sq="&ctrlbl Squared";
	run;
%mend center;

%macro dataprep;
	Data New_Data (keep=empid salary raw_salary female minority &ethnicity Time_In_Current_Pos Other_Time_In_Company Time_In_Company Prior_Experience Age_At_Hire part_time 
                        exempt pay_analysis_group whitecat dummy_pag
	                    %if &other1 ne 0 %then &other1;
						%if &other2 ne 0 %then &other2;
						%if &other3 ne 0 %then &other3;
						%if &other4 ne 0 %then &other4;
						%if &other5 ne 0 %then &other5;
						%if &other6 ne 0 %then &other6;
						%if &other7 ne 0 %then &other7;
						%if &other8 ne 0 %then &other8;
						%if &other9 ne 0 %then &other9;
						%if &other10 ne 0 %then &other10;
	                    %if &User_Defined_Factors ne 0 %then &User_Defined_Factors;) Exclude_Data;
		length pay_analysis_group $100.;
		Set inputdata;
		format pay_analysis_group;
		informat pay_analysis_group;
		empid=&empid;
		/* convert char salary to numeric if needed */
	    if &paytype = 2 then salary=input(compress(&salary,'$,'),10.);        
	    else salary=&salary;
		/* convert salary to log if requested above */
		raw_salary = salary;
		if &uselogsal = 1 then salary = log(salary); 
		female=&female;
		minority=&ethnicity;
        Time_In_Current_Pos=&Time_In_Current_Pos;
		Other_Time_In_Company=&Other_Time_In_Company;
		Time_In_Company=&Time_In_Company;
		Prior_Experience=&Prior_Experience;
		Age_At_Hire=&Age_at_Hire;
		part_time=&part_time;
		exempt=&exempt;
		pay_analysis_group=upcase(&pay_analysis_group);
		if &ethnicity = "&nonmincat" then whitecat = 1;
		else whitecat = 0;
		dummy_pag = 'DUMMY PAY ANALYSIS GROUP'; /* dummy PAG for error proc reg */
		label female='Female';
		label minority='Ethnicity';
		label Prior_Experience='Prior Experience in Years';
		label Age_At_Hire='Age at Hire in Years';
		label Time_In_Current_Pos='Years in Current Job';
		label Other_Time_In_Company='Other Years at Company';
		label Time_In_Company='Years at Company';
		label part_time='Part-Time Status';
		label exempt='FLSA Exempt Status';
		/* delete records with missing data - mainly Excel phantom rows */
		if missing(pay_analysis_group) or 
	       missing(salary) or 
	      (missing(female) and missing(minority)) then output Exclude_Data; 
		else output New_Data;	
	run;

	/* center all tenure vars */
	%center(Time_In_Current_Pos, Years in Current Job);
	%center(Other_Time_In_Company, Other Years at Company);
	%center(Time_In_Company, Years at Company);
	%center(Prior_Experience, Prior Experience);
	%center(Age_At_Hire, Age at Hire);
%mend dataprep;

%dataprep;

Title2 'Observations Dropped due to Missing Data';
proc print data=Exclude_Data;
	var empid female minority pay_analysis_group salary;
run;

/* Perform any subsetting specified by the user */
%macro subset;
	%if &Subsetting_If ne 0 %then %do;
		Data New_Data;
			set New_Data;
			if %unquote(&Subsetting_If);
		run;
		filename cas dde 'excel|A. Overview of Data & Findings!r8c1:r8c1' notab;
		data _null_;
			file cas;
			set New_Data;
			displayif = symget('Subsetting_If');
			put displayif;
		run;
	%end;
%mend subset;
%subset

proc contents data=New_Data;
run;

* STEP 5 - CREATE JOB-TITLE SPECIFIC DUMMIES FOR THE CATEGORICAL VARS ;
%let Catvars_In_Reg = ;
%let Catvars_Count = 0;
%let Minvars_In_Reg = ;
%let Minvars_Count = 0;

%macro checkref;
	data freqcnt2;
		set freqcnt (keep=pay_analysis_group &ethnicity count percent cum_freq cum_pct _type_ _freq_ 
                           avgsal allemps ignore);
		by pay_analysis_group;
		smallref = 0;
		if first.pay_analysis_group and 
			allemps ge 30 and 
			count < 5 and ignore = 0 then do;
				smallref = 1;
				ignore = 1;
		end;
	run;
	proc summary data=freqcnt2;
		var smallref;
		output out=hassmall sum=hassmall;
	run;
	data _null_;
		set hassmall;
		if hassmall < 1 then call symput('keepchecking','no');
	run;
	%if &keepchecking = yes %then %do;
		proc sort data=freqcnt2 out=freqcnt;
			by pay_analysis_group ignore smallref descending avgsal;
		run;	
	%end;
%mend checkref;


%macro dummyout(dumvar);
	/* get raw and cumulative freqs for categories */
	proc sort data=New_Data;
		by pay_analysis_group &dumvar;
	run;
	proc freq data=New_Data noprint;
		by pay_analysis_group;
		tables &dumvar /out=freqcnt outcum;
	run;
	proc summary data=New_Data;
		by pay_analysis_group &dumvar;
		var raw_salary;
		output out=avgsal mean=avgsal sum=sumsal;
	run;
	data freqcnt;
		merge freqcnt (in=a)
		      avgsal;
		by pay_analysis_group &dumvar;
		if a;
	run;
	/* assign categories */
	%if &dumvar = &ethnicity and &ethrefcat = -1 %then %do;
		/* assign highest-paid ethnicity as reference category */
		proc sort data=New_Data;
			by pay_analysis_group &dumvar;
		run;
		proc sort data=freqcnt;
			by pay_analysis_group descending avgsal;
		run;
		/* if highest-paid ethnicity has < 5, need to pick next-highest paid ethnicity */
		data empcnt (rename=(cum_freq=allemps));
			set freqcnt (keep=pay_analysis_group cum_freq cum_pct);
			if cum_pct > 99;
		run;
		data freqcnt;
			merge freqcnt (in=a)
			      empcnt;
			by pay_analysis_group;
			if a;
			ignore = 0;
		run;
		proc sql noprint;
			select count(*) into :freqobs
			from freqcnt;
		quit;
		%global keepchecking;
		%if &freqobs = 0 %then %let keepchecking = no;
		%else %let keepchecking = yes;
		%do %until(&keepchecking = no);
			/* Put program to sleep for one second to prevent memory conflict */
			data _null_;
				slept = sleep(1000,.001);
			run;
			%checkref
		%end; 
	%end;
	%else %do;
		proc sort data=freqcnt;
			/* descending option below assumes White is last category of ethnicity var */
			by pay_analysis_group descending %if &dumvar ne &ethnicity %then count; &dumvar; 
		run;
	%end;
	data cats;
		set freqcnt;
		by pay_analysis_group;
		retain dumcat versus;
		if first.pay_analysis_group then do;
			dumcat = 1;
			versus = &dumvar;
		end;
		else do;
			dumcat = dumcat + 1;
			versus = versus;
		end;
	run;
	%if &dumvar = &ethnicity and &ethrefcat ne -1 %then %do;
		/* Check which titles have the user-defined ref cat for ethnicity */
		data cats;
			set cats;
			if 
			%if &ethrefcat = 0 %then %do;
				&dumvar = "&nonmincat" 
			%end;
			%else %do;
				&dumvar = "&ethrefcat"
			%end;
			then hasrefcat = 1;
			else hasrefcat = 0;
		run;
		proc summary data=cats;
			by pay_analysis_group;
			var hasrefcat;
			output out=hasref sum=hasref;
		run;
		data cats;
			merge cats (in=a)
			      hasref;
			by pay_analysis_group;
			if a;
			%if &ethrefcat = 0 %then %do;
				versus = "&nonmincat"; 
			%end;
			%else %do;
				versus = "&ethrefcat";
			%end;
		run;
	%end;
	%if &dumvar ne &ethnicity %then %do;
		/* For non-ethnicity vars, roll categories < 5 up by average salary */
		/* First, split cats dataset */
		data refcat othercats;
			set cats;
			diffup = 0;
			diffdown = 0;
			if dumcat = 1 then output refcat;
			else output othercats;
		run;
		/* Roll up categories < 5 to nearest neighbor */
		%let keeprolling = yes;
		%let roll = 1;
		%do %until(&keeprolling = no); 
			proc sort data=othercats;
				by pay_analysis_group avgsal;
			run; 
			%if &roll = 1 %then %do;
				data ranks;
					set othercats;
					by pay_analysis_group;
					retain dumrank;
					if first.pay_analysis_group then dumrank = 1;
					else dumrank = dumrank + 1;
					diffdown = abs(avgsal - lag(avgsal));
					if missing(diffdown) or pay_analysis_group ne lag(pay_analysis_group) then diffdown = 999999;
				run;
			%end;
			%else %do;
				data ranks (drop=catcnt catavg);
					merge othercats2 (in=a) /* use othercats ds from last iteration */
					      checkcnt (keep=pay_analysis_group dumcat catcnt)
						  checksum (keep=pay_analysis_group dumcat catavg);
					by pay_analysis_group dumcat;
					if a;
					if dumcat = 0 then delete; /* get rid of reference category in subsequent iterations */
					dumrank = dumcat;
					count = catcnt; /* use category counts as cats roll together */
					avgsal = catavg; /* use category avg as cats roll together */
				run;
				/* category averages may have changed last iteration - ensure they are still sorted in ascending order */
				proc sort data=ranks;
					by pay_analysis_group avgsal;
				run;
				/* compute distance to next-lowest category */
				data ranks;
					set ranks;
					diffdown = abs(avgsal - lag(avgsal));
					if missing(diffdown) or pay_analysis_group ne lag(pay_analysis_group) then diffdown = 999999;
					movedup = 0;
				run;
			%end;
			proc sort data=ranks;
				by pay_analysis_group descending avgsal;
			run;
			/* compute distance to next-highest category */
			data ranks2;
				set ranks;
				diffup = abs(avgsal - lag(avgsal));
				if missing(diffup) or pay_analysis_group ne lag(pay_analysis_group) then diffup = 999999;
				if count < 5 then do;
					if diffup le diffdown then do;
                    	dumrank = dumrank + 1;
						movedup = 1;
					end;
				end;
			run;
			proc sort data=ranks2;
				by pay_analysis_group avgsal;
			run;
			data ranks3;
				set ranks2;
				if count < 5 then do;
					if diffdown < diffup and lag(movedup) = 0 then dumrank = dumrank - 1;
					/* lag(movedup) = 0 helps prevent adjacent categories < 5 from just switching places */
				end;
			run;
			data refcat2;
				set refcat;
				dumrank = 0;
			run;
			data othercats2;
				set refcat2
                    ranks3;
				dumcat = dumrank;
			run;
			proc sort data=othercats2;
				by pay_analysis_group dumcat;
			run;
			proc summary data=othercats2;
				by pay_analysis_group dumcat;
				var _freq_;
				output out=checkcnt sum=catcnt;
			run;
			proc summary data=othercats2;
				by pay_analysis_group dumcat;
				var sumsal _freq_;
				output out=checksum sum=catsum catfreq;
			run;
			data checksum;
				set checksum;
				catavg = catsum/catfreq; /* create new weighted category average salary */
			run;
			data othercats3;
				merge othercats2 (in=a)
				      checkcnt (drop = _TYPE_ _FREQ_);
				by pay_analysis_group dumcat;
				if a;
			run;
			/* Last, merge new cats back into cats dataset */
			proc sort data=cats;
				by pay_analysis_group &dumvar;
			run;
			proc sort data=othercats3;
				by pay_analysis_group &dumvar;
			run;
			data cats;
				merge cats (in=a drop=dumcat)
				      othercats3 (keep=pay_analysis_group &dumvar dumcat);
				by pay_analysis_group &dumvar;
				if a;
			run;
			%let keeprolling = no;
			data checkcnt;
				set checkcnt;
				if catcnt < 5 then call symput('keeprolling','yes');
			run; 
			%let roll = %eval(&roll + 1);
			%if &roll > 50 %then %let keeprolling = no; /* automatic stop after 50 iterations, regardless whether cats fully combined */
		%end;
	%end;
	/* final coding crosswalk for this variable */
	data &dumvar.xwalk; 
		set cats (keep = pay_analysis_group &dumvar dumcat count %if &dumvar = &ethnicity and &ethrefcat ne -1 %then hasref; %if &dumvar = &ethnicity %then versus; );
		%if &dumvar = &ethnicity and &ethrefcat ne -1 %then %do;
			/* re-number categories to put user-defined ref cat first, where applicable */
			if hasref > 0 then do;	
				%if &ethrefcat = 0 %then %do;
					if &dumvar = "&nonmincat" then dumcat = 1;
					if &dumvar > "&nonmincat" then dumcat = dumcat + 1;
				%end;
				%else %do;
					if &dumvar = "&ethrefcat" then dumcat = 1;
					if &dumvar > "&ethrefcat" then dumcat = dumcat + 1;
				%end;
			end;
			else do;
				versus = "&nonmincat";
			end;
		%end;
		%if &dumvar ne &ethnicity %then %do;
			dumcat = dumcat + 1; /* resets zero-indexed ranks to 1-index for later dummy coding */
		%end;
	run;
    %if &dumvar ne &ethnicity %then %do;
		/* roll up category names for multi-category dummies */
		proc sort data=&dumvar.xwalk;
			by pay_analysis_group dumcat &dumvar;
		run;
		proc summary data=&dumvar.xwalk;
			by pay_analysis_group dumcat;
			var count;
			output out=xwalkcnt sum=catcnt;
		run;
		data &dumvar.xwalk;
			merge &dumvar.xwalk (in=a)
			      xwalkcnt (drop=_type_ _freq_);
				  by pay_analysis_group dumcat;
				  if a;
			length &dumvar._recode $100;
			if pay_analysis_group = lag(pay_analysis_group) and dumcat = lag(dumcat) then &dumvar._recode = cats('Category #',dumcat);
			else &dumvar._recode = &dumvar;
		run;
		proc sort data=&dumvar.xwalk;
			by pay_analysis_group descending dumcat descending &dumvar;
		run;
		data &dumvar.xwalk;
			set &dumvar.xwalk;
			if pay_analysis_group = lag(pay_analysis_group) and dumcat = lag(dumcat) then &dumvar._recode = cats('Category #',dumcat);
		run;
		proc sort data=&dumvar.xwalk;
			by pay_analysis_group dumcat;
		run;
		%if &roll > 50 %then %do;
			/* detect and resolve unresolved categories */
			proc summary data=&dumvar.xwalk;
				var dumcat;
				output out=varmax max=varmax;
			run;
			data _null_;
				set varmax;
				call symput("max&dumvar",varmax);
			run;
			data &dumvar.xwalk;
				set &dumvar.xwalk;
				if catcnt < 5 then do;
					dumcat = symget("max&dumvar") + 1;
					&dumvar._recode = cats('Category #',dumcat,'-Residual');
				end;
			run;
			proc sort data=&dumvar.xwalk;
				by pay_analysis_group dumcat &dumvar;
			run;
			proc summary data=&dumvar.xwalk;
				by pay_analysis_group dumcat;
				var count;
				output out=xwalkcnt sum=catcnt;
			run;
			data &dumvar.xwalk (drop=catcnt);
				merge &dumvar.xwalk (in=a)
			          xwalkcnt (drop=_type_ _freq_);
				by pay_analysis_group dumcat;
				if a;
				count = catcnt;
			run;
			proc freq data=&dumvar.xwalk;
				by pay_analysis_group;
				tables &dumvar*dumcat /nocum nopercent norow nocol;
				title2 "Coding Crosswalk for Categorical Variable &dumvar";
				title3 'First Category = Reference Group';
			run;
		%end;
		%else %do;
			data &dumvar.xwalk (drop=catcnt);
				merge &dumvar.xwalk (in=a)
			          xwalkcnt (drop=_type_ _freq_);
				by pay_analysis_group dumcat;
				if a;
				count = catcnt;
			run;
			proc freq data=&dumvar.xwalk;
				by pay_analysis_group;
				tables &dumvar*dumcat /nocum nopercent norow nocol;
				title2 "Coding Crosswalk for Categorical Variable &dumvar";
				title3 'First Category = Reference Group';
			run;
		%end;
	%end;
	/* load max # of categories as macro variable */
	proc summary data=&dumvar.xwalk;
		var dumcat;
		output out=varmax max=varmax;
	run;
	data _null_;
		set varmax;
		call symput("max&dumvar",varmax);
	run;
	/* now merge back to New_Data and code dummy variables */
	proc sort data=&dumvar.xwalk;
		by pay_analysis_group &dumvar;
	run;
	proc sort data=New_Data;
		by pay_analysis_group &dumvar;
	run;
	data New_Data (drop= %if &dumvar ne &ethnicity %then dumcat &dumvar.1; /* first dummy is dropped to make it the reference category */);
		merge New_Data (in=a)
		      &dumvar.xwalk (in=b);
		by pay_analysis_group &dumvar;
		if a;
		%do i=1 %to &&max&dumvar;
			if dumcat = &i then &dumvar&i = 1;
			else &dumvar&i = 0;
			%if &i > 1 %then %do;
				%if &dumvar = &ethnicity %then %do;
					%let Minvars_Count = %eval(&Minvars_Count + 1);
					%let Minvars_In_Reg = &Minvars_In_Reg &dumvar&i;
				%end;
				%else %do;
					%let Catvars_Count = %eval(&Catvars_Count + 1);
					%let Catvars_In_Reg = &Catvars_In_Reg &dumvar&i;
				%end;
			%end;
		%end;
	run;
	data &dumvar.xwalk;
		set &dumvar.xwalk;
		if pay_analysis_group = lag(pay_analysis_group) and dumcat = lag(dumcat) then delete;
	run;
%mend dummyout;

%macro makedummy;	
	%if &other1 ne 0 %then %dummyout(&other1);
	%if &other2 ne 0 %then %dummyout(&other2);
	%if &other3 ne 0 %then %dummyout(&other3);
	%if &other4 ne 0 %then %dummyout(&other4);
	%if &other5 ne 0 %then %dummyout(&other5);
	%if &other6 ne 0 %then %dummyout(&other6);
	%if &other7 ne 0 %then %dummyout(&other7);
	%if &other8 ne 0 %then %dummyout(&other8);
	%if &other9 ne 0 %then %dummyout(&other9);
	%if &other10 ne 0 %then %dummyout(&other10);
	%if &ethnicity ne 0 %then %dummyout(&ethnicity); 
%mend makedummy;

%makedummy

%macro dummyin(dumvar,inpag,inlbl,ds); /* this macro is called in the regress macro */
	proc sort data=&dumvar.xwalk;
		by pay_analysis_group dumcat;
	run;
	proc summary data=&dumvar.xwalk;
		var dumcat;
		output out=varmax max=varmax;
	run;
	data _null_;
		set varmax;
		call symput("max&dumvar",varmax);
	run;
	data &dumvar.xwalk;
		set &dumvar.xwalk;
		/* delete extra residual lines */
		if pay_analysis_group = lag(pay_analysis_group) and dumcat = lag(dumcat) then delete;
	run;
	data _null_;
		set &dumvar.xwalk;
		if pay_analysis_group = "%unquote(&inpag)" %if &dumvar ne &ethnicity %then and dumcat > 1;;
		%do j = 1 %to &&max&dumvar;
			%let addlbl&j = ; /* prime label to prevent warning msg */
			if dumcat = &j then do;
				%if &dumvar = &ethnicity %then call symput("addlbl&j",strip(&dumvar));
				%else call symput("addlbl&j",strip(&dumvar._recode));; /* double semicolon is intentional */
				call symput("countlbl&j",strip(count));
			end;
		%end;
		%if &dumvar = &ethnicity %then call symput('vslbl',versus);;
	run;
	data &ds;
		set &ds;
		%do j = 1 %to &&max&dumvar;
			%if "%unquote(&inlbl)" = "MINORITY" %then %do;
				%if &ethrefcat = 0 %then %do;
					if name2 = upcase("&dumvar&j") then label2 = "%unquote(&inlbl)";
				%end;
				%else %do;
					if name2 = upcase("&dumvar&j") then label2 = "ETHNICITY - NON-&vslbl";
				%end;
			%end;
			%else %do;
				if name2 = upcase("&dumvar&j") then label2 = "%unquote(&inlbl) - &&addlbl&j (N=&&countlbl&j)";
			%end;
		%end;
		label2 = upcase(label2);
	run;
%mend dummyin;

* STEP 6 - CREATE COUNTS OF EMPLOYEES AND REGRESSION FACTORS BY JOB TITLE ;

/* Create counts of employees by job title */
%macro refine;
	proc sort data=New_Data;
		by pay_analysis_group;
	run;
	proc summary data=New_Data;
		var female whitecat &Minvars_In_Reg exempt part_time &Catvars_In_Reg salary time_in_current_pos_ctr 
	        other_time_in_company_ctr time_in_company_ctr prior_experience_ctr age_at_hire_ctr;
		by pay_analysis_group;
		output out=job_specs sum=nfem nwhite
			%do i=2 %to %eval(&Minvars_Count + 1);
				/* lack of semicolon on next line is intentional */
				nmin&i 
			%end;		
		nexe npart 
	    	%do i=1 %to &Catvars_Count;
				/* lack of semicolon on next line is intentional */
				no&i 
			%end;
		sumsal ntij notic ntic nprior nage;
	run;
	%let finalfact = %eval(&Catvars_Count + 6);
	data job_specs (drop=_type_ sumsal regfactfem1-regfactfem&finalfact regfactmin1-regfactmin&finalfact 
	                factorcount block2min0-block2min&Minvars_Count rename=(_freq_=emps));
		set job_specs;
		nnonfem = 0;
		nnonfem = _freq_ - nfem; /* counts of males */
		nnonwhite = 0;
		nnonwhite = _freq_ - nwhite; /* counts of non-minorities for tab A */
		%do i=2 %to %eval(&Minvars_Count + 1);
			nnonmin&i = 0;
			nnonmin&i = _freq_ - nmin&i; /* counts of emps with 0 on each minority factor */
		%end;
		%if &Minvars_Count ge 1 %then %do;
			nallmin = sum(of nmin:); /* total count of minorities */
		%end;
		%else %do;
			nallmin = 0;
			nmin2 = 0; /* a placeholder so Tab B will print */
		%end;
		nnonmin = 0;
		nnonmin = _freq_ - nallmin; /* counts of non-minorities */
		nnonexe = 0;
		nnonexe = _freq_ - nexe; /* counts of non-exempt */
		nnonpart = 0;
		nnonpart = _freq_ - npart; /* counts of full-time */ 
		%do i=1 %to &Catvars_Count;
			nnono&i = 0;
			nnono&i = _freq_ - no&i; /* counts of emps with 0 on each catvar factor */
		%end;
		salary = sumsal/_freq_; /* to get mean salary by job title */
		/* build regression factor line */
		regfactfem1 = 'female ';
		regfactmin1 = ''; /* blanked out in v4m0 because minority now added last */
		factorcount = 1; /* count of factors in regression */
		/* add time in job, other time in company */
		%if &time_in_current_pos ne 0 %then %do;
			/* double semicolons on next 3 lines are intentional */
			regfactfem2 = regfactfem1||'time_in_current_pos_ctr other_time_in_company_ctr ' %if &usequadtenure = 1 %then ||'time_in_current_pos_sq other_time_in_company_sq ';;
			regfactmin2 = regfactmin1||'time_in_current_pos_ctr other_time_in_company_ctr ' %if &usequadtenure = 1 %then ||'time_in_current_pos_sq other_time_in_company_sq ';;
			factorcount = factorcount + 2 %if &usequadtenure = 1 %then +2;;
		%end;
		%else %do;
		    /* if tij and otic not available, use tic */
			%if &time_in_company ne 0 %then %do;
				/* double semicolons on next 3 lines are intentional */
				regfactfem2 = regfactfem1||'time_in_company_ctr ' %if &usequadtenure = 1 %then ||'time_in_company_sq ';;
				regfactmin2 = regfactmin1||'time_in_company_ctr ' %if &usequadtenure = 1 %then ||'time_in_company_sq ';;
				factorcount = factorcount + 1 %if &usequadtenure = 1 %then +1;;
			%end;
			%else %do;
				regfactfem2 = regfactfem1;
				regfactmin2 = regfactmin1;
			%end;
		%end;
		/* add prior experience */
		%if &prior_experience ne 0 %then %do;
			/* double semicolons on next 3 lines are intentional */
			regfactfem3 = regfactfem2||'prior_experience_ctr ' %if &usequadtenure = 1 %then ||'prior_experience_sq ';;
			regfactmin3 = regfactmin2||'prior_experience_ctr ' %if &usequadtenure = 1 %then ||'prior_experience_sq ';;
			factorcount = factorcount + 1 %if &usequadtenure = 1 %then +1;;
		%end;
		%else %do;
			regfactfem3 = regfactfem2;
			regfactmin3 = regfactmin2;
		%end;
		/* add age at hire */
		%if &age_at_hire ne 0 %then %do;
			/* double semicolons on next 3 lines are intentional */
			regfactfem4 = regfactfem3||'age_at_hire_ctr ' %if &usequadtenure = 1 %then ||'age_at_hire_sq ';;
			regfactmin4 = regfactmin3||'age_at_hire_ctr ' %if &usequadtenure = 1 %then ||'age_at_hire_sq ';;
			factorcount = factorcount + 1 %if &usequadtenure = 1 %then +1;;
		%end;
		%else %do;
			regfactfem4 = regfactfem3;
			regfactmin4 = regfactmin3;
		%end;/* add dummies part_time, exempt, and other1-10 */
		/* must have at least 5 on each side to go into regression factors */
		if npart ge 5 and nnonpart ge 5 then do;
			regfactfem5 = regfactfem4||'part_time ';
			regfactmin5 = regfactmin4||'part_time ';
			factorcount = factorcount + 1;
		end;
		else do;
			regfactfem5 = regfactfem4;
			regfactmin5 = regfactmin4;
		end;
		if nexe ge 5 and nnonexe ge 5 then do;
			regfactfem6 = regfactfem5||'exempt ';
			regfactmin6 = regfactmin5||'exempt ';
			factorcount = factorcount + 1;
		end;
		else do;
			regfactfem6 = regfactfem5;
			regfactmin6 = regfactmin5;
		end;
		%do i = 1 %to &Catvars_Count;
			%let j = %eval(&i + 6);
			%let k = %eval(&j - 1);
			%let nextspace = %index(&Catvars_In_Reg,%str( ));
			%if &nextspace = 0 %then %let thisfactor = %substr(&Catvars_In_Reg,1);
			%else %let thisfactor = %substr(&Catvars_In_Reg,1,&nextspace);
			if no&i ge 1 and nnono&i ge 1 then do;
				factorcount = factorcount + 1;
				regfactfem&j = regfactfem&k||"&thisfactor"||' ';
				regfactmin&j = regfactmin&k||"&thisfactor"||' ';
			end;
			else do;
				regfactfem&j = regfactfem&k;
				regfactmin&j = regfactmin&k;
			end;
			%if &nextspace ne 0 %then %let Catvars_In_Reg = %substr(&Catvars_In_Reg,&nextspace);
		%end;
		udf = symget('User_Defined_Factors'); /* add any user defined factors to factor line */
		if udf ne '0' then do;
			regfactfem = regfactfem&finalfact||udf;
			regfactmin = regfactmin&finalfact||udf;
		end;
		else do;
			regfactfem = regfactfem&finalfact;
			regfactmin = regfactmin&finalfact;
		end;
		/* Must now create Block 2 line for minority reg, containing the ethnicity dummies */
		block2min0 = '';
		empsinanal = _freq_;
		%do i = 1 %to &Minvars_Count;
			%let j = %eval(&i - 1);
			%let k = %eval(&i + 1);
			%let nextspace = %index(&Minvars_In_Reg,%str( ));
			%if &nextspace = 0 %then %let thisfactor = %substr(&Minvars_In_Reg,1);
			%else %let thisfactor = %substr(&Minvars_In_Reg,1,&nextspace);
			if nmin&k ge 5 and nnonmin&k ge 5 then do;
				block2min&i = block2min&j||"&thisfactor"||' ';
			end;
			else do;
				block2min&i = block2min&j;
				empsinanal = empsinanal - nmin&k; /* decrement emps for excluded min cat */
			end;
			%if &nextspace ne 0 %then %let Minvars_In_Reg = %substr(&Minvars_In_Reg,&nextspace);
		%end;
		block2min = block2min&Minvars_Count;
	run;
	/* Determine which obs will be dropped from the race analysis if use polychotomous race */
	data New_Data (drop=dumcat block2min %if &Minvars_Count ge 2 %then dropcat candrop i; );
		merge New_Data (in=a)
		      job_specs (keep=pay_analysis_group block2min);
		by pay_analysis_group;
		if a;
		%if &Minvars_Count ge 2 %then %do;
			array ethnic &ethnicity.2-&ethnicity.%eval(&Minvars_Count + 1);
			dropcat = strip(put(dumcat,1.));
			candrop = index(block2min,dropcat);
			if dumcat ne 1 and candrop = 0 then 
				do i = 1 to &Minvars_Count;
					ethnic(i) = .; /* set to missing - this keeps obs in gender analysis but drops from race analysis */
				end;
		%end;
	run;	
%mend refine;


%refine

* STEP 7 - DECIDE WHICH TITLES TO ANALYZE AND ANALYZE ACCORDING TO NUMBER OF EMPLOYEES IN 
           THE PAY ANALYSIS GROUP;

/* This portion of the code creates 2 datasets off the job_specs dataset: regress_&grp,
   and fail_&grp.  Titles that meet 30/5 rule will be output to the regress_&grp
   dataset for regression analysis.  All other titles
   will be output to fail_&grp for eventual output to CAS tab C. */
%macro flagtitle(grp);
	data regress_&grp fail_&grp;
		set job_specs;
		%if &grp = min %then %do;
			if empsinanal < 30 or block2min = '' then output fail_&grp;
			else output regress_&grp;
		%end;
		%else %do;
			if emps ge 30 and n&grp ge 5 and nnon&grp ge 5 then output regress_&grp;
			else output fail_&grp;
		%end;
	run;
%mend flagtitle;

%flagtitle(fem)
%flagtitle(min)

data errmsg; /* create error message database */
	input errgrp $4. message $60.;
	datalines;
femr No job titles meet 30/5 for regression analysis of female
minr No job titles meet 30/5 for regression analysis of ethnicity
merg No job titles met 30/5 for analysis
fail All job titles met 30/5 for analysis of female or ethnicity
noln Meta-analysis not presented for raw salary models
	;
run;

/* perform regression analysis of job titles meeting 30/5 */
%macro regress(grp,group);
	data _null_;
		set regress_&grp;
		call symput('pag'||left(_n_),pay_analysis_group); /* create array of macro variables for PAGs */
		call symput('rf'||left(_n_),regfact&grp); /* create array of macro variables for regression factors */
		%if &grp = min %then %do;
			call symput('b2'||left(_n_),block2min); /* create array of macro variables for block 2 in min regs */
		%end;
	run;
	proc sql noprint;
		select count(*) into :jobs&grp
		from regress_&grp;
	quit;
	%if &grp = min %then %do;
		%let pageno = D;
		%let grp2 = Race;
	%end;
	%else %do;
		%let pageno = E;
		%let grp2 = Gender;
	%end;
	%do i=1 %to &&jobs&grp;
		title2 "Univariate Statistics for Salary in &&pag&i by &group";
		proc univariate normal plot data=New_Data (where=(pay_analysis_group="&&pag&i"));
			var raw_salary;
		run;
		title2 "Levene F for Homogeneity of Salary Variance in &&pag&i by &group";
		proc anova data=New_Data (where=(pay_analysis_group="&&pag&i"));
			%if &grp = min %then %do;
				class &ethnicity;
				model salary = &ethnicity;
				means &ethnicity /hovtest=levene;
			%end;
			%else %do;
				class &group;
				model salary = &group;
				means &group /hovtest=levene;
			%end;
		run;
		proc reg data=New_Data outest=regout_&grp&i edf tableout ;
			model salary=&&rf&i /
			%if &grp = fem %then %do;
				/* lack of semicolon on next line is intentional */
				spec 
			%end;
				scorr2 vif;
			%if &grp = min %then %do;
				model salary = &&rf&i &&b2&i / scorr2 vif spec; /* Enter ethnicity on block 2 */
				%if &&b2&i = &ethnicity.1 %then %let ethniclabel = MINORITY;
				%else %let ethniclabel = ETHNICITY;
			%end;
			by pay_analysis_group;
			where pay_analysis_group = "&&pag&i" ;
			/* Output each obs' externally studentized residual and Welsch-Kuh distance */
			output out=resids_&grp&i p=predsal r=resid rstudent=tresid dffits=dffit;
			title2 "Regression Analysis of &&pag&i by &group";
		run;
		proc reg data=New_Data ;
			model salary=&&rf&i 
			%if &grp = min %then &&b2&i;
			    / hccmethod=3; /* Compute heteroscedasticity-consistent SEs */
			by pay_analysis_group;
			where pay_analysis_group = "&&pag&i" ;
			title2 "Heteroscedasticity-Consistent Regression Analysis of &&pag&i by &group";
		run;
		title2 "Univariate Statistics for Residuals in &&pag&i";
		proc univariate normal plot data=resids_&grp&i;
			var resid;
		run;
		%if &plots = 1 %then %do;
			proc sgplot data=resids_&grp&i;
				scatter x=tresid y=predsal;
				reg x=tresid y=predsal;
				title2 "Plot of Predicted Salary on Studentized Residual of &&pag&i by &group";
			run;
		%end;
		data resids_&grp&i;
			set resids_&grp&i;
			absfit = abs(dffit);
		run;
		proc sort data=resids_&grp&i;
			by descending absfit;
		run;
		title2 "30 Most Influential Obs (Welsch-Kuh distance) in Regression of &&pag&i by &group";
		proc print data=resids_&grp&i (obs=30);
			var empid pay_analysis_group 
				%if &grp = min %then %do;
					&ethnicity /* lack of semicolon is intentional */
				%end;
				%else %do;
					&group /* lack of semicolon is intentional */
				%end;
				salary tresid dffit;
		run;
		/* Output to CAS tabs D and E as you analyze */
		proc transpose data=regout_&grp&i out=regxpose_&grp&i;
			%if &grp = min %then where _model_ = 'MODEL2';; /* double semicolon is intentional */
			id _type_;
		run;
		data regxpose_&grp&i (keep=name2 label2 parms stderr t pvalue);
			set regxpose_&grp&i;
			if upcase(_name_) not in ('_RMSE_','SALARY','_IN_','_P_','_EDF_','_RSQ_');
			length label2 $100.;
			name2 = upcase(_name_);
			label2 = upcase(_label_);
		run;
		%if &other1 ne 0 %then %dummyin(&other1,%bquote(&&pag&i),%bquote(&other1label),regxpose_&grp&i);
		%if &other2 ne 0 %then %dummyin(&other2,%bquote(&&pag&i),%bquote(&other2label),regxpose_&grp&i);
		%if &other3 ne 0 %then %dummyin(&other3,%bquote(&&pag&i),%bquote(&other3label),regxpose_&grp&i);
		%if &other4 ne 0 %then %dummyin(&other4,%bquote(&&pag&i),%bquote(&other4label),regxpose_&grp&i);
		%if &other5 ne 0 %then %dummyin(&other5,%bquote(&&pag&i),%bquote(&other5label),regxpose_&grp&i);
		%if &other6 ne 0 %then %dummyin(&other6,%bquote(&&pag&i),%bquote(&other6label),regxpose_&grp&i);
		%if &other7 ne 0 %then %dummyin(&other7,%bquote(&&pag&i),%bquote(&other7label),regxpose_&grp&i);
		%if &other8 ne 0 %then %dummyin(&other8,%bquote(&&pag&i),%bquote(&other8label),regxpose_&grp&i);
		%if &other9 ne 0 %then %dummyin(&other9,%bquote(&&pag&i),%bquote(&other9label),regxpose_&grp&i);
		%if &other10 ne 0 %then %dummyin(&other10,%bquote(&&pag&i),%bquote(&other10label),regxpose_&grp&i);
		%if &grp = min %then %dummyin(&ethnicity,%bquote(&&pag&i),%bquote(&ethniclabel),regxpose_&grp&i);
		proc sql noprint;
			select count(*) into :addrows
			from regxpose_&grp&i;
		quit;
		%if &i = 1 %then %do;
			%let titlerow = 5;
			%let startrow = 7;
		%end;
		%else %do;
			%let titlerow = %eval(&endrow + 2);
			%let startrow = %eval(&endrow + 4);
		%end;
		%let endtitle = %eval(&titlerow + 1);
		%if &grp = min %then %do;
			%let endrow = %eval(&startrow + &addrows);
		%end;
		%else %do;
			%let endrow = %eval(&startrow + &addrows - 1);
		%end;
		filename casde1 dde "excel|&pageno.. &grp2 Regressions!r&titlerow.c1:r&endtitle.c1" notab;
		/* Compute overall model P value and adjusted R-square */
		data regout_&grp&i;
			set regout_&grp&i;
			modelf = (_rsq_*_edf_)/((1-_rsq_)*_in_);      /* F test for regression */
			modelp = 1 - probf(modelf,_in_,_edf_);        /* significance of F */
			adjrsq = 1 - (1-_rsq_)*((_in_+_edf_)/_edf_);  /* Adjusted R-square */
			if adjrsq < 0 then adjrsq = 0;                /* Set Adjusted R-Sq to zero if negative */
			nobs = _p_ + _edf_;
			if _n_ = 1 then call symput('nminus0',nobs); /* Load total n in memory for meta-analysis */
		run;
		/* Output full model information */
		data _null_;
			file casde1;
			set regout_&grp&i;
			%if &grp = min %then %do;
				if _n_ = 7;
			%end;
			%else %do;
				if _n_ = 1;
			%end;
			put pay_analysis_group;
			put +2 'Model (df =' _in_ ', ' _edf_ '; R-Sq =' _rsq_ 5.4 '; p =' modelp 5.4 '; Adj R-Sq =' adjrsq 5.4 '):';
		run;
		/* Output full model equation */
		filename casde2 dde "excel|&pageno.. &grp2 Regressions!r&startrow.c1:r&endrow.c6" notab;
		data _null_;
			file casde2;
			set regxpose_&grp&i;
			put +4 label2 '09'x parms '09'x t '09'x pvalue;
		run;
		/* For minority, compute and output incremental R-square  - CODE DELETED for v6*/

		/* Prepare data for meta-analysis */
		data meta_&grp&i (drop=lbllen paren1);
			set regxpose_&grp&i;
			if %if &grp = fem %then name2 = 'FEMALE'; %else substr(name2,1,%length(&ethnicity)) = %upcase("&ethnicity");; /* double semicolon is intentional */
			nobs = 0;
			lbllen = 0;
			paren1 = 0;
			nclass = 0;
			nobs = symgetn('nminus0');
			wgtvar = (stderr**2)*(nobs-1); /* weighted variance of race/gender effect */
			wgteff = parms*nobs; /* weighted race/gender effect */
			%if &grp = min %then %do;
				lbllen = length(label2);
				paren1 = index(label2,'N=');
				sumlbl = substr(label2,13,paren1-15);
				nclass = substr(label2,paren1+2,length(label2)-(paren1+2));
			%end;
			%else %do;
				sumlbl = label2;
			%end;
		run;

		/* Prepare merge datasets for output to CAS tab B */
		%if &i = 1 %then %do;
			data regmerge_&grp;
				set regout_&grp&i;
				%if &grp = min %then %do;
					if _model_ = 'MODEL2';
				%end;
			run;
			data metamerge_&grp;
				set meta_&grp&i;
			run;
		%end;
		%else %do;
			data regmerge_&grp;
				merge regmerge_&grp (in=a) 
                      regout_&grp&i (in=b);
				by pay_analysis_group;
				if a or b;
				%if &grp = min %then %do;
					if _model_ = 'MODEL2';
				%end;
			run;
			data metamerge_&grp;
				set metamerge_&grp
                    meta_&grp&i;
			run;
		%end;
		/* Put program to sleep for one second to prevent memory conflict */
		data _null_;
			slept = sleep(1000,.001);
		run;
	%end;
	/* if do loop never executed (jobs&grp = 0) output message */
	%if &&jobs&grp = 0 %then %do;
		filename casde4 dde "excel|&pageno.. &grp2 Regressions!r5c1:r5c4" notab;
		data _null_;
			file casde4;
			set errmsg;
			if errgrp = "&grp.r";
			put message;
		run;
		/* also, perform a dummy regression to get a dummy regmerge dataset */
		proc reg data=New_Data outest=regmerge_&grp (rename=(dummy_pag=pay_analysis_group)) 
                 edf tableout noprint;
			%if &grp = min %then %do;
				model salary=&ethnicity.1 ;
			%end;
			%else %do;
				model salary=female ;
			%end;
			by dummy_pag;
		run;
	%end;
%mend regress;

%regress(fem,female)
%regress(min,minority)

/* create merged dataset of job titles that failed to enter either analysis */
data fail_all (keep=pay_analysis_group emps nfem nnonfem nwhite nnonwhite salary);
	merge fail_fem (in=fem keep=pay_analysis_group)
	      fail_min (in=min keep=pay_analysis_group)
          job_specs;
	by pay_analysis_group;
	if fem or min;
run;

* STEP 8 - WRITE OUTPUT TO CAS ************************************************;

/* CAS TAB A -- OVERVIEW OF DATA AND FINDINGS*/
/* Part 1 - Header Information */
data casheadr;
	name = symget('Case_Name');
	cris = symget('CRIS_Number');
	region = symget('Region');
	rundate = symget('Analysis_Date');
	batch = symget('Batch_Number');
	analyst = symget('Analyst_Name');
	contact = symget('Contact_Name');
run;
filename casa1 dde 'excel|A. Overview of Data & Findings!r4c2:r8c5' notab;
data _null_;
	file casa1;
	set casheadr;
	put name /;
	put cris /;
	put analyst;
run;
filename casa2 dde 'excel|A. Overview of Data & Findings!r4c7:r8c10' notab;
data _null_;
	file casa2;
	set casheadr;
	put rundate '09'x '09'x 'BATCH:' '09'x batch /;
	put region /;
	put contact;
run;

/* Part 2 - Employee Count in Review */
proc summary data=job_specs;
	var emps nnonfem nfem nexe nnonexe nnonpart npart;
	output out=emps_all sum=emps_total male_total fem_total 
                            exe_total nex_total ful_total par_total;
run;
/* create special output vars for exempt and fulltime */
/* if not using either as a factor, should display as N/A */
data emps_all;
	set emps_all;
	exe_out = 'Unknown';
	nex_out = 'Unknown';
	ful_out = 'Unknown';
	par_out = 'Unknown';
run;
filename casa3 dde 'excel|A. Overview of Data & Findings!r11c2:r11c8';
%macro revline;
	data _null_;
		file casa3;
		set emps_all;
		put male_total fem_total  
		    %if &exempt ne 0 %then exe_total nex_total;
			%else exe_out nex_out; 
            %if &part_time ne 0 %then ful_total par_total; 
            %else ful_out par_out;
		emps_total;
	run;
%mend revline;

%revline

/* Output race/ethnicity line - will show up to nine ethnic groups */
proc sort data = &ethnicity.xwalk;
	by &ethnicity;
run;
proc summary data=&ethnicity.xwalk;
	by &ethnicity;
	var count;
	output out=races_all sum=racesum;
run;
data races_all (drop=_type_ _freq_ racesum);
	length char_racesum $8;
	set races_all ;
	char_racesum = input(racesum,12.);
run;
proc transpose data=races_all out=races_xpose;
	var &ethnicity char_racesum;
run;
data races_xpose (drop=_name_ _label_);
	set races_xpose ;
run;

filename casa5 dde 'excel|A. Overview of Data & Findings!r12c2:r13c10' notab;
data _null_;
	file casa5;
	set races_xpose;
	put col1 '09'x col2 '09'x col3 '09'x col4 '09'x col5 '09'x col6 '09'x col7 '09'x col8 '09'x col9;
run;

/* Part 4 - Summary of Job Titles/SSEGs */
proc summary data=regress_fem;
	var emps;
	output out=met_fem sum=emps_met_fem;
run;
proc summary data=regress_min;
	var emps;
	output out=met_min sum=emps_met_min;
run;
/* check for 0 job titles met in fem and min and fill empty datasets*/
%macro fill(grp);
	proc sql noprint;
		select count(*) into :met&grp
		from met_&grp;
		%if &&met&grp = 0 %then %do;
			insert into met_&grp
      			set _freq_= 0,
				    emps_met_&grp = 0;
		%end;
	quit;	
%mend fill;

%fill(fem)
%fill(min)

data emps_merge;
	merge emps_all (keep=_freq_ emps_total rename=(_freq_=jobs_total))
	      met_fem (rename=(_freq_=jobs_fem))
          met_min (rename=(_freq_=jobs_min));
	pctmet_fem = 100*(emps_met_fem/emps_total);
	pctmet_min = 100*(emps_met_min/emps_total);
	pctfail_fem = 100 - pctmet_fem;
	pctfail_min = 100 - pctmet_min;
	call symput('failfem',pctfail_fem);
	call symput('failmin',pctfail_min);
	fail_fem = jobs_total - jobs_fem;
	fail_min = jobs_total - jobs_min;
	call symput('jobstot',jobs_total);
run;

filename casa6 dde 'excel|A. Overview of Data & Findings!r17c2:r18c5';
data _null_;
	file casa6;
	set emps_merge;
	put jobs_fem pctmet_fem jobs_min pctmet_min;
	put fail_fem pctfail_fem fail_min pctfail_min;
run;

/* CAS TAB B -- REGRESSION RESULTS */
%let mincats = %eval(&Minvars_Count + 1); /* moved from line 1080 of build 3 to use during detransform of log sal */
%macro outgroup(group,grp);
	data regmerge_&grp (drop=intercept);
		set regmerge_&grp (keep=pay_analysis_group _type_ intercept
		%if &grp = min %then %do;
			&ethnicity:
		%end;
		%else %do;
			female /*lack of semicolon is intentional */
		%end; 
		_rsq_);
		/* convert log disparity to raw dollars if log salary analyzed */
		%if &uselogsal = 1 %then %do;
			%if &grp = min %then %do;
				array ethnic &ethnicity.: ;
				do i = 1 to dim(ethnic);
					if _type_ = 'PARMS' then ethnic(i) = exp(intercept)*(exp(ethnic(i))-1);
				end;
			%end;
			%else %do;
				if _type_ = 'PARMS' then female = exp(intercept)*(exp(female)-1);
			%end;
		%end;
	run;
	proc transpose data=regmerge_&grp out=regxpose_&grp;
		by pay_analysis_group;
		id _type_;
		copy _rsq_;
	run;
	data regxpose_&grp;
		length pay_analysis_group $100.;
		set regxpose_&grp;
    run;
	/* copy r-square to all records in regxpose_min */
	%if &grp = min %then %do;
		data regxpose_&grp (drop = r2);
			set regxpose_&grp;
			by pay_analysis_group;
			retain r2;
			if first.pay_analysis_group then r2 = _rsq_;
			else _rsq_ = r2;
		run;
	%end;
	data regxpose_&grp (rename=(parms=&grp.diff t=&grp.sd _rsq_=&grp.rsq));
		set regxpose_&grp (keep=pay_analysis_group 
		%if &grp = min %then %do;
			_name_ /* lack of semicolon is intentional */
		%end;
		parms t _rsq_);
		%if &grp = min %then %do;
			if parms ne .;
			cklength = length(_name_);
			dumcat = input(substr(_name_,cklength,1),1.);
		%end;
	run;
	%if &grp = min %then %do;
		proc sort data=regxpose_&grp;
			by pay_analysis_group dumcat;
		run;
		proc sort data=&ethnicity.xwalk;
			by pay_analysis_group dumcat;
		run;
		data regxpose_&grp (keep = pay_analysis_group _name_ versus &grp.diff &grp.sd &grp.rsq dumcat);
			length _name_ $12.;
			merge regxpose_&grp (in = a)
			      &ethnicity.xwalk (in = b);
			by pay_analysis_group dumcat;
			if a and b;
			if dumcat = 1 then _name_ = 'NON-'||upcase(versus);
			else _name_ = upcase(&ethnicity);
			versus = upcase(versus);
		run;
	%end;
%mend outgroup;

%outgroup(female,fem)
%outgroup(minority,min)

/* Re-sort regxpose_min to put dummy categories in reverse order */
proc sort data=regxpose_min;
	by pay_analysis_group descending dumcat;
run;
data combine (drop = i nmin2-nmin&mincats);
	merge job_specs (keep=pay_analysis_group emps nnonfem nfem nmin: nallmin nnonmin)
	      regxpose_fem (in=fem)
		  regxpose_min (in=min);
	by pay_analysis_group;
	if fem or min;
	if pay_analysis_group = 'DUMMY PAY ANALYSIS GROUP' then delete; /* not a real result */
	if min and not fem then do;
		nfem = .;
		nnonfem = .;
	end;
	if fem and not min then do;
		nallmin = .;
		nnonmin = .;
	end;
	/* for tab B display, load nmin with specific ethnicity n */
	array ethnic nmin2-nmin&mincats;
	do i = 1 to dim(ethnic);
		if dumcat = i + 1 then nallmin = ethnic(i);
	end;	
run;
data combine;
	set combine;
	by pay_analysis_group;
	if not first.pay_analysis_group then do;
		emps = .;
		nnonfem = .;
		nfem = .;
		nnonmin = .;
		femdiff = .;
		femrsq = .;
		femsd = .;
		minrsq = .;
	end;
	else do; /* reset favored count for dichtomous-only race analysis */
		if emps = nnonmin then nnonmin = emps - nallmin;
	end;
run;

proc sql noprint;
	select count(*) into :mergeobs
	from combine;

	create table jobsinb as
		select distinct pay_analysis_group
		from combine;

	select count(*) into :jobsobs
	from jobsinb;
quit;

%let mergeobs = %eval(&mergeobs + 9 + &jobsobs); /* add 9 bcs output starts on line 9 */
                                                 /* add jobsobs to account for blank lines between titles */

filename casb dde "excel|B. Regression Results!r9c1:r&mergeobs.c14" notab;
%macro displayb;
	%if &mergeobs ne 9 %then %do; /* if mergeobs = 9, no obs in combine dataset */
		data _null_;
			file casb;
			set combine;
			by pay_analysis_group;
			if last.pay_analysis_group then do;
				put pay_analysis_group '09'x emps '09'x nnonfem '09'x nfem '09'x femrsq '09'x femdiff '09'x femsd '09'x nallmin '09'x nnonmin '09'x minrsq '09'x _name_ '09'x versus '09'x mindiff '09'x minsd /;
			end;
			else do;
				put pay_analysis_group '09'x emps '09'x nnonfem '09'x nfem '09'x femrsq '09'x femdiff '09'x femsd '09'x nallmin '09'x nnonmin '09'x minrsq '09'x _name_ '09'x versus '09'x mindiff '09'x minsd;
			end;
		run;
	%end;
	%else %do;
		data _null_;
			file casb;
			set errmsg;
			if errgrp = 'merg';
			put message;
		run;
	%end;
%mend displayb;

%displayb

/* CAS TAB C -- FAILED JOB TITLES */
proc sql noprint;
	select count(*) into :failjobs
	from fail_all;
quit;
proc sort data=fail_all;
	by pay_analysis_group;
run;
/* Get avg sal by group and merge to fail_all dataset */
proc sort data=New_Data;
	by pay_analysis_group female;
run;
/* Use raw salary for printing */
proc summary data=New_Data;
	by pay_analysis_group female;
	var raw_salary;
	output out=femsal mean=avgsal;
run;
proc sort data=New_Data;
	by pay_analysis_group whitecat;
run;
proc summary data=New_Data;
	by pay_analysis_group whitecat;
	var raw_salary;
	output out=minsal mean=avgsal;
run;
proc transpose data=femsal out=femsal2 (rename=(_0=nonfemsal _1=femsal));
	by pay_analysis_group;
	id female;
	var avgsal;
run;
proc transpose data=minsal out=minsal2 (rename=(_0=minsal _1=nonminsal));
	by pay_analysis_group;
	id whitecat;
	var avgsal;
run;
data fail_all2;
	merge fail_all (in=a)
	      femsal2
		  minsal2;
	by pay_analysis_group;
	if a;
run;
%let failjobs = %eval(&failjobs + 7); /* add 7 bcs output starts on line 7 */
filename casc dde "excel|C. Failed Pay Analysis Groups!r7c1:r&failjobs.c9" notab;

%macro displayc;
	%if &failjobs ne 7 %then %do; /* if failjobs = 7, no obs in fail_all dataset */
		data _null_;
			file casc;
			set fail_all2;
			put pay_analysis_group '09'x nfem '09'x nnonfem '09'x nnonwhite '09'x nwhite '09'x femsal '09'x nonfemsal '09'x minsal '09'x nonminsal;
		run;
	%end;
	%else %do;
		data _null_;
			file casc;
			set errmsg;
			if errgrp = 'fail';
			put message;
		run;
	%end;
%mend displayc;

%displayc

/* CAS TABS D and E -- JOB TITLE REGRESSIONS */
/* already written out by regress macro */

/* CAS TAB F -- META-ANALYSIS */
data meta_all;
	set metamerge_fem metamerge_min;
run;
proc sort data=meta_all;
	by sumlbl;
run;
proc summary data=meta_all;
	by sumlbl;
	var nobs nclass wgteff wgtvar;
	output out=metasum sum=allobs allclass alleff allvar;
run;
/* The meta-analytic procedure to this point has not kept track of female class members, as those counts are not 
   available in the regxpose_fem datasets.  Need to pull in the total female class from Tab B information. */
proc summary data=combine;
	var nfem;
	output out=femclass sum=femclass;
run;
data femclass;
	set femclass;
	call symput('femclass',femclass);
run;
data metasum;
	set metasum;
	if sumlbl = 'FEMALE' then allclass = symget('femclass');
run;
/* Now that all relevant data are loaded, conduct meta-analysis */
data meta_analysis;
	set metasum (keep=sumlbl allobs allclass alleff allvar);
	wace = alleff/allobs; /* Weighted average class effect */
	wase = sqrt(allvar/(allobs-1)); /* Weighted average standard error */
	metat = wace/wase; /* T-test for weighted average class effect */
	metap = cdf('T',metat,allobs-1); /* Cum. probability of T */
	if metap > .5 then metap = 1 - metap; /* Convert to one-tailed probability beyond T */
	metap = metap*2; /* Two-tailed value */
	label sumlbl = 'Class';
	label allobs = 'Total Emps';
	label allclass = 'Total Class';
	label wace = 'Wgt Avg Class Effect';
	label wase = 'Wgt Avg Std Err';
	label metat = 'Meta-Analytic SD';
	label metap = 'Meta-Analytic p-value';
run;
proc print data=meta_analysis noobs label;
	var sumlbl allobs allclass wace wase metat metap;
	title2 'Meta-Analytic Results for all PAGs meeting 30/5';
run;

%macro displayf;
	filename casf dde "excel|F. Meta-Analysis!r9c1:r21c7" notab;
	%if (&failfem = 100 and &failmin = 100) or &jobstot < 2  %then %do;
		data _null_;
			file casf;
			set errmsg;
			if errgrp = 'fail';
			put message;
		run;
	%end;
	%else %do;
		%if &uselogsal = 0 %then %do;
			data _null_;
				file casf;
				set errmsg;
				if errgrp = 'noln';
				put message;
			run;
		%end;
		%else %do;
			data _null_;
				file casf;
				set meta_analysis;
				put sumlbl '09'x allobs '09'x allclass '09'x wace '09'x wase '09'x metap '09'x metat;
			run;
		%end;
	%end;
%mend displayf;

%displayf;

* END OF COMPENSATION ANALYSIS SUMMARY PROGRAM ********************************;

/* Export regression data to Excel for post-estimation testing */
%macro prepexport;
	data Export_Data (drop=whitecat dummy_pag versus _type_ _freq_ count minority
	                       %if &Time_In_Company = 0 %then Time_In_Company_ctr;
						   %if &Time_In_Current_Pos = 0 %then Time_In_Current_Pos_ctr Other_Time_In_Company_ctr;
						   %if &Prior_Experience = 0 %then Prior_Experience_ctr;
						   %if &Age_at_Hire = 0 %then Age_at_Hire_ctr;
						   %if &usequadtenure = 0 %then time_in_company_sq time_in_current_pos_sq other_time_in_company_sq prior_experience_sq age_at_hire_sq;
						   %if &part_time = 0 %then part_time;
						   %if &exempt = 0 %then exempt;
	                  );
		set New_Data;
	run;
%mend prepexport;

%prepexport;

proc export data=Export_Data outfile="&Excel_Path.\&Case_Name batch &Batch_Number regression data &Analysis_Date" dbms=xlsx replace;
run;

proc datasets kill; /* delete temporary datasets in working memory */
quit;
run;

proc printto; /* redirects log and output to the window if set to an external file */
run;
