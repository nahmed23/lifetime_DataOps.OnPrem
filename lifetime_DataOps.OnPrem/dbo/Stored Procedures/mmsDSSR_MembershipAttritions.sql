



--THIS PROCEDURE RETURNS THE DETAILS OF MEMBERSHIP ATTRITIONS 
--IN THE CURRENT MONTH FOR A GIVEN CLUB(S).
-- WILL TAKE LIST OF CLUBS(SEPERATED BY |) AS INPUT.

CREATE           PROCEDURE dbo.mmsDSSR_MembershipAttritions (
  @ClubList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @FirstOfNextMonth DATETIME
  DECLARE @LastDayOfPriorMonth DATETIME
  DECLARE @FirstDayOfMonthAfterNext DATETIME

  SET @Yesterday = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @FirstOfNextMonth = DATEADD(mm, 1,@FirstOfMonth)
  SET @LastDayOfPriorMonth = DATEADD(dd,-1,@FirstOfMonth)
  SET @FirstDayOfMonthAfterNext = DATEADD(mm, 2,@FirstOfMonth)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  SELECT DISTINCT DS.MembershipClubID AS ClubID,DS.MembershipClubName AS ClubName,DS.MemberID ,DS.PrimarymemberFirstName,
         DS.PrimarymemberLastName,DS.ExpirationDate,DS.TermReasonDescription,
         DS.AdvisorFirstName,DS.AdvisorLastName,DS.MembershipTypeDescription,
         DS.JoinDate, @Yesterday AS ReportDate,DS.MembershipSizeDescription,DATEADD(mm, 1,@FirstOfMonth) AS FirstOfNextMonth,
         DS.AdvisorEmployeeID,DS.Expire_Today_Flag, CP.Price AS MembershipDuesPrice, VR.Description AS MMS_Region
    FROM vDSSRSummary DS JOIN #Clubs tC
         ON DS.mEMBERSHIPClubName = tC.ClubName
         OR tC.ClubName = 'All'
         JOIN vProduct P
          ON DS.MembershipTypeDescription = P.Description
         JOIN vClubProduct CP
          ON CP.ProductID = P.ProductID
            AND CP.ClubID = DS.MembershipClubID 
         JOIN vClub C
          ON  DS.MembershipClubID = C.ClubID
         JOIN vValRegion VR
          ON C.ValRegionID = VR.ValRegionID
   WHERE DS.ExpirationDate>=@LastDayOfPriorMonth AND  
         DS.ExpirationDate < @FirstDayOfMonthAfterNext AND
         DS.MembershipTypeDescription NOT LIKE '%Employee%' AND 
         DS.MembershipTypeDescription NOT LIKE '%Short%'
    ORDER BY DS.MembershipClubName,DS.ExpirationDate

  DROP TABLE #tmpList
  DROP TABLE #Clubs

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



