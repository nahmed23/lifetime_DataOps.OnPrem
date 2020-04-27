

--
-- Returns the drawer activity for a single draweractivityid
--
-- parameters: a single draweractivityid integer
--
-- EXEC mmsPosdrawerclosed_POSDrawerDetail '213424'
CREATE      PROC [dbo].[mmsPosdrawerclosed_POSDrawerDetail] (
  @DrawerActivityID INT
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @ClubID INT
SELECT @ClubID = C.ClubID
FROM vClub C
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
WHERE DA.DrawerActivityID = @DrawerActivityID

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

SELECT PDD.CloseDateTime as CloseDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, PDD.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PDD.CloseDateTime),5,DataLength(Convert(Varchar, PDD.CloseDateTime))-12)),' '+Convert(Varchar,Year(PDD.CloseDateTime)),', '+Convert(Varchar,Year(PDD.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, PDD.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, PDD.CloseDateTime ,22),2)) as CloseDateTime,    		
	   PDD.ClubName, PDD.DrawerActivityID, 
       PDD.PostDateTime as PostDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, PDD.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, PDD.PostDateTime),5,DataLength(Convert(Varchar, PDD.PostDateTime))-12)),' '+Convert(Varchar,Year(PDD.PostDateTime)),', '+Convert(Varchar,Year(PDD.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, PDD.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, PDD.PostDateTime ,22),2)) as PostDateTime,    		
	   PDD.MemberID, PDD.FirstName, 
       PDD.LastName, PDD.TranVoidedID, PDD.ReceiptNumber, 
       PDD.EmployeeID, PDD.DomainName, PDD.Quantity, 
       PDD.Sort, 
       PDD.Desc1, PDD.Desc2, PDD.Record,  
       E.LastName AS EmployeeLastname, E.FirstName AS EmployeeFirstname, DA.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.OpenDateTime),5,DataLength(Convert(Varchar, DA.OpenDateTime))-12)),' '+Convert(Varchar,Year(DA.OpenDateTime)),', '+Convert(Varchar,Year(DA.OpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.OpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.OpenDateTime ,22),2)) as OpenDateTime,    		
       PDD.DrawerStatusDescription, PDD.RegionDescription, 
       PDD.TranTypeDescription, PDD.DeptDescription,
       TV.VoidDateTime, TV.Comments AS VoidComments, E2.FirstName AS VoidEmplFirstname, 
       E2.LastName AS VoidEmplLastname, MSA.AddressLine1, MSA.AddressLine2, MSA.City,
       S.Abbreviation AS State, MSA.Zip, PDD.ReceiptComment, PDD.CardOnFileFlag,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   PDD.Amount * #PlanRate.PlanRate as Amount,	   
	   PDD.Amount as LocalCurrency_Amount,	   
	   PDD.Amount * #ToUSDPlanRate.PlanRate as USD_Amount,
	   PDD.Total * #PlanRate.PlanRate as Total,	   
	   PDD.Total as LocalCurrency_Total,	   
	   PDD.Total * #ToUSDPlanRate.PlanRate as USD_Total, 	 	   	 	      	
	   PDD.TipAmount * #PlanRate.PlanRate as TipAmount,	   
	   PDD.TipAmount as LocalCurrency_TipAmount,	   
	   PDD.TipAmount * #ToUSDPlanRate.PlanRate as USD_TipAmount,
	   PDD.Tax * #PlanRate.PlanRate as Tax,	   
	   PDD.Tax as LocalCurrency_Tax,
	   PDD.Tax * #ToUSDPlanRate.PlanRate as USD_Tax,
	   PDD.ChangeRendered * #PlanRate.PlanRate as ChangeRendered,	 
	   PDD.ChangeRendered as LocalCurrency_ChangeRendered,
	   PDD.ChangeRendered * #ToUSDPlanRate.PlanRate as USD_ChangeRendered,
	   PDD.IssuanceAmount * #PlanRate.PlanRate as IssuanceAmount,	 
	   PDD.IssuanceAmount as LocalCurrency_IssuanceAmount,
	   PDD.IssuanceAmount * #ToUSDPlanRate.PlanRate as USD_IssuanceAmount
/***************************************/

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
 WHERE PDD.DrawerActivityID = @DrawerActivityID
 ORDER BY PDD.PostDateTime,
       PDD.Sort

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

