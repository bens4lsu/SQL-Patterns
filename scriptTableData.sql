

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
	/*                             Usage note:                                                                                */
	/*                                If the output record is particularly long (either many columns, many rows, or just big  */
	/*                                data in a column, you may have cut off results when you run from SSMS. You can still    */
	/*                                get the result set using bcp.  The syntax from a command or powershell prompt is:       */
	/*                                                                                                                        */
	/*                                bcp "scriptTableData 'MyTable', DEFAULT, DEFAULT, 1, DEFAULT" queryout                  */
	/*                                    "OUTPUT_FILE_NAME.TXT" -c -S "SERVER_NAME" -d "DATABASE_NAME" -T -e                 */
	/*                                    "ERROR_FILE_NAME.TXT" -q                                                            */
	/*                                                                                                                        */
	/**************************************************************************************************************************/

	SET NOCOUNT ON

	DECLARE @crlf nchar(2) = char(13) + char(10),
		@tab nvarchar(200),
		@colList nvarchar(max),
		@colListEq nvarchar(max),
		@colListPrefxd nvarchar(max),
		@colListEqAll nvarchar(max),
		@dsql nvarchar(max),
		@res nvarchar(max),
		@out nvarchar(max) = '',
		@hasIdentity tinyint,
		@rowLimitText nvarchar(20)


	SELECT @tab = '[' + @schemaName + '].[' + @tableName + ']',
		@rowLimitText = CASE WHEN @rowLimit IS NULL THEN '' ELSE 'TOP ' + CAST(@rowLimit AS nvarchar(20)) END


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
			, i.is_primary_key
		FROM sys.columns c 
			JOIN sys.objects o ON c.object_id = o.object_id 
			LEFT OUTER JOIN sys.index_columns ic  ON c.object_id = ic.object_id AND c.column_id = ic.column_id
			LEFT OUTER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
		WHERE o.name = @tableName
	)
	
	, cteCol(list) AS (
		SELECT SUBSTRING(
			(SELECT  ', ' + ColName [text()]
			 FROM cteColumns  
			 FOR XML PATH('') 
		), 3, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)

	, cteColRepl(list) AS (
		SELECT SUBSTRING(
			(SELECT  ' + '''''','''''' + REPLACE(' + ColName + ', '''''''', '''''''''''')' [text()]
			 FROM cteColumns  
			 FOR XML PATH('') 
		), 9, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)

	, cteColSel(list) AS (
		SELECT ''''' + CAST(' + ColName + ' AS nvarchar) + '''''''' + '', ''' [text()]
		FROM cteColumns 
		FOR XML PATH('') 
	)

	, cteColEq(list) AS (
		SELECT  't.' + ColName + ' = c.' + ColName + ' AND ' [text()]
		FROM cteColumns  
		WHERE is_primary_key = 1
		FOR XML PATH('') 
	)

	, cteColEqAll(list) AS (
		SELECT  't.' + ColName + ' = c.' + ColName + ' , ' [text()]
		FROM cteColumns  
		WHERE is_primary_key IS NULL 
		FOR XML PATH('') 
	)


	SELECT @dsql = 'INSERT #tmpCol(txt) SELECT ' + @rowLimitText + ' ''( ''' + SUBSTRING(c4.list                       , 0, LEN(c4.list                       ) - 12) + ''''''''', '''''''''''') + '''''')'' AS txt FROM ' + @tab 
--	SELECT @dsql = 'INSERT #tmpCol(txt) SELECT ' + @rowLimitText + ' ''( ''' + SUBSTRING(REPLACE(c1.list, '''', ''''''), 0, LEN(REPLACE(c1.list, '''', '''''')) - 12) + ' + '''''')'' AS txt FROM ' + @tab 
		, @colList = c2.list
		, @colListEq = SUBSTRING(c3.list, 0, LEN(c3.list) - 3)
		, @colListPrefxd = 'c.' + REPLACE(@colList, ', ', ', c.')
		, @colListEqAll = SUBSTRING(c5.list, 0, LEN(c5.list) - 1)
	FROM cteColSel c1, cteCol c2,  cteColEq c3, cteColRepl c4, cteColEqAll c5

	-- SELECT @dsql

	CREATE TABLE #tmpCol (txt nvarchar(max))

	EXEC sp_executesql @dsql


	
	--------------------------------------------------------------------------------------------------------------
	-- 3.  Insert part of our MERGE Statement.

	;WITH cteAlmost(list) AS (
		SELECT SUBSTRING(
			(SELECT  @crlf + ', ' + txt [text()]
			 FROM #tmpCol  
			 FOR XML PATH('') 
		), 9, 1000000000)  -- SUBSTRING knocks off the ', ' that comes before the very first row.
	)
	SELECT @out = @out + 'WITH cteMerge  AS ( SELECT * FROM (VALUES ' + @crlf 
		+ REPLACE(REPLACE(list, '&#x0D;', ''), '&amp;' , '') + @crlf 
		+ ') x (' + @colList + ') ) 
		MERGE ' + @tab + ' t USING cteMerge c ON(' + @colListEq + ')
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (' + @colList + ')
		VALUES (' + @colListPrefxd + ')' + @crlf
	FROM cteAlmost

	

	--------------------------------------------------------------------------------------------------------------
	-- 3. Make the INSERT part of the MERGE statement

	IF ISNULL(@includeUpdate, 0) = 1
	BEGIN
		SELECT @out = @out + '
			WHEN MATCHED THEN UPDATE 
			SET ' +  @colListEqAll + @crlf
	END


	--------------------------------------------------------------------------------------------------------------
	-- 4. Make the DELETE part of the MERGE statement

	IF ISNULL(@includeDelete, 0) = 1
	BEGIN
		SELECT @out = @out + '
			WHEN NOT MATCHED BY SOURCE THEN 
				DELETE
		'
	END

	--------------------------------------------------------------------------------------------------------------
	-- 5. Output

	SELECT @out = @out + ';'
	SELECT @out

END

GO
