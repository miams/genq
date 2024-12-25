SELECT   
-- AllFacts4Person#.sql romermb's incredible combination of events, shared events plus 'marriage' and alternate names as Facts 
-- 1 2010-01-06 original
-- 2 2010-01-06 rev by ve3meo to bring out RoleName from RoleTableand Sharee's Names from NameTable, tried to speed up using UNION ALL
--    - not much gain - still ~270 secs on a 50,000 event, 16,000 person table.
-- 3 2010-01-07 rev by romermb to incorporate COUNT, GROUP BY
-- #4 2010-01-11 rev by ve3meo for 80 to 1 speedup using index idxNameOwnerID- now 3sec using SQLiteSpy but wont run on SQLiteman, 
--    DBManager et al that use old SQLite releases. Runs on SQLiteSpy (fastest) and SQLite Developer (most useful results)
-- #5 2010-01-12 rev by ve3meo for more explicit control over indexing after running ANALYZE caused execution time to skyrocket 
--    from <3s to 190s.. sqlites auto query optimisation changed order and selected less appropriate indexes for prior rev after ANALYZE.
-- #6 2010-01-14 rev by ve3meo to add births of children as facts for parents
-- #7 2010-01-14 rev by ve3meo redesigned to eliminate INNER JOINS and INDEXED clauses to achieve high speed with auto query optimisation
--    and to run on older versions of sqlite3 (SQLiteman, DBManager...)
-- #8 2010-01-16 rev by ve3meo #7 failed to achieve the desired result without the use of INDEXED clauses.. replaced the queries to 
--    add Family facts to the Husband and Wife by a process that builds a temporary table which is then queried to get the Family facts 
--    per partner of a couple. Blazingly fast (<4s for ~72500 records out) but some managers cannot keep up with sqlite3. SQLiteSpy and 
--    DBManager succeed. Others throw errors requiring the temporary table to be built in one pass, the queries for the results in a second.
--    Rearranged column order to put Fact and Role Type in middle.
-- #9 2010-01-21 rev by ve3meo - added core of DateDecoder.sql to add dates for events and SortDate for sorting
-- #10 2010-03-08 rev by ve3meo - made compatible with OpenOffice Base and probably other SQLite managers that could not keep up with
--    SQLite temp table creation - now one long series of SELECT ... UNION ALL ... SELECT ... i.e., one
--    SQL command eliminating temp tables, moved comments to after 1st SELECT.., eliminated semi-colons and single quote marks or apostrophes
--    from comments, used +IsPrimary in WHERE to prevent SQLite query optimiser
--    from choosing slow index.
-- #11 2010-03-08 rev bt ve3meo - concatenated names and add Treeless witnesses
--------------------------------

-- Husband as Principal in Couple events
  Nametable1.Ownerid COLLATE binary AS  RIN , 
  UPPER(Nametable1.Surname) COLLATE Nocase ||' '|| 
    Nametable1.Suffix COLLATE Nocase ||', '||  
    Nametable1.Prefix COLLATE Nocase ||' '||  
    Nametable1.Given COLLATE Nocase AS 'Principal',  
  'Partner' AS 'Role Type' , 
  Facttypetable.Name COLLATE Nocase AS Fact , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
  END AS Date,
  Nametable2.Ownerid COLLATE binary AS 'Sharer RIN' , 
  UPPER(Nametable2.Surname) COLLATE Nocase ||' '|| 
  Nametable2.Suffix COLLATE Nocase ||', '||  
  Nametable2.Prefix COLLATE Nocase ||' '||  
  Nametable2.Given COLLATE Nocase AS 'Sharer',
  COUNT(1) AS Count,
  E.SortDate 


FROM 
  Eventtable E, 
  Familytable , 
  Nametable AS Nametable1 , 
  Nametable AS Nametable2 , 
  Facttypetable  
WHERE 
  E.Ownertype = 1 AND 
  E.Ownerid = Familytable.Familyid AND 
  Familytable.Fatherid = Nametable1.Ownerid AND 
  Familytable.Motherid = Nametable2.Ownerid AND 
  E.Eventtype = Facttypetable.Facttypeid AND
  +Nametable1.IsPrimary=1 AND
  +Nametable2.IsPrimary=1 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL

SELECT   
-- Wife as Principal in Couple events
  Nametable2.Ownerid COLLATE binary AS RIN  , 
  UPPER(Nametable2.Surname) COLLATE Nocase ||' '|| 
  Nametable2.Suffix COLLATE Nocase ||', '||  
  Nametable2.Prefix COLLATE Nocase ||' '||  
  Nametable2.Given COLLATE Nocase AS 'Wife',
  'Partner' AS 'Role Type' , 
  Facttypetable.Name COLLATE Nocase AS Fact , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
  END AS Date,
  Nametable1.Ownerid COLLATE binary AS 'Sharer RIN' , 
  UPPER(Nametable1.Surname) COLLATE Nocase ||' '|| 
    Nametable1.Suffix COLLATE Nocase ||', '||  
    Nametable1.Prefix COLLATE Nocase ||' '||  
    Nametable1.Given COLLATE Nocase AS Sharer,  
  COUNT(1) AS Count,
  E.SortDate 


FROM 
  Eventtable E, 
  Familytable , 
  Nametable AS Nametable1 , 
  Nametable AS Nametable2 , 
  Facttypetable  
WHERE 
  E.Ownertype = 1 AND 
  E.Ownerid = Familytable.Familyid AND 
  Familytable.Fatherid = Nametable1.Ownerid AND 
  Familytable.Motherid = Nametable2.Ownerid AND 
  E.Eventtype = Facttypetable.Facttypeid AND
  +Nametable1.IsPrimary=1 AND
  +Nametable2.IsPrimary=1 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL

SELECT 
-- add all events for Individual
  Nametable.Ownerid , 
  UPPER(Nametable.Surname) COLLATE Nocase ||' '|| 
  Nametable.Suffix COLLATE Nocase ||', '||  
  Nametable.Prefix COLLATE Nocase ||' '||  
  Nametable.Given COLLATE Nocase AS 'Individual',
  'Principal' , 
  Facttypetable.Name COLLATE Nocase , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
END AS Date ,
  NULL , 
  NULL , 
  Count( 1 ),
  E.SortDate AS 'SortDate' 
 
FROM 
  Eventtable AS E, 
  Nametable ,
  Facttypetable  
WHERE 
  E.Ownertype = 0 AND 
  E.Ownerid = Nametable.Ownerid AND 
  E.Eventtype = Facttypetable.Facttypeid AND 
  +Nametable.Isprimary = 1 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL

SELECT
-- add Alternate Name as a Fact
  Ownerid , 
  UPPER(Surname) COLLATE Nocase ||' '|| 
  Suffix COLLATE Nocase ||', '||  
  Prefix COLLATE Nocase ||' '||  
  Given COLLATE Nocase , 
  'Principal' , 
  'Alternate name' , 
  NULL , 
  NULL , 
  NULL , 
  Count( 1 ),
  NULL 
 
FROM 
  Nametable 
WHERE 
  +Isprimary = 0 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL

SELECT 
-- add shared events from WitnessTable other than couple events as Facts 
-- revised by ve3meo to bring out RoleName from RoleTable and Sharer Names from NameTable
  Nametable2.Ownerid , 
-- to bring out Treeless witnesses
  CASE W.PersonID   
  WHEN 0 THEN
  UPPER(W.Surname) COLLATE Nocase ||' '|| 
    W.Suffix COLLATE Nocase ||', '||  
    W.Prefix COLLATE Nocase ||' '||  
    W.Given COLLATE Nocase  
  ELSE
  UPPER(Nametable2.Surname) COLLATE Nocase ||' '|| 
    Nametable2.Suffix COLLATE Nocase ||', '||  
    Nametable2.Prefix COLLATE Nocase ||' '||  
    Nametable2.Given COLLATE Nocase
  END AS Principal,  
  Rolename COLLATE Nocase , 
  Facttypetable.Name COLLATE Nocase , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
  END AS Date ,
  E.Ownerid AS 'Sharer RIN', 
  UPPER(Nametable1.Surname) COLLATE Nocase ||' '|| 
    Nametable1.Suffix COLLATE Nocase ||', '||  
    Nametable1.Prefix COLLATE Nocase ||' '||  
    Nametable1.Given COLLATE Nocase   
    AS 'Sharer Name',
--  Nametable2.Surname COLLATE Nocase , 
--  Nametable2.Suffix COLLATE Nocase , 
--  Nametable2.Prefix COLLATE Nocase , 
--  Nametable2.Given COLLATE Nocase , 
  Count( 1 ),
  E.SortDate 
