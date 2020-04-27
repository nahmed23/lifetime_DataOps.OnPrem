





-- Returns a result set of unique Company names

CREATE    PROC dbo.mmsGetCompanies
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT distinct CompanyName, SUBSTRING(LTRIM(CompanyName),1,1) AS FirstCharacter,CompanyID,CorporateCode
  FROM dbo.vCompany
 WHERE CompanyName IS NOT NULL
 ORDER BY CompanyName

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






