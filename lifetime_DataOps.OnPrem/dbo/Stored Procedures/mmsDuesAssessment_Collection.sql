
CREATE PROC [dbo].[mmsDuesAssessment_Collection](
       @TransactionClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*    =============================================
Object:            mmsDuesAssessment_Collection
Author:            
Create date:     06/28/2010 MLL Defect 4942
Description:    Create a report of the current month's assessment in detail or summary.
Modified date:    12/3/2010 BSD DBCR 03331

Exec mmsDuesAssessment_Collection '141|10'
    =============================================    */

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList(StringField VARCHAR(50))

---- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @TransactionClubIDList
CREATE TABLE #Clubs(ClubID INT)
INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())  
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())  
  AND ToCurrencyCode = 'USD'

/***************************************/

DECLARE @QueryStartDate DATETIME,
        @QueryEndDate DATETIME
SET @QueryStartDate  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
SET @QueryEndDate = DATEADD(dd,2,@QueryStartDate)
 
SELECT DISTINCT MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
       MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTran MMST
WHERE MMST.PostDateTime > @QueryStartDate
  AND MMST.PostDateTime < @QueryEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2

  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

CREATE TABLE #DuesAssessment 
       (MembershipID INT, 
       SumItemAmount MONEY, 
       SumItemSalesTax MONEY, 
       MembershipType VARCHAR(50), 
       TranClubID INT, 
       MembershipCount INT )

INSERT INTO #DuesAssessment 
       (MembershipID, 
       SumItemAmount, 
       SumItemSalesTax, 
       MembershipType, 
       TranClubID,
       MembershipCount )
SELECT MT.MembershipID, 
       SUM(TI.ItemAmount),
       SUM(TI.ItemSalesTax),
       CASE
            WHEN MT.ReasonCodeID = 125
                 THEN P2.Description
            ELSE P.Description
        END,
        MT.ClubID,
        SUM(CASE
                  WHEN MT.ReasonCodeID = 125
                    THEN 0
                 ELSE 1
            END)

  FROM #MMSTran MT
  JOIN vTranItem TI 
    ON MT.MMSTranID = TI.MMSTranID
  JOIN vProduct P 
    ON TI.ProductID = P.ProductID
  JOIN vMembership MS 
    ON MT.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MB 
    ON MS.MembershipID = MB.MembershipID
  JOIN vMembershipType MST 
    ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN vProduct P2 
    ON MST.ProductID = P2.ProductID
  JOIN #Clubs Clubs
    ON MT.ClubID = Clubs.ClubID
 WHERE MT.ValTranTypeID = 1 --- TranType 1 is a Charge Transaction
   AND MT.PostDateTime > @QueryStartDate
   AND MT.PostDateTime < @QueryEndDate
   AND MT.EmployeeID = -2 
   AND P.DepartmentID IN (1)
   AND P.ValRecurrentProductTypeID IS NULL 
   AND P.GLAccountNumber <> 4010 -- BSD 12/3/2010
 GROUP BY MT.MembershipID,
       CASE
            WHEN MT.ReasonCodeID = 125
                 THEN P2.Description
            ELSE P.Description
       END,
       MT.ClubID

