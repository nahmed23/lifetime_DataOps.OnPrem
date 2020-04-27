


--
-- gathers member information the date of birth range furnished
-- and member ussage statistics for the date range
-- parameters: Club, StartDate, EndDate
--

Create   PROC dbo.mmsMemberByAgeRange_21Usage (
  @ClubList VARCHAR(1000),
  @StartDOB         SMALLDATETIME,
  @EndDOB           SMALLDATETIME,
  @StartDate        SMALLDATETIME,
  @EndDate          SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (Clubname VARCHAR(50))

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
EXEC procParseStringList @ClubList
INSERT INTO #Clubs (Clubname) SELECT StringField FROM #tmpList

SELECT C.ClubID,C.ClubName,C.ValRegionID,C.DisplayUIFlag
INTO #ClubID
FROM #Clubs CS JOIN vClub C ON CS.CLubName = C.ClubName

SELECT DISTINCT C.ClubName,
       M.MemberID,
       VMT.Description AS Member_Type,
       M.ActiveFlag,
       MS.MembershipTypeID,
       VMST.Description AS Membership_Status,
       MS.ExpirationDate,
       M.DOB,
       DATEPART(dy, MU.UsageDateTime) AS Usage,
       MU.UsageDateTime,
       GETDATE() AS CurrentDate
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN #ClubID C
       ON MS.ClubID = C.ClubID
  LEFT JOIN vMemberUsage MU
       ON C.ClubID = MU.ClubID AND
       M.MemberID = MU.MemberID AND 
       MU.UsageDateTime > @StartDate AND 
       MU.UsageDateTime < @EndDate
  JOIN dbo.vValMembershipStatus VMST
       ON MS.ValMembershipStatusID = VMST.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
 WHERE M.DOB BETWEEN @StartDOB AND @EndDOB


DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


