




--
-- MemberStatusSummary_sport_sched.bqy
-- Count of total club memberships
-- 
--

CREATE  PROC dbo.mmsSportsSched_ClubMemberCount 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName, Count (MS.MembershipID) AS MembershipCount, C.ClubID
  FROM dbo.vMembership MS
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValMembershipStatus VMSS 
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
 WHERE VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')
 GROUP BY C.ClubName, C.ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





