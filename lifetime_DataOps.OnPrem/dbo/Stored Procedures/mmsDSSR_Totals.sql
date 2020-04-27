


--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIPS SOLD BY EACH MEMBERSHIPADVISOR 
--TILL YESTERDAY. WILL TAKE LIST OF CLUBS(SEPERATED BY COMMA) AS INPUT.

CREATE       PROCEDURE dbo.mmsDSSR_Totals (
  @ClubList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME

  SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  SELECT DA.MembershipCount,
         DA.AdvisorFirstName,
         DA.AdvisorLastName,DA.ClubID,
         DA.ClubName, DA.DomainNamePrefix,@Yesterday AS ReportDate,
         DA.VALTerminationReasonID,DA.ExpirationDate,C.ValPreSaleID,
         C.CRMDivisionCode, DA.AdvisorEmployeeID
    FROM vDSSRAdvisorMembershipTotalsSummary DA 
       JOIN #Clubs tC 
         ON DA.ClubName = tC.ClubName
         OR tC.ClubName = 'All'
       JOIN dbo.vClub C
         ON DA.ClubID = C.ClubID
    ORDER BY DA.ClubName

  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



