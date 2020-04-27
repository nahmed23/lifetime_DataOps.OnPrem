

-- Returns a result set of unique regions

CREATE  PROC [dbo].[mmsGetRegions]
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT distinct R.ValRegionID, R.Description
FROM dbo.vValRegion R
	JOIN vClub C ON C.ValRegionID = R.ValRegionID
WHERE  C.ClubActivationDate is not Null and C.ClubDeActivationDate is Null
ORDER BY R.Description


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity



