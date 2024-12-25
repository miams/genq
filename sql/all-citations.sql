-- AllCitations RM8 version-CTE format.sql
/*

rev 20241225 miams 
- source from: https://sqlitetoolsforrootsmagic.com/wp-content/uploads/2022/04/AllCitations-RM8.sql
- added COLLATE NOCASE to all necessary fields to make compatible with nushell

rev 20220427 ve3meo
- Added CitationLinkTable.LinkID and ALL to UNIONs to reveal duplicate "uses" of a Citation
- other minor changes
- observed that this query does not report 'headless' citations (lacking a Master Source), unused Sources,
 unused Citations, broken CitationLinks  
*/

With Cit8 as
(Select c.CitationID, cl.LinkID, cl.OwnerType, cl.OwnerID, c.SourceID, cl.Quality, cl.IsPrivate, c.Comments, c.ActualText, c.RefNumber, cl.Flags, c.Fields
from CitationTable c LEFT OUTER JOIN CitationLinkTable cl --20220427 was INNER, but no apparent diff
USING (CitationID)) --20220427 was ON c.CitationID = cl.CitationID) but no apparent diff

,tmpCitations AS
(
SELECT  c.LinkiD, c.CITATIONID AS CitID, c.sourceid AS SrcID, n.ownerid AS RIN, n.IsPrimary AS Uniq, n.surname COLLATE NOCASE AS Surname, 
n.suffix COLLATE NOCASE AS Sfx, n.prefix COLLATE NOCASE AS Pfx, n.given COLLATE NOCASE AS Givens, n.birthyear AS Born, 
  n.deathyear AS Died, 'Personal' AS Citer, s.NAME COLLATE NOCASE AS Source, s.refnumber AS SrcREFN, s.actualtext AS SrcTxt, s.comments AS SrcComment, c.refnumber AS CitREFN, 
  QUOTE(c.actualtext) AS CitTxt, QUOTE(c.comments) AS CitComment
FROM  Cit8 c 
  LEFT OUTER JOIN sourcetable s ON c.sourceid=s.sourceid 
  LEFT OUTER JOIN persontable p ON c.ownerid=p.personid 
  LEFT OUTER JOIN  nametable n ON p.personid=n.ownerid
WHERE  c.ownertype=0 AND +n.IsPrimary=1

UNION ALL
-- all Fact citations for Individual
SELECT  c.LinkiD, c.CITATIONID, c.sourceid AS SrcID, n.ownerid AS RIN, n.IsPrimary, n.surname COLLATE NOCASE, n.suffix COLLATE NOCASE, n.prefix COLLATE NOCASE, n.given COLLATE NOCASE, n.birthyear, 
  n.deathyear, f.NAME COLLATE NOCASE AS Citer, s.NAME COLLATE NOCASE , s.refnumber, s.actualtext, s.comments, c.refnumber, 
  c.actualtext, c.comments
FROM  Cit8 c
  LEFT OUTER JOIN sourcetable s ON c.sourceid=s.sourceid
  LEFT OUTER JOIN eventtable e ON c.ownerid=e.eventid
  LEFT OUTER JOIN persontable p ON e.ownerid=p.personid
  LEFT OUTER JOIN nametable n ON p.personid=n.ownerid
  LEFT OUTER JOIN facttypetable f ON e.eventtype=f.facttypeid
WHERE c.ownertype=2 AND e.ownertype=0 AND f.ownertype=0 AND +n.IsPrimary=1 


UNION ALL
-- all Spouse citations for Father|Husband|Partner 1
SELECT  c.LinkiD, c.CITATIONID, c.sourceid AS SrcID, n.ownerid AS RIN, n.IsPrimary, n.surname COLLATE NOCASE, n.suffix COLLATE NOCASE, n.prefix COLLATE NOCASE, n.given COLLATE NOCASE, n.birthyear, 
  n.deathyear, 'Spouse' as 'Citer', s.NAME COLLATE NOCASE, s.refnumber, s.actualtext, s.comments, c.refnumber, 
  c.actualtext, c.comments
FROM  Cit8 c
  LEFT OUTER JOIN sourcetable s ON c.sourceid=s.sourceid 
  LEFT OUTER JOIN familytable fm ON c.ownerid=fm.FamilyID
  LEFT OUTER JOIN persontable p ON fm.fatherid=p.personid
  LEFT OUTER JOIN nametable n ON p.personid=n.ownerid
--  LEFT OUTER JOIN eventtable e ON e.ownerid=fm.familyid
--  LEFT OUTER JOIN facttypetable f ON e.eventtype=f.facttypeid
WHERE c.ownertype=1 -- AND e.ownertype=1 AND f.ownertype=1 
AND +n.IsPrimary=1


UNION ALL
-- all Couple Event citations for Father|Husband|Partner 1
SELECT  c.LinkiD, c.CITATIONID, c.sourceid AS SrcID, n.ownerid AS RIN, n.IsPrimary, n.surname, n.suffix COLLATE NOCASE, n.prefix COLLATE NOCASE, n.given COLLATE NOCASE, n.birthyear, 
  n.deathyear, f.NAME COLLATE NOCASE, s.NAME COLLATE NOCASE, s.refnumber, s.actualtext, s.comments, c.refnumber, 
  c.actualtext, c.comments
FROM  Cit8 c
  LEFT OUTER JOIN sourcetable s ON c.sourceid=s.sourceid 
  LEFT OUTER JOIN eventtable e ON e.eventid=c.ownerid
  LEFT OUTER JOIN familytable fm ON e.ownerid=fm.familyID
  LEFT OUTER JOIN persontable p ON fm.fatherid=p.personid
  LEFT OUTER JOIN nametable n ON p.personid=n.ownerid
  LEFT OUTER JOIN facttypetable f ON e.eventtype=f.facttypeid
WHERE c.ownertype=2 AND e.ownertype=1 AND f.ownertype=1 AND n.IsPrimary=1


UNION ALL
-- Citations for Alternate Names 
SELECT  c.LinkiD, c.CITATIONID, c.sourceid AS SrcID, n.ownerid AS RIN, NOT n.IsPrimary, n.surname, n.suffix COLLATE NOCASE, n.prefix COLLATE NOCASE, n.given COLLATE NOCASE, n.birthyear, 
  n.deathyear, 'Alternate Name' AS Citer, s.NAME AS Source, s.refnumber, s.actualtext, s.comments, c.refnumber, 
  c.actualtext, c.comments 
FROM  Cit8 c 
  LEFT OUTER JOIN sourcetable s ON c.sourceid=s.sourceid 
  LEFT OUTER JOIN  nametable n ON n.nameid=c.ownerid
WHERE  c.ownertype=7  AND +n.IsPrimary=0
)
 

-- Now filter the results to get rid of duplicate citation IDs due Alt Names
SELECT LinkID, CitID, SrcID, RIN, Uniq, Surname, Sfx, Pfx, Givens, Born, 
  Died, Citer, Source, SrcREFN, SrcTxt, SrcComment, CitREFN, 
  CitTxt, CitComment --, MM.MediaID, MM.MediaPath, MM.MediaFile, MM.Caption, MM.RefNumber
FROM tmpcitations t 
   --LEFT JOIN  MediaLinkTable AS ML 
	-- ON t.CITID = ML.OWNERID AND ML.OWNERTYPE = 4
	-- LEFT JOIN MultiMediaTable AS MM 
	-- ON ML.MediaID = MM.MediaID
WHERE uniq=1 OR uniq ISNULL --20220427 no apparent diff with this constraint
ORDER BY RIN, Citer , SOURCE
;

-- CitID
-- RIN, Citer;
-- END 