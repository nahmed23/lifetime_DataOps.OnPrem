


--THIS PROCEDURE RETURNS THE DETAILS OF DELIVERED BODY AGE ASSESSMENT SESSIONS
--FOR THE MONTH THROUGH YESTERDAY FOR All CLUBS.

CREATE    PROCEDURE dbo.mmsPT_DSSR_DeliveredBodyAgeSessions_MTD_AllClubs
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC dbo.mmsPT_DSSR_DeliveredBodyAgeSessions_MTD 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






