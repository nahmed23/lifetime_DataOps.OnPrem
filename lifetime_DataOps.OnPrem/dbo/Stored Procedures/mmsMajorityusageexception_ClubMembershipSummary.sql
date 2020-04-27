


--
-- Returns distinct count of memberships by club
--
-- Parameters: a Region
-- EXEC mmsMajorityusageexception_ClubMembershipSummary 'West-Minnesota'

CREATE PROC [dbo].[mmsMajorityusageexception_ClubMembershipSummary] (
  @RegionDescription VARCHAR(50)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VR.Description RegionDescription, C.ClubName, 
       COUNT (DISTINCT (MS.MembershipID)) Membershipid,
       MAX ( GETDATE() ) as Today_Sort,
  Replace(Substring(convert(varchar,MAX ( GETDATE() ),100),1,6)+', '+Substring(convert(varchar,MAX ( GETDATE() ),100),8,10)+' '+Substring(convert(varchar,MAX ( GETDATE() ),100),18,2),'  ',' ') as Today
  FROM dbo.vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
 WHERE VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       C.DisplayUIFlag = 1 AND
       VR.Description = @RegionDescription
 GROUP BY VR.Description, C.ClubName

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

