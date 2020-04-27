






-- This procedure returns all of the child center usage exeptions plus all 
-- check-ins with no check-out record, for a selected club within a  
-- selected date range.

CREATE  PROCEDURE dbo.mmsChildCenterExceptions
@ClubID VARCHAR(1000),
@StartDate datetime,
@EndDate datetime

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT 
C.ClubName, 
CCU.MemberID, 
CCU.ChildCenterUsageID, 
CCU.CheckInDateTime, 
CCU.CheckInMemberID, 
CCU.CheckOutDateTime, 
CCU.CheckOutMemberID, 
VCCUE.Description ExceptionDescription, 
E.FirstName EmployeeFirstName, 
E.LastName EmployeeLastName, 
M.FirstName ChildFirstName, 
M.LastName ChildLastName

FROM 
dbo.vClub C JOIN dbo.vChildCenterUsage CCU ON  C.ClubID=CCU.ClubID
            JOIN dbo.vMember M ON CCU.MemberID=M.MemberID 
            LEFT OUTER JOIN dbo.vChildCenterUsageException CCUE ON CCU.ChildCenterUsageID=CCUE.ChildCenterUsageID 
            LEFT OUTER JOIN dbo.vValChildCenterUsageException VCCUE ON CCUE.ValChildCenterUsageExceptionID=VCCUE.ValChildCenterUsageExceptionID 
            LEFT OUTER JOIN dbo.vEmployee E ON CCUE.EmployeeID=E.EmployeeID 

WHERE 
CCU.CheckInDateTime >= @StartDate AND
CCU.CheckInDateTime <= @EndDate AND 
C.ClubID=@ClubID AND 
C.DisplayUIFlag=1 AND 
(CCU.CheckOutDateTime IS NULL OR LEN(VCCUE.Description)> 0 )

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END







