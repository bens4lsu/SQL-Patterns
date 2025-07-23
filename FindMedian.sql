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
