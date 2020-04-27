






--
-- Returns a listing of all Employees for a selected club and 
-- Sales department employees for all clubs  
--

CREATE       PROCEDURE dbo.mmsGetEmployees(
  @ClubList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName,C.ClubID, E.EmployeeID, E.FirstName EmployeeFirstName, 
E.LastName EmployeeLastName, E.ActiveStatusFlag EmployeeActiveFlag,VER.DepartmentID,
@ClubList AS QueriedClub, C.CRMDivisionCode
FROM dbo.vClub C
 JOIN dbo.vEmployee E 
   ON C.ClubID=E.ClubID
 LEFT OUTER JOIN dbo.vEmployeeRole ER 
   ON E.EmployeeID=ER.EmployeeID
 LEFT OUTER JOIN dbo.vValEmployeeRole VER 
   ON ER.ValEmployeeRoleID=VER.ValEmployeeRoleID
WHERE VER.DepartmentID = 1 OR
      C.ClubName = @ClubList OR
      @ClubList = 'All' OR
      E.EmployeeID = -1


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END












