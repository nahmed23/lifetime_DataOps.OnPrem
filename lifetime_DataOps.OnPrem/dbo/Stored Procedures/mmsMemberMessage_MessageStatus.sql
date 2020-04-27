







--
-- Returns recordset of recordstatuss for the MemberMessage brio report
--
-- Parameters: a | separated list of clubs
--   a | separated list of message statuss
--   a start and end open date
--   a flag whether to use the dates or not
--

CREATE PROC dbo.mmsMemberMessage_MessageStatus (
  @ClubList VARCHAR(1000),
  @MessageStatusList VARCHAR(4000),
  @OpenStartDate SMALLDATETIME,
  @OpenEndDate SMALLDATETIME,
  @IgnoreDatesFlag INT
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubName VARCHAR(50))
--INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubList
   INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

CREATE TABLE #MessageStatuss (Description VARCHAR(50))
--INSERT INTO #MessageStatuss EXEC procParseStringList @MessageStatusList
   EXEC procParseStringList @MessageStatusList
   INSERT INTO #MessageStatuss (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

SELECT C.ClubName, MSM.MembershipID, MSM.OpenDateTime,
       MSM.CloseDateTime, VMS2.Description StatusDescription, M.FirstName,
       M.LastName, MSM.MembershipMessageID, M.MemberID,
       MSMT.Description MessageCodeDescription, MSM.ReceivedDateTime, 
       VR.Description RegionDescription,
       MSM.Comment, MSM.OpenDateTimeZone, MSM.CloseDateTimeZone,
       MSM.ReceivedDateTimeZone, MSM.OpenEmployeeID
  FROM dbo.vMembershipMessage MSM
  JOIN dbo.vValMessageStatus VMS2
       ON MSM.ValMessageStatusID = VMS2.ValMessageStatusID
  JOIN #MessageStatuss MSS
       ON VMS2.Description = MSS.Description
  JOIN dbo.vMembership MS
       ON MSM.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubName = CS.ClubName
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  LEFT JOIN dbo.vValMembershipMessageType MSMT
       ON (MSM.ValMembershipMessageTypeID = MSMT.ValMembershipMessageTypeID) 
 WHERE M.ValMemberTypeID = 1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       --C.ClubName IN (SELECT ClubName FROM #Clubs) AND
       --VMS2.Description IN (SELECT Description FROM #MessageStatuss) AND
       (MSM.OpenDateTime BETWEEN @OpenStartDate AND @OpenEndDate OR
       @IgnoreDatesFlag = 1) AND
       C.DisplayUIFlag = 1
       
DROP TABLE #Clubs
DROP TABLE #MessageStatuss
DROP TABLE #tmpList


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END








