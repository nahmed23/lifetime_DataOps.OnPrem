




------- Sample Execution
-----  EXEC procCognos_PosClosedDrawerTenderedDetail '470432' 
--------

CREATE      PROC [dbo].[procCognos_PosClosedDrawerTenderedDetail] (
  @DrawerActivityID VARCHAR(8000)
  )


AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

SELECT DISTINCT DrawerActivityID.Item  DrawerActivityID
  INTO #DrawerActivityIDs
  FROM fnParsePipeList(@DrawerActivityID) DrawerActivityID

DECLARE @EarliestDrawerOpenDateTime DATETIME
SET @EarliestDrawerOpenDateTime = (Select Min(DA.OpenDateTime) 
                                   FROM vDrawerActivity DA 
		                            JOIN #DrawerActivityIDs 
		                              ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID)
DECLARE @LatestDrawerCloseDateTime DATETIME
SET @LatestDrawerCloseDateTime = (Select Max(DA.CloseDateTime) 
                                   FROM vDrawerActivity DA 
		                            JOIN #DrawerActivityIDs 
		                              ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID)


DECLARE @HeaderDrawerActivityIDList VARCHAR(1000) 
DECLARE @HeaderOpenDateTimeList VARCHAR(1000) 
DECLARE @HeaderCloseDateTimeList VARCHAR(1000)

SET @HeaderDrawerActivityIDList = STUFF((SELECT ', ' + CONVERT(VARCHAR(7),DA.DrawerActivityID )
										 FROM vDrawerActivity DA 
										 JOIN #DrawerActivityIDs ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID
                                         ORDER BY DA.DrawerActivityID 
                                         FOR XML PATH('')),1,1,'') 
SET @HeaderOpenDateTimeList = Replace(Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),1,6)+', '+Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),8,10)+' '+Substring(convert(varchar,@EarliestDrawerOpenDateTime,100),18,2),'  ',' ')
  
SET @HeaderCloseDateTimeList = Replace(Substring(convert(varchar,@LatestDrawerCloseDateTime,100),1,6)+', '+Substring(convert(varchar,@LatestDrawerCloseDateTime,100),8,10)+' '+Substring(convert(varchar,@LatestDrawerCloseDateTime,100),18,2),'  ',' ')


DECLARE @ClubID INT 
DECLARE @Region VARCHAR(50) 
DECLARE @ClubName VARCHAR(100)
DECLARE @ReportingCurrencyCode VARCHAR(15)
SELECT @ClubID = C.ClubID,
        @Region = R.Description,
        @ClubName = C.ClubName,
		@ReportingCurrencyCode = CC.CurrencyCode
FROM vClub C
JOIN vValRegion R ON R.ValRegionID = C.ValRegionID
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
JOIN #DrawerActivityIDs ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID
JOIN vValCurrencyCode CC ON C.ValCurrencyCodeID = CC.ValCurrencyCodeID
GROUP BY C.ClubID, R.Description, C.ClubName,CC.CurrencyCode
/*
/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT VCC.CurrencyCode
  FROM vClub C  
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  WHERE C.ClubID = @ClubID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/
*/