SELECT C.ClubName AS TransactionClub, 
       M.MembershipID, 
       M.FirstName AS PrimaryFirstName, 
       M.LastName AS PrimaryLastName,
       M.MemberID AS PrimaryMemberID,
       VR.Description AS TransactionRegionDescription,
       M.JoinDate AS PrimaryMemberJoinDate,
       C.GLClubId,
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MB.EFTAmount AS LocalCurrency_MembershipEFTAmountBalance,
       MB.EFTAmount * #PlanRate.PlanRate as MembershipEFTAmountBalance,
       MB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipEFTAmountBalance,
       DA.MembershipCount,
       DA.SumItemAmount AS LocalCurrency_DuesAssessmentItemAmountSum,
       DA.SumItemAmount * #PlanRate.PlanRate as DuesAssessmentItemAmountSum,
       DA.SumItemAmount * #ToUSDPlanRate.PlanRate as USD_DuesAssessmentItemAmountSum,
       DA.SumItemSalesTax AS LocalCurrency_DuesAssessmentSalesTaxSum,
       DA.SumItemSalesTax * #PlanRate.PlanRate as DuesAssessmentSalesTaxSum,
       DA.SumItemSalesTax * #ToUSDPlanRate.PlanRate as USD_DuesAssessmentSalesTaxSum,
       @QueryStartDate AS AssessmentDate_Sort,
       Replace(SubString(Convert(Varchar, @QueryStartDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, @QueryStartDate),5,DataLength(Convert(Varchar, @QueryStartDate))-12)),' '+Convert(Varchar,Year(@QueryStartDate)),', '+Convert(Varchar,Year(@QueryStartDate))) + ' ' + LTRIM(SubString(Convert(Varchar, @QueryStartDate,22),10,5) + ' ' + Right(Convert(Varchar, @QueryStartDate ,22),2)) as AssessmentDate,    

       CASE    
            WHEN MB.EFTAmount <= 0
                 THEN 'Y'
            ELSE 'N'
       END SuccessfulDuesCollection,


       CASE
            WHEN MB.EFTAmount <= 0
                 THEN DA.SumItemAmount
            ELSE 0
       END as LocalCurrency_SuccessfulDuesCollectionNoTax,
       CASE
            WHEN MB.EFTAmount <= 0
                 THEN DA.SumItemAmount * #PlanRate.PlanRate
            ELSE 0
       END as SuccessfulDuesCollectionNoTax,
       CASE
            WHEN MB.EFTAmount <= 0
                 THEN DA.SumItemAmount * #ToUSDPlanRate.PlanRate
            ELSE 0
       END as USD_SuccessfulDuesCollectionNoTax,



       CASE
            WHEN MB.EFTAmount > 0
                 THEN DA.SumItemAmount
            ELSE 0
       END as LocalCurrency_UnsuccessfulDuesCollectionNoTax,
       CASE
            WHEN MB.EFTAmount > 0
                 THEN DA.SumItemAmount * #PlanRate.PlanRate
            ELSE 0
       END as UnsuccessfulDuesCollectionNoTax,
       CASE
            WHEN MB.EFTAmount > 0
                 THEN DA.SumItemAmount * #ToUSDPlanRate.PlanRate
            ELSE 0
       END as USD_UnsuccessfulDuesCollectionNoTax,



       CASE
            WHEN MB.EFTAmount <= 0
                 THEN (DA.SumItemAmount + DA.SumItemSalesTax)
            ELSE 0
       END as LocalCurrency_SuccessfulDuesCollectionWithTax,
       CASE
            WHEN MB.EFTAmount <= 0
                 THEN ((DA.SumItemAmount * #PlanRate.PlanRate) + (DA.SumItemSalesTax * #PlanRate.PlanRate))
            ELSE 0
       END as SuccessfulDuesCollectionWithTax,
       CASE
            WHEN MB.EFTAmount <= 0
                 THEN ((DA.SumItemAmount * #ToUSDPlanRate.PlanRate) + (DA.SumItemSalesTax * #ToUSDPlanRate.PlanRate))
            ELSE 0
       END as USD_SuccessfulDuesCollectionWithTax,



       CASE
            WHEN MB.EFTAmount > 0
                 THEN (DA.SumItemAmount+ DA.SumItemSalesTax)
            ELSE 0
       END as LocalCurrency_UnsuccessfulDuesCollectionWithTax,
       CASE
            WHEN MB.EFTAmount > 0
                 THEN ((DA.SumItemAmount * #PlanRate.PlanRate) + (DA.SumItemSalesTax * #PlanRate.PlanRate))
            ELSE 0
       END as UnsuccessfulDuesCollectionWithTax,
       CASE
            WHEN MB.EFTAmount > 0
                 THEN ((DA.SumItemAmount * #ToUSDPlanRate.PlanRate) + (DA.SumItemSalesTax * #ToUSDPlanRate.PlanRate))
            ELSE 0
       END as USD_UnsuccessfulDuesCollectionWithTax,



       CASE
            WHEN MB.EFTAmount <= 0
                 THEN 1
            ELSE 0
       END SuccessfulDuesCollectionMembershipCount,
       CASE
            WHEN MB.EFTAmount > 0
                 THEN 1
            ELSE 0
       END UnsuccessfulDuesCollectionMembershipCount


  FROM vMembership MS
  JOIN #DuesAssessment DA 
    ON DA.MembershipID = MS.MembershipID 
  JOIN vMember M 
    ON MS.MembershipID = M.MembershipID
  JOIN vClub C 
    ON DA.TranClubID = C.ClubID
  JOIN vValRegion VR 
    ON C.ValRegionID =  VR.ValRegionID
  JOIN vMembershipBalance MB 
    ON MS.MembershipID = MB.MembershipID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/   
 WHERE M.ValMemberTypeID = 1
 ORDER BY M.MembershipID

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #DuesAssessment
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

