/* Import des tables */

/*1*/

%web_drop_table(WORK.INDIC_PAUV);


FILENAME REFFILE '/home/u62518117/indicateur_pauvrete.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.INDIC_PAUV;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.INDIC_PAUV; RUN;


%web_open_table(WORK.INDIC_PAUV);


/*2*/

%web_drop_table(WORK.RESULTATS_DNB);


FILENAME REFFILE '/home/u62518117/resultats_dnb.xlsx';

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
BY nom_commune;
run;

proc print
data=resultats_dnb(obs=50);
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
		inner join resultats_dnb as rd on rd.nom_commune = ip.commune;
quit;
/* Renommer les variables et remplacer les virgules */
data fusion_data;
set FUSION_DATA;
rename "Secteur d'enseignement"n = secteur;
rename "Taux de réussite"n = Tauxreussite;
rename "Libellé région"n = Region;
rename "Médiane du niveau vie (€)"n = Mediane;
rename "Taux de pauvreté-Ensemble (%)"n = Taux_pauvreté;
rename "Admis Mention bien"n = Mbien;
rename "Admis Mention très bien"n = MTbien;
tauxreussite= tranwrd(tauxreussite,',','.');
drop nom_commune;
run;
/* Pourcentage du taux de réussite par région: Haut de France avec le plus grand pourcentage de réussite*/
proc sql;
select Region, put(round(avg(input(scan(tauxreussite,1,'%'),best.)),0.001),best.)as pourcentage_taux_de_réussite
from fusion_data
group by 1
ORDER BY 2 desc;
quit;

/*Le taux d'admission par secteur: Secteur privé en premier lieu */
proc sql;
select secteur, cat(put(round(avg(admis/presents)*100,0.2),best.),'%') as taux_admission
from fusion_data
group by 1;
quit;


/* La médiane du niveau de vie par an pour chaque secteur: globalement la meme*/
proc sql;
select secteur,cat(round(avg(Mediane),0.2),'€') as Médiane_du_niveau_de_vie_par_an
from fusion_data
group by 1;
quit;
/*La région ayant le taux de pauvreté le plus élevé: Guadaloupe */
proc sql outobs=1;
select region, round(avg(input(Taux_pauvreté,best.)),0.2) as pauvreté
into :pauvrete
from fusion_data
group by 1
order by 2 desc;
quit;
%put &pauvrete.;
/* Le taux de pauvreté par secteur*/
%macro stats(var1);
proc sql ;
select secteur, round(avg(input(&var1,best.)),0.2) as pauvreté
from fusion_data
group by 1;
%MEND stats;
%stats(Taux_pauvreté)
/*Macro pour les taux de pauvreté du plus élevé au plus bas:*/
%macro stats(var1);
proc sql ;
select region, round(avg(input(&var1,best.)),0.2) as &var1
from fusion_data
group by 1
order by 2 desc;
%MEND stats;
%stats(Taux_pauvreté);


proc sql ;
select max(Mbien/presents) into :top1
from fusion_data;
quit;
proc sql ;
select max(MTbien/presents) into :top2
from fusion_data;
quit;
%let o = %eval(&top1. + &top2.);
