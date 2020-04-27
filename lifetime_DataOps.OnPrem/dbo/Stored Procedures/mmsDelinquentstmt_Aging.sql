


--
-- returns deliquent accounts per club within specified parameters 
--
-- Parameters: A | separated list MemberIDs
-- EXEC mmsDelinquentstmt_Aging '102105010', '10', 'May 1, 2011'

CREATE         PROC [dbo].[mmsDelinquentstmt_Aging] (
  @MemberIDList VARCHAR(8000),
  @ClubIDList VARCHAR(2000),
  @CancellationRequestDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #MemberIDs (MemberID INT)
if @MemberIDList = 'NPT' 
begin
  CREATE TABLE #Clubs (ClubID VARCHAR(15))
--INSERT INTO #Clubs EXEC procParseStringList @ClubList
  EXEC procParseStringList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
INSERT INTO #MemberIDs (MemberID)
SELECT M.MemberID
  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
--  JOIN #Clubs CS
--       ON C.ClubName = CS.ClubName
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vValTerminationReason VTR 
       ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
 WHERE --C.ClubName IN (SELECT ClubName FROM #Clubs) AND
       MS.CancellationRequestDate = @CancellationRequestDate AND
       M.ValMemberTypeID = 1 AND
       VMS.Description = 'Pending Termination' AND
       VTR.Description = 'Non-Payment Terms' AND
       C.DisplayUIFlag = 1

DROP TABLE #Clubs

END

ELSE

BEGIN
--INSERT INTO #MemberIDs EXEC procParseIntegerList @MemberIDList
  EXEC procParseStringList @MemberIDList
  INSERT INTO #MemberIDs (MemberID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
END 

SELECT TB.MembershipID, MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) as TranDate,
       P.Description ProductDescription, MMST.MemberID, TB.TranBalanceAmount, VTT.Description TranTypeDescription,
       VR.Description RegionDescription, C.ClubName, VMS.Description MembershipStatusDescription,
       MMST.DrawerActivityID, TI.TranItemID, M.MemberID UISelectedMemberID,
       GETDATE() as RunDate_Sort,
	   Replace(SubString(Convert(Varchar, GETDATE()),1,3)+' '+LTRIM(SubString(Convert(Varchar, GETDATE()),5,DataLength(Convert(Varchar, GETDATE()))-12)),' '+Convert(Varchar,Year(GETDATE())),', '+Convert(Varchar,Year(GETDATE()))) as RunDate

  FROM dbo.vClub C
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON M.MembershipID = TB.MembershipID
  JOIN #MemberIDs MI
       ON M.MemberID = MI.MemberID
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN dbo.vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN dbo.vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID
  LEFT JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  LEFT JOIN dbo.vProduct P
       ON P.ProductID = TI.ProductID 
 WHERE TB.TranBalanceAmount > 0 AND
       --M.MemberID IN (SELECT MemberID FROM #MemberIDs) AND
       MSB.CommittedBalance > 0
       
DROP TABLE #MemberIDs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

