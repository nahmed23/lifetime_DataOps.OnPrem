
CREATE PROC [dbo].[procCognos_PointOfSaleCloseDrawerPaymentMethodAndDistributionSummary] (
	 @StartDate DateTime,
	 @EndDate DateTime,
	 @ClubID INT,
	 @DrawerActivityIDList VARCHAR(8000)
)

AS
BEGIN 

SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
   END

------ Sample Execution
--- Exec procCognos_PointOfSaleCloseDrawerPaymentMethodAndDistributionSummary '2/1/2017','2/2/2017','151','474124|474156|474157|474158|474159|474160|479109|479207|459310'
------

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @AdjStartDate DATETIME
DECLARE @AdjEndDate DATETIME
SET @AdjStartDate = (SELECT CASE WHEN @StartDate = '1/1/1900'   ----- default to beginning of prior month
                                  THEN CalendarPriorMonthStartingDate
								  ELSE @StartDate
								  END  
								FROM vReportDimDate 
								WHERE CalendarDate = Cast(GetDate() as Date))
SET @AdjEndDate = (SELECT CASE WHEN @EndDate = '1/1/1900'       ------ default to the 1st of the current month
                                THEN CalendarMonthStartingDate 
								ELSE DateAdd(day,1,@EndDate)
								END 
								FROM vReportDimDate 
								WHERE  CalendarDate = Cast(GetDate() as Date))


SELECT DISTINCT DrawerActivityID.Item  DrawerActivityID
  INTO #TempDrawerActivityID
  FROM fnParsePipeList(@DrawerActivityIDList) DrawerActivityID 


 ----- pull the list of IDs based on the passed parameters, some parameters may be ignored -- set up to allow scheduling for prior month
SELECT DrawerActivityID
  INTO #DrawerActivityIDs
  FROM #TempDrawerActivityID
   WHERE @StartDate <> '1/1/1900'
    AND @DrawerActivityIDList not like '-1%'

UNION

SELECT DrawerActivityID
  FROM vDrawerActivity DA
   JOIN vDrawer Drawer
     ON DA.DrawerID = Drawer.DrawerID
   WHERE @DrawerActivityIDList like '-1%'
     AND Drawer.ClubID = @ClubID
	 AND DA.CloseDateTime >= @AdjStartDate
	 AND DA.CloseDateTime < @AdjEndDate

DECLARE @EarliestDrawerOpenDateTime DATETIME
SET @EarliestDrawerOpenDateTime = (Select Min(DA.OpenDateTime) 
                                   FROM vDrawerActivity DA 
		                            JOIN #DrawerActivityIDs 
		                              ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID)
DECLARE @EarliestDrawerCloseDateTime DATETIME
SET @EarliestDrawerCloseDateTime = (Select Min(DA.CloseDateTime) 
                                   FROM vDrawerActivity DA 
		                            JOIN #DrawerActivityIDs 
		                              ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID) 
DECLARE @LatestDrawerCloseDateTime DATETIME
SET @LatestDrawerCloseDateTime = (Select Max(DA.CloseDateTime) 
                                   FROM vDrawerActivity DA 
		                            JOIN #DrawerActivityIDs 
		                              ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID)

DECLARE @HeaderDrawerActivityIDList VARCHAR(1000) 
DECLARE @HeaderOpenDateTimeEarliest VARCHAR(1000) 
DECLARE @HeaderCloseDateTimeLatest VARCHAR(1000)
DECLARE @HeaderCloseDateTimeEarliest VARCHAR(1000)

SET @HeaderDrawerActivityIDList = STUFF((SELECT ', ' + CONVERT(VARCHAR(7),DA.DrawerActivityID )
										 FROM vDrawerActivity DA 
										 JOIN #DrawerActivityIDs 
										   ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID
                                         ORDER BY DA.DrawerActivityID 
                                         FOR XML PATH('')),1,1,'') 

