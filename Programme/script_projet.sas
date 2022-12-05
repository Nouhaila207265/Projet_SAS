/* Import des tables */

/*1*/

%web_drop_table(WORK.INDIC_PAUV);


FILENAME REFFILE '/home/u57966059/projet_sas2022/indicateur_pauvrete.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.INDIC_PAUV;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.INDIC_PAUV; RUN;


%web_open_table(WORK.INDIC_PAUV);


/*2*/

%web_drop_table(WORK.RESULTATS_DNB);


FILENAME REFFILE '/home/u57966059/projet_sas2022/resultats_dnb.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.RESULTATS_DNB;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.RESULTATS_DNB; RUN;


%web_open_table(WORK.RESULTATS_DNB);


/*---------------------------------------------------------------------------------------*/

/* Tri par clé de jointure (commune_1) sur la table resultats_dnb */	
PROC SORT
DATA=resultats_dnb;
BY commune_1;
run;

proc print 
data=resultats_dnb(obs=50);
run;

DATA resultats_dnb ;
    SET resultats_dnb (RENAME = ('Taux de réussite'n = TauxReussite)) ;
 RUN ;

data resultats_dnb ;
	set work.resultats_dnb;
	Taux_de_réussite = input(TauxReussite, percent10.);
run;

/* Mise en majuscule & tri par clé de jointure (commune) sur la table indicateur_pauvrete */	

data indicateur_pauvrete;
set indic_pauv;
commune = upcase(commune);
run;

proc sort data=indicateur_pauvrete;
by commune;
run;


/* Jointure entre les deux tables */

proc sql ;
	create table fusion_data as
	select *
	from indicateur_pauvrete as ip
		inner join resultats_dnb as rd on rd.commune_1 = ip.commune;
quit;
	
	
/* Moyenne des résultats au DNB */

/*DATA fusion_data ;
    SET fusion_data (RENAME = ('Taux de réussite'n = TauxReussite)) ;
RUN ;*/

data fusion_data ;
	set work.fusion_data;
	Taux_de_réussite = input(TauxReussite, percent10.);
run;

proc sql ;
	select avg(Taux_de_réussite) format = 5.3
	from fusion_data;
quit;

	/** la moyenne nationale des résultats du DNB est de 87,22% pour nos données **/
	

/* Moyenne des résultats public/privé */

proc sql ;
	select count(*),"Secteur d'enseignement"n as sec, avg(Taux_de_réussite) format = 5.3
	from resultats_dnb 
	where sec ne "-"
	group by "Secteur d'enseignement"n;
quit;

	/** en moyenne, le privé gagne 10 point de % sur le public **/


/* Corrélation et reg lin. */
	
proc corr data=fusion_data;
var "Médiane du niveau vie (€)"n Taux_de_réussite;
run;

proc gplot data=fusion_data;
plot Taux_de_réussite*"Médiane du niveau vie (€)"n;
run;

proc reg data=fusion_data corr;
model Taux_de_réussite="Médiane du niveau vie (€)"n /clb cli clm;
plot Taux_de_réussite*"Médiane du niveau vie (€)"n /pred;
plot residual.*"Médiane du niveau vie (€)"n;
run;


/* T Test */
proc ttest data=fusion_data;
 var Taux_de_réussite;
 class "Secteur d'enseignement"n;
run;

/* Pas d'écart significatif des variances selon T Test */
/* On constate toutefois un écart de presque 9 point de pourcentage entre le public et le privé */





/* 1ère Macro ->  comparaison secteur privé/public 
-> on renvoi taux d’admission moyen par secteur (pourcentage de réussite par villes) */

data resultats_dnb (drop=Commune);
set resultats_dnb;
run;

data fusion_data;
run;


/* Macro resultats au dnb par ville */

data resultats_dnb;
	set resultats_dnb (rename=('Code département'n = numdep));
run;

%macro resultat_dnb_villes; 
proc sql; 
	select distinct(commune), numdep, avg(Taux_de_réussite) format = 5.2 as moy_admis
	into :commune trimmed 
	from indicateur_pauvrete as a
	inner join resultats_dnb as b on a.commune = b.commune_1 
	where commune = 'REIMS'
	group by 1;  
quit; 
%put &commune &'Code département'n &moy_admis; 
%mend; 
%resultat_dnb_villes;

	/* A Reims, la moyenne d'admission au dnb est de 90.83% */


/* 2ème Macro -> niveau de médiane de vie par départements 
(arguments = département, ça doit nous ressortir niveau de médiane de vie)  */


%macro niv_vie_dep;
proc sql;
	select distinct(numdep), avg("Médiane du niveau vie (€)"n) format = 8.2 as med
	from indicateur_pauvrete as ip
	inner join resultats_dnb as rb on ip.commune = rb.commune_1
	where numdep = '051'
	group by 1;
quit;
%put &dep&med;
%mend;
%niv_vie_dep;

	/* Dans la Marne (51), le niveau de vie médian est de 20437.06€ */
