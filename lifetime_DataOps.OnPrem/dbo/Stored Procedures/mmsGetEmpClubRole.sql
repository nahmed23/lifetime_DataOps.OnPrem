


CREATE    PROC mmsGetEmpClubRole(
              @ClubList VARCHAR(2000)
)
AS
BEGIN

-- =============================================
-- Object:			dbo.mmsGetEmpClubRole
-- Author:			
-- Create date: 	
-- Description:		Returns a result set of Employees, club, and role of the employee
-- Modified date:	4/1/2009 GRB: added ClubID; dbcr_4372
-- 	
-- Exec mmsGetEmpClubRole 'All'
-- =============================================
-- 

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
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Clubs VALUES('All')
END
SELECT C.ClubName, 
       VER.Description AS RoleDescription, 
       E.EmployeeID, E.FirstName, E.LastName
		, C.ClubID			-- added 4/1/2009 GRB
  FROM dbo.vClub C 
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
  JOIN dbo.vEmployee E
       ON E.ClubID = C.ClubID
  JOIN dbo.vEmployeeRole ER
       ON ER.EmployeeID = E.EmployeeID
  JOIN dbo.vValEmployeeRole VER 
       ON VER.ValEmployeeRoleID = ER.ValEmployeeRoleID
-- WHERE (C.ClubName IN (SELECT ClubName FROM #Clubs) OR
--       @ClubList = 'All')

DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
