set search_path = fima,us,summary;


-- county subdivision data, not in use
DELETE FROM fima.national_county_subdivision;
-- import csv file data using pgAdmin3.
DELETE FROM fima.hourseholds_income_county_subdivision;
-- import csv file data using pgAdmin3.

alter table national_county_subdivision alter column countyfp type character varying(3);

alter table fima.national_county_subdivision add primary key(statefp, countyfp, cousubfp);
alter table fima.hourseholds_income_county_subdivision add primary key(id);

alter table fima.hourseholds_income_county_subdivision add column statefp character varying(2);
update fima.hourseholds_income_county_subdivision h
set statefp = (
  select substr(id2, 1, 2) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id)
where exists(
  select substr(id2, 1, 2) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id);
  
alter table fima.hourseholds_income_county_subdivision add column countyfp character varying(3);
update fima.hourseholds_income_county_subdivision h
set countyfp = (
  select substr(id2, 3, 3) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id)
where exists(
  select substr(id2, 3, 3) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id);

alter table fima.hourseholds_income_county_subdivision add column cousubfp character varying(5);
update fima.hourseholds_income_county_subdivision h
set cousubfp = (
  select substr(id2, 6, 5) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id)
where exists(
  select substr(id2, 6, 5) 
  from hourseholds_income_county_subdivision hh
  where h.id = hh.id);
  
  
drop table fima.county_subdivision_income;
create table fima.county_subdivision_income as
select
h.id,
h.id2,
n.state,
n.statefp,
n.countyname,
n.countyfp,
n.cousubname,
n.cousubname as scousubname,
n.cousubfp,
h.geography,
h.total_households,
h.median_income,
n.funcstat
from fima.national_county_subdivision n
left outer join fima.hourseholds_income_county_subdivision h using(statefp, countyfp, cousubfp)
order by n.statefp, n.countyfp, n.cousubfp;

alter table fima.county_subdivision_income add primary key(statefp, countyfp, cousubfp);
  
update fima.county_subdivision_income c
set scousubname = (
  select trim(trailing ' CCD' from cousubname)
  from fima.county_subdivision_income cc
  where c.id = cc.id)
where scousubname like '%CCD' and
exists(
  select trim(trailing ' CCD' from cousubname)
  from fima.county_subdivision_income cc
  where c.id = cc.id);

  
alter table fima.nfip_community_status add column countyfp character varying(3);
-- not working
update fima.nfip_community_status n
set countyfp = (
  select s.countyfp from fima.national_county_subdivision s
  where s.countyname = n.county_name limit 1)
where exists(
  select s.countyfp from fima.national_county_subdivision s
  where s.countyname = n.county_name limit 1);

--------------------------------------------------------------------------------------------------------------------------------------------
-- income by jurisdiciton

-- option 1: average medium income
avg(t.cti_median_income) as income
-- option 2: weighted average medium income by number of hourseholds
sum(t.cti_households * t.cti_median_income)/sum(t.cti_households) as income

-- test
select avg(tract_2010census.cti_median_income) 
from tract_2010census, jurisdictions 
where ST_Intersects(tract_2010census.boundary,jurisdictions.boundary) and jurisdictions.j_area_id = '06J0488';

drop table fima.j_income;
create table fima.j_income as
select 
j.jurisdiction_id,
count(t.geoid10) as ntract,
avg(t.cti_median_income) as income
from tract_2010census t, jurisdictions j
where ST_Intersects(t.boundary,j.boundary) 
-- and j.j_area_id = '06J0488'
group by 1
order by 1;

INSERT INTO fima.j_income VALUES
    (28058, 0.0, 0.0);
INSERT INTO fima.j_income VALUES
    (28059, 0.0, 0.0);    
INSERT INTO fima.j_income VALUES
    (28060, 0.0, 0.0);
INSERT INTO fima.j_income VALUES
    (28061, 0.0, 0.0);    

alter table fima.j_income add primary key (jurisdiction_id);

alter table fima.j_income add column class character varying(2);

update fima.j_income
set class = 1
where income <= 15000;
update fima.j_income
set class = 2
where income > 15000 and income <= 25000;
update fima.j_income
set class = 3
where income > 25000 and income <= 35000;
update fima.j_income
set class = 4
where income > 35000 and income <= 50000;
update fima.j_income
set class = 5
where income > 50000 and income <= 75000;
update fima.j_income
set class = 6
where income > 75000 and income <= 100000;
update fima.j_income
set class = 7
where income > 100000 and income <= 150000;
update fima.j_income
set class = 8
where income > 150000 and income <= 200000;
update fima.j_income
set class = 9
where income > 200000;


-- number of jurisdictions of each income class
select class, count(*) from fima.j_income group by 1 order by 1;
class | count 
-------+-------
 1     |    25
 2     |   211
 3     |  2069
 4     | 12074
 5     | 11046
 6     |  1912
 7     |   677
 8     |    43
 9     |     4


--------------------------------------------------------------------------------------------------------------------------------------------
-- income by jurisdiciton and 0.1 lat/long for claims database

drop table fima.llj_income;
create table fima.llj_income as
select 
llj.llj_id,
count(t.geoid10) as ntract,
avg(t.cti_median_income) as income,
sum(t.cti_households * t.cti_median_income)/sum(t.cti_households) as income2
from fima.tract_2010census t, fima.llj
where ST_Intersects(t.boundary,llj.boundary) 
group by 1
order by 1;