SELECT 
       DD.DrawerStatusDescription, 
       DD.RegionDescription, 
       DD.TranTypeDescription, 
       DD.DeptDescription, 
       DD.CloseDateTime as CloseDateTime_Sort, 
	   CASE WHEN IsNull(DD.CloseDateTime,'1/1/1900') <> '1/1/1900'
	        THEN Replace(Substring(convert(varchar,DD.CloseDateTime,100),1,6)+', '+Substring(convert(varchar,DD.CloseDateTime,100),8,10)+' '+Substring(convert(varchar,DD.CloseDateTime,100),18,2),'  ',' ')   
	        ELSE NULL END AS CloseDateTime,
	   DD.ClubName, 
	   DD.DrawerActivityID, 
       CASE WHEN Sort<>2 THEN DD.PostDateTime ELSE NULL END as PostDateTime_Sort, 
	   CASE WHEN Sort<>2 AND IsNull(DD.PostDateTime,'1/1/1900') <> '1/1/1900'
	        THEN Replace(Substring(convert(varchar,DD.PostDateTime,100),1,6)+', '+Substring(convert(varchar,DD.PostDateTime,100),8,10)+' '+Substring(convert(varchar,DD.PostDateTime,100),18,2),'  ',' ')
	        ELSE NULL END AS PostDateTime,    
	   DD.ReceiptNumber, 
	   DD.TranVoidedID, 
       DD.Sort, 
       DD.Desc1, 
	   DD.Desc2, 
       DA.OpenDateTime as OpenDateTime_Sort, 
	   CASE WHEN IsNull(DA.OpenDateTime,'1/1/1900') <> '1/1/1900'
	        THEN Replace(Substring(convert(varchar,DA.OpenDateTime,100),1,6)+', '+Substring(convert(varchar,DA.OpenDateTime,100),8,10)+' '+Substring(convert(varchar,DA.OpenDateTime,100),18,2),'  ',' ')
			ELSE NULL END AS OpenDateTime,    
	   DD.MemberID, 
	   M.MembershipID,
       E.FirstName AS CloseEmployeeFirstName,
       E.LastName AS CloseEmployeeLastName,
       C.ClubName AS MemberHomeClub,

       -- POS Closed Drawer Sales and Payments on Account
       CASE WHEN Sort = 1 OR Sort = 3 
	        THEN DD.DeptDescription 
            ELSE ' ' END AS Dept,
       
       CASE WHEN Sort=1 OR Sort = 3 
	        THEN IsNull(DD.Amount,0)
            ELSE 0.00 END AS ItemAmount, 
            
       CASE WHEN Sort = 1 OR Sort = 3 
	        THEN IsNull(DD.Tax,0)
            ELSE 0.00 END AS Itemsalestax,
       
       CASE WHEN Sort=1 OR Sort=3 
             THEN IsNull(DD.Total,0)
             ELSE 0.00 END AS DeptTotal,
             
        CASE WHEN Sort=1 OR Sort=3 
		      THEN IsNull(DD.Total,0)
             WHEN Sort = 4 
			  THEN (IsNull(DD.Total,0)) - (IsNull(DD.ChangeRendered,0))             
             WHEN Sort=7 
			  THEN IsNull(DD.Total,0) -- refunds
             ELSE 0.00 END AS SummaryTotal,
             
        CASE WHEN Sort=1 OR Sort=3 
		      THEN 'Sales'
             WHEN Sort = 4 
			  THEN 'Payments on Account'             
             ELSE '' END AS Sales_PaymentOnAcc,

        CASE WHEN Sort=3 
		      THEN 'Charge To Account'
             WHEN Sort = 7 
			  THEN 'Credit Card Refunds'             
             ELSE '' END AS ChargeToAcc_Refunds,            
                 
           
        CASE WHEN Sort=3 
		      THEN IsNull(DD.Total,0) * (-1)  
             ELSE 0.00 END AS ChargeToAcctAmount,
             
        -- POS Drawer Payment Method Summary     
       CASE WHEN Sort=2 -- Payment side of the sale
            THEN IsNull(DD.Total,0)
            ELSE 0.00 END AS Sale_PaymentSide,

       CASE WHEN Sort=4  -- Payment
            THEN IsNull(DD.Total,0)
            ELSE 0.00 END AS PaymentOnAcc,

       CASE WHEN Sort=7 -- Refund
            THEN IsNull(DD.Total,0)
            ELSE 0.00 END AS Refund,

       CASE WHEN DESC1 IN ('VISA','MasterCard','American Express','Discover') AND Sort IN (2,4,7)
            THEN IsNull(DD.Total,0)
            ELSE 0.00 END AS CreditCardNet,

       CASE WHEN Sort IN (2,4,7)AND IsNull(DESC1,'x') <> 'x' 
            THEN DESC1
            ELSE 'undefined' END AS Payment_Type,
       
       -- POS Drawer Club Distribution
       CASE WHEN Sort=1 -- sale
            THEN IsNull(DD.Total,0)
            ELSE 0.00 END AS Sale,
                    
       @ReportRunDateTime AS ReportRunDateTime,
       @HeaderDrawerActivityIDList AS HeaderDrawerActivityIDList, 
       @HeaderOpenDateTimeList AS HeaderOpenDateTimeList,
       @HeaderCloseDateTimeList AS HeaderCloseDateTimeList,
       @ReportingCurrencyCode AS ReportingCurrencyCode 
  INTO #Results     
  FROM vDrawerActivity DA
  JOIN vPOSDrawerDetail DD 
       ON DA.DrawerActivityID = DD.DrawerActivityID
  JOIN vClub DrawerClub
       ON DD.ClubName = DrawerClub.ClubName
  JOIN #DrawerActivityIDs DIDS
       ON DD.DrawerActivityID = DIDS.DrawerActivityID
  LEFT JOIN vMember M 
       ON DD.MemberID = M.MemberID
  LEFT JOIN vEmployee E
       ON DA.Closeemployeeid = E.EmployeeID
  LEFT JOIN vMembership MS
       ON M.MembershipID = MS.MembershipID
  LEFT JOIN vClub C
       ON MS.ClubID = C.ClubID
