




----
----  This query returns the counts of non-Junior members who have joined since
----  the beginning of the prior calendar month. For the DSSR, this count is used
----  as the denominator in the calculation of the Body Age - Show %
----

CREATE   PROCEDURE [dbo].[mmsDSSR_NewMemberCount]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfLastMonth DATETIME

SET @FirstOfLastMonth = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-1, GETDATE() - DAY(GETDATE()-1)),110),110)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT C.ClubName, C.ClubID, Count (M.MemberID) AS NewNonJrMemberCount
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID

 WHERE M.JoinDate >= @FirstOfLastMonth
   AND M.ValMemberTypeID in(1,2,3) ----- no Jr. Members
GROUP BY C.ClubName,C.ClubID
Order by C.ClubID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END 



