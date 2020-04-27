

----------------------------------------------------- dbo.eposGetTerminalNames

CREATE PROC dbo.eposGetTerminalNames 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

Select Distinct(Name)AS TerminalName 
from vPTCreditCardTerminal

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

