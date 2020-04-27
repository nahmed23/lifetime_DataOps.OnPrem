







-- Returns a YTD recordset used in the CancelationReasons Brio document in the qSummary section
-- 

CREATE  PROC dbo.mmsCancelationReasons_Summary
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT M.CancellationRequestDate,
       GETDATE() AS RunDate,
       R.Description AS RegionDescription,
       C.ClubName,
       M.MembershipID,
       TR.Description AS TerminationDescription,
       M.ExpirationDate,
       CO.CorporateCode 
  FROM dbo.vMembership M
  JOIN dbo.vClub C
       ON M.ClubID = C.ClubID
  JOIN dbo.vValRegion R
       ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vValTerminationReason TR 
       ON M.ValTerminationReasonID = TR.ValTerminationReasonID
  LEFT JOIN dbo.vCompany CO
       ON M.CompanyID = CO.CompanyID
 WHERE DATEDIFF(year,M.CancellationRequestDate,GETDATE()) = 0 AND
       M.CancellationRequestDate <= GETDATE()




-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity




