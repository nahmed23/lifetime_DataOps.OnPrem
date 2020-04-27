


/* 

	Creates an export Usage Date for the City of Minneapolis
	Data is exported to a location on the network where it is picked up and FTP'd

	Created: 1/18/2013
	By: Travis Puppe

	NOTE: Hardcoded IDs for the City of Mpls (03324, 12084, 12086)

	Updated:  5/15/2014
	By:  Cash Durrett

	Note:  Changed summation of visits from per visit to per day.

*/


CREATE PROCEDURE [dbo].[mmsExportCWUsageReportCityofMpls]
								@RowsProcessed INT OUTPUT, 
								@Description  VARCHAR(80) OUTPUT
AS 
BEGIN


SET XACT_ABORT ON
SET NOCOUNT    ON
DECLARE @CompanyID INT
DECLARE @UsageReportMemberType VARCHAR(50)
DECLARE @FirstOfLastMonth DATETIME
DECLARE @FirstOfCurrentMonth VARCHAR(150)
DECLARE @FileDate VARCHAR(25)
DECLARE @Destination VARCHAR(400)
DECLARE @FileName VARCHAR(400)
DECLARE @Cmd VARCHAR(2000)
DECLARE @CorporateCode VARCHAR(5)

SET @FirstOfLastMonth = CONVERT(varchar,MONTH(DATEADD(MM,-1,GETDATE()))) + '/01/' + CONVERT(VARCHAR,YEAR(DATEADD(MM,-1,GETDATE())))
SET @FirstOfCurrentMonth = DATEADD(MM,1,@FirstOfLastMonth)

SELECT CompanyID, CorporateCode, UsageReportMemberType
INTO #Companies
FROM vCompany
WHERE CompanyID IN (3324, 12084, 12086)--City of Mpls


SELECT @RowsProcessed = COUNT(*) FROM #Companies
SELECT @Description = 'Number of Companies that generated reports'


--Create the results set to return
IF OBJECT_ID('tempdb..##CityMpls') IS NOT NULL
	DROP TABLE ##CityMpls

CREATE TABLE ##CityMpls (
	MemberID VARCHAR(9),
	FirstName VARCHAR(50),
	LastName VARCHAR(50),
	ProductDesc VARCHAR(50),
	DuesRate DECIMAL(10,2),
	JrDuesRate DECIMAL(10,2),
	JoinDate VARCHAR(10),
	MembershipStatus VARCHAR(50),
	MemberType VARCHAR(50),
	Visits VARCHAR(5),
	DOB VARCHAR(10)
	)

SET @FileDate = REPLACE(CONVERT(VARCHAR(10), GETDATE(), 111), '/', '')-- yyyymmdd

SET @Destination = CASE WHEN @@SERVERNAME = 'MNCODB24'
						THEN '\\ltfinc.net\ltfshare\software\FTP\CityMpls\' --Prod
						ELSE '\\Ltfinc.net\ltfshare\Corp\Public\Database\TravisTest\' --Test
				   END

