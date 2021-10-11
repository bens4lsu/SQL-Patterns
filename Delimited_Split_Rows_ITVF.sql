

CREATE FUNCTION dbo.Delimited_Split_Rows_ITVF (@pString VARCHAR(MAX), @pDelimiter CHAR(1))
RETURNS TABLE WITH SCHEMABINDING
AS
	RETURN
	WITH E1(N) AS (
		SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
	)
	, E2(N) AS (
		SELECT 1 FROM E1 a, E1 b, E1 c, E1 d, E1 f, E1 g, E1 h
	)
	, cteTally(N) AS (
		SELECT TOP (ISNULL(DATALENGTH(@pString), 0)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
		FROM E2
	)
	, cteStart(N1) AS (
		SELECT 1
		UNION ALL
		SELECT t.N + 1
		FROM cteTally t
		WHERE SUBSTRING(@pString, t.N, 1) = @pDelimiter
	)
	, cteLen (N1, L1) AS (
		SELECT
			s.N1
		   ,ISNULL(NULLIF(CHARINDEX(@pDelimiter, @pString, s.N1), 0) - s.N1, 8000)
		FROM cteStart s
	)
	SELECT
		ItemNumber = ROW_NUMBER() OVER (ORDER BY l.N1)
	   ,Item = SUBSTRING(@pString, l.N1, l.L1)
	FROM cteLen l
;