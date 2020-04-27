


CREATE  PROC [dbo].[mmsGetPaymentTypes]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT vValPaymentType.Description,vValEFTAccountType.ValEFTAccountTypeID, vValEFTAccountType.Description EFTAccountTypeDescription
  FROM dbo.vValPaymentType
  JOIN dbo.vValEFTAccountType ON vValPaymentType.ValEFTAccountTypeID = vValEFTAccountType.ValEFTAccountTypeID
 WHERE vValPaymentType.ViewBankAccountTypeFlag = 1
 ORDER BY vValPaymentType.Description

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