SET @HeaderOpenDateTimeEarliest = Replace(Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),1,6)+', '+Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),8,10)+' '+Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),18,2),'  ',' ')
SET @HeaderCloseDateTimeLatest = Replace(Substring(convert(varchar,@LatestDrawerCloseDateTime,100),1,6)+', '+Substring(convert(varchar,@LatestDrawerCloseDateTime,100),8,10)+' '+Substring(convert(varchar,@LatestDrawerCloseDateTime,100),18,2),'  ',' ')                                                              
SET @HeaderCloseDateTimeEarliest  = Replace(Substring(convert(varchar,@EarliestDrawerCloseDateTime,100),1,6)+', '+Substring(convert(varchar,@EarliestDrawerCloseDateTime,100),8,10)+' '+Substring(convert(varchar,@EarliestDrawerCloseDateTime,100),18,2),'  ',' ')                                                                   

----- Return Sale Amounts
SELECT distinct VDS.Description AS DrawerStatus, 
       Region.Description AS MMSRegion,
	   TranType.Description AS TranType,
       Dept.Description AS DescriptionField_Dept_PaymentType,
	   DA.CloseDateTime AS DrawerCloseDateTime,  
	   Club.ClubName AS DrawerClub, 
	   DA.DrawerActivityID, 
	   MMSTran.PostDateTime, 
	   MemberHomeClub.ClubName AS MemberHomeClub, 
	   MMSTran.TranVoidedID, 
	   STR ( (MMSTran.MMSTranID/MMSTran.MMSTranID), 1, 0 ) AS Sort, 
	   ' ' AS Desc2,
	   0 AS Sale_PaymentSide,
	   0 AS PaymentOnAcc,
	   'undefined' AS Payment_Type,
       (TI.ItemAmount + TI.ItemSalesTax) AS SaleAndTax,
	   MMSTran.MMSTranID,
	   VCC.CurrencyCode AS DrawerCurrencyCode,
	   TIClub.ClubName AS TransactionClub,
	   VCC2.CurrencyCode AS TransactionClubCurrency 
INTO #Results 
FROM vDrawerActivity DA
  JOIN #DrawerActivityIDs IDs
   ON DA.DrawerActivityID = IDs.DrawerActivityID
  JOIN vMMSTran MMSTran
   ON MMSTran.DrawerActivityID=DA.DrawerActivityID
 JOIN vValDrawerStatus VDS
   ON DA.ValDrawerStatusID=VDS.ValDrawerStatusID
 JOIN vDrawer Drawer
   ON DA.DrawerID=Drawer.DrawerID  
 JOIN vClub Club
   ON Drawer.ClubID=Club.ClubID   
 JOIN vValRegion Region     
   ON Club.ValRegionID=Region.ValRegionID
 JOIN vValCurrencyCode VCC
   ON Club.ValCurrencyCodeID = VCC.ValCurrencyCodeID  
 LEFT JOIN vMember Member 
   ON Member.MemberID=MMSTran.MemberID
 LEFT JOIN vMembership MS
   ON Member.MembershipID = MS.MembershipID
 LEFT JOIN vClub MemberHomeClub
   ON MS.ClubID = MemberHomeClub.ClubID
 LEFT JOIN dbo.vValTranType TranType 
   ON TranType.ValTranTypeID=MMSTran.ValTranTypeID 
 LEFT JOIN vTranItem TI 
   ON MMSTran.MMSTranID=TI.MMSTranID 
 LEFT JOIN vProduct Product 
   ON TI.ProductID=Product.ProductID 
 LEFT JOIN dbo.vDepartment Dept 
   ON Product.DepartmentID=Dept.DepartmentID 
 LEFT JOIN vClub TIClub
   ON MMSTran.ClubID = TIClub.ClubID
 LEFT JOIN vValCurrencyCode VCC2
   ON MMSTran.ValCurrencyCodeID = VCC2.ValCurrencyCodeID  
