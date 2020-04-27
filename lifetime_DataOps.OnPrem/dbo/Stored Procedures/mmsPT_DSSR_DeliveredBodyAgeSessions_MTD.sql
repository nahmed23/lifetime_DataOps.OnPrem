






----
---- This procedure returns information on delivered sessions of product # 1482 or 2785
---- "Body Age Fitness Assessment" for selected or All clubs
----

CREATE       PROCEDURE [dbo].[mmsPT_DSSR_DeliveredBodyAgeSessions_MTD](
         @ClubList VARCHAR(8000)
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @Yesterday DATETIME
DECLARE @FirstOfMonth DATETIME
DECLARE @Today 	DATETIME
DECLARE @FirstOfLastMonth DATETIME

SET @Yesterday = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(d,-1,GETDATE()),110),110)
SET @FirstOfMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @Today = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @FirstOfLastMonth = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-1, GETDATE() - DAY(GETDATE()-1)),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
  
   --- Parse the Club names into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  TRUNCATE TABLE #tmpList

BEGIN

SELECT PKGS.ClubID AS DeliveredClubID, C.ClubName AS DeliveredClubName, PKG.MemberID, M.FirstName, M.LastName, 
       PKG.EmployeeID AS SaleEmployeeID, SALEE.FirstName AS SaleEmplFirstName, SALEE.LastName AS SaleEmplLastName, 
       PKGS.DeliveredEmployeeID, DLVE.FirstName AS DelivEmplFirstName, DLVE.LastName AS DelivEmplLastName, 
       PKG.PackageID, PKG.ProductID, PKGS.DeliveredDateTime, PKG.CreatedDateTime, PKG.ClubID AS SaleClubID,
       PKG.NumberOfSessions,
       CASE
       WHEN PKGS.DeliveredDateTime>= @Yesterday 
       AND PKGS.DeliveredDateTime < @Today 
       THEN 1
       ELSE 0
       END TodayDeliveredFlag,
       M.JoinDate, @Today AS ReportDate, DateDiff(day,M.JoinDate,@Today) AS MemberLengthInDays, 
       @FirstOfLastMonth AS FirstOfLastMonth, DateDiff(Day,@FirstOfLastMonth,@Today)AS DaysSinceFirstOfLastMonth
FROM dbo.vPackage PKG
     JOIN dbo.vPackageSession PKGS
       ON PKG.PackageID=PKGS.PackageID
     JOIN dbo.vClub C
       ON C.ClubID=PKGS.ClubID
     JOIN #Clubs CS
       ON C.ClubName = CS.ClubName
	  OR CS.ClubName = 'All'
     JOIN dbo.vEmployee SALEE
       ON SALEE.EmployeeID= PKG.EmployeeID
     JOIN dbo.vEmployee DLVE
       ON DLVE.EmployeeID= PKGS.DeliveredEmployeeID
     JOIN dbo.vMember M 
       ON M.MemberID= PKG.MemberID
     ------JOIN vProductGroup PG
      ------ ON PG.ProductID = PKG.ProductID

WHERE PKG.ProductID in(1482,2785) AND
 PKGS.DeliveredDateTime >= @FirstOfMonth 
 AND 
 PKGS.DeliveredDateTime < @Today

END

 DROP TABLE #Clubs
 DROP TABLE #tmpList
 
 -- Report Logging
   UPDATE HyperionReportLog
   SET EndDateTime = getdate()
   WHERE ReportLogID = @Identity

END

