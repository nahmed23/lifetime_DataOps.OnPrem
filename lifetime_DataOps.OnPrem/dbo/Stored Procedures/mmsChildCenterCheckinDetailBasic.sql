














-- This procedure returns child center check-in data for a single selected club and date range 

CREATE      PROCEDURE dbo.mmsChildCenterCheckinDetailBasic
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
CCU.CheckInDateTime, 
CCU.CheckOutDateTime, 
DATEDIFF ( minute, CCU.CheckInDateTime, CCU.CheckOutDateTime ) LengthOfStayInMinutes, 
CCU.MemberID, 
M.DOB, 
M.Gender, 
DATENAME (weekday, CCU.CheckInDateTime) DayOfWeek, 
DATEPART (hour, CCU.CheckInDateTime) CheckInHourOfDay,
GETDATE() ReportDateTime 

FROM 
dbo.vChildCenterUsage CCU JOIN dbo.vMember M ON CCU.MemberID=M.MemberID 
			  JOIN dbo.vClub C ON C.ClubID=CCU.ClubID  


WHERE 
CCU.CheckInDateTime >= @StartDate  AND
CCU.CheckInDateTime <= @EndDate AND 
C.ClubID= @ClubID AND 
C.DisplayUIFlag=1

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END


SET QUOTED_IDENTIFIER OFF 










