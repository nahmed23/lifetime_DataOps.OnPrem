



--THIS PROCEDURE RETURNS THE DETAILS OF THE ORIGINAL IF SALES TRANSACTIONS FOR  
--THE CURRENT MONTHS 30 DAY CANCELLATIONS AND 30 DAY DOWNGRADES.

CREATE    PROCEDURE dbo.mmsDSSR_CashReductionsAllClubs
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDSSR_CashReductions 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



