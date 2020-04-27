





--THIS PROCEDURE RETUNRS THE DETAILS OF Sports Non Access memberships sale attritions 
--FOR MONTH TO DAY Yesterday FOR ALL CLUBS.

CREATE PROCEDURE dbo.mmsDSSR_SportsNonAccessAllClubs
AS
BEGIN

  SET XACT_ABORT ON
  SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  EXEC mmsDSSR_SportsNonAccess ''

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END







