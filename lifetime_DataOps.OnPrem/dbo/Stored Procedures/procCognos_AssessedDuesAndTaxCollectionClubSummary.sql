




CREATE PROC [dbo].[procCognos_AssessedDuesAndTaxCollectionClubSummary](
       @TransactionClubIDList VARCHAR(2000),
       @RegionList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*    =============================================
Object:         procCognos_AssessedDuesAndTaxCollectionClubSummary
Description:    Create a report of the current month's assessment in summary.
Exec procCognos_AssessedDuesAndTaxCollectionClubSummary '141|176|14|153|158|10|196|149|195|188|51|7|176|7|178|1|177','All Regions'
Exec procCognos_AssessedDuesAndTaxCollectionClubSummary '141|10','All Regions'
    =============================================    */

SELECT DISTINCT Club.ClubID as ClubID
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@TransactionClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @TransactionClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'

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


/***************************************/

DECLARE @QueryStartDate DATETIME,
        @QueryEndDate DATETIME
SET @QueryStartDate  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
SET @QueryEndDate = DATEADD(dd,2,@QueryStartDate)


DECLARE @HeaderAssessmentDate VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderAssessmentDate = convert(varchar(12), @QueryStartDate, 107) + ' through ' + convert(varchar(12), @QueryEndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')
 
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
  JOIN #Clubs Clubs
    ON MMST.ClubID = Clubs.ClubID
WHERE MMST.PostDateTime > @QueryStartDate
  AND MMST.PostDateTime < @QueryEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2
  
  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

CREATE TABLE #DuesAssessment 
       (MembershipID INT,
       ReasonCodeID INT, 
       SumItemAmount MONEY, 
       SumItemSalesTax MONEY, 
       MembershipType VARCHAR(50), 
       TranClubID INT, 
       MembershipCount INT )

INSERT INTO #DuesAssessment 
       (MembershipID, 
       ReasonCodeID,
       SumItemAmount, 
       SumItemSalesTax, 
       MembershipType, 
       TranClubID,
       MembershipCount )
SELECT MT.MembershipID, 
       MT.ReasonCodeID,
       SUM(TI.ItemAmount),
       SUM(TI.ItemSalesTax),
       CASE WHEN MT.ReasonCodeID = 125
                 THEN P2.Description
            ELSE P.Description
            END,
        MT.ClubID,
        SUM(CASE WHEN MT.ReasonCodeID = 125
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
  WHERE P.DepartmentID IN (1)
   AND P.ValRecurrentProductTypeID IS NULL 
  GROUP BY MT.MembershipID, 
           MT.ReasonCodeID,
           CASE  WHEN MT.ReasonCodeID = 125
                 THEN P2.Description
            ELSE P.Description
          END,
          MT.ClubID

SELECT 
C.ClubName AS TransactionClub, 
C.ClubID,
SUM(DA.MembershipCount) AS TotalAssessmentCount,
SUM((DA.SumItemAmount * #PlanRate.PlanRate) + (DA.SumItemSalesTax * #PlanRate.PlanRate)) AS TotalAssessmentAmount,
SUM(CASE WHEN MB.EFTAmount <= 0
         THEN ((DA.SumItemAmount * #PlanRate.PlanRate) + (DA.SumItemSalesTax * #PlanRate.PlanRate))
         ELSE 0
       END) as SuccessfulDuesCollectionWithTax,
SUM(CASE WHEN MB.EFTAmount > 0
         THEN ((DA.SumItemAmount * #PlanRate.PlanRate) + (DA.SumItemSalesTax * #PlanRate.PlanRate))
         ELSE 0
       END) as UnsuccessfulDuesCollectionWithTax,
SUM(CASE WHEN MB.EFTAmount <= 0
         THEN DA.MembershipCount
         ELSE 0
       END) AS SuccessfulDuesCollectionMembershipCount,
SUM(CASE WHEN MB.EFTAmount > 0
         THEN DA.MembershipCount
         ELSE 0
       END) AS UnsuccessfulDuesCollectionMembershipCount, 
MAX(@ReportingCurrencyCode) as ReportingCurrencyCode,
MAX(@HeaderAssessmentDate) AS HeaderAssessmentDate,
MAX(@ReportRunDateTime) AS ReportRunDateTime		

  FROM vMembership MS
  JOIN #DuesAssessment DA 
    ON DA.MembershipID = MS.MembershipID 
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
  --JOIN #ToUSDPlanRate
  --     ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
  --    AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/   
 GROUP BY C.ClubName, C.ClubID
 ORDER BY C.ClubName

DROP TABLE #Clubs
DROP TABLE #DuesAssessment
DROP TABLE #PlanRate
DROP TABLE #MMSTran


END





