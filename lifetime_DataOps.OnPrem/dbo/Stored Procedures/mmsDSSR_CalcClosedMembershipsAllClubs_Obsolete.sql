

--THIS PROCEDURE RETUNRS THE DETAILS OF COMMISSION FOR MAs FOR MEMBERSHIPS SOLD 
--FOR MONTH TO DAY TILL YESTERDAY FOR ALL CLUBS.

CREATE PROCEDURE [dbo].[mmsDSSR_CalcClosedMembershipsAllClubs_Obsolete]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDSSR_CalcClosedMemberships 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

