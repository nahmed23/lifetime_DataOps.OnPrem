



--
-- MemberStatusSummary_sport_sched.bqy
-- Returns records memberships with complete package sales
--   Filters out Fitness and Express memberships and terminated memberships
--

CREATE    PROC dbo.mmsSportsSched_CompletePkg
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, M.MemberID, C.ClubName,
       C.ClubID, MMST.PostDateTime, TI.ItemAmount,
       P.Description AS ProductDescription, P.ProductID
  FROM dbo.vMMSTran MMST
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P
       ON TI.ProductID = P.ProductID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vMembership MS
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vMembershipType MT
       ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID    
  JOIN dbo.vValMembershipStatus VMSS 
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
 WHERE P.ProductID IN (154,155,156,316,1143,1144,1145,1146,1147) AND --- Complete package product IDs
       MT. ValCheckInGroupID >= 43 AND  --- this check-in  level excludes Express and Fitness memberships
       VMSS.ValMembershipStatusID IN (2,3,4,5,6,7) AND --- all statuses except terminated
       MMST.TranVoidedID IS NULL

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




