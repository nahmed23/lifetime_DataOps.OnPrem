
------------------------------------------------------------------------------------------------------------------------
--
-- returns the products available at a given clubs department
--
-- Parameters: A | separated list of clubs and a similar departments list
-- mmsGetProductForClubDepartment 'Chanhassen, MN|Plymouth, MN|Allen, TX', 'All'

CREATE PROC [dbo].[mmsGetProductForClubDepartment] (
  @ClubList VARCHAR(8000),
  @DepartmentList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubName VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubList <> 'All'

BEGIN
--  INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Clubs VALUES('All')
END
CREATE TABLE #Departments (Description VARCHAR(50))
IF @DepartmentList <> 'All'
BEGIN
--  INSERT INTO #Departments EXEC procParseStringList @DepartmentList
   EXEC procParseStringList @DepartmentList
   INSERT INTO #Departments (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Departments VALUES('All')
END
  
SELECT P.ProductID, P.Description ProductDescription, P.PackageProductFlag, D.Description AS DepartmentDescription, D.DepartmentID
  FROM dbo.vClub C
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID
  JOIN dbo.vProduct P
       ON CP.ProductID = P.ProductID
  JOIN dbo.vDepartment D
       ON P.DepartmentID = D.DepartmentID
  JOIN #Departments DS
       ON D.Description = DS.Description OR DS.Description = 'All'
 WHERE --(C.ClubName IN (SELECT ClubName FROM #Clubs) OR
       --@ClubList = 'All') AND
       --(D.Description IN (SELECT Description FROM #Departments) OR
       --@DepartmentList = 'All') AND
       C.DisplayUIFlag = 1
 GROUP BY P.ProductID, P.Description, P.PackageProductFlag, D.Description, D.DepartmentID
 ORDER BY P.Description

DROP TABLE #Clubs
DROP TABLE #Departments
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
