/*********************************This program includes the SAS scripts associated with the article.*************************************************/
	/************************************************Important to know**********************************************************************/
	/* This is for DATA GENERATING PROCESS AND SMETRICS COMPUTING

1-Generating the "memory" library with libname
You'll find the results in the form of 4 different data sets (independent, independent with outliers,
correlated, correlated with outliers).
H0 = Independence
H1 = Dependence


This algorithm will help you calculate metrics on 4 different sets.
2-Proc IML
3-Definition of required modules Iman-Conover .
4- Set selection method and stop criterion value in proc glmselect
		REPEAT THE PROCESS BY DATA TYPE FOR EACH PAIR (METHOD, CRITERION)*/
/***************************************KEY WORDS USED ************************************************/
/* perfF:perferct fitting ; overF:over fittinng;  underF:under fitting;  fail : under fitting but with additional values
that are not from the true model.*/


libname out ".";
/*********************************************** FUNCTION************************************************************************/

									/* IMAN CONOVER */

/*IMANCONOVER : This transformation is a statistical method used to generate samples of random variables 
that have a specific correlation structure. It is often used in Monte Carlo simulations and other applications 
other applications requiring the generation of simulated data that must respect a certain dependency structure.*/


proc iml;
start ImanConoverTransform(X, C);/*X is a data matrix and C is a correlation matrix of rank*/
N= nrow(X);
S= J(N, ncol(X));
do i= 1 to ncol(X);
ranks= ranktie(X[,i], "mean");         
S[,i]= quantile("Normal", ranks/(N+1)); 
end;
CS= corr(S);      
Q= root(CS);        
P= root(C);      
T= solve(Q,P);    
Y= S*T;          
W= X;
do i= 1 to ncol(Y);
rank= rank(Y[,i]);          
tmp = W[,i]; call sort(tmp); 
W[,i]= tmp[rank]; 
end;
return( W );

finish;

store module=(ImanConoverTransform); /*save the module for later use*/


/*Permanent table*/
OPTIONS NONOTES; /* To suppress the display of notes in SAS program output*/ 

/*This code creates several data sets (PERFORMANCE_GDP1, PERFORMANCE_GDP2, PERFORMANCE_GDP3, PERFORMANCE_GDP4)
and defines specific attributes (length, format, label) for certain variables in these datasets.
These attributes can be useful for data management and documentation purposes and contain all method and criterion pairs(3500)*/

DATA out.PERFORMANCE_GDP1 out.PERFORMANCE_GDP2 out.PERFORMANCE_GDP3 out.PERFORMANCE_GDP4;
ATTRIB
	METHODE length=$15 format=$15. label="Selection Method"
	CRITERE length=$15 format=$15. label="Stop Criterion"
	RESULTAT length=$15 format=$15. label="Result";
STOP;
RUN;

/**********************************************END FUNCTION************************************************************/


/******************************************VARIABLE SELECTION PROCESS**************************************************/

/************************************METRICS CALCULATION FOR NORMAL DATA UNDER H0*****************************************/

proc iml;
%LET METHOD=LAR;
%LET CRITERION=BIC;
%let Obs=250;
	m=1000;
	TrueX={"Intercept","X1","X2","X3","X4","X5"};/*True model*/
	free resultat_final;
	resultat_final=j(1,4,0);
	do rep= 1 to m;
	/* DGP1*/
	SIGMA=I(50); /*Covariance matrix*/
	MU=j(50,1,0);/*average vector*/
	free resultat;

		X= randNormal(&obs,MU,SIGMA);
		EPS=randNormal(&obs,0,0.1);
		BETA= {1.1 , 1, 0.5, -0.7, 0.3}; 
		Y=X[,1:5]*BETA+EPS;
		ens=Y || X;
		namescol="Y"//("X1":"X50")`;
		create GDP_indep from ens[colname=namescol];
		append from ens;
		close GDP_indep;
		submit;
		/*Selection de variable*/
PROC GLMSELECT data= GDP_indep outdesign=toto noprint;
		model Y= X1-X50 / selection=&method ( stop=SBC choose=&criterion.);
		partition fraction(validate=0.3); /*Select this option for LASSO, LAR,ELASTICNET and 
		add LSCOEFFS with the PRESS criterion*/
		run;
