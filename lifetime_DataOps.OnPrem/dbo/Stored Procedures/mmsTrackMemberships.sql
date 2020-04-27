

--
-- Returns a set of memberships details that are set up for tracking.
-- 
--

CREATE   PROC dbo.mmsTrackMemberships----(@MembershipGroup SMALLINT)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, C.ClubName, 
       VMSS.Description AS StatusDescription,
       P.Description AS MembershipTypeDescription, 
       MS.ExpirationDate,MembershipGroup AS TrackingMembershipGroup
  FROM dbo.vClub C 
  JOIN dbo.vMembership MS
       ON C.ClubID = MS.ClubID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMSS 
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vMembershipTrack VMT
       ON MS.MembershipID = VMT.MembershipID
 -----WHERE VMT.MembershipGroup = @MembershipGroup

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


