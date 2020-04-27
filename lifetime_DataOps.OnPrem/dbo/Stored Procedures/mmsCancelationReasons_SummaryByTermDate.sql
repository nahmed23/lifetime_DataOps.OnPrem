








-- Returns a YTD recordset used in the CancelationReasons Brio document in the qSummaryByTermDate section
-- 

CREATE   PROC dbo.mmsCancelationReasons_SummaryByTermDate
AS
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT M.ExpirationDate,
       GETDATE() AS RunDate,
       R.Description AS RegionDescription,
       C.ClubName,
       M.MembershipID,
       TR.Description AS TerminationDescription,
       P.Description AS ProductDescription,
       M.CancellationRequestDate,
       MS.Description AS MembershipStatusDescription,
       CO.CorporateCode 
  FROM dbo.vMembership M
  JOIN dbo.vClub C
       ON M.ClubID = C.ClubID
  JOIN dbo.vValRegion R
       ON C.ValRegionID = R.ValRegionID
  JOIN dbo.vValTerminationReason TR
       ON M.ValTerminationReasonID = TR.ValTerminationReasonID
  JOIN dbo.vMembershipType MT
       ON M.MembershipTypeID = MT.MembershipTypeID
  JOIN dbo.vProduct P
       ON MT.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus MS 
       ON M.ValMembershipStatusID = MS.ValMembershipStatusID
  LEFT JOIN dbo.vCompany CO
       ON M.CompanyID = CO.CompanyID
 WHERE DATEDIFF(year,M.ExpirationDate,GETDATE()) = 0 AND
       M.ExpirationDate <= GETDATE()




-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity



