/**********************************************************************************************/
/*  Ben Schultz - 2/27/2015                                                                   */
/*  Anything between the first comma and the next is considered a suffix.  If there's more    */
/*  than one comma, anything after the 2nd is dropped.  Then, it's just the first name up to  */
/*  a space is the first name and the last name is the last name.  Everything else gets       */
/*  dumped into middle                                                                        */
/*                                                                                            */
/**********************************************************************************************/


WITH  cteParse1 AS (
		SELECT myTable.KeyCol1, myTable.OtherColumn1, myTable.OtherColumn2, myTable.OtherColumn3, dsri.ItemNumber, dsri.Item
		FROM My_Table myTable
			CROSS APPLY dbo.Delimited_Split_Rows_ITVF(myTable.Full_Name, ' ') dsri
	)

, cteCount AS (
	SELECT KeyCol1
		, COUNT(*) AS NumNames
	FROM cteParse1
	GROUP BY KeyCol1
)
	

SELECT fname.OtherColumn1
	, fname.OtherColumn2
	, myTable.OtherColumn4
	, myTable.Full_Name
	, prt.Relation_SSN
	, fname.Item AS First_Name
	, mname.Middle_Name
	, lname.Item AS Last_Name
FROM My_Table myTable   -- not strictly necessary, but this will help the optimizer use indexes like we want them to
	JOIN cteParse1 fname ON myTable.KeyCol1 = fname.KeyCol1 
	JOIN cteCount ON fname.KeyCol1 = cteCount.KeyCol1 
	LEFT JOIN cteParse1 lname ON fname.KeyCol1 = lname.KeyCol1 AND NumNames = lname.ItemNumber AND 1 != lname.ItemNumber
	
	OUTER APPLY (
		SELECT SUBSTRING(
			(SELECT  ' ' + RTRIM(Item) [text()]
				FROM cteParse1 p1Inner
				JOIN cteCount ON p1Inner.KeyCol1 = cteCount.KeyCol1 
				WHERE p1Inner.ItemNumber != 1
				AND p1Inner.ItemNumber != cteCount.NumNames
				AND p1Inner.KeyCol1 = myTable.KeyCol1
				FOR XML PATH('') 
			), 2, 1000000000
		) AS Middle_Name
	) mname

WHERE fname.ItemNumber = 1

GO