FROM 
  Eventtable AS E, 
  Witnesstable AS W, 
  Roletable , 
  Facttypetable , 
  Nametable AS Nametable1  
  LEFT JOIN  Nametable AS Nametable2 ON  W.Personid = Nametable2.Ownerid AND +NameTable2.isprimary = 1
WHERE 
  W.Eventid = E.Eventid AND 
  W.Role = Roletable.Roleid AND 
  E.Eventtype = Facttypetable.Facttypeid AND 
  E.Ownerid = Nametable1.Ownerid AND 
  E.OwnerType = 0 AND
  +Nametable1.Isprimary = 1 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL

SELECT 
-- add shared events from WitnessTable for couple events as Facts 
  Nametable.OWNERID , 
-- to bring out Treeless witnesses
  CASE W.PersonID   
  WHEN 0 THEN
  UPPER(W.Surname) COLLATE Nocase ||' '|| 
    W.Suffix COLLATE Nocase ||', '||  
    W.Prefix COLLATE Nocase ||' '||  
    W.Given COLLATE Nocase  
  ELSE
  UPPER(Nametable.Surname) COLLATE Nocase ||' '|| 
    Nametable.Suffix COLLATE Nocase ||', '||  
    Nametable.Prefix COLLATE Nocase ||' '||  
    Nametable.Given COLLATE Nocase
  END AS Principal,  
  Rolename COLLATE Nocase , 
  Facttypetable.Name COLLATE Nocase , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
  END AS Date ,
  Fam.FamilyID AS 'Sharer RIN', 
  UPPER(Nametable1.Surname) COLLATE Nocase ||' '|| 
    Nametable1.Suffix COLLATE Nocase ||', '||  
    Nametable1.Prefix COLLATE Nocase ||' '||  
    Nametable1.Given COLLATE Nocase
    ||' & '||   
  UPPER(Nametable2.Surname) COLLATE Nocase ||' '|| 
    Nametable2.Suffix COLLATE Nocase ||', '|| 
    Nametable2.Prefix COLLATE Nocase ||' '|| 
    Nametable2.Given COLLATE Nocase  
    AS 'Sharer Name',
  Count( 1 ),
  E.SortDate 
FROM 
  Eventtable AS E, 
  Facttypetable ,   
  Witnesstable AS W, 
  Roletable  
  LEFT JOIN  Nametable ON  W.Personid = Nametable.Ownerid AND NameTable.IsPrimary = 1
  LEFT JOIN FamilyTable AS Fam ON
  E.OwnerID = Fam.FamilyID
  LEFT JOIN NameTable AS NameTable1 ON
  Fam.FatherID = NameTable1.OwnerID
  LEFT JOIN NameTable AS NameTable2 ON
  Fam.MotherID = NameTable2.OwnerID
WHERE 
  W.Eventid = E.Eventid AND 
  W.Role = Roletable.Roleid AND 
  E.Eventtype = Facttypetable.Facttypeid AND 
  E.OwnerType = 1 AND
   +Nametable1.Isprimary =1  AND +Nametable2.Isprimary = 1
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL 

SELECT 
-- Add fact for Fathers having children 
  P.Personid AS Rin , 
  UPPER(N.Surname) COLLATE Nocase ||' '|| 
  N.Suffix COLLATE Nocase ||', '|| 
  N.Prefix COLLATE Nocase ||' '|| 
  N.Given COLLATE Nocase AS Principal, 
  'Parent' AS 'role type' , 
  'Fathered' AS Fact , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
END AS Date ,
  C.Childid , 
  UPPER(N2.Surname) COLLATE Nocase ||' '|| 
  N2.Suffix COLLATE Nocase ||', '|| 
  N2.Prefix COLLATE Nocase ||' '|| 
  N2.Given COLLATE Nocase AS 'Child' , 
  Count( 1 ) AS Count,
  E.SortDate 
FROM 
  Persontable P , 
  Nametable N , 
  Familytable F , 
  Childtable C , 
  Nametable N2 , 
  Eventtable E , 
  Facttypetable F2 
WHERE 
  P.Personid = N.Ownerid AND 
  P.Personid = F.Fatherid AND 
  F.Familyid = C.Familyid AND 
  C.Childid = N2.Ownerid AND 
  C.Childid = E.Ownerid AND 
  E.Eventtype = F2.Facttypeid AND 
  F2.Facttypeid = 1 AND 
  +N.Isprimary = 1 AND 
  C.Relfather = 0 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 

UNION ALL 

