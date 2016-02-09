# What is this

This is a generic Postgres function that is does a “Esri union” between two polygon layers in a postgis database. More info about Esri union can be found at http://resources.esri.com/help/9.3/arcgisengine/java/gp_toolref/analysis_tools/union_analysis_.htm.

The basic idea is that you call this function and with 2 tables as input. Build a grid to split up the data, compute the result and return a table name with a union of this two tables. For areas that intersect you get attributes from both tables and for areas that only exits in one of the tables you only get attributes from one table.

# How to use :
For each table we need the following information as input 
* table name
* primary key column name (supports only a single column, could have been been computed in the code. The primary key is used to remove grid lines after the result is done.)
* geometry column name (can be computed in the code)

## Example 1 : Returns a tmp table
run the function  get_esri_union with 2 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo')"; </pre></code>
The result is stored in temp table esri_union_result. To keep the result when you get back to sql
<pre><code> CREATE TABLE sl_lop.result1 AS SELECT * FROM  esri_union_result; </pre></code>

## Example 2 : Return a unlogged table with given name
run the function  get_esri_union with 3 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo','sl_lop.result')"; </pre></code>
The result is stored in a unlogged table sl_lop.result . If the the db server crashes or is be restored the  sl_lop.result will gone, so remember to change table to logged (9.5 only) or copy the result to another table.

## Example 3 : Return a unlogged table, but use bigger cells
run the function  get_esri_union with 4 parameters
<pre><code> select get_esri_union('table_1 id geo', 'table_2 objectid geo','sl_lop.result',5000)"; </pre></code>
The result is stored in a unlogged table sl_lop.result . If the the db server crashes or is be restored the  sl_lop.result will gone, so remember to change table to logged (9.5 only) or copy the result to another table.

# How to install :
<pre><code> 
git clone https://github.com/larsop/content_balanced_grid
cat content_balanced_grid/func_grid/functions_*.sql | psql 
git clone https://github.com/larsop/esri_union.git
cat ../esri_union/src/main/sql/function_0*.sql | psql
</pre></code>

# Some limitations/features :
Tested with Postgres 9.3 and above. (We use some JSON feature)
Both layers must has the same projection. (To avoid to take a copy of the tables)
Return a temp table or a unlogged table. (To avoid to create tons of wall files. If the result is suppose be kept for later do “create table as” for temp tables or in Postgres 9.5 do alter table if unlogged.)
Runs default in one single thread (Almost the same code also works with multiple threads and you can the run many times a fast. How to do work in parallel will be added to the repo later. In parallel mode we can handle thousands of surfaces pr. second )


# How it works in more details :

* Fist we have to create grid that has cells that varies with the map density. If there are many polygons in one area, this area will get small cells in in areas with no polygons the will verry big cell. This is done by using the using the code from https://github.com/larsop/content_balanced_grid . The default number off rows pr cell is 3000. 
We can now divide an conquer and work us through cell by cell. (We can also work on each cell i parallel if needed)
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