PROC TRANSPOSE data = toto out=toto;
        run;
		endsubmit;
		use toto;
		read all var {_label_} into totomat[colname=_label_];
        close toto;
								/*Metrics computation*/
		X_glmselect= totomat[1:(nrow(totomat)-1),1];
		X_intersect= xsect(trueX,X_glmselect); /*contains variables that are both true and selected*/
		cGLM=nrow(X_glmselect);
		cInter=ncol(X_intersect);
		cTRUEX=nrow(trueX);
		/*metric boolen*/
		if cInter=6 & cGLM=6 then perfF=1;
		else perfF=0;

		if cInter=6 & cGLM>6 then overF=1;
		else overF=0;

		if cInter<6 & cGLM=cInter then underF=1;
		else underF=0;

		if cInter<6 & cGLM>cInter then fail=1;
		else fail=0;

							/*Subroutine to put data in a single table*/
resultat= perfF||overF||underF||fail;	
resultat_final=resultat_final//resultat;
end;
	
create resultat1 from resultat_final[colname={'Perfect fit','Over fit','Under fit','fail'}];
append from resultat_final;
close resultat1;
submit;

data resultat1; 
set resultat1 ;
if _N_=1 then delete;
		METHODE="&method.";
CRITERE="&criterion.";
		IF perfect_fit=1 THEN RESULTAT="PERFECT FIT";
ELSE IF under_fit=1 THEN RESULTAT="UNDER FIT";
ELSE IF over_fit=1 THEN RESULTAT="OVER FIT";
ELSE RESULTAT="FAIL";
KEEP METHODE CRITERE RESULTAT;
run;
DATA OUT.PERFORMANCE_GDP1;
SET OUT.PERFORMANCE_GDP1 RESULTAT1;
RUN;
ENDSUBMIT;
/* ***************************graphs to evaluate the performance of the variable selection algorithm********************/
SUBMIT;

GOPTIONS DEVICE="ACTXIMG";
ODS GRAPHICS ON / height=6in width=9in;
ODS LISTING GPATH="./graph";

PROC FREQ DATA=OUT.PERFORMANCE_GDP1;
TABLES CRITERE*METHODE*RESULTAT/ out=FREQ_TEST outpct;
RUN;


TITLE "Independent data ";
FOOTNOTE "NB : Non displayed goodness-of-fits are 0, PRESS is not avalaible for ELASTICNET" ;
proc sgpanel data=FREQ_TEST ;
	panelby CRITERE /SPARSE columns=3 rows=1 layout=rowlattice;
	vbar METHODE / MISSING response=pct_row group=RESULTAT groupdisplay=cluster datalabel;
	ROWAXIS LABEL="Percentage";
	format pct_row 4.2;
	label;
run;
ODS LISTING CLOSE;
TITLE;
FOOTNOTE;
ENDSUBMIT;
/******************************************END METRICS COMPUTATION FOR NORMAL DATA UNDER H0****************************/

/******************************************METRICS COMPUTATION FOR NORMAL DATA WITH OUTLIERS UNDER H0****************************/


PROC IML;
%LET METHOD=LAR;
%LET CRITERION=PRESS;
%let Obs=250; 
m=1000;
TrueX={"Intercept","X1","X2","X3","X4","X5"}; /*True model*/
				/*DGP2*/

n=250 ;p= 50; outliers= 10;/* Number of observations, variables and outliers*/
free resultat_final;
resultat_final=j(1,4,0);
	SIGMA = I(p);/* Covariance matrix (identity for independence) */
	do rep= 1 to m;
MU = j(p, 1, 0);
free resultat; 
X = randNormal(n, MU, SIGMA); /*Normal independent data*/
	
							/*Adding outliers*/
do i = 1 TO n;
do j= 1 to p; /*Randomly add outliers to all variables */
u= uniform(0);
if u < 0.9 then X[i,j]= X[i,j]; /*in 90% of the variables it reproduces the uniform distribution and in 10% it reproduces random outliers*/
else X[i,j]= normal(0)+5; /* Adding outliers*/
end; 
end;
*call histogram(X[,1]);/*For an overview of extreme value distributions*/
EPS = randNormal(n, 0, 0.1); 

BETA = {1.1, 1, 0.5, -0.7, 0.3}; 
Y = X[,1:5]*BETA+EPS; 
Z = Y || X||X1; /*Concatenation */
namescol = "Y"//t("X1":"X50");
CREATE GDP_indep_outliers from z[colname=namescol];
APPEND from z;
CLOSE GDP_indep_outliers;
/*Variable selection*/
submit;
PROC GLMSELECT data= GDP_indep_outliers outdesign= toto noprint;
		model Y=X1-X50  /selection=&Method. (LSCOEFFS stop=AICC choose=&Criterion.);
		partition fraction(validate=0.3);/*Select this option for LASSO AND LAR and 
		add LSCOEFFS with the PRESS criterion*/
		run; 
	