WHILE (SELECT COUNT(CompanyID) FROM #Companies) > 0
BEGIN

   SELECT TOP 1 
		  @CompanyID = CompanyID,
		  @CorporateCode = CorporateCode,
          @UsageReportMemberType = isnull(UsageReportMemberType,'Both') 
   FROM #Companies

	  INSERT INTO ##CityMpls
      SELECT M.MemberID, M.FirstName, M.LastName,P.Description AS ProductDesc,
             CONVERT( DECIMAL(6,2),CP.Price * ( ( ISNULL( tCPTR.SumTaxPercentage, 0 ) * .01 ) + 1 ) ) AS DuesRate,
             SUM(ISNULL(JrMember.JrMemberCount,0)) * CONVERT( DECIMAL(6,2), ISNULL( JrDues.JrDues, 0 ) ) AS JrDuesRate,
             CONVERT( VARCHAR(10), M.JoinDate, 110 ) AS JoinDate,VMS.Description AS MembershipStatus,
             VMT.Description AS MemberType,SUM(ISNULL(MU.ClubUsage,0)) AS Visits, CONVERT( VARCHAR(10), M.DOB, 110 )
      FROM dbo.vMember M JOIN vMembership MS ON M.MembershipID = MS.MembershipID
           JOIN vClub C ON MS.ClubID = C.ClubID
           JOIN vMembershipType MST	ON MS.MembershipTypeID= MST.MembershipTypeID
           JOIN vProduct P ON P.ProductID= MST.ProductID
           JOIN vValMembershipStatus VMS	ON MS.ValMembershipStatusID= VMS.ValMembershipStatusID
           JOIN vValMemberType VMT ON M.ValMemberTypeID= VMT.ValMemberTypeID
           JOIN vClubProduct CP ON MS.ClubID = CP.ClubID
                AND MST.ProductID= CP.ProductID
           LEFT JOIN ( SELECT SUM(isnull(TaxPercentage,0))AS SumTaxPercentage, CPTR.ClubID,CPTR.ProductID
                       FROM vClubProductTaxRate CPTR JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
                       GROUP BY CPTR.ClubID, CPTR.ProductID) tCPTR ON CP.ClubID = tCPTR.ClubID
                                                                    AND	CP.ProductID = tCPTR.ProductID
           LEFT JOIN (SELECT MemberID,COUNT(DISTINCT CAST(UsageDateTime AS VARCHAR(12))) ClubUsage
                        FROM vMemberUsage  
                       WHERE UsageDateTime BETWEEN @FirstOfLastMonth AND @FirstOfCurrentMonth
                       GROUP BY MemberID) AS MU ON MU.MemberID= M.MemberID
           LEFT JOIN ( SELECT CP.ClubID,CP.ProductID,CP.Price * ( ( ISNULL( SUM( isnull(TR.TaxPercentage,0) ), 0 ) + 100 ) / 100 ) AS JrDues
                       FROM vClubProduct CP JOIN vProduct PR ON	CP.ProductID = PR.ProductID AND PR.JrMemberDuesFlag = 1
                       LEFT JOIN vClubProductTaxRate CPTR ON	CP.ProductID = CPTR.ProductID AND CP.ClubID = CPTR.ClubID
                       LEFT JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
                       GROUP BY	CP.ClubID,	CP.ProductID,	CP.Price ) JrDues ON MS.ClubID = JrDues.ClubID
                                                                               AND MS.JrMemberDuesProductID= JrDues.ProductID
                                                                               --AND MS.AssessJrMemberDuesFlag = 1
                                                                               AND C.AssessJrMemberDuesFlag= 1
                                                                               --AND( MS.AssessJrMemberDuesFlag = 1 OR MS.AssessJrMemberDuesFlag IS NULL )
            LEFT JOIN (SELECT MembershipID,Count(*) JrMemberCount
                         FROM vMember 
                        WHERE ValMemberTypeID= 4	
                          AND ActiveFlag= 1
                         GROUP BY MembershipID) JrMember ON MS.MembershipID= JrMember.MembershipID	
	WHERE VMS.Description IN ( 'Active', 'Pending Termination' ) AND( MS.ExpirationDate IS NULL	OR MS.ExpirationDate>= @FirstOfLastMonth  )
	      AND	M.ActiveFlag = 1
	      AND	MS.CompanyID =  convert(varchar,@CompanyID)
	      AND CP.ClubID= MS.ClubID
	      AND CASE WHEN 'Both' = @UsageReportMemberType AND VMT.Description IN ('Primary', 'Partner') THEN 'Both' ELSE VMT.Description END = @UsageReportMemberType
	GROUP BY M.MemberID, M.FirstName,M.LastName,M.JoinDate,VMT.Description,P.Description,VMS.Description,CP.Price,JrDues.JrDues,tCPTR.sumTaxPercentage, M.DOB

	SET @FileName = 'LTF_Usage_' + @FileDate + '_' + @CorporateCode + '.txt'

	SET @Cmd = 'bcp "SELECT ''MemberID'', ''FirstName'', ''LastName'', ''ProductDesc'', ''DuesRate'', ''JrDuesRate'', ''JoinDate'', ''MembershipStatus'', ''MemberType'', ''Visits'', ''DOB'' UNION ALL SELECT MemberID, FirstName, LastName, ProductDesc, CAST(DuesRate AS VARCHAR(10)), CAST(JrDuesRate AS VARCHAR(10)), JoinDate, MembershipStatus, MemberType, Visits, DOB FROM ##CityMpls" queryout "' + @Destination + @FileName + '" -c -T -S ' + @@SERVERNAME 

	EXEC master.dbo.xp_cmdshell @cmd

    DELETE #Companies WHERE CompanyID = @CompanyID
	TRUNCATE TABLE ##CityMpls

END --END WHILE Loop


DROP TABLE #Companies
DROP TABLE ##CityMpls


END --END Sproc

