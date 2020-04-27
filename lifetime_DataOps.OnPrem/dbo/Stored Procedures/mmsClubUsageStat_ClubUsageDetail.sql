


--
-- Returns Usage details per usage
--
-- Parameters: a usage date range and a clubname
--

-- EXEC dbo.mmsClubUsageStat_ClubUsageDetail 'Gilbert, AZ', '2/1/06 12:00 AM', '2/28/06 11:59 PM'

CREATE      PROC dbo.mmsClubUsageStat_ClubUsageDetail (
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

SELECT C.ClubName, MU.UsageDateTime, VMT.Description MemberTypeDescription,
       M.MemberID, M.FirstName, M.LastName,
       MU.MemberUsageID, M.Gender, M.MembershipID, M.DOB,
       Age =
       Case When Month(M.DOB) <= Month(MU.UsageDateTime) Then DateDiff(Year, M.DOB, MU.UsageDateTime)
       Else DateDiff(Year, M.DOB, MU.UsageDateTime) - 1
       End
--       DateDiff(Year, M.DOB, MU.UsageDateTime) Age
  FROM dbo.vClub C
  JOIN dbo.vMemberUsage MU
       ON MU.ClubID = C.ClubID
  JOIN dbo.vMember M
       ON MU.MemberID = M.MemberID
  JOIN dbo.vValMemberType VMT
       ON VMT.ValMemberTypeID = M.ValMemberTypeID
 WHERE C.ClubName = @ClubName AND
       MU.UsageDateTime BETWEEN @UsageStartDate AND @UsageEndDate AND
       C.DisplayUIFlag = 1

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



