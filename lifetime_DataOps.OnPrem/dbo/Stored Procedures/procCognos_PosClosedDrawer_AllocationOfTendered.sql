
/*
exec procCognos_PosClosedDrawer_AllocationOfTendered '327918'
'325807'
*/


CREATE    PROC [dbo].[procCognos_PosClosedDrawer_AllocationOfTendered] (
  @DrawerActivityID VARCHAR(50)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @ClubID INT
SELECT @ClubID = C.ClubID
FROM vClub C
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
WHERE DA.DrawerActivityID = @DrawerActivityID

      

-- Payment types  
CREATE TABLE #PaymetTypes (Description VARCHAR(50), ValPaymentTypeID INT, Sort INT)
INSERT INTO #PaymetTypes VALUES ('Cash',1,1),('Check',2,2),('VISA',3,3),('MasterCard',4,4),('Discover',5,6),('Gift Certificate',7,7),('American Express',8,5),('Gift Card',14,8),('Club Tab',15,9)

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
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


-- Change rendered for Cash payments
SELECT SUM(MMST.ChangeRendered) AS ChangeRendered, DA.DrawerActivityID, 'Cash' AS PaymentType 
 INTO #ChangeRendered
 FROM dbo.vDrawerActivity DA       
      JOIN dbo.vMMSTran MMST ON DA.DrawerActivityID = MMST.DrawerActivityID
  --JOIN dbo.vPOSDrawerDetail DD 
  --     ON DA.DrawerActivityID = DD.DrawerActivityID
  JOIN dbo.vClub DrawerClub
       ON MMST.ClubID = DrawerClub.ClubID
  JOIN vValCurrencyCode VCC
       ON DrawerClub.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
       AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear	
  WHERE DA.DrawerActivityID = @DrawerActivityID
        AND MMST.TranVoidedID is null
  GROUP BY DA.DrawerActivityID
      
-- DROP CASH and Tip Amount
SELECT 
       SUM(DD.Total * #PlanRate.PlanRate) AS DropCashTotal, 
       SUM(DD.TipAmount * #PlanRate.PlanRate) AS TipAmountTotal, 
       DA.DrawerActivityID, 
       'Cash' AS PaymentType,
       e.FirstName +' '+ e.LastName AS CloseEmployeeName
  INTO #DropCash
  FROM dbo.vDrawerActivity DA
  JOIN dbo.vPOSDrawerDetail DD 
       ON DA.DrawerActivityID = DD.DrawerActivityID
  JOIN dbo.vClub DrawerClub
       ON DD.ClubName = DrawerClub.ClubName        
  LEFT OUTER JOIN dbo.vEmployee E
       ON DA.Closeemployeeid = E.EmployeeID       
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON DrawerClub.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
       AND YEAR(DD.PostDateTime) = #PlanRate.PlanYear	
      
  WHERE DA.DrawerActivityID = @DrawerActivityID AND DD.DeptDescription = 'Drop Cash' -- Sort 6
  GROUP BY DA.DrawerActivityID,
           e.FirstName +' '+ e.LastName


SELECT DAA.DrawerActivityID, 
       VPT.ValPaymentTypeID, 
       VPT.Description PaymentDescription, 
       VPT.SortOrder, 
       C.ClubName, 
       VR.Description RegionDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   DAA.ActualTotalAmount * #PlanRate.PlanRate as ActualTotalAmount,	   
	   DAA.ActualTotalAmount as LocalCurrency_ActualTotalAmount,	   
	   DAA.ActualTotalAmount * #ToUSDPlanRate.PlanRate as USD_ActualTotalAmount  	   	
/***************************************/
INTO #AllocationOfTendered_DrawerActivity
FROM dbo.vDrawerActivityAmount DAA
  JOIN dbo.vDrawerActivity DA
       ON DAA.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vDrawer D
       ON DA.DrawerID = D.DrawerID
  JOIN dbo.vClub C
       ON D.ClubID = C.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  RIGHT OUTER JOIN dbo.vValPaymentType VPT 
       ON VPT.ValPaymentTypeID = DAA.ValPaymentTypeID
  WHERE VPT.Description <> 'Charge to Account' AND 
       DAA.DrawerActivityID = @DrawerActivityID 
  ORDER BY VPT.SortOrder


SELECT       

   --TranType =  if (Sort==2 ) { } else {Trantypedescription }
/*  Tables("rTenderedDetail").Columns("CashSubTotal").Sum(currBreak)-
    Tables("rTenderedDetail").Columns("ChangeTotal").Sum(currBreak)-
              -- ChangeTotal = if (Receiptnumber == Next ( Receiptnumber ) ) {0}  else   if (Sort == 2 || Sort==4 ) {Changerendered } else {0}  
    Tables("rTenderedDetail").Columns("Tipamount").Sum(currBreak)
 */
        CASE WHEN DD.DeptDescription = 'Cash' AND Sort in (2,4,7) THEN 'Cash' 
       -- CheckTotal
            WHEN DD.DeptDescription = 'Check' AND Sort in (2,4,7) THEN 'Check'
       -- VisaTotal 
            WHEN DD.DeptDescription = 'Visa' AND Sort in (2,4,7) THEN 'Visa' 
       -- MasterCardTotal 
            WHEN DD.DeptDescription = 'MasterCard' AND Sort in (2,4,7) THEN 'MasterCard'    
       -- AMEXTotal 
            WHEN DD.DeptDescription = 'American Express' AND Sort in (2,4,7) THEN 'American Express'
       -- DiscoverTotal 
            WHEN DD.DeptDescription = 'Discover' AND Sort in (2,4,7) THEN 'Discover'            
       --GiftCertTotal       
            WHEN DD.DeptDescription = 'Gift Certificate' AND Sort in (2,4,7) THEN 'Gift Certificate'            
       --GiftCardTotal
            WHEN DD.DeptDescription = 'Gift Card' AND Sort in (2,4,7) THEN 'Gift Card'           
       --CardOnFileTotal
            WHEN ((DD.DeptDescription = 'Card on File' OR DD.DeptDescription = 'Club Tab') AND Sort in (2,4,7)) THEN 'Club Tab'            
        END AS PaymentType,

        SUM(
        CASE WHEN DD.DeptDescription = 'Cash' AND Sort in (2,4,7) THEN (DD.Total * #PlanRate.PlanRate) - (DD.TipAmount * #PlanRate.PlanRate)
            WHEN DD.DeptDescription = 'Check' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate
            WHEN DD.DeptDescription = 'Visa' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate
            WHEN DD.DeptDescription = 'MasterCard' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate  
            WHEN DD.DeptDescription = 'American Express' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate
            WHEN DD.DeptDescription = 'Discover' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate 
             WHEN DD.DeptDescription = 'Gift Certificate' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate 
            WHEN DD.DeptDescription = 'Gift Card' AND Sort in (2,4,7) THEN DD.Total * #PlanRate.PlanRate 
            WHEN ((DD.DeptDescription = 'Card on File' OR DD.DeptDescription = 'Club Tab') AND Sort in (2,4,7)) THEN DD.Total * #PlanRate.PlanRate 
       END) AS Amount,
        
        DA.DrawerActivityID
  
  INTO #AllocationOfTendered_POSDrawerDetail
  FROM dbo.vDrawerActivity DA
  JOIN dbo.vPOSDrawerDetail DD 
       ON DA.DrawerActivityID = DD.DrawerActivityID
  JOIN dbo.vClub DrawerClub
       ON DD.ClubName = DrawerClub.ClubName 
  --JOIN #DrawerActivityIDs DIDS
    --   ON DD.DrawerActivityID = DIDS.DrawerActivityID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON DrawerClub.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(DD.PostDateTime) = #PlanRate.PlanYear	  
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(DD.PostDateTime) = #ToUSDPlanRate.PlanYear	 
/*******************************************/
WHERE DA.DrawerActivityID = @DrawerActivityID 
      AND ((DD.Sort<>6 AND DD.Tranvoidedid is null) OR DD.Sort=6)/*Exclude Voided*/ 

GROUP BY 
        CASE 
            WHEN DD.DeptDescription = 'Cash' AND Sort in (2,4,7) THEN 'Cash' 
            WHEN DD.DeptDescription = 'Check' AND Sort in (2,4,7) THEN 'Check'
            WHEN DD.DeptDescription = 'Visa' AND Sort in (2,4,7) THEN 'Visa' 
            WHEN DD.DeptDescription = 'MasterCard' AND Sort in (2,4,7) THEN 'MasterCard'    
            WHEN DD.DeptDescription = 'American Express' AND Sort in (2,4,7) THEN 'American Express'
            WHEN DD.DeptDescription = 'Discover' AND Sort in (2,4,7) THEN 'Discover'            
            WHEN DD.DeptDescription = 'Gift Certificate' AND Sort in (2,4,7) THEN 'Gift Certificate'            
            WHEN DD.DeptDescription = 'Gift Card' AND Sort in (2,4,7) THEN 'Gift Card'           
            WHEN ((DD.DeptDescription = 'Card on File' OR DD.DeptDescription = 'Club Tab') AND Sort in (2,4,7)) THEN 'Club Tab'            
        END,
        
        DA.DrawerActivityID 
     
        
	SELECT 
		#PT.Description, 
		ISNULL(#AOT_POS.Amount, 0.00) AS Amount, 
		ISNULL(#AOT_POS.DrawerActivityID, 0) AS DrawerActivityID,
		ISNULL(#CR.ChangeRendered, 0.00) AS ChangeRendered,
		ISNULL(#AOT_DA.ActualTotalAmount,0.00) AS ActualAmount,
		#DC.DropCashTotal AS DropCashTotal,
		ISNULL(#DC.TipAmountTotal, 0.00) AS TipAmountTotal,
		#DC.CloseEmployeeName, 
		#PT.Sort
	
	FROM #AllocationOfTendered_POSDrawerDetail  #AOT_POS      
	LEFT JOIN #ChangeRendered #CR 
		 ON #CR.DrawerActivityID = #AOT_POS.DrawerActivityID 
		 AND #CR.PaymentType = #AOT_POS.PaymentType
    LEFT JOIN #DropCash #DC 
         ON #DC.DrawerActivityID = #AOT_POS.DrawerActivityID 
         AND #DC.PaymentType = #AOT_POS .PaymentType
    RIGHT JOIN #AllocationOfTendered_DrawerActivity #AOT_DA 
         ON #AOT_DA.DrawerActivityID = #AOT_POS.DrawerActivityID 
         AND #AOT_POS.PaymentType = #AOT_DA.PaymentDescription
    RIGHT JOIN #PaymetTypes #PT 
        ON #PT.ValPaymentTypeID = #AOT_DA.ValPaymentTypeID
 
 
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #ChangeRendered
DROP TABLE #AllocationOfTendered_POSDrawerDetail
DROP TABLE #AllocationOfTendered_DrawerActivity
DROP TABLE #PaymetTypes
DROP TABLE #DropCash

END

