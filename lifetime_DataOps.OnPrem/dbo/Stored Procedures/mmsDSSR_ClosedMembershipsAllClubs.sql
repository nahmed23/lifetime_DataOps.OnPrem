



--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP SOLD
--FOR MONTH TO DAY TILL YESTERDAY FOR All CLUBS.

CREATE  PROCEDURE dbo.mmsDSSR_ClosedMembershipsAllClubs
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDSSR_ClosedMemberships 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




