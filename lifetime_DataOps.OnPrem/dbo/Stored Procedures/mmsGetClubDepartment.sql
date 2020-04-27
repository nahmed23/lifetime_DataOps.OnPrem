
-- =============================================
-- Object:			dbo.mmsGetClubDepartment
-- Author:			
-- Create date: 	
-- Description:		returns Departments for a list of Clubs
-- Parameters:		a list of club names
-- Modified date:	6/11/08 GRB added DepartmentID to end of SELECT statement
-- Release date:	6/18/2008 dbcr_3274
-- Exec mmsGetClubDepartment '151'
-- =============================================

CREATE  PROC [dbo].[mmsGetClubDepartment] (
  @ClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

BEGIN
--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END

SELECT DISTINCT D.Description DeptDescription, 
	D.DepartmentID	-- 6/11/2008 GRB
       /*C.ClubName, P.Description ProductDescription*/
  FROM dbo.vClubProduct CP
  JOIN dbo.vClub C
    ON C.ClubID = CP.ClubID
  JOIN #Clubs CS
    ON C.ClubID = CS.ClubID
--  JOIN #Clubs CS
--    ON C.ClubName = CS.ClubName
  JOIN dbo.vProduct P
    ON CP.ProductID = P.ProductID
  JOIN dbo.vDepartment D
    ON P.DepartmentID = D.DepartmentID
 WHERE --C.ClubName IN (SELECT ClubName FROM #Clubs) AND 
       C.DisplayUIFlag=1
 ORDER BY D.Description

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