select j.llj_id from fima.llj j where llj_id not in (select lj.llj_id from fima.llj_income lj) order by 1;

INSERT INTO fima.llj_income VALUES
    (43063, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43064, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43065, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43066, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43067, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43068, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43069, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43070, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43071, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43072, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43102, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43103, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43104, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43105, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43106, 0, 0.0, 0.0);    
INSERT INTO fima.llj_income VALUES
    (43107, 0, 0.0, 0.0);
INSERT INTO fima.llj_income VALUES
    (43108, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43109, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43110, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43111, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43112, 0, 0.0, 0.0); 
INSERT INTO fima.llj_income VALUES
    (43113, 0, 0.0, 0.0); 
    
alter table fima.llj_income add primary key (llj_id);

update fima.llj_income
set income = 0.0 where income is null;

alter table fima.llj_income add column class character varying(2);

update fima.llj_income
set class = 1
where income <= 15000;
update fima.llj_income
set class = 2
where income > 15000 and income <= 25000;
update fima.llj_income
set class = 3
where income > 25000 and income <= 35000;
update fima.llj_income
set class = 4
where income > 35000 and income <= 50000;
update fima.llj_income
set class = 5
where income > 50000 and income <= 75000;
update fima.llj_income
set class = 6
where income > 75000 and income <= 100000;
update fima.llj_income
set class = 7
where income > 100000 and income <= 150000;
update fima.llj_income
set class = 8
where income > 150000 and income <= 200000;
update fima.llj_income
set class = 9
where income > 200000;

-- number of llj units for claim database of each income class
select class, count(*) from fima.llj_income group by 1 order by 1;
class | count 
-------+-------
 1     |   135
 2     |   597
 3     |  5094
 4     | 25957
 5     | 29142
 6     |  7087
 7     |  2602
 8     |   216
 9     |    12


--------------------------------------------------------------------------------------------------------------------------------------------
-- income by jurisdiciton and 0.1 lat/long for policy database

drop table fima.lljpolicy_income;
create table fima.lljpolicy_income as
select 
llj.llj_id,
count(t.geoid10) as ntract,
avg(t.cti_median_income) as income,
sum(t.cti_households * t.cti_median_income)/sum(t.cti_households) as income2
from fima.tract_2010census t, fima.lljpolicy llj
where ST_Intersects(t.boundary,llj.boundary) 
group by 1
order by 1;

select j.llj_id from fima.lljpolicy j where j.llj_id not in (select lj.llj_id from fima.lljpolicy_income lj) order by 1;

INSERT INTO fima.lljpolicy_income VALUES
    (7180, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (16127, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (23971, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (30242, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (32211, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (33607, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (36472, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (38424, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (38443, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (42515, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (43574, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (54574, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (47700, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (54949, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (58875, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (59785, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (69181, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (69392, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (73262, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (74996, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (75028, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (80517, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (81084, 0, 0.0, 0.0); 
INSERT INTO fima.lljpolicy_income VALUES
    (102419, 0, 0.0, 0.0); 

alter table fima.lljpolicy_income add primary key (llj_id);

update fima.lljpolicy_income
set income = 0.0 where income is null;

alter table fima.lljpolicy_income add column class character varying(2);

update fima.lljpolicy_income
set class = 1
where income <= 15000;
update fima.lljpolicy_income
set class = 2
where income > 15000 and income <= 25000;
update fima.lljpolicy_income
set class = 3
where income > 25000 and income <= 35000;
update fima.lljpolicy_income
set class = 4
where income > 35000 and income <= 50000;
update fima.lljpolicy_income
set class = 5
where income > 50000 and income <= 75000;
update fima.lljpolicy_income
set class = 6
where income > 75000 and income <= 100000;
update fima.lljpolicy_income
set class = 7
where income > 100000 and income <= 150000;
update fima.lljpolicy_income
set class = 8
where income > 150000 and income <= 200000;
update fima.lljpolicy_income
set class = 9
where income > 200000;

-- number of llj units for policy database of each income class
select class, count(*) from fima.lljpolicy_income group by 1 order by 1;
class | count 
-------+-------
 1     |   162
 2     |   893
 3     |  9395
 4     | 46504
 5     | 43435
 6     |  8135
 7     |  2729
 8     |   221
 9     |    12

update summary.policy_yearly_2015_j  set j_pop10  = 9999999999 where j_pop10 = 0;

-- hhtp://obamacarefacts.com/federal-poverty-level/
-- 2014 Federal Poverty Guidelines – 48 Contiguous States & DC
-- Persons in Household: 4
-- 2014 Federal Poverty Level threshold 100% FPL: $23,850
-- 2014 POVERTY GUIDELINES – ALASKA: $29,820  FIPS Code 02
-- 2014 POVERTY GUIDELINES – HAWAII: $27,430  FIPS Code 15

update fima.lljpolicy_income
set class = 99;

update fima.lljpolicy_income li
set class = 1 
where li.income <= 29820 and 
li.llj_id in (
  select l.llj_id 
  from fima.lljpolicy l, fima.jurisdictions j
  where l.jurisdiction_id = j.jurisdiction_id and j.j_statefp10 = '02');

update fima.lljpolicy_income li
set class = 1 
where li.income <= 27430 and 
li.llj_id in (
  select l.llj_id 
  from fima.lljpolicy l, fima.jurisdictions j
  where l.jurisdiction_id = j.jurisdiction_id and j.j_statefp10 = '15');

update fima.lljpolicy_income li
set class = 1 
where li.income <= 23850 and li.class = '99';