PROC TRANSPOSE data = toto out=toto;
        run;
		endsubmit;
		
		use toto;
		read all var {_label_} into totomat[colname=_label_];
        close toto;
				/*Metrics computation*/
		X_glmselect= totomat[1:(nrow(totomat)-1),1];
		X_intersect= xsect(trueX,X_glmselect); /*contains variables that are both true and selected*/
		cGLM=nrow(X_glmselect);
		cInter=ncol(X_intersect);
		cTRUEX=nrow(trueX);
		
		if cInter=6 & cGLM=6 then perfF=1;
		else perfF=0;

		if cInter=6 & cGLM>6 then overF=1;
		else overF=0;

		if cInter<6 & cGLM=cInter then underF=1;
		else underF=0;

		if cInter<6 & cGLM>cInter then fail=1;
		else fail=0;
resultat=perfF||overF||underF||fail;
resultat_final=resultat_final//resultat;
end;
	/*Subroutine to put data in a single table*/

create resultat2 from resultat_final[colname={'Perfect fit','Over fit','Under fit','fail'}];
append from resultat_final;
close�resultat2;
SUBMIT;

DATA RESULTAT2;
SET RESULTAT2;
IF _N_=1 THEN DELETE;
METHODE="&method.";
CRITERE="&criterion.";
IF perfect_fit=1 THEN RESULTAT="PERFECT FIT";
ELSE IF under_fit=1 THEN RESULTAT="UNDER FIT";
ELSE IF over_fit=1 THEN RESULTAT="OVER FIT";
ELSE RESULTAT="FAIL";
KEEP METHODE CRITERE RESULTAT;
RUN;

DATA OUT.PERFORMANCE_GDP2;
SET OUT.PERFORMANCE_GDP2 RESULTAT2;
RUN;
ENDSUBMIT;
/* ***************************graphs to evaluate the performance of the variable selection algorithm********************/
SUBMIT;

GOPTIONS DEVICE="ACTXIMG";
ODS GRAPHICS ON / height=6in width=9in;
ODS LISTING GPATH="./graph";

PROC FREQ DATA=OUT.PERFORMANCE_GDP2;
TABLES CRITERE*METHODE*RESULTAT/ out=FREQ_TEST outpct;
RUN;


TITLE "Independent data with outliers ";
FOOTNOTE "NB : Non displayed goodness-of-fits are 0, PRESS is not avalaible for ELASTICNET" ;
proc sgpanel data=FREQ_TEST ;
	panelby CRITERE /SPARSE columns=3 rows=1 layout=rowlattice;
	vbar METHODE / MISSING response=pct_row group=RESULTAT groupdisplay=cluster datalabel;
	ROWAXIS LABEL="Percentage";
	format pct_row 4.2;
	label;
run;
ODS LISTING CLOSE;
TITLE;
FOOTNOTE;
ENDSUBMIT;


/*************************END METRICS COMPUTATION FOR NORMAL DATA WITH OUTLIERS UNDER H0****************************************/


/******************************METRICS COMPUTATION FOR NORMAL DATA UNDER H1*************************************/

PROC IML;
%LET METHOD=BACKWARD;
%LET CRITERION=AICC;
	%let Obs=250; 
	m=1000;
	TrueX={"Intercept","X1","X2","X3","X4","X5"};/*True model*/
	n= 250; p=5;
	free resultat_final;
	resultat_final=j(1,4,0);
do rep= 1 to m;
	MU= j(p,1,0);
	
	sigma=toeplitz({1,0.8,0.7,0.4,0.3});

	free resultat;
	X=randNormal(n, MU, SIGMA); 
	EPS= randNormal(n, 0, 0.1); 
	BETA = {1.1, 1, 0.5, -0.7, 0.3};
	Y= X[,1:5]*BETA+EPS;
	MU= j(45,1,0); 
	X1= randNormal(n, MU, I(45)); 
	Z=Y||X||X1;
	SIGMA= j(p, p, 0.5); /*Initialization with basic correlation*/

	DO i= 1 TO p;
		SIGMA[i,i]= 1; 
	END;

	namescol= "Y" //t("X1":"X50");
	CREATE GDP_corr from Z[colname=namescol];
	APPEND from Z;
	CLOSE GDP_corr;
	/*submit;
	/*Not mandatory, but important if you want to check whether the matrix is correlated.*/
