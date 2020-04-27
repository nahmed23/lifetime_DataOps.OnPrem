

--
-- Returns a count of memberships at a each club
--

CREATE PROC dbo.mmsSportsSched_MonthToDateJoins
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT MS.ClubID, C.ClubName, COUNT (DISTINCT (MS.MembershipID))
    FROM dbo.vMembership MS
    JOIN dbo.vClub C
         ON MS.ClubID = C.ClubID
    JOIN dbo.vMember M
         ON M.MembershipID = MS.MembershipID
    JOIN dbo.vMembershipType MST
         ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P 
         ON MST.ProductID = P.ProductID
   WHERE M.ValMemberTypeID = 1 AND
         M.JoinDate > =  cast(DATEPART(month,GETDATE()) as varchar(2))
           +'/01/'
           + cast(DATEPART(year,GETDATE()) as varchar(4)) AND
         (NOT (P.Description LIKE '%Employee%' 
         OR P.Description LIKE '%Old Fitness%' 
         OR P.Description LIKE '%Short%' 
         OR P.Description LIKE '%Trade%'))
   GROUP BY MS.ClubID, C.ClubName


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



