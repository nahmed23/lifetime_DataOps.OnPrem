





--
-- This procedure returns transacton data for the current day's sales of "Initiation Fee - Rejoin" and 
-- Membership data related to these rejoin members
-- 4/2007 modification - users wanted to be able review the full day's business even after midnight, but at that time
-- the report was then displaying only transactions since midnight for the new day. Users decided to start displaying
-- the new day's transactions only after 6:00 am
--

CREATE               PROCEDURE dbo.mmsTodaysBusiness_POSTransactions 

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @ToDay DATETIME
  DECLARE @Yesterday DATETIME
  DECLARE @ToDayPlus_SixHrs DATETIME
  DECLARE @QueryDateTime DATETIME
  SET @ToDay  = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102) 
  SET @Yesterday  = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @ToDayPlus_SixHrs = DATEADD(hh,6, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @QueryDateTime = GETDATE()

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @QueryDateTime >= @ToDayPlus_SixHrs
     
  BEGIN
 SELECT MT.MembershipID, MT.PostDateTime, M.MemberID,C.ClubID AS TranClubID,C.ClubName AS TranClub, P.Description ProductDescription,
         P1.Description MembershipTypeDescription,M.FirstName PrimaryMemberFirstName,
         M.LastName PrimaryMemberLastName,C1.ClubID AS MembershipClubID,C1.ClubName AS MembershipClub,MS.CreatedDateTime,E1.FirstName AdvisorFirstName,
         E1.LastName AdvisorLastName,TI.ItemAmount,P.ProductID, M.JoinDate, P.DepartmentID,P.AllowZeroDollarFlag,
         CSC.CommissionCount, E.FirstName CommEmployeeFirstName,MT.TranVoidedID,
         E.LastName CommEmployeeLastName,MS.CompanyID,TI.Quantity, MS.ExpirationDate,MT.MMSTranID,
         E.EmployeeID CommEmployeeID, E1.EmployeeID AdvisorEmployeeID, VTT.Description AS TranType, RC.Description AS TranReason,
         CASE
           WHEN M.EmailAddress IS NULL THEN 0
           WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
         ELSE 1
         END Email_OnFile_Flag, @Yesterday AS Yesterday, @QueryDateTime AS QueryDateTime,@Today AS RejoinsReportDate
    FROM dbo.vMMSTran MT 
    JOIN dbo.vTranItem TI ON MT.MMSTranID = TI.MMSTranID
    JOIN dbo.vProduct P ON TI.ProductID = P.ProductID
    JOIN dbo.vMembership MS ON MS.MembershipID = MT.MembershipID
    JOIN dbo.vClub C1 ON C1.ClubID = MS.ClubID
    JOIN dbo.vMember M ON MS.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P1 ON MST.ProductID = P1.ProductID
    JOIN dbo.vEmployee E1 ON MS.AdvisorEmployeeID = E1.EmployeeID
    JOIN dbo.vClub C ON C.ClubID = MT.ClubID
    JOIN dbo.vValTranType VTT ON MT.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vReasonCode RC ON MT.ReasonCodeID = RC.ReasonCodeID
    LEFT OUTER JOIN dbo.vCommissionSplitCalc CSC ON TI.TranItemID = CSC.TranItemID 
    LEFT OUTER JOIN dbo.vSaleCommission SC ON TI.TranItemID = SC.TranItemID
    LEFT OUTER JOIN dbo.vEmployee E ON SC.EmployeeID = E.EmployeeID 

   WHERE MT.PostDateTime >= @ToDay AND
         MT.TranVoidedID IS NULL AND
         P.Productid = 286 AND
         M.ValMemberTypeID = 1
END

ELSE

BEGIN
 SELECT MT.MembershipID, MT.PostDateTime, M.MemberID,C.ClubID AS TranClubID,C.ClubName AS TranClub, P.Description ProductDescription,
         P1.Description MembershipTypeDescription,M.FirstName PrimaryMemberFirstName,
         M.LastName PrimaryMemberLastName,C1.ClubID AS MembershipClubID,C1.ClubName AS MembershipClub,MS.CreatedDateTime,E1.FirstName AdvisorFirstName,
         E1.LastName AdvisorLastName,TI.ItemAmount,P.ProductID, M.JoinDate, P.DepartmentID,P.AllowZeroDollarFlag,
         CSC.CommissionCount, E.FirstName CommEmployeeFirstName,MT.TranVoidedID,
         E.LastName CommEmployeeLastName,MS.CompanyID,TI.Quantity, MS.ExpirationDate,MT.MMSTranID,
         E.EmployeeID CommEmployeeID, E1.EmployeeID AdvisorEmployeeID, VTT.Description AS TranType, RC.Description AS TranReason,
         CASE
           WHEN M.EmailAddress IS NULL THEN 0
           WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
         ELSE 1
         END Email_OnFile_Flag, @Yesterday AS Yesterday, @QueryDateTime AS QueryDateTime,@Yesterday AS RejoinsReportDate
    FROM dbo.vMMSTran MT 
    JOIN dbo.vTranItem TI ON MT.MMSTranID = TI.MMSTranID
    JOIN dbo.vProduct P ON TI.ProductID = P.ProductID
    JOIN dbo.vMembership MS ON MS.MembershipID = MT.MembershipID
    JOIN dbo.vClub C1 ON C1.ClubID = MS.ClubID
    JOIN dbo.vMember M ON MS.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P1 ON MST.ProductID = P1.ProductID
    JOIN dbo.vEmployee E1 ON MS.AdvisorEmployeeID = E1.EmployeeID
    JOIN dbo.vClub C ON C.ClubID = MT.ClubID
    JOIN dbo.vValTranType VTT ON MT.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vReasonCode RC ON MT.ReasonCodeID = RC.ReasonCodeID
    LEFT OUTER JOIN dbo.vCommissionSplitCalc CSC ON TI.TranItemID = CSC.TranItemID 
    LEFT OUTER JOIN dbo.vSaleCommission SC ON TI.TranItemID = SC.TranItemID
    LEFT OUTER JOIN dbo.vEmployee E ON SC.EmployeeID = E.EmployeeID 

   WHERE MT.PostDateTime >= @Yesterday AND
         MT.PostDateTime < @ToDay AND
         MT.TranVoidedID IS NULL AND
         P.Productid = 286 AND
         M.ValMemberTypeID = 1


  END

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





