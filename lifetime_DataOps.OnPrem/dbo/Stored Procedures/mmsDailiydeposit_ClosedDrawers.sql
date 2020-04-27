





--
-- Returns a set of drawer activity between a given date
-- 
-- Parameters: a start and end date for the closedatetime
--

CREATE PROC dbo.mmsDailiydeposit_ClosedDrawers (
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName, DA.DrawerActivityID, DA.OpenDateTime,
       DA.CloseDateTime, C.ClubID, D.DrawerID
  FROM dbo.vClub C
  JOIN dbo.vDrawer D
       ON C.ClubID=D.ClubID
  JOIN dbo.vDrawerActivity DA
       ON DA.DrawerID=D.DrawerID
 WHERE DA.CloseDateTime>=@CloseStartDate AND
       DA.CloseDateTime<=@CloseEndDate


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