/*proc corr data=GDP_corr; 
	var X1-X5;
	run
endsubmit;*/

submit;
				/*Variable selection */
PROC GLMSELECT data= GDP_corr outdesign= toto noprint;
		model Y=X1-X50  /selection=&method. (stop=AIC choose=&criterion.);
		*partition fraction(validate=0.3);/*Select this option for LASSO AND LAR and 
		add LSCOEFFS with the PRESS criterion*/
		run;
		
PROC TRANSPOSE data = toto out=toto;
run;
endsubmit;
use toto;
read all var {_label_} into totomat[colname=_label_];
close toto;
	/*Metrics computation*/
	X_glmselect= totomat[1:(nrow(totomat)-1),1];
	X_intersect= xsect(trueX,X_glmselect); /*contains variables that are both true and selected*/
	cGLM=nrow(X_glmselect);
	cInter=ncol(X_intersect);
	cTRUEX=nrow(trueX);
		/* METRIQUE BOOLENE*/
	if cInter=6 & cGLM=6 then perfF=1;
		else perfF=0;

	if cInter=6 & cGLM>6 then overF=1;
		else overF=0;

	if cInter<6 & cGLM=cInter then underF=1;
		else underF=0;

	if cInter<6 & cGLM>cInter then fail=1;
		else fail=0;

resultat=perfF||overF||underF||fail;
resultat_final=resultat_final//resultat;
end;

create resultat3 from resultat_final[colname={'Perfect fit','Over fit','Under fit','fail'}];
append from resultat_final;
close�resultat3;

SUBMIT;

DATA RESULTAT3;
SET RESULTAT3;
IF _N_=1 THEN DELETE;
METHODE="&method.";
CRITERE="&criterion.";
IF perfect_fit=1 THEN RESULTAT="PERFECT FIT";
ELSE IF under_fit=1 THEN RESULTAT="UNDER FIT";
ELSE IF over_fit=1 THEN RESULTAT="OVER FIT";
ELSE RESULTAT="FAIL";
KEEP METHODE CRITERE RESULTAT;
RUN;

DATA OUT.PERFORMANCE_GDP3;
SET OUT.PERFORMANCE_GDP3 RESULTAT3;
RUN;
ENDSUBMIT;
/* ***************************graphs to evaluate the performance of the variable selection algorithm********************/
SUBMIT;

GOPTIONS DEVICE="ACTXIMG";
ODS GRAPHICS ON / height=6in width=9in;
ODS LISTING GPATH="./graph";

PROC FREQ DATA=OUT.PERFORMANCE_GDP3;
TABLES CRITERE*METHODE*RESULTAT/ out=FREQ_TEST outpct;
RUN;


TITLE "Dependent data  ";
FOOTNOTE "NB : Non displayed goodness-of-fits are 0, PRESS is not avalaible for ELASTICNET" ;
proc sgpanel data=FREQ_TEST ;
	panelby CRITERE /SPARSE columns=3 rows=1 layout=rowlattice;
	vbar METHODE / MISSING response=pct_row group=RESULTAT groupdisplay=cluster datalabel;
	ROWAXIS LABEL="Percentage";
	format pct_row 4.2;
	label;
run;
ODS LISTING CLOSE;
TITLE;
FOOTNOTE;
ENDSUBMIT;

/**********************************END METRICS COMPUTATION FOR NORMAL DATA UNDER H1******************************************/



/********************************METRICS COMPUTATION FOR DATA WITH OUTLIERS UNDER H1*******************************************/

/*Before running this part, run the IMANCONOVER function as it is called here*/
PROC IML;
load module=(ImanConoverTransform);
%let Obs=250; 
%let Method=LAR;
%let Criterion=PRESS;
	
	m=1000;
	TrueX={"Intercept","X1","X2","X3","X4","X5"};
	
matcorr= toeplitz({1,0.8,0.7,0.4,0.3});
n= 250; p=5;
free resultat_final;
	resultat_final=j(1,4,0);
Do rep = 1 to m;

