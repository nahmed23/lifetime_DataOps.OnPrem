




--
-- Returns Members and their usage counts by usage club who
--   use away clubs more than they use their home club
--
-- Parameters: a Clubname and a usage date range
--

CREATE PROC dbo.mmsMajorityusageexception_Usage (
  @ClubName VARCHAR(50),
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

-- select usage counts into temp table
SELECT AL1.MemberID, AL1.FirstName, AL1.LastName, VMT.Description MemberTypeDescription,
       AL5.ClubID MembershipClubID, P.Description ProductDescription, 
       AL5.ClubName MembershipClubName, AL4.ClubID UsageClubID,
       AL4.ClubName UsageClubName,
       SUM(CASE WHEN AL4.ClubID = AL5.ClubID THEN 1 ELSE 0 END) HomeUsageTally,
       SUM(CASE WHEN AL4.ClubID = AL5.ClubID THEN 0 ELSE 1 END) AwayUsageTally
  INTO #Usage
  FROM dbo.vMember AL1
  JOIN dbo.vMemberUsage AL2
       ON AL1.MemberID = AL2.MemberID
  JOIN dbo.vMembership AL3
       ON AL1.MembershipID = AL3.MembershipID
  JOIN dbo.vClub AL4
       ON AL2.ClubID = AL4.ClubID
  JOIN dbo.vClub AL5
       ON AL3.ClubID = AL5.ClubID
  JOIN dbo.vValMemberType VMT
       ON AL1.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vMembershipType MT
       ON AL3.MembershipTypeID = MT.MembershipTypeID
  JOIN dbo.vProduct P
       ON MT.ProductID = P.ProductID
 WHERE AL5.ClubName = @ClubName AND
       AL2.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate
 GROUP BY AL1.MemberID, AL1.FirstName, AL1.LastName, VMT.Description,
       AL5.ClubID, P.Description, AL5.ClubName, AL4.ClubID,
       AL4.ClubName
 ORDER BY AL1.MemberID

-- return usage tallies for Members who use away clubs more than their home club
SELECT *
  FROM #Usage
 WHERE MemberID IN (
SELECT MemberID
  FROM #Usage
 GROUP BY MemberID
HAVING SUM(HomeUsageTally) < SUM(AwayUsageTally)
)


DROP TABLE #Usage

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





