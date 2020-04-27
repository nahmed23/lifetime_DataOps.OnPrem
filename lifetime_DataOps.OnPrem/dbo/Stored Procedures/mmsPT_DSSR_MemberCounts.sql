
--
-- returns Member Count by Member type within Club
--
--

CREATE          PROC [dbo].[mmsPT_DSSR_MemberCounts] 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfPriorMonth DATETIME
DECLARE @FirstOfCurrentMonth DATETIME

SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName, Count (M.MemberID) AdultMemberCount,
       C.ClubID,@FirstOfPriorMonth NewAdultMember_JoinDateCalc,
       SUM( CASE
            WHEN M.JoinDate >= @FirstOfPriorMonth AND
                 M.JoinDate < @FirstOfCurrentMonth
            THEN 1
            ELSE 0
            END) NewAdultMemberCount_JoinedLastMonth,
       SUM(CASE
           WHEN M.ValMemberTypeID = 1
           THEN 1 
           ELSE 0
           END) UniqueMembershipCount
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
 WHERE (MS.ExpirationDate > @FirstOfCurrentMonth OR MS.ExpirationDate IS Null)
        AND M.ActiveFlag = 1
		AND M.ValMemberTypeID in (1,2,3)
        AND MS.ValMembershipStatusID <> 3 ----- Membership is not in Suspended status
GROUP BY C.ClubName, C.ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
