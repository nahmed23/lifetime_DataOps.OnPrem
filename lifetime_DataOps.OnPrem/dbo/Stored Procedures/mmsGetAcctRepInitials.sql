


-- Returns a result set of unique Corporate Account Rep Initials

CREATE        PROC dbo.mmsGetAcctRepInitials
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON 

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

   SELECT DISTINCT AccountRepInitials 
      FROM vCompany 
     WHERE AccountRepInitials IS NOT NULL
     ORDER BY AccountRepInitials

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





