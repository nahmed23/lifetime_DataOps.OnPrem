

--
-- returns membership counts
--
-- Parameters: a expiration date range
--

CREATE PROC dbo.mmsMembershipCompositionSummary_MembershipLength (
  @ExpireStartDate SMALLDATETIME,
  @ExpireEndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VR.Description RegionDescription, 
       C.ClubName, 
       COUNT(DISTINCT MS.MembershipID) MembershipID,
       DATEDIFF( month, ISNULL( MS.CreatedDateTime, M.JoinDate), MS.ExpirationDate) LengthInMonths, 
       SUBSTRING( STR( MS.CompanyID, 6, 0), 6, 1) CompanyIDFlag
  FROM dbo.vCLUB C
  JOIN dbo.vMembership MS
       ON C.ClubID=MS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID=C.ValRegionID
  JOIN dbo.vMember M
       ON MS.MembershipID=M.MembershipID
  JOIN dbo.vMembershipType MST 
       ON MST.MembershipTypeID=MS.MembershipTypeID
 WHERE MS.ExpirationDate BETWEEN @ExpireStartDate AND @ExpireEndDate AND
       M.ValMemberTypeID=1 AND
       MST.ShortTermMembershipFlag=0
 GROUP BY VR.Description, C.ClubName, 
       DATEDIFF( month, 
         ISNULL( MS.CreatedDateTime, M.JoinDate ),
         MS.ExpirationDate ), 
       SUBSTRING( STR( MS.CompanyID, 6, 0 ), 6, 1 )


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


