	
/* Finds who signed up for Risk Point Products on the given date */
/* 
    Test: EXEC mmsEmailHCSignUps '5410', 'itdatabase@lifetimefitness.com'

    Change Log
	Created:  11/12/2010	Travis Puppe
*/

CREATE PROCEDURE [dbo].[mmsEmailHCSignUps] (
	@ProductList VARCHAR(200), --seperated by |
	@Recipients VARCHAR(500),  --seperated by ,
    @Date DATETIME = NULL      --defaults to yesterday
)
AS 
BEGIN


	SET XACT_ABORT ON
	SET NOCOUNT    ON

	IF @Date IS NULL
	SET @Date = DATEADD(DD, -1, DATEADD(DD,0,DATEDIFF(DD,0,GETDATE()))) --Yesterday


	CREATE TABLE #tmpList (StringField VARCHAR(50))

	-- Parse the ClubIDs into a temp table
	EXEC procParseIntegerList @ProductList
	CREATE TABLE ##Products (ProductID INT)
	INSERT INTO ##Products (ProductID) SELECT StringField FROM #tmpList


	/*Set-up variable to include the current date in the name */
	DECLARE @subjectline VARCHAR (250)
	SET @subjectline = 'Signups for Risk Point ' + CONVERT(VARCHAR(12),@Date,110)

	DECLARE @BodyText VARCHAR(100)
	SET @BodyText = 'Here are the latest signups for ' + CONVERT(VARCHAR(12),@Date,101)

	DECLARE @FileName VARCHAR(50)
	SET @FileName = 'RiskPoint_Signups_' + CONVERT(VARCHAR(12),@Date,110) +'.csv'


	DECLARE @HCQuery VARCHAR(MAX)

	set @HCQuery='
	SET ANSI_WARNINGS OFF
	SET NOCOUNT ON

	SELECT p.ProductID, p.Description, CONVERT(VARCHAR, mt.TranDate, 101) TranDate, m.FirstName + '' '' + m.LastName [Name], ma.AddressLine1, 
		   ISNULL(ma.AddressLine2,'''') AddressLine2, ma.City, vs.Description [State], 
		   ma.Zip, mp.AreaCode + ''-'' + mp.Number PhoneNumber, CONVERT(VARCHAR, m.DOB, 101) DOB, m.MemberID
	FROM vMMSTran mt
	JOIN vTranItem ti
	  ON ti.MMSTranID = mt.MMSTranID
	JOIN vMembership ms
	  ON ms.MembershipID = mt.MembershipID
	JOIN vMember m
	  ON mt.MemberID = m.MemberID
	JOIN vMembershipAddress ma
	  ON ma.MembershipID = ms.MembershipID
	JOIN vMembershipPhone mp
	  ON mp.MembershipID = ms.MembershipID
	JOIN vValState vs
	  ON vs.ValStateID = ma.ValStateID
	JOIN vProduct p
	  ON p.ProductID = ti.ProductID
	WHERE ti.ProductID IN (SELECT ProductID FROM ##Products)
	  AND ma.ValAddressTypeID = 1
	  AND mp.ValPhoneTypeID = 1
	  AND mt.PostDateTime >= ''' + CAST(@Date AS VARCHAR(11)) + '''
	  AND mt.PostDateTime < DATEADD(DD,1,''' + CAST(@Date AS VARCHAR(11)) + ''')
	ORDER BY m.MemberID

	SET ANSI_WARNINGS ON
	SET NOCOUNT OFF
	'

	EXEC msdb.dbo.sp_send_dbmail 
						 @profile_name = 'sqlsrvcacct'
						,@recipients = @Recipients
						,@copy_recipients = 'itdatabase@lifetimefitness.com'
						,@subject=@subjectline
						,@body = @BodyText
						,@attach_query_result_as_file = 1
						,@query_attachment_filename = @FileName
						,@exclude_query_output = 1
						,@query_result_width = 4000
						,@query_result_separator = '	' --tab
						,@execute_query_database = 'Report_MMS'
						,@query=@HCQuery


	DROP TABLE ##Products
	DROP TABLE #tmpList

END
