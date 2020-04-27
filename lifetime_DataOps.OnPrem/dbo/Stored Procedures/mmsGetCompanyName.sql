

-- Returns a result set of unique Company names

CREATE         PROC dbo.mmsGetCompanyName(
 @CompanyName VARCHAR(50)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT CompanyName,CompanyID,AccountRepInitials
  FROM dbo.vCompany
Where CompanyName LIKE @CompanyName+'%' OR @CompanyName = ''
 ORDER BY CompanyName

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


