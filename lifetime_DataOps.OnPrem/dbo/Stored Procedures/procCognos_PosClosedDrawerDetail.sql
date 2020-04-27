
/*
-- Returns the drawer activity for a single draweractivityid
-- parameters: a single draweractivityid integer
--

EXEC procCognos_PosClosedDrawerDetail '325807'

*/

CREATE PROC [dbo].[procCognos_PosClosedDrawerDetail] (
  @DrawerActivityID VARCHAR(15))
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @ClubID INT
SELECT @ClubID = C.ClubID
FROM vClub C
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
WHERE DA.DrawerActivityID = CONVERT(INT,@DrawerActivityID)

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


SELECT 
       PDD.CloseDateTime as CloseDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, PDD.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PDD.CloseDateTime),5,DataLength(Convert(Varchar, PDD.CloseDateTime))-12)),' '+Convert(Varchar,Year(PDD.CloseDateTime)),', '+Convert(Varchar,Year(PDD.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, PDD.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, PDD.CloseDateTime ,22),2)) as CloseDateTime,    		
	   PDD.DrawerActivityID, 
       PDD.PostDateTime as PostDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, PDD.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PDD.PostDateTime),5,DataLength(Convert(Varchar, PDD.PostDateTime))-12)),' '+Convert(Varchar,Year(PDD.PostDateTime)),', '+Convert(Varchar,Year(PDD.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, PDD.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, PDD.PostDateTime ,22),2)) as PostDateTime,    		
	   PDD.MemberID, 
       PDD.TranVoidedID,
       PDD.EmployeeID, 
       PDD.DomainName, 
       PDD.Quantity, 
       PDD.Sort, 
       PDD.Desc2, 
       PDD.Record,  
       E.LastName AS EmployeeLastname, E.FirstName AS EmployeeFirstname, DA.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.OpenDateTime),5,DataLength(Convert(Varchar, DA.OpenDateTime))-12)),' '+Convert(Varchar,Year(DA.OpenDateTime)),', '+Convert(Varchar,Year(DA.OpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.OpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.OpenDateTime ,22),2)) as OpenDateTime,    		
       PDD.DrawerStatusDescription, 
       PDD.RegionDescription, 
       PDD.TranTypeDescription, 
       PDD.DeptDescription,
       
       CASE WHEN Sort<>6 THEN TV.VoidDateTime ELSE NULL END VoidDateTime, 
       CASE WHEN Sort<>6 THEN TV.Comments ELSE '' END AS VoidComments, 
       CASE WHEN Sort<>6 THEN E2.FirstName ELSE '' END AS VoidEmplFirstname, 
       CASE WHEN Sort<>6 THEN E2.LastName ELSE '' END AS VoidEmplLastname, 
       
       MSA.AddressLine1, MSA.AddressLine2, MSA.City,S.Abbreviation AS State, MSA.Zip, 
       PDD.ReceiptComment, PDD.CardOnFileFlag,
              
       PDD.ClubName,       	    
	   CASE WHEN Sort=6 THEN ' ' ELSE ISNULL(PDD.MemberID,0) END AS MemberNo,	   
	   PDD.FirstName, 
       PDD.LastName, 
       CASE WHEN Sort IN (2,6,7) THEN ' ' ELSE PDD.ReceiptNumber END ReceiptNo,
	   CASE WHEN Sort=2 OR Sort = 7 THEN '' ELSE Replace(SubString(Convert(Varchar, PDD.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PDD.PostDateTime),5,DataLength(Convert(Varchar, PDD.PostDateTime))-12)),' '+Convert(Varchar,Year(PDD.PostDateTime)),', '+Convert(Varchar,Year(PDD.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, PDD.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, PDD.PostDateTime ,22),2)) END AS PostTime,
	   CASE WHEN Sort=2 OR Sort = 7 THEN '' ELSE E.FirstName+' '+ SUBSTRING(E.LastName , 1, 1 )+'.' END AS EmployeeName, 
       CASE WHEN Sort=2 OR Sort = 6 OR Sort = 7 THEN '' ELSE PDD.DomainName END AS PCID,
       CASE WHEN Sort=2 OR Sort = 7 THEN '' ELSE  PDD.TranTypeDescription END AS TranType,
       CASE WHEN Sort IN (2,4,6,7) THEN '' ELSE PDD.DeptDescription END AS Department, -- Dept 
       CASE WHEN Sort IN (2,4,6,7) THEN '' ELSE PDD.Quantity END AS Qty,
       CASE WHEN Sort IN (1,3,5) THEN  PDD.Amount * #PlanRate.PlanRate ELSE 0 END AS ItemAmount,  
       CASE WHEN Sort IN (1,3,5) THEN  PDD.Tax * #PlanRate.PlanRate ELSE 0 END AS ItemSalesTax,  
       PDD.Total * #PlanRate.PlanRate as Total,	   

       -- Desc = Desc1+" "+Desc6+" "+Desc2_1+" "+Desc3+" "+Desc4+" "+Desc5
       
       (PDD.Desc1 + ' '+
         /*DESC6*/
       CASE WHEN PDD.CardOnFileFlag = 1 THEN ' - Club Tab' ELSE '' END + ' '+
       /* DESC2_1*/
       CASE WHEN len(desc2)>0 THEN '#' + PDD.Desc2 ELSE '' END + ' '+
  	    /* DESC3*/
  	   CASE WHEN PDD.Changerendered = 0  THEN '' WHEN PDD.Changerendered <> 0 AND PDD.DeptDescription = 'Cash' THEN  'Change  $ '+ CONVERT(VARCHAR(20), CONVERT(NUMERIC(8,2),PDD.Changerendered * #PlanRate.PlanRate)) END + ' '+
  	    /* DESC4*/
  	   CASE WHEN PDD.TipAmount * #PlanRate.PlanRate = 0 OR ((PDD.TipAmount * #PlanRate.PlanRate) IS NULL) THEN '' ELSE 'Tip  $ '+ CONVERT(VARCHAR(6), CONVERT(DECIMAL(6,2), PDD.TipAmount * #PlanRate.PlanRate)) END + ' '+
  	    /*DESC5*/
  	   CASE WHEN PDD.IssuanceAmount * #PlanRate.PlanRate = 0 THEN '' 
  	                 WHEN (PDD.IssuanceAmount * #PlanRate.PlanRate) IS NULL THEN ''   	                 
  	                 ELSE '('+ CONVERT(VARCHAR(6), CONVERT(DECIMAL(6,2), PDD.IssuanceAmount * #PlanRate.PlanRate)) END) AS Description,

       CASE WHEN PDD.Sort=1 AND PDD.TranVoidedID IS NULL THEN PDD.Total * #PlanRate.PlanRate ELSE 0.00 END AS Sale,
       --CASE WHEN PDD.Sort<>2 AND PDD.Sort <> 7 AND PDD.TranTypeDescription = 'Charge' AND PDD.TranVoidedID IS NULL THEN PDD.Total * #PlanRate.PlanRate ELSE 0.00 END AS Charge,
       CASE WHEN PDD.Sort=3 AND PDD.TranVoidedID IS NULL THEN PDD.Total * #PlanRate.PlanRate ELSE 0.00 END AS Charge,
       CASE WHEN (PDD.Sort=2 OR PDD.Sort = 4) AND PDD.TranVoidedID IS NULL THEN PDD.Total * #PlanRate.PlanRate - PDD.Changerendered * #PlanRate.PlanRate ELSE 0.00 END AS Payment,
  	     	    	     
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PDD.Amount * #PlanRate.PlanRate as Amount,	   
	   PDD.Amount as LocalCurrency_Amount,	   
	   PDD.Amount * #ToUSDPlanRate.PlanRate as USD_Amount,
	   PDD.Total as LocalCurrency_Total,	   
	   PDD.Total * #ToUSDPlanRate.PlanRate as USD_Total, 	 	   	 	      	
	   PDD.TipAmount * #PlanRate.PlanRate as TipAmount,	   
	   PDD.TipAmount as LocalCurrency_TipAmount,	   
	   PDD.TipAmount * #ToUSDPlanRate.PlanRate as USD_TipAmount,
	   PDD.Tax * #PlanRate.PlanRate as Tax,	   
	   PDD.Tax as LocalCurrency_Tax,
	   PDD.Tax * #ToUSDPlanRate.PlanRate as USD_Tax,
	   CASE WHEN PDD.Changerendered <> 0 AND PDD.DeptDescription = 'Cash' THEN PDD.ChangeRendered * #PlanRate.PlanRate ELSE 0.00 END AS ChangeRendered,	 	   
	   CASE WHEN PDD.Changerendered <> 0 AND PDD.DeptDescription = 'Cash' THEN PDD.ChangeRendered ELSE 0.00 END as LocalCurrency_ChangeRendered,
	   CASE WHEN PDD.Changerendered <> 0 AND PDD.DeptDescription = 'Cash' THEN PDD.ChangeRendered * #ToUSDPlanRate.PlanRate ELSE 0.00 END as USD_ChangeRendered,
	   PDD.IssuanceAmount * #PlanRate.PlanRate as IssuanceAmount,	 
	   PDD.IssuanceAmount as LocalCurrency_IssuanceAmount,
	   PDD.IssuanceAmount * #ToUSDPlanRate.PlanRate as USD_IssuanceAmount,
	   
	   @ReportRunDateTime AS ReportRunDateTime
	   
  
  FROM vPOSDrawerDetail PDD
  JOIN vDrawerActivity DA
       ON PDD.DrawerActivityID = DA.DrawerActivityID
  JOIN vEmployee E 
       ON PDD.EmployeeID = E.EmployeeID
  LEFT JOIN vTranVoided TV
       ON PDD.TranVoidedID = TV.TranVoidedID
  LEFT JOIN vEmployee E2
       ON TV.EmployeeID = E2.EmployeeID
  LEFT JOIN vMember M
       ON M.MemberID = PDD.MemberID
  LEFT JOIN vMembershipAddress MSA
       ON MSA.MembershipID = M.MembershipID
  LEFT JOIN vValState S
       ON S.ValStateID = MSA.ValStateID
/********** Foreign Currency Stuff **********/
  JOIN vDrawer D
       ON DA.DrawerID = D.DrawerID
  JOIN vClub C
	   ON D.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(PDD.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(PDD.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
 WHERE PDD.DrawerActivityID = CONVERT(INT,@DrawerActivityID) AND 
       PDD.TranTypeDescription <> 'Update Actual Amount' 

 ORDER BY PDD.PostDateTime, PDD.Sort

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

END


