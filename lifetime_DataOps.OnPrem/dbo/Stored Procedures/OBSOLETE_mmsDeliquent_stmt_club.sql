


--
-- returns deliquent accounts per club within specified parameters 
--
-- Parameters: clubname
--

CREATE    PROC dbo.[OBSOLETE_mmsDeliquent_stmt_club] (
  @ClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubIDList <> 'All'
BEGIN
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES('All') 
END
SELECT TB.MembershipID, MMS.TranDate, TB.TranBalanceAmount,
       P.Description AS ProductDescription, MMS.MemberID, 
       VTT.Description AS TranTypeDescription,
       VR.Description AS RegionDescription, C.ClubName, 
       VMSS.Description AS MembershipStatusDescription,
       MMS.DrawerActivityID, TI.TranItemID, GETDATE() AS RunDate,
       VTR.Description AS TerminationReasonDescription
  FROM dbo.vClub C
  JOIN #Clubs CS 
       ON C.ClubID = CS.ClubID OR CS.ClubID = 'All'
--  JOIN #Clubs CS 
--       ON C.ClubName = CS.ClubName OR CS.ClubName = 'All'
  JOIN dbo.vMembership M
       ON M.ClubID = C.ClubID  
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValMembershipStatus VMSS
       ON M.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vMembershipBalance MSB
       ON M.MembershipID = MSB.MembershipID
  JOIN dbo.vTranBalance TB
       ON TB.MembershipID = M.MembershipID
  LEFT OUTER JOIN dbo.vTranItem TI 
       ON (TB.TranItemID = TI.TranItemID) 
  LEFT OUTER JOIN dbo.vMMSTran MMS 
       ON (TI.MMSTranID = MMS.MMSTranID) 
  LEFT OUTER JOIN dbo.vValTranType VTT 
       ON (VTT.ValTranTypeID = MMS.ValTranTypeID) 
  LEFT OUTER JOIN dbo.vProduct P 
       ON (P.ProductID = TI.ProductID) 
  LEFT OUTER JOIN dbo.vValTerminationReason VTR 
       ON (M.ValTerminationReasonID = VTR.ValTerminationReasonID)
 WHERE TB.TranBalanceAmount>0 AND
       --(C.ClubName IN (SELECT ClubName FROM #Clubs) OR
       --@ClubList = 'All') AND
       VMSS.Description IN ('Active', 'Pending Termination', 'Suspended') AND
       MSB.CommittedBalance>0 
 ORDER BY TB.MembershipID

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



