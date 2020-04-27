

--THIS PROCEDURE RETUNRS THE DETAILS OF MEMBERSHIP ATTRITIONS 
--IN THE CURRENT MONTH.

CREATE PROCEDURE [dbo].[mmsDSSR_MembershipAttritionsAllClubs_Obsolete]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

  EXEC mmsDSSR_MembershipAttritions 'All'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

