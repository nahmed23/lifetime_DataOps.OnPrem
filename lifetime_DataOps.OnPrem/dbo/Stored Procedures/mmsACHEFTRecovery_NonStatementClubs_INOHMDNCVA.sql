
/* 2 */
CREATE   PROC [dbo].[mmsACHEFTRecovery_NonStatementClubs_INOHMDNCVA]
AS
BEGIN

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

DECLARE @RegionList VARCHAR(1000)
SELECT @RegionList = STUFF((SELECT DISTINCT '|'+Description
                              FROM vValRegion
                             WHERE ValRegionID NOT IN (15,17,20,22,23,26,27,28,29,32,33,35,36,37)
                               FOR XML PATH('')),1,1,'')

 EXEC dbo.mmsACHEFTRecovery @RegionList, 'Commercial Checking EFT|Individual Checking|Savings Account'

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
