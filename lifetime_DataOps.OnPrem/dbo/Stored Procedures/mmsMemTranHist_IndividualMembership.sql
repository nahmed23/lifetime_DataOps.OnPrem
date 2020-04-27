

--
-- returns Member transactions for a given Membership
--
-- Parameters: A single MembershipID
--     a start and end transaction date
--

CREATE    PROC dbo.mmsMemTranHist_IndividualMembership (
  @MemberIDList VARCHAR(1000),
  @TranStartDate SMALLDATETIME,
  @TranEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  CREATE TABLE #tmpList (StringField INT)
  EXEC procParseIntegerList @MemberIDList

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT VR.Description RegionDescription, C.ClubName, M2.FirstName PrimaryFirstName,
         M2.LastName PrimaryLastName, M2.MemberID PrimaryMemberid, M3.MemberID TranMemberid,
         M3.FirstName TranMemberFirstName, M3.LastName TranMemberLastName, MMST.TranDate,
         P.Description ProductDescription, VTT.Description TranTypeDescription, MMST.DrawerActivityID,
         MMST.POSAmount, MMST.TranAmount, MMST.PostDateTime,
         TI.TranItemID, M.MemberID, VMT.Description TranMemberTypeDesc,
         TI.ItemAmount, TI.ItemSalesTax, MMST.MMSTranID
    FROM dbo.vClub C
    JOIN dbo.vValRegion VR
         ON VR.ValRegionID = C.ValRegionID
    JOIN dbo.vMMSTran MMST
         ON C.ClubID = MMST.ClubID
    JOIN dbo.vMember M2
         ON MMST.MembershipID = M2.MembershipID
    JOIN dbo.vMember M3
         ON M3.MemberID = MMST.MemberID
    JOIN dbo.vValTranType VTT
         ON VTT.ValTranTypeID = MMST.ValTranTypeID
    JOIN dbo.vMember M
         ON M.MembershipID = MMST.MembershipID
    JOIN dbo.vValMemberType VMT
         ON VMT.ValMemberTypeID = M3.ValMemberTypeID
    LEFT JOIN dbo.vTranItem TI
         ON MMST.MMSTranID = TI.MMSTranID
    LEFT JOIN dbo.vProduct P
         ON P.ProductID = TI.ProductID
   WHERE M.MemberID IN (SELECT StringField FROM #tmpList) AND
         M2.ValMemberTypeID = 1 AND
         MMST.TranDate BETWEEN @TranStartDate AND @TranEndDate AND
         MMST.TranVoidedID IS NULL
  
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