WHERE TranType.Description='Sale'

UNION ALL
---- Returns Payment & Refund transactions
SELECT distinct VDS.Description AS DrawerStatus, 
	   Region.Description AS MMSRegion,
       TranType.Description AS TranType, 
	   PMTType.Description AS DescriptionField_Dept_PaymentType,   
	   DA.CloseDateTime AS DrawerCloseDateTime, 
       Club.ClubName AS DrawerClub,
	   DA.DrawerActivityID,
       MMSTran.PostDateTime, 
	   MemberHomeClub.ClubName AS MemberHomeClub,
	   MMSTran.TranVoidedID, 
       STR ((4* (MMSTran.MMSTranID/MMSTran.MMSTranID)), 1, 0 ) AS Sort, 
       Payment.ApprovalCode AS Desc2,
	   0 AS Sale_PaymentSide,
	   Payment.PaymentAmount AS PaymentOnAcc,
       PMTType.Description AS Payment_Type,
	   0 AS SaleAndTax,
	   MMSTran.MMSTranID,
	   VCC.CurrencyCode AS DrawerCurrencyCode,
	   TIClub.ClubName AS TransactionClub,
	   VCC2.CurrencyCode AS TransactionClubCurrency 
FROM vDrawerActivity DA  
 JOIN #DrawerActivityIDs IDs
   ON DA.DrawerActivityID = IDS.DrawerActivityID
 JOIN vMMSTran MMSTran
   ON MMSTran.DrawerActivityID=DA.DrawerActivityID
 JOIN vValDrawerStatus VDS
   ON DA.ValDrawerStatusID=VDS.ValDrawerStatusID
 JOIN vDrawer Drawer
   ON DA.DrawerID=Drawer.DrawerID
 JOIN vClub Club
   ON Drawer.ClubID=Club.ClubID
 JOIN vValRegion Region
   ON Club.ValRegionID=Region.ValRegionID
 JOIN vValCurrencyCode VCC
   ON Club.ValCurrencyCodeID = VCC.ValCurrencyCodeID 
 JOIN vMember Member 
   ON Member.MemberID=MMSTran.MemberID 
 JOIN vMembership MS
   ON Member.MembershipID = MS.MembershipID
 JOIN vClub MemberHomeClub
   ON MS.ClubID = MemberHomeClub.ClubID
 LEFT JOIN vValTranType TranType 
   ON TranType.ValTranTypeID=MMSTran.ValTranTypeID 
 LEFT JOIN vPayment Payment 
   ON MMSTran.MMSTranID=Payment.MMSTranID 
 LEFT JOIN vValPaymentType PMTType 
   ON Payment.ValPaymentTypeID=PMTType.ValPaymentTypeID 
 LEFT JOIN vTranItem TI 
   ON MMSTran.MMSTranID=TI.MMSTranID 
 LEFT JOIN vClub TIClub
   ON MMSTran.ClubID = TIClub.ClubID
 LEFT JOIN vValCurrencyCode VCC2
   ON MMSTran.ValCurrencyCodeID = VCC2.ValCurrencyCodeID  
WHERE TranType.Description in ('Payment','Refund')

UNION ALL
---- Returns the payment side of a sale transaction
SELECT distinct VDS.Description AS DrawerStatus, 
       Region.Description AS MMSRegion,
       TranType.Description AS TranType,
	   PMTType.Description AS DescriptionField_Dept_PaymentType,
       DA.CloseDateTime AS DrawerCloseDateTime, 
       Club.ClubName  AS DrawerClub, 
	   DA.DrawerActivityID, 
	   MMSTran.PostDateTime, 
	   MemberHomeClub.ClubName AS MemberHomeClub,
       MMSTran.TranVoidedID,
       STR ((2*( MMSTran.MMSTranID/MMSTran.MMSTranID)), 1, 0 ), 
	   Payment.ApprovalCode AS Desc2,
	   Payment.PaymentAmount AS Sale_PaymentSide,
	   0 AS PaymentOnAcc,
       PMTType.Description AS Payment_Type,
	   0 AS SaleAndTax,
	   MMSTran.MMSTranID,
	   VCC.CurrencyCode AS DrawerCurrencyCode,
	   TIClub.ClubName AS TransactionClub,
	   VCC2.CurrencyCode AS TransactionClubCurrency 
