-- from excel
SELECT * 
INTO ceg.SurveyData2015_05_DNA
FROM OPENDATASOURCE('Microsoft.ACE.OLEDB.12.0','Data Source=G:\CEG Data\Survey data\RT 2015-05 Session Evaluation Did Not Attend - Responses -  2016-12-29 13-40 36285.xlsx;Extended Properties=Excel 12.0')...[Sheet1$]

-- from csv file
SELECT * 
--INTO ceg.SurveyData2015_05_DNA
FROM OPENDATASOURCE('Microsoft.ACE.OLEDB.12.0','Data Source=G:\HR-CPI Data\Benefit Harbor to CPI\Benefit Harbor Data\;Extended Properties="Text;HDR=YES"')...[Bernhard_TEST_20170531_COB#csv]

