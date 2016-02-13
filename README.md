# What is this function doing ?
[![Build Status](https://secure.travis-ci.org/larsop/esri_union.png)]
(http://travis-ci.org/larsop/esri_union)

This is a generic Postgres function that is does a “Esri union” between two polygonlayers in a postgis database. More info about Esri union can be found at http://resources.esri.com/help/9.3/arcgisengine/java/gp_toolref/analysis_tools/union_analysis_.htm.

The basic idea is that you call this function and with 2 tables as input. The code builds a grid to splits up the data, compute the result and return a table name with a union of this two tables. For areas that intersect you get attributes from both tables and for areas that only exits in one of the tables you only get attributes from one table.

# How to use :
For each table we need the following information as input 
* table name
* primary key column name (supports only a single column, could have been been computed in the code. The primary key is used to remove grid lines after the result is done.)
* geometry column name (could have be computed in the code)

## Example 1 : Union beetween table_1 and table_2 and return a tmp table
run the function  get_esri_union with 2 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo')"; </pre></code>
The result is stored in uniqie temp table with a name like esri_union_result_11876d5db5a9b85570fb4f3813ea31e9. 
To keep the result when you get back to sql, where the last part of the name is unique mm5 sum
<pre><code> CREATE TABLE sl_lop.result1 AS SELECT * FROM  esri_union_result_11876d5db5a9b85570fb4f3813ea31e9; </pre></code>

## Example 2 : Union beetween table_1 and table_2 and return a unlogged table with name sl_lop.result
run the function  get_esri_union with 3 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo','sl_lop.result')"; </pre></code>

The result is stored in a unlogged table sl_lop.result . If the the db server crashes or is be restored the  sl_lop.result will gone, so remember to change table to logged (9.5 only) or copy the result to another table.

## Example 3 : Union beetween table_1 and table_2 and return a unlogged table with name sl_lop.result, but use bigger cells
run the function  get_esri_union with 4 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo','sl_lop.result',5000)"; </pre></code>
The result is stored in a unlogged table sl_lop.result . If the the db server crashes or is be restored the  sl_lop.result will gone, so remember to change table to logged (9.5 only) or copy the result to another table.

## Example 4 :Do a analyze of the two tables schema1.municipality and schema3.data1, where the schema1.municipality is suppose to cover all of areas of schema1.data1.

Run the function to get the result, but you change the default number of rows pr cell to 100. Since this layer has a low density we only want 100 rows pr cell. In some cases we see that reducing the cell size do reduce that chance of topology exceptions.

<pre><code>select get_esri_union('schema1.data1 sl_sdeid geo', 'schema1.municipality sl_sdeid geo','schema3.municipality_data1',100);</pre></code>
 
(You need write access to schema3.municipality_data1 and it can not exist from before. If you don't have write set the name to null like this and you get a temp table back, but that table will be gone when you leave your psql session.

<pre><code>select get_esri_union('schema1.data1 sl_sdeid geo', 'schema1.municipality sl_sdeid geo',null,100);</pre></code>

Get area grouped by column komid from schema1.municipality for all the rows in schema1.data1

<pre><code>select * from (
select t2_komid, Sum(ST_Area(ST_transform(geom,3035))) as m2 from schema3.municipality_data1 where t1_sl_sdeid is not null group by t2_komid
) as r order by t2_komid desc;
</pre></code>

In the result below we see that are rows where t2_komid is null. 
<pre><code>
 t2_komid |        m2        
----------+------------------
   [NULL] | 154181279.621773
     2030 | 19332444.5574537
     2027 | 252377877.535185
     2025 | 1020569592.49986
     2024 | 45542291.4551781
     2020 | 390228154.928155
     2015 | 26485.4287747904
     2014 | 43330957.1494888
     2012 | 817415562.691178
.
</pre></code>

Then you can zoom to this rows or download rows to check them out.

<pre><code>pgsql2shp -f data -h  dbserver -u user -P password dbname "select * from schema3.municipality_data1 where t2_komid is null"</pre></code>


# How to install :
<pre><code> 
git clone https://github.com/larsop/content_balanced_grid
cat content_balanced_grid/func_grid/functions_*.sql | psql 
git clone https://github.com/larsop/esri_union.git
cat ../esri_union/src/main/sql/function_0*.sql | psql
</pre></code>

# Some limitations/features :
* Tested with Postgres 9.3 and above. (We use some JSON feature)
* Testet with srid 4258 (degrees) and 25833 (meter)
* Both layers must has the same projection. (To avoid to take a copy of the tables)
* Both layers must contain rows
* Return a temp table or a unlogged table. (To avoid to create tons of wall files. If the result is suppose be kept for later do “create table as” for temp tables or in Postgres 9.5 do alter table if unlogged.)
* If the same logged in user runs this function at the same against the same table we seems to block that resolved after a while.
* Runs default in one single thread (Almost the same code also works with multiple threads and you can the run many times a fast. How to do work in parallel will be added to the repo later. In parallel mode we can handle thousands of surfaces pr. second )


# How it works in more details :

* Fist we have to create grid that has cells that varies with the map density. If there are many polygons in one area, this area will get small cells in in areas with no polygons the will verry big cell. This is done by using the using the code from https://github.com/larsop/content_balanced_grid. 
* The default number off rows pr cell is 3000. The number of polygons pr. cell depends on much memory you have and the density of points. In some cases we see that reducing the cell size do reduce that chance of topology exceptions.
* We can now divide an conquer and work us through cell by cell. (We can also work on each cell i parallel if needed)
* In each cell the followings happens
    * Get the content from both layers for the current cell
    * Find all intersection between selected rows from table one and two
    * Find rows from table one - minus area that are covered by table two
    * Find rows from table two - minus area that are covered by table one
    * Find rows from table one that are not added yet
    * Find rows from table two that are not added yet
* When all cells are done remove grid lines from the result (this work may be done in parallel but is now done in one single operation)

 

# Todo :
* Add tests 
* Compute geometry and primary column on the fly
* Take sql with where conditions as input and not tables
* Add the code for running parallel
* Remove grid lines in parallel
* Return empty areas for instance if you create map with full coverage (this is quite easy to do since we split up data in cells).
* Create coverage maps for different scales (this is also quite easy to do since we split data up into cells)  