/*
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON DrawerClub.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(IsNull(DD.PostDateTime,DD.CloseDateTime)) = #PlanRate.PlanYear	  
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(IsNull(DD.PostDateTime,DD.CloseDateTime)) = #ToUSDPlanRate.PlanYear	 
/*******************************************/
*/

---TP
OPTION (MAXDOP 1)
---/TP

INSERT INTO #Results (
DrawerStatusDescription,
RegionDescription,
TranTypeDescription,
DeptDescription,
CloseDateTime_Sort,
CloseDateTime,
ClubName,
DrawerActivityID,
PostDateTime_Sort,
PostDateTime,
ReceiptNumber,
TranVoidedID,
Sort,
Desc1,
Desc2,
OpenDateTime_Sort,
OpenDateTime,
MemberID,
MembershipID,
CloseEmployeeFirstName,
CloseEmployeeLastName,
MemberHomeClub,
Dept,
ItemAmount,
Itemsalestax,
DeptTotal,
SummaryTotal,
Sales_PaymentOnAcc,
ChargeToAcc_Refunds,
ChargeToAcctAmount,
Sale_PaymentSide,
PaymentOnAcc,
Refund,
CreditCardNet,
Payment_Type,
Sale,
ReportRunDateTime,
HeaderDrawerActivityIDList,
HeaderOpenDateTimeList,
HeaderCloseDateTimeList,
ReportingCurrencyCode) 
VALUES ('',@Region,'','',null,null,@ClubName,-1,null,null,NULL,NULL,'','','',null,null,-1,-1,'','','','',0,0,0,
0,'','Charge To Account',0,0,0,0,0,'',0,null,'',null,null,''),
('',@Region,'','',null,null,@ClubName,-1,null,null,NULL,NULL,'','','',null,null,-1,-1,'','','','',0,0,0,
0,'','Credit Card Refunds',0,0,0,0,0,'',0,null,'',null,null,'')






SELECT DrawerStatusDescription,
RegionDescription,
TranTypeDescription,
DeptDescription,
CloseDateTime_Sort,
CloseDateTime,
ClubName,
DrawerActivityID,
PostDateTime_Sort,
PostDateTime,
ReceiptNumber,
Sort,
Desc1,
Desc2,
OpenDateTime_Sort,
OpenDateTime,
MemberID,
MembershipID,
CloseEmployeeFirstName,
CloseEmployeeLastName,
MemberHomeClub,
Dept,
ItemAmount,
Itemsalestax,
DeptTotal,
SummaryTotal,
Sales_PaymentOnAcc,
ChargeToAcc_Refunds,
ChargeToAcctAmount,
Sale_PaymentSide,
PaymentOnAcc,
Refund,
CreditCardNet,
Payment_Type,
Sale,
ReportRunDateTime,
HeaderDrawerActivityIDList,
HeaderOpenDateTimeList,
HeaderCloseDateTimeList,
ReportingCurrencyCode 
FROM #Results
WHERE Sort=6 
  OR IsNull(TranVoidedID,0)=0    /*Exclude Voided*/ 
 


DROP TABLE #DrawerActivityIDs
DROP TABLE #Results



END




