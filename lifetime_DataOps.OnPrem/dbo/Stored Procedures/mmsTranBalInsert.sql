
-- This job cleans the TranBalance table and
-- then calls the procedure mmsTranBalanceInsert

CREATE PROCEDURE [dbo].[mmsTranBalInsert]
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--Since EFT runs on 1st there is no need for this job to run.
IF DAY(GETDATE()) <> 1
BEGIN
  DELETE FROM MMS..vTranBalance
  EXEC mmsTranBalanceInsert
END


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
