




--
-- MemberStatusSummary_sport_sched.bqy
--
-- 
--

CREATE   PROC dbo.mmsSportsSched_LTFSportUpgrade 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, M.MemberID, AL5.ClubName,
       AL5.ClubID, MMST.PostDateTime, TI.ItemAmount,
       P.Description AS ProductDescription, 
       P2.Description AS MembershipTypeDescription
  FROM dbo.vMMSTran MMST 
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P
       ON TI.ProductID = P.ProductID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vMembership MS
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vClub AL5
       ON MS.ClubID = AL5.ClubID     
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P2 
       ON MST.ProductID = P2.ProductID
 WHERE P.Description = 'LTF Sport Upgrade' AND
       VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       MMST.TranVoidedID IS NULL

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





