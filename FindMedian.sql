WITH cteTestData AS (
	SELECT *
	FROM (VALUES (1), (19), (12), (8), (NULL)) z (val)
	WHERE z.val IS NOT NULL
)
SELECT MAX(val) FROM (
	SELECT top 51 PERCENT val 
	FROM cteTestData
	ORDER BY val
) Y



;WITH cteTestData AS (
	SELECT *
	FROM (VALUES (1, 19, 12, 8, CAST(NULL as int))) z (valA, valB, valC, valD, valE)
)
, cteUnpivoted AS (
	SELECT val
	FROM cteTestData
	UNPIVOT (
		val FOR columnName IN (valA, valB, valC, valD, valE)
	) as unpiv
)
SELECT MAX(val) FROM (
	SELECT top 51 PERCENT val 
	FROM cteUnpivoted
	ORDER BY val
) Y