SELECT 
-- Add fact for Mothers having children
  P.Personid AS Rin , 
  UPPER(N.Surname) COLLATE Nocase ||' '|| 
  N.Suffix COLLATE Nocase ||', '|| 
  N.Prefix COLLATE Nocase ||' '|| 
  N.Given COLLATE Nocase AS Principal, 
  'Parent' AS 'role type' , 
  'Mothered' AS Fact , 
  CASE Substr( E.Date , 1 , 1 )
	WHEN 'Q' THEN E.Date 
	WHEN 'T' THEN Substr( E.Date , 2 ) 
	WHEN 'D' THEN 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'A' THEN 'aft ' 
			WHEN 'B' THEN 'bef ' 
			WHEN 'F' THEN 'from ' 
			WHEN 'I' THEN 'since ' 
			WHEN 'R' THEN 'bet ' 
			WHEN 'S' THEN 'from ' 
			WHEN 'T' THEN 'to ' 
			WHEN 'U' THEN 'until ' 
			WHEN 'Y' THEN 'by ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 13 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 3 , 1 ) = '-' THEN 'BC' ELSE '' END  
		|| 
		CASE WHEN Substr( E.Date , 4 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 4 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 12 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 3 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' AND ( Substr( E.Date , 4 , 4 ) <> '0000' AND Substr( E.Date , 10 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 8 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 8 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 10 , 2 ) , '-00' ) , '' ) 
		|| 
		CASE Substr( E.Date , 2 , 1 ) 
			WHEN 'R' THEN ' and ' 
			WHEN 'S' THEN ' to ' 
			WHEN 'O' THEN ' or ' 
			WHEN '-' THEN ' - ' 
		ELSE '' 
		END 
		|| 
		CASE Substr( E.Date , 24 , 1 ) 
			WHEN 'A' THEN 'abt ' 
			WHEN 'E' THEN 'est ' 
			WHEN 'L' THEN 'calc ' 
			WHEN 'C' THEN 'ca ' 
			WHEN 'S' THEN 'say ' 
			WHEN '6' THEN 'cert ' 
			WHEN '5' THEN 'prob ' 
			WHEN '4' THEN 'poss ' 
			WHEN '3' THEN 'lkly ' 
			WHEN '2' THEN 'appar ' 
			WHEN '1' THEN 'prhps ' 
			WHEN '?' THEN 'maybe ' 
		ELSE '' 
		END 
		|| 
		CASE WHEN Substr( E.Date , 14 , 1 ) = '-' THEN 'BC' ELSE '' END 
		|| 
		CASE WHEN Substr( E.Date , 15 , 4 ) = '0000' THEN '' ELSE Substr( E.Date , 15 , 4 ) END 
		|| 
		CASE WHEN Substr( E.Date , 23 , 1 ) = '/' THEN '/' || ( 1 + Substr( E.Date , 14 , 5 ) ) ELSE '' END 
		|| 
		CASE 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) <> '00' ) THEN '-??' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' AND ( Substr( E.Date , 15 , 4 ) <> '0000' AND Substr( E.Date , 21 , 2 ) == '00' ) THEN '' 
			WHEN Substr( E.Date , 19 , 2 ) = '00' THEN '' 
		ELSE '-' || Substr( E.Date , 19 , 2 ) 
		END 
		|| 
		Coalesce( Nullif( '-' || Substr( E.Date , 21 , 2 ) , '-00' ) , '' ) 
	ELSE '' 
END AS Date ,
  C.Childid , 
  UPPER(N2.Surname) COLLATE Nocase ||' '|| 
  N2.Suffix COLLATE Nocase ||', '|| 
  N2.Prefix COLLATE Nocase ||' '|| 
  N2.Given COLLATE Nocase AS 'Child' , 
  Count( 1 ) AS Count,
  E.SortDate 
FROM 
  Persontable P , 
  Nametable N , 
  Familytable F , 
  Childtable C , 
  Nametable N2 , 
  Eventtable E , 
  Facttypetable F2 
WHERE 
  P.Personid = N.Ownerid AND 
  P.Personid = F.Motherid AND 
  F.Familyid = C.Familyid AND 
  C.Childid = N2.Ownerid AND 
  C.Childid = E.Ownerid AND 
  E.Eventtype = F2.Facttypeid AND 
  F2.Facttypeid = 1 AND 
  +N.Isprimary = 1 AND 
  C.RelMother = 0 
GROUP BY  1 ,  2 ,  3 ,  4 ,  5 ,  6 ,  7 
ORDER BY 
  Rin, SortDate 
  ;