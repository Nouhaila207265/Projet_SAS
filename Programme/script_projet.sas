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

/* Tri par clÃ© de jointure (commune_1) sur la table resultats_dnb */	
PROC SORT
DATA=resultats_dnb;
BY commune_1;
run;

proc print 
data=resultats_dnb(obs=50);
run;

DATA resultats_dnb ;
    SET resultats_dnb (RENAME = ('Taux de rÃ©ussite'n = TauxReussite)) ;
 RUN ;

data resultats_dnb ;
	set work.resultats_dnb;
	Taux_de_rÃ©ussite = input(TauxReussite, percent10.);
run;

/* Mise en majuscule & tri par clÃ© de jointure (commune) sur la table indicateur_pauvrete */	

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
	
	
/* Moyenne des rÃ©sultats au DNB */

/*DATA fusion_data ;
    SET fusion_data (RENAME = ('Taux de rÃ©ussite'n = TauxReussite)) ;
RUN ;*/

data fusion_data ;
	set work.fusion_data;
	Taux_de_rÃ©ussite = input(TauxReussite, percent10.);
run;

proc sql ;
	select avg(Taux_de_rÃ©ussite) format = 5.3
	from fusion_data;
quit;

	/** la moyenne nationale des rÃ©sultats du DNB est de 87,22% pour nos donnÃ©es **/
	

/* Moyenne des rÃ©sultats public/privÃ© */

proc sql ;
	select count(*),"Secteur d'enseignement"n as sec, avg(Taux_de_rÃ©ussite) format = 5.3
	from resultats_dnb 
	where sec ne "-"
	group by "Secteur d'enseignement"n;
quit;

	/** en moyenne, le privÃ© gagne 10 point de % sur le public **/


/* CorrÃ©lation et reg lin. */
	
proc corr data=fusion_data;
var "MÃ©diane du niveau vie (â¬)"n Taux_de_rÃ©ussite;
run;

proc gplot data=fusion_data;
plot Taux_de_rÃ©ussite*"MÃ©diane du niveau vie (â¬)"n;
run;

proc reg data=fusion_data corr;
model Taux_de_rÃ©ussite="MÃ©diane du niveau vie (â¬)"n /clb cli clm;
plot Taux_de_rÃ©ussite*"MÃ©diane du niveau vie (â¬)"n /pred;
plot residual.*"MÃ©diane du niveau vie (â¬)"n;
run;


/* T Test */
proc ttest data=fusion_data;
 var Taux_de_rÃ©ussite;
 class "Secteur d'enseignement"n;
run;

/* Pas d'Ã©cart significatif des variances selon T Test */
/* On constate toutefois un Ã©cart de presque 9 point de pourcentage entre le public et le privÃ© */





/* 1Ã¨re Macro ->  comparaison secteur privÃ©/public 
-> on renvoi taux dâadmission moyen par secteur (pourcentage de rÃ©ussite par villes) */

data resultats_dnb (drop=Commune);
set resultats_dnb;
run;

data fusion_data;
run;


/* Macro resultats au dnb par ville */

data resultats_dnb;
	set resultats_dnb (rename=('Code dÃ©partement'n = numdep));
run;

%macro resultat_dnb_villes; 
proc sql; 
	select distinct(commune), numdep, avg(Taux_de_rÃ©ussite) format = 5.2 as moy_admis
	into :commune trimmed 
	from indicateur_pauvrete as a
	inner join resultats_dnb as b on a.commune = b.commune_1 
	where commune = 'REIMS'
	group by 1;  
quit; 
%put &commune &'Code dÃ©partement'n &moy_admis; 
%mend; 
%resultat_dnb_villes;

	/* A Reims, la moyenne d'admission au dnb est de 90.83% */


/* 2Ã¨me Macro -> niveau de mÃ©diane de vie par dÃ©partements 
(arguments = dÃ©partement, Ã§a doit nous ressortir niveau de mÃ©diane de vie)  */


%macro niv_vie_dep;
proc sql;
	select distinct(numdep), avg("MÃ©diane du niveau vie (â¬)"n) format = 8.2 as med
	from indicateur_pauvrete as ip
	inner join resultats_dnb as rb on ip.commune = rb.commune_1
	where numdep = '051'
	group by 1;
quit;
%put &dep&med;
%mend;
%niv_vie_dep;

	/* Dans la Marne (51), le niveau de vie mÃ©dian est de 20437.06â¬ */
/* Renommer les variables et remplacer les virgules */
data fusion_data;
set FUSION_DATA;
rename "Secteur d'enseignement"n = secteur;
rename "Libellé région"n = Region;
rename "Médiane du niveau vie (€)"n = Mediane;
rename "Taux de pauvreté-Ensemble (%)"n = Taux_pauvreté;
rename "Admis Mention bien"n = Mbien;
rename "Admis Mention très bien"n = MTbien;
tauxreussite= tranwrd(tauxreussite,',','.');
run;
/*Macro pour les taux de pauvreté du plus élevé au plus bas:*/

%macro stats(var1);
proc sql ;
select region, round(avg(input(&var1,best.)),0.2) as &var1 
from fusion_data
group by 1
order by 2 desc;
%MEND stats;
%stats(Taux_pauvreté).;
/*Macro pour les taux de pauvreté du plus élevé au plus bas:*/

%macro stats(var1);
proc sql ;
select region, round(avg(input(&var1,best.)),0.2) as &var1 
from fusion_data
group by 1
order by 2 desc;
%MEND stats;
%stats(Taux_pauvreté).;
/* Creation d'une macro qui determine le pourcentage des departements ayant plus que mention bien */
%macro prc_mbien;
proc sql ;
select region, avg(Mbien/presents) + avg(MTbien/presents)  as prc into top1
from fusion_data
group by 1
order by 2;
quit;
%mend;
%prc_mbien;

