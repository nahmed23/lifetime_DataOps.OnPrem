






--
-- Returns recordset of record types for the MemberMessage brio report
--
-- Parameters: a | separated list of message statuss
--   a | separated list of Message types
--   a start and end open date
--   a flag whether to use the dates or not
--

CREATE  PROC dbo.mmsMemberMessage_MessageType (
  @MessageStatusList VARCHAR(4000),
  @MessageTypeList VARCHAR(4000),
  @OpenStartDate SMALLDATETIME,
  @OpenEndDate SMALLDATETIME
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
CREATE TABLE #MessageStatuss (Description VARCHAR(50))
--INSERT INTO #MessageStatuss EXEC procParseStringList @MessageStatusList
EXEC procParseStringList @MessageStatusList
INSERT INTO #MessageStatuss (Description) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MessageTypes (Description VARCHAR(50))
--INSERT INTO #MessageTypes EXEC procParseStringList @MessageTypeList
EXEC procParseStringList @MessageTypeList
INSERT INTO #MessageTypes (Description) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT VMMT.Description MessageTypeDescription, M.MemberID, M.FirstName,
       M.LastName, MSM.Comment, M.JoinDate,
       MSM.OpenDateTime, VMGS.Description MessageStatusDescription, 
       VMS.Description MembershipStatusDescription,
       C.ClubName, E1.FirstName AdvisorFirstname, E1.LastName AdvisorLastname,
       EMP.EmployerName, MSM.ReceivedDateTime, MSM.OpenDateTimeZone,
       MSM.ReceivedDateTimeZone, E2.FirstName OpenEmployeeFirstname, 
       E2.LastName OpenEmployeeLastname, VMGS.ValMessageStatusID, M.MembershipID
  FROM dbo.vMembershipMessage MSM
  JOIN dbo.vMember M
       ON M.MembershipID = MSM.MembershipID
  JOIN dbo.vValMembershipMessageType VMMT
       ON MSM.ValMembershipMessageTypeID = VMMT.ValMembershipMessageTypeID
  JOIN #MessageTypes MT
       ON VMMT.Description = MT.Description
  JOIN dbo.vValMessageStatus VMGS
       ON MSM.ValMessageStatusID = VMGS.ValMessageStatusID
  JOIN #MessageStatuss MSS
       ON VMGS.Description = MSS.Description
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vEmployee E1
       ON MS.AdvisorEmployeeID = E1.EmployeeID
  JOIN dbo.vEmployee E2
       ON MSM.OpenEmployeeID = E2.EmployeeID
  LEFT JOIN dbo.vEmployer EMP
       ON M.EmployerID = EMP.EmployerID
 WHERE MSM.OpenDateTime BETWEEN @OpenStartDate AND @OpenEndDate AND
      -- VMMT.Description IN (SELECT Description FROM #MessageTypes) AND
       M.ValMemberTypeID = 1 --AND
      -- VMGS.Description IN (SELECT Description FROM #MessageStatuss)
       
DROP TABLE #MessageStatuss
DROP TABLE #MessageTypes
DROP TABLE #tmpList


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END







