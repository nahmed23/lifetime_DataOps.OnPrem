

--
-- this procedure will return the count of memberships joining in the current
-- month with $0 initiation fee
--

CREATE             PROCEDURE dbo.mmsDSSR_ZeroIF
  @ClubList VARCHAR(1000)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME
  DECLARE @LastDayOfMonth INT
  DECLARE @To_Day INT
  DECLARE @FirstOfNextMonth DATETIME
  DECLARE @LastDayOfPriorMonth DATETIME
  DECLARE @FirstDayOfMonthAfterNext DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
  SET @LastDayOfMonth = DAY(DATEADD(MM,1,@FirstOfMonth)-1)
  SET @To_Day = DAY(@Yesterday)
  SET @LastDayOfPriorMonth = DATEADD(dd,-1,@FirstOfMonth)
  SET @FirstDayOfMonthAfterNext = DATEADD(mm, 2,@FirstOfMonth)
  SET @FirstOfNextMonth = DATEADD(mm, 1,@FirstOfMonth)

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  -- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
-- INSERT INTO #tmpList VALUES('algonquin, il')

  SELECT C.ClubName, C.ClubID
    INTO #Clubs
    FROM dbo.vClub C 
    JOIN #tmpList tmp 
         ON tmp.StringField = C.ClubName
         OR tmp.StringField = 'All'

  SELECT DS.MembershipClubID,DS.MembershipID,DS.JoinDate,SUM(ItemAmount)AS MembershipIF,
         @Yesterday AS ReportDate,DS.AdvisorEmployeeID,
         CASE WHEN SUM(ItemAmount)=0
              THEN 1
              ELSE 0
              END NewMembership_ZeroIF_Count,
         CASE WHEN DS.JoinDate = @Yesterday AND SUM(ItemAmount)=0
              THEN 1
              ELSE 0
              END Today_NewMembership_ZeroIF_Count
         FROM vDSSRSummary DS 
         JOIN #Clubs C 
         ON DS.MembershipClubID = C.ClubID 
    WHERE 
         DS.JoinDate <= @Yesterday AND
          DS.MembershipTypeDescription NOT LIKE '%Employee%' AND
          DS.MembershipTypeDescription NOT LIKE '%Short%' AND
          DS.MembershipTypeDescription NOT LIKE '%Trade%' AND
          DS.ProductID = 88
    GROUP By DS.MembershipClubID, DS.MembershipID, DS.JoinDate,DS.AdvisorEmployeeID 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


