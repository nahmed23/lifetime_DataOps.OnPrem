

--
-- Returns a listing of all Sales Employees ( Dept 1 )  
--

CREATE            PROCEDURE [dbo].[mmsGetClubMembershipAdvisors_Obsolete]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


SELECT C.ClubName,C.ClubID, E.EmployeeID, E.FirstName AS EmployeeFirstName, 
E.LastName AS EmployeeLastName, E.ActiveStatusFlag AS EmployeeActiveFlag,
VER.ValEmployeeRoleID, VER.Description AS EmployeeRoleDescription,PrimaryEmployeeRoleFlag
FROM dbo.vClub C
 JOIN dbo.vEmployee E 
   ON C.ClubID=E.ClubID
 LEFT OUTER JOIN dbo.vEmployeeRole ER 
   ON E.EmployeeID=ER.EmployeeID
 LEFT OUTER JOIN dbo.vValEmployeeRole VER 
   ON ER.ValEmployeeRoleID=VER.ValEmployeeRoleID
WHERE E.EmployeeID = 0 OR ---- a "0" employee number is needed as a placeholder for subsequest linking
      VER.DepartmentID=1 
     
 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

