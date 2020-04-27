




--
-- returns initiation fee exception information for a given dollar amount range and date range
--
-- Parameters: a range of member join dates and a range of dollar amounts
--

CREATE PROC dbo.mmsIFException_EnrollmentFeeException (
  @StartJoinDate SMALLDATETIME,
  @EndJoinDate SMALLDATETIME,
  @StartItemAmt MONEY,
  @EndItemAmt MONEY
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT R.Description RegionDescription, C.ClubName [Club Name], 
       E.FirstName [Advisor First Name], E.LastName [Advisor Last Name], 
       M.FirstName [Member First Name], M.LastName [Member Last Name],
       M.MemberID [Member ID], M.JoinDate [Join Date], 
       CO.CompanyName [Company Name], CO.CorporateCode [Corporate Code], 
       TI.ItemAmount, TT.Description TranTypeDescription, 
       P2.Description MembershipTypeDescription
  FROM dbo.vClub C
  JOIN dbo.vValRegion R
    ON R.ValRegionID = C.ValRegionID
  JOIN dbo.vMembership MS
    ON C.ClubID=MS.ClubID
  JOIN dbo.vMember M
    ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValMemberType MT
    ON M.ValMemberTypeID = MT.ValMemberTypeID
  JOIN dbo.vMMSTran MMST
    ON MS.MembershipID = MMST.MembershipID
  JOIN dbo.vValTranType TT
    ON TT.ValTranTypeID=MMST.ValTranTypeID
  JOIN dbo.vMembershipType MST
    ON MST.MembershipTypeID = MS.MembershipTypeID
  JOIN dbo.vProduct P2
    ON MST.ProductID = P2.ProductID
  JOIN dbo.vTranItem TI
    ON TI.MMSTranID = MMST.MMSTranID
  JOIN dbo.vProduct P
    ON TI.ProductID = P.ProductID
  LEFT OUTER JOIN dbo.vEmployee E
    ON MS.AdvisorEmployeeID = E.EmployeeID
  LEFT OUTER JOIN dbo.vCompany CO
    ON MS.CompanyID = CO.CompanyID    
 WHERE M.JoinDate BETWEEN @StartJoinDate AND @EndJoinDate AND
       P.Description='Initiation Fee' AND
       TT.Description IN ('Charge', 'Sale') AND
       TI.ItemAmount BETWEEN @StartItemAmt AND @EndItemAmt AND
       MMST.TranVoidedID IS NULL AND 
       MT.Description='Primary'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





