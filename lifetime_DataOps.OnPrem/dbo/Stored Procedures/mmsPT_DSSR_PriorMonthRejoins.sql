



--
-- Returns detail on all Initiation Fee-Rejoin transactions in the prior month,
-- including the member IDs of all the active members on these rejoin memberships.
-- This is used to determine rejoin members
--
--

CREATE            PROC dbo.mmsPT_DSSR_PriorMonthRejoins 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
  DECLARE @FirstOfCurrentMonth AS DATETIME
  DECLARE @FirstOfPriorMonth AS DATETIME

  SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
  SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT RS.PostingClubid, RS.MembershipID, RS.ProductID, RS.ItemAmount, M.MemberID, RS.PostDateTime,
       M.JoinDate AS OriginalJoinDate, @FirstOfPriorMonth AS ReportingMonth
FROM vMembership MS
    JOIN vMMSRevenueReportSummary RS
       ON RS.MembershipID=MS.MembershipID
    JOIN  vMember M
       ON MS.MembershipID=M.MembershipID
WHERE RS.PostDateTime >=@FirstOfPriorMonth AND 
      RS.PostDateTime < @FirstOfCurrentMonth AND 
      M.ActiveFlag=1 AND 
      M.ValMemberTypeID IN (1, 2, 3) AND 
      RS.ProductID=286 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END