FROM vDrawerActivity DA
 JOIN #DrawerActivityIDs IDs
   ON DA.DrawerActivityID = IDS.DrawerActivityID
 JOIN vMMSTran MMSTran
   ON MMSTran.DrawerActivityID=DA.DrawerActivityID
 JOIN vValDrawerStatus VDS
   ON DA.ValDrawerStatusID=VDS.ValDrawerStatusID
 JOIN vDrawer Drawer
   ON DA.DrawerID=Drawer.DrawerID
 JOIN vClub Club
   ON Drawer.ClubID=Club.ClubID
 JOIN vValRegion Region
   ON Club.ValRegionID=Region.ValRegionID
 JOIN vValCurrencyCode VCC
   ON Club.ValCurrencyCodeID = VCC.ValCurrencyCodeID 
 LEFT JOIN vMember Member 
   ON Member.MemberID=MMSTran.MemberID 
 LEFT JOIN vMembership MS
   ON Member.MembershipID = MS.MembershipID
 LEFT JOIN vClub MemberHomeClub
   ON MS.ClubID = MemberHomeClub.ClubID
 LEFT JOIN vValTranType TranType 
   ON TranType.ValTranTypeID=MMSTran.ValTranTypeID 
 LEFT JOIN vPayment Payment 
   ON MMSTran.MMSTranID=Payment.MMSTranID 
 LEFT JOIN vValPaymentType PMTType 
   ON Payment.ValPaymentTypeID=PMTType.ValPaymentTypeID 
 LEFT JOIN vTranItem TI 
   ON MMSTran.MMSTranID=TI.MMSTranID 
 LEFT JOIN vClub TIClub
   ON MMSTran.ClubID = TIClub.ClubID
 LEFT JOIN vValCurrencyCode VCC2
   ON MMSTran.ValCurrencyCodeID = VCC2.ValCurrencyCodeID  
WHERE TranType.Description='Sale'

Select MMSRegion,
       TranType,
	   DescriptionField_Dept_PaymentType,
       DrawerClub, 
	   DrawerActivityID, 
	   Min(PostDateTime) AS MinPostDateTime, 
	   MemberHomeClub,
	   Payment_Type,
	   Desc2 AS ApprovalCode,
	   Sum(Sale_PaymentSide) AS Sale_PaymentSide,
	   Sum(PaymentOnAcc) AS PaymentOnAcc,
	   Sum(SaleAndTax) AS SaleAndTax,
	   DrawerCurrencyCode,
	   TransactionClub,
	   TransactionClubCurrency,
	   @ReportRunDateTime AS ReportRunDateTime,
	   @HeaderDrawerActivityIDList AS HeaderDrawerActivityIDList, 
       @HeaderOpenDateTimeEarliest AS HeaderOpenDateTimeEarliest, 
       @HeaderCloseDateTimeLatest AS HeaderCloseDateTimeLatest,
	   @HeaderCloseDateTimeEarliest AS HeaderCloseDateTimeEarliest
FROM #Results 
WHERE  IsNull(TranVoidedID,0) = 0
 GROUP BY MMSRegion,
       TranType,
	   DescriptionField_Dept_PaymentType,
       DrawerClub, 
	   DrawerActivityID, 
	   MemberHomeClub,
	   Payment_Type,
	   Desc2,
	   DrawerCurrencyCode,
	   TransactionClub,
	   TransactionClubCurrency 

DROP TABLE #DrawerActivityIDs
DROP TABLE #Results 
DROP TABLE #TempDrawerActivityID

END