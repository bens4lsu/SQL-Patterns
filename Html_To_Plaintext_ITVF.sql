
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'Html_To_Plaintext_ITVF' AND type = 'IF' AND schema_id = SCHEMA_ID('dbo'))
	DROP FUNCTION dbo.Html_To_Plaintext_ITVF
GO

CREATE FUNCTION [dbo].[Html_To_Plaintext_ITVF] (@HTMLText nvarchar(max), @linefeed nvarchar(10))
RETURNS TABLE
AS

	/***************************************************************************************************************/
	/*                                                                                                             */
	/* 2021-12-30 - Ben Schultz - Initial version of function.  Replaces <br> and </p> with line feeds, then       */
	/*                            strips any other html tags.                                                      */
	/*                                                                                                             */
	/***************************************************************************************************************/

	RETURN 
	
	WITH cteTagsToReplaceWithLF AS (
		SELECT a.tag
			, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS R 
		FROM (
			VALUES ('</p>'), ('</tr>'), ('<br>'), ('<br />'), ('</li>')
		) a(tag)
	)

	, cteWithLineFeeds(n, Html) AS (
		SELECT 1, REPLACE(@HTMLText, cteTags.tag, @linefeed)
		FROM cteTagsToReplaceWithLF cteTags
		WHERE cteTags.R = 1

		UNION ALL

		SELECT n + 1, REPLACE(ctelf.Html, cteTags.tag, @linefeed)
		FROM cteWithLineFeeds ctelf
			JOIN cteTagsToReplaceWithLF cteTags ON ctelf.n = cteTags.R
	)

	, cteHtml (i, HtmlText) AS (
		SELECT TOP 1 0, Html
		FROM cteWithLineFeeds
		ORDER BY n DESC
	
		UNION ALL

		SELECT i + 1, CONVERT(nvarchar(MAX), STUFF(HtmlText, CHARINDEX(N'<', HtmlText), CHARINDEX(N'>', HtmlText, CHARINDEX(N'<', HtmlText)) - CHARINDEX(N'<', HtmlText) + 1, ''))
		FROM cteHtml
		WHERE CHARINDEX('<', HtmlText) > 0
			AND CHARINDEX('>', HtmlText, CHARINDEX('<', HtmlText)) > 0
			AND CHARINDEX('>', HtmlText, CHARINDEX('<', HtmlText)) - CHARINDEX('<', HtmlText) > 0
	)

	SELECT TOP 1 LTRIM(RTRIM(HtmlText)) AS PlainText
	FROM cteHtml
	ORDER BY i DESC

GO