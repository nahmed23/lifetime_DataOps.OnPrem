




--
-- Returns a set of tran records for the topmembershiprevenue bqy
-- 
-- Parameters include ClubName 
--

CREATE   PROC dbo.mmsTopMembership_DetailTopMembershipRevenue (
  @ClubName VARCHAR(50)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #Memberships (MembershipID INT)
INSERT INTO #Memberships EXEC mmsTopMembership_Revenue_MembershipIDs @ClubName

SELECT MMST.MembershipID, TI.ItemAmount, P2.Description ProductDescription, 
       C1.ClubName MembershipClubname, VR.Description MembershipRegion, 
       P.Description MembershipTypeDescription, 
       VMS.Description MembershipStatusDescription, 
       M2.FirstName TranMemberFirstname, M2.LastName TranMemberLastname, 
       M.MemberID PrimaryMemberid, M.FirstName PrimaryFirstname, M.LastName PrimaryLastname, 
       VTT.Description TranTypeDescription, M.JoinDate PrimaryJoinDate, MMST.PostDateTime, 
       C2.ClubName TranClubname, MMST.ClubID TranClubid
  FROM dbo.vMMSTran MMST
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P2
       ON TI.ProductID = P2.ProductID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C1
       ON MS.ClubID = C1.ClubID
  JOIN dbo.vValRegion VR
       ON C1.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON P.ProductID = MST.ProductID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vMember M2
       ON M2.MemberID = MMST.MemberID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN dbo.vClub C2 
       ON C2.ClubID = MMST.ClubID
  JOIN #Memberships TMP1
       ON MS.MembershipID = TMP1.MembershipID
 WHERE DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 1 AND 
       MMST.TranVoidedID IS NULL AND 
       M.ValMemberTypeID = 1 AND 
       C2.ClubName IN (@ClubName, 'Corporate INTERNAL', 'Corporate IT Dept', 'EFT INTERNAL', 'Legacy Conversion') AND
       MS.MembershipID IN (SELECT MembershipID FROM #Memberships)


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






