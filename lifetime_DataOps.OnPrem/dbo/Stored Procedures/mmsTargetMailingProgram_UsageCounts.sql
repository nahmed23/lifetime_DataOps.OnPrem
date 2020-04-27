

--
-- returns Usage counts for memberships showing usage during a timespan
--   originally used for the TargetMailingProgram Brio bqy
--
-- Parameters: a | separated list of clubnames, A start and end usage date
--
-- EXEC dbo.mmsTargetMailingProgram_UsageCounts '10|164|11|174|3', '11/01/06', '11/08/06'
--
CREATE    PROC dbo.mmsTargetMailingProgram_UsageCounts (
  @ClubIDList VARCHAR(2000),
  @UsageStartDate SMALLDATETIME,
  @UsageEndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField Int)
CREATE TABLE #Clubs (ClubID Int)
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

SELECT M.MemberID, M.MembershipID, M.FirstName, M.LastName,
       COUNT(MU.MemberID) UsageCount
  FROM dbo.vMemberUsage MU
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
 WHERE MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate AND
       VMS.Description = 'Active' AND
       C.DisplayUIFlag = 1 AND
       M.ActiveFlag = 1
 GROUP BY M.MemberID, M.MembershipID, M.FirstName, M.LastName

DROP TABLE #Clubs
DROP TABLE #tmpList


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

