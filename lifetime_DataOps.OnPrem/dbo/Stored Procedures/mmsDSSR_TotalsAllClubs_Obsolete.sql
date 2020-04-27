







--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIPS SOLD BY EACH MEMBERSHIPADVISOR 
--TILL YESTERDAY.

CREATE PROCEDURE [dbo].[mmsDSSR_TotalsAllClubs_Obsolete]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDSSR_Totals 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

