





----
---- Returns Employee dues related transactions posted during a selected period and 
---- membership data related to these employee members
----


CREATE      PROC dbo.mmsEmployeeDuesAnalysis(
    @StartDate DateTime,
    @EndDate DateTime
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

---- To find if, and at what rate, membership dues are taxed at each club 

Select CPTR.ClubID, CPTR.ProductID, SUM(TR.TaxPercentage)AS TaxPercentage
INTO #T1
FROM vClubProductTaxRate CPTR
 JOIN vTaxRate TR
 ON CPTR.TaxRateID = TR.TaxRateID
WHERE CPTR.ProductID IN(94,171,890,1875)----Athletic-Single,Sports-Single,Fitness-Single,Advantage-Single
GROUP BY CPTR.ClubID,CPTR.ProductID

Select ClubID,MAX(TaxPercentage)AS DuesTaxPercentage
INTO #T2
FROM #T1
Group By ClubID





SELECT R.Description AS RegionDescription, C.ClubID AS TransactionClubID, C.ClubName AS TransactionClubName, 
P2.Description AS ProductDescription, P.Description AS MembershipTypeDescription, M.MemberID, 
M.FirstName, M.LastName, TI.ItemAmount, TI.ItemSalesTax, TT.Description AS TranTypeDescription, 
MMST.PostDateTime, E.EmployeeID,E.ActiveStatusFlag As EmployeeActiveStatusFlag, 
MS.ExpirationDate AS MembershipExpirationDate, T2.DuesTaxPercentage, @StartDate AS ReportStartDate,
@EndDate AS ReportEndDate, TI.TranItemID

FROM vMMSTran  MMST
     JOIN vMember M
         ON MMST.MemberID=M.MemberID
    JOIN vTranItem TI
         ON  MMST.MMSTranID=TI.MMSTranID 
    JOIN vMembership MS
         ON M.MembershipID=MS.MembershipID
    JOIN vMembershipType MST
         ON MS.MembershipTypeID=MST.MembershipTypeID
    JOIN vProduct P
         ON MST.ProductID=P.ProductID
    JOIN vProduct P2
         ON TI.ProductID=P2.ProductID
    JOIN vCLUB C
         ON MMST.ClubID=C.ClubID
    JOIN vValTranType TT
        ON MMST.ValTranTypeID=TT.ValTranTypeID
    JOIN vValRegion R 
       ON C.ValRegionID=R.ValRegionID
    LEFT JOIN vEmployee E
       ON M.MemberID = E.MemberID
    LEFT JOIN #T2 T2
       ON C.ClubID = T2.ClubID

WHERE MMST.PostDateTime >= @StartDate  AND 
      MMST.PostDateTime <= @EndDate AND 
      MMST.ValTranTypeID = 1 AND  ---- ( Charge trans. only )
      P2.DepartmentID=1  AND  ------ ( Member Dues & Fees )
      P2.Description LIKE '%Employee%'




Drop Table #T1
Drop Table #T2

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





