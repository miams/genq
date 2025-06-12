/*  RM-10 person-tree extractor
    :starting   – focus PersonID (RIN)
    :max_depth  – generations to crawl (0-3)
*/

WITH RECURSIVE rels(from_id, to_id, rel_code, depth) AS (

  /* seed row (the focus person) */
  SELECT :starting, :starting, 'self', 0

  /* PARENTS ------------------------------------------------------------- */
  UNION ALL
  SELECT r.to_id, f.FatherID, 'parent', r.depth + 1
  FROM rels r
  JOIN ChildTable  c ON c.ChildID  = r.to_id
  JOIN FamilyTable f ON f.FamilyID = c.FamilyID
  WHERE f.FatherID IS NOT NULL
        AND r.depth < :max_depth

  UNION ALL
  SELECT r.to_id, f.MotherID, 'parent', r.depth + 1
  FROM rels r
  JOIN ChildTable  c ON c.ChildID  = r.to_id
  JOIN FamilyTable f ON f.FamilyID = c.FamilyID
  WHERE f.MotherID IS NOT NULL
        AND r.depth < :max_depth

  /* CHILDREN ------------------------------------------------------------ */
  UNION ALL
  SELECT r.to_id, c.ChildID, 'child', r.depth + 1
  FROM rels r
  JOIN FamilyTable f
         ON (f.FatherID = r.to_id OR f.MotherID = r.to_id)
  JOIN ChildTable  c ON c.FamilyID = f.FamilyID
  WHERE r.depth < :max_depth
        AND c.ChildID <> r.to_id            -- avoid self-loops

  /* SPOUSES ------------------------------------------------------------- */
  UNION ALL
  SELECT r.to_id,
         CASE WHEN f.FatherID = r.to_id THEN f.MotherID
              ELSE f.FatherID END,
         'spouse',
         r.depth + 1
  FROM rels r
  JOIN FamilyTable f
         ON (f.FatherID = r.to_id OR f.MotherID = r.to_id)
  WHERE r.depth < :max_depth
)

SELECT  r.to_id        AS PersonID,
        r.rel_code     AS RelCode,
        r.depth        AS GenDepth,
        n.Surname,
        n.Given,
        n.BirthYear,   -- quick display years
        n.DeathYear,
        p.Sex
FROM    rels r
JOIN    PersonTable p ON p.PersonID = r.to_id
JOIN    NameTable   n ON n.OwnerID  = r.to_id
                       AND n.IsPrimary = 1
ORDER BY r.depth, n.Surname COLLATE NOCASE, n.Given COLLATE NOCASE;