MU= j(p,1,0); /*MEASUREMENT ERROR*/
sigma= I(5);
free resultat;
X=randNormal(n, MU, SIGMA); 
X = ImanConoverTransform(X, matcorr);
EPS= randNormal(n, 0, 0.1); 
BETA = {1.1, 1, 0.5, -0.7, 0.3};
Y= X[,1:5]*BETA+EPS;
MU= j(45,1,0); 
X1= randNormal(n, MU, I(45)); 
/*Adding outliers*/
DO i = 1 TO n;
	Do j= 1 to p; /*Randomly add outliers to all variables */
		u= uniform(0); if u < 0.9 then X[i,j]= X[i,j]; 
		else X[i,j]= X[i,j]+RAND("Normal")*5; /* adding outlier*/
	end; 
end;
Z=Y||X||X1;


/*Concat�nation */
namescol= "Y" // t("X1":"X50");

CREATE GDP_corr_outliers from Z[colname=namescol];
APPEND from Z;
CLOSE GDP_corr_outliers;
/*submit;
Not mandatory, but important if you want to check whether the matrix is correlated.*/
/*proc corr data=GDP_corr_outliers; 
var X1-X5;
run;
endsubmit;*/

 submit;
PROC GLMSELECT data= GDP_corr_outliers outdesign= toto noprint;
		model Y=X1-X50  /selection=&Method. (LSCOEFFS stop=PRESS choose= &Criterion.);
partition fraction(validate=0.3); /*Select this option for LASSO AND LAR and 
		add LSCOEFFS with the PRESS criterion*/
		run; 
		
PROC TRANSPOSE data = toto out=toto;
        run;
		endsubmit;
		
		use toto;
		read all var {_label_} into totomat[colname=_label_];
        close toto;
					/*Metrics computation*/

		X_glmselect= totomat[1:(nrow(totomat)-1),1];
		
		
		X_intersect= xsect(trueX,X_glmselect); /*contains variables that are both true and selected*/
		cGLM=nrow(X_glmselect);
		cInter=ncol(X_intersect);
		cTRUEX=nrow(trueX);
		
		if cInter=6 & cGLM=6 then perfF=1;
		else perfF=0;

		if cInter=6 & cGLM>6 then overF=1;
		else overF=0;

		if cInter<6 & cGLM=cInter then underF=1;
		else underF=0;

		if cInter<6 & cGLM>cInter then fail=1;
		else fail=0;


resultat=perfF||overF||underF||fail;
resultat_final=resultat_final//resultat;
end;
	/*Subroutine to put data in a single table*/

create resultat4 from resultat_final[colname={'Perfect fit','Over fit','Under fit','fail'}];
append from resultat_final;
close�resultat4;

SUBMIT;

DATA RESULTAT4;
SET RESULTAT4;
IF _N_=1 THEN DELETE;
METHODE="&method.";
CRITERE="&criterion.";
IF perfect_fit=1 THEN RESULTAT="PERFECT FIT";
ELSE IF under_fit=1 THEN RESULTAT="UNDER FIT";
ELSE IF over_fit=1 THEN RESULTAT="OVER FIT";
ELSE RESULTAT="FAIL";
KEEP METHODE CRITERE RESULTAT;
RUN;

DATA OUT.PERFORMANCE_GDP4;
SET OUT.PERFORMANCE_GDP4 RESULTAT4;
RUN;
ENDSUBMIT;

/* ***************************graphs to evaluate the performance of the variable selection algorithm********************/
SUBMIT;
/

GOPTIONS DEVICE="ACTXIMG";
ODS GRAPHICS ON / height=6in width=9in;
ODS LISTING GPATH="./graph";

PROC FREQ DATA=OUT.PERFORMANCE_GDP4;
TABLES CRITERE*METHODE*RESULTAT/ out=FREQ_TEST outpct;
RUN;


TITLE "Dependent data with outliers ";
FOOTNOTE "NB : Non displayed goodness-of-fits are 0, PRESS is not avalaible for ELASTICNET" ;
proc sgpanel data=FREQ_TEST ;
	panelby CRITERE /SPARSE columns=3 rows=1 layout=rowlattice;
	vbar METHODE / MISSING response=pct_row group=RESULTAT groupdisplay=cluster datalabel;
	ROWAXIS LABEL="Percentage";
	format pct_row 4.2;
	label;
run;
ODS LISTING CLOSE;
TITLE;
FOOTNOTE;
ENDSUBMIT;
/*NB: The proc freq part can only be added towards the end, just be sure to change the data types each time.*/
