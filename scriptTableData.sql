

CREATE OR ALTER PROCEDURE dbo.scriptTableData (
	@tableName nvarchar(400),
	@schemaName nvarchar(100) ='dbo',
	@includeUpdate bit = 1,
	@includeDelete bit = 0,
	@rowLimit int = NULL

	-- Future:
	-- @whereClause @nvarchar(max) = NULL

)
AS
BEGIN

	/**************************************************************************************************************************/
	/*                                                                                                                        */
	/*  2021-06-07 - Ben Schultz - Intial version of procedure.                                                               */
	/*                                                                                                                        */
	/*                             Usage:                                                                                     */
	/*                                                                                                                        */
	/*                                EXEC scriptTableData 'MyTable', 'dbo', 1, 1, null                                       */
	/*                                                                                                                        */
	/*                                Parameters 1 & 2, table name and schema name:  for the table whose data you want to     */
	/*                                    export.                                                                             */
	/*                                                                                                                        */
	/*                                Parameter 3, @includeUpdate:  if the target table already has a row with the key for    */
	/*                                    a particular row, this flag tells the script whether or not to update that row so   */
	/*                                    that all of the columns match.                                                      */
	/*                                                                                                                        */
    /*                                Parameter 4, @includeDelete:  if the target table has a row with a primary key isn't in */
    /*                                    the source data, this flag indicates whether that row should be deleted or not.     */
    /*	                                                                                                                      */
    /*                                Parameter 5, @rowLimit:  will add a "TOP X" to the selection, so that you can just      */
    /*                                    grab a subset of the source data.                                                   */
	/*                                                                                                                        */
	/*                                If the output record is particularly long (either many columns, many rows, or just big  */
	/*                                data in a column, you may have cut off results when you run from SSMS. You can still    */
	/*                                get the result set using bcp.  The syntax from a command or powershell prompt is:       */
	/*                                                                                                                        */
	/*                                bcp "scriptTableData 'MyTable', DEFAULT, DEFAULT, 1, DEFAULT" queryout                  */
	/*                                    "OUTPUT_FILE_NAME.TXT" -c -S "SERVER_NAME" -d "DATABASE_NAME" -T -e                 */
	/*                                    "ERROR_FILE_NAME.TXT" -q                                                            */
	/*                                                                                                                        */
    /*                               The part that runs is this procedure call:                                               */
	/*                                                                                                                        */
	/*                                                                                                                        */
	/**************************************************************************************************************************/

	SET NOCOUNT ON

	DECLARE @crlf nchar(2) = char(13) + char(10),
		@tab nvarchar(200),
		@colList nvarchar(max),
		@colListEq nvarchar(max),
		@colListPrefxd nvarchar(max),
		@colListEqAll nvarchar(max),
		@colListMerge nvarchar(max),
		@colListPK nvarchar(max),
		@dsql nvarchar(max),
		@res nvarchar(max),
		@out nvarchar(max) = '',
		@hasIdentity tinyint,
		@rowLimitText nvarchar(20)


	SELECT @tab = '[' + @schemaName + '].[' + @tableName + ']',
		@rowLimitText = CASE WHEN @rowLimit IS NULL OR @rowLimit < 1 THEN '' ELSE 'TOP ' + CAST(@rowLimit AS nvarchar(20)) END


	--------------------------------------------------------------------------------------------------------------
	-- 1.  SET IDENTITY_INSERT where applicable

	SELECT @hasIdentity = MAX(CAST(c.is_identity AS tinyint)) 
	FROM sys.columns c 
		JOIN sys.objects o ON c.object_id = o.OBJECT_ID 
	WHERE o.name = @tableName AND o.schema_id = SCHEMA_ID(@schemaName)


	IF @hasIdentity = 1
		SELECT @out = @out + 'SET IDENTITY_INSERT ' + @tab + ' ON' + @crlf + 'GO' + REPLICATE(@crlf, 2)
		


	--------------------------------------------------------------------------------------------------------------
	-- 2.  Create all of the column lists that we're going to need.

	;WITH cteColumns AS (
		SELECT c.name AS ColName
			, c.column_id
			, MAX(ISNULL(CAST(i.is_primary_key AS TINYINT), 0)) AS is_primary_key
		FROM sys.columns c 
			JOIN sys.objects o ON c.object_id = o.object_id 
			LEFT OUTER JOIN sys.index_columns ic  ON c.object_id = ic.object_id AND c.column_id = ic.column_id
			LEFT OUTER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
		WHERE o.name = @tableName
		GROUP BY c.name, c.column_id
	)
	
	, cteCol(list) AS (
		SELECT SUBSTRING(
			(SELECT ', ' + ColName [text()]
			 FROM cteColumns  
			 ORDER BY column_id
			 FOR XML PATH('') 
		), 3, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)

	, cteColRepl(list) AS (
		SELECT SUBSTRING(
			(SELECT  ' + ISNULL('''''''' + (REPLACE(' + ColName + ', '''''''', '''''''''''')) + '''''''', ''null'') + '', '' ' [text()]
			 FROM cteColumns 
			 ORDER BY column_id
			 FOR XML PATH('') 
		), 3, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)

	, cteColSel(list) AS (
		SELECT ''''' + CAST(' + ColName + ' AS nvarchar) + '''''''' + '', ''' [text()]
		FROM cteColumns 
		ORDER BY column_id
		FOR XML PATH('') 
	)

	, cteColEq(list) AS (
		SELECT  't.' + ColName + ' = c.' + ColName + ' AND ' [text()]
		FROM cteColumns  
		WHERE is_primary_key = 1
		ORDER BY column_id
		FOR XML PATH('') 
	)

	, cteColPk(list) AS (
		SELECT  ColName + ', ' [text()]
		FROM cteColumns  
		WHERE is_primary_key = 1
		ORDER BY column_id
		FOR XML PATH('') 
	)

	, cteColEqAll(list) AS (
		SELECT  't.' + ColName + ' = c.' + ColName + ' , ' [text()]
		FROM cteColumns  
		WHERE is_primary_key = 0 
		ORDER BY column_id
		FOR XML PATH('') 
	)

	, cteColMerge(list) AS (
		SELECT  ColName + ' nvarchar(1000) , ' [text()]
		FROM cteColumns  
		ORDER BY column_id
		FOR XML PATH('') 
	)


	SELECT 
		@dsql = 'INSERT #tmpCol(txt) SELECT ''('' + ' + @rowLimitText + SUBSTRING(c4.list, 0, LEN(c4.list) - 2 ) + ')'' AS txt FROM ' + @tab 
		, @colList = c2.list
		, @colListEq = SUBSTRING(c3.list, 0, LEN(c3.list) - 3)
		, @colListPrefxd = 'c.' + REPLACE(@colList, ', ', ', c.')
		, @colListEqAll = SUBSTRING(c5.list, 0, LEN(c5.list) - 1)
		, @colListMerge = c6.list + ' CONSTRAINT tmpPK_' + REPLACE(CAST(NEWID() AS NVARCHAR(MAX)), '-', '_') + ' PRIMARY KEY (' + SUBSTRING(c7.list, 0, LEN(c7.list) - 0) + ')'
	FROM cteColSel c1, cteCol c2,  cteColEq c3, cteColRepl c4, cteColEqAll c5, cteColMerge c6, cteColPk c7

	CREATE TABLE #tmpCol (txt nvarchar(max))

	EXEC sp_executesql @dsql


	
	--------------------------------------------------------------------------------------------------------------
	-- 3.  Insert part of our MERGE Statement.

	SELECT @out = @out + REPLICATE(@crlf, 2) +
		'CREATE TABLE #tmpMerge (' + @colListMerge + ')'  + REPLICATE(@crlf, 2)

	;WITH cteAlmost(list) AS (
		SELECT SUBSTRING(
			(SELECT  @crlf + ', ' + txt [text()]
			 FROM #tmpCol  
			 FOR XML PATH('') 
		), 9, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)

	SELECT @out = @out + 'INSERT #tmpMerge SELECT * FROM (VALUES ' + @crlf 
		+ REPLACE(REPLACE(list, '&#x0D;', ''), '&amp;' , '') + @crlf 
		+ ') x (' + @colList + ') ' + REPLICATE(@crlf, 2)
	FROM cteAlmost

	
	SELECT @out = @out + '
		MERGE ' + @tab + ' t USING #tmpMerge c ON(' + @colListEq + ')
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (' + @colList + ')
		VALUES (' + @colListPrefxd + ')' + @crlf


	--------------------------------------------------------------------------------------------------------------
	-- 4. Make the INSERT part of the MERGE statement

	IF ISNULL(@includeUpdate, 0) = 1
	BEGIN
		SELECT @out = @out + '
			WHEN MATCHED THEN UPDATE 
			SET ' +  @colListEqAll + @crlf
	END


	--------------------------------------------------------------------------------------------------------------
	-- 5. Make the DELETE part of the MERGE statement

	IF ISNULL(@includeDelete, 0) = 1
	BEGIN
		SELECT @out = @out + '
			WHEN NOT MATCHED BY SOURCE THEN 
				DELETE
		'
	END

	--------------------------------------------------------------------------------------------------------------
	-- 6. Clean up and Output

	SELECT @out = @out + ';' + REPLICATE(@crlf, 2) + 'DROP TABLE #tmpMerge' 

	SELECT @out

END

GO
