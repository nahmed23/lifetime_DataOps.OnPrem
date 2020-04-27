


--
-- Returns memberid communication preferences
--
-- Parameters: requiring a list of Memberid's
--
-- EXEC mmsMembershipCommunicationPreference '102234894|102234895'
CREATE          PROC dbo.mmsMembershipCommunicationPreference (
  @MemberIDList VARCHAR(5000)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(10))
CREATE TABLE #MemberIDs (MemberID VARCHAR(10))
EXEC procParseStringList @MemberIDList
INSERT INTO #MemberIDs (MemberID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList
  
SELECT CAST(MID.MemberID AS Int) As MemberID,
       CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 ELSE NULL END DoNotMailFlag,
       CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 ELSE NULL END DoNotPhoneFlag,
       CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1 ELSE NULL END DoNotEmailFlag
  FROM #MemberIDs MID
  LEFT JOIN dbo.vMember M
       ON MID.MemberID = M.MemberID
  LEFT JOIN dbo.vMembershipCommunicationPreference MCP
       ON M.MembershipID = MCP.MembershipID AND MCP.ActiveFlag = 1
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
  ORDER BY MID.MemberID

DROP TABLE #MemberIDs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




