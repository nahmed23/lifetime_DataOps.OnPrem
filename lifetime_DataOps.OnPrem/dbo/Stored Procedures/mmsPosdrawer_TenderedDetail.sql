




-- EXEC dbo.mmsPosdrawer_TenderedDetail '213242|213536'

CREATE      PROC [dbo].[mmsPosdrawer_TenderedDetail] (
  @DrawerActivityIDs VARCHAR(8000)
--  @DrawerActivityID INT
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #DrawerActivityIDs (DrawerActivityID INT)
   EXEC procParseIntegerList @DrawerActivityIDs
   INSERT INTO #DrawerActivityIDs (DrawerActivityID) SELECT StringField FROM #tmpList

DECLARE @ClubID INT
SELECT @ClubID = C.ClubID
FROM vClub C
JOIN vDrawer D ON C.ClubID = D.ClubID
JOIN vDrawerActivity DA ON D.DrawerID = DA.DrawerID
JOIN #DrawerActivityIDs ON DA.DrawerActivityID = #DrawerActivityIDs.DrawerActivityID
GROUP BY C.ClubID

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

SELECT DD.DrawerStatusDescription, DD.RegionDescription, 
       DD.TranTypeDescription, DD.DeptDescription, 
       DD.CloseDateTime as CloseDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DD.CloseDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DD.CloseDateTime),5,DataLength(Convert(Varchar, DD.CloseDateTime))-12)),' '+Convert(Varchar,Year(DD.CloseDateTime)),', '+Convert(Varchar,Year(DD.CloseDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DD.CloseDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DD.CloseDateTime ,22),2)) as CloseDateTime,    
	   DD.ClubName, DD.DrawerActivityID, 
       DD.PostDateTime as PostDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DD.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DD.PostDateTime),5,DataLength(Convert(Varchar, DD.PostDateTime))-12)),' '+Convert(Varchar,Year(DD.PostDateTime)),', '+Convert(Varchar,Year(DD.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DD.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DD.PostDateTime ,22),2)) as PostDateTime,    
	   DD.ReceiptNumber, DD.TranVoidedID, 
       DD.Sort, 
       DD.Desc1, DD.Desc2, 
       DA.OpenDateTime as OpenDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, DA.OpenDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, DA.OpenDateTime),5,DataLength(Convert(Varchar, DA.OpenDateTime))-12)),' '+Convert(Varchar,Year(DA.OpenDateTime)),', '+Convert(Varchar,Year(DA.OpenDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, DA.OpenDateTime,22),10,5) + ' ' + Right(Convert(Varchar, DA.OpenDateTime ,22),2)) as OpenDateTime,    
	   DD.MemberID, M.MembershipID,
       E.FirstName AS CloseEmployeeFirstName,
       E.LastName AS CloseEmployeeLastName,
       C.ClubName AS MemberHomeClub,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   DD.Amount * #PlanRate.PlanRate as Amount,
	   DD.Amount as LocalCurrency_Amount,
	   DD.Amount * #ToUSDPlanRate.PlanRate as USD_Amount,
	   DD.Tax * #PlanRate.PlanRate as Tax,
	   DD.Tax as LocalCurrency_Tax,
	   DD.Tax * #ToUSDPlanRate.PlanRate as USD_Tax,
	   DD.Total * #PlanRate.PlanRate as Total,
	   DD.Total as LocalCurrency_Total,
	   DD.Total * #ToUSDPlanRate.PlanRate as USD_Total,
	   DD.ChangeRendered * #PlanRate.PlanRate as ChangeRendered,
	   DD.ChangeRendered as LocalCurrency_ChangeRendered,
	   DD.ChangeRendered * #ToUSDPlanRate.PlanRate as USD_ChangeRendered,
	   DD.Tipamount * #PlanRate.PlanRate as Tipamount,
	   DD.Tipamount as LocalCurrency_Tipamount,
	   DD.Tipamount * #ToUSDPlanRate.PlanRate as USD_Tipamount	     	
/***************************************/

  FROM dbo.vDrawerActivity DA
  JOIN dbo.vPOSDrawerDetail DD 
       ON DA.DrawerActivityID = DD.DrawerActivityID
  JOIN dbo.vClub DrawerClub
       ON DD.ClubName = DrawerClub.ClubName
  JOIN #DrawerActivityIDs DIDS
       ON DD.DrawerActivityID = DIDS.DrawerActivityID
  LEFT OUTER JOIN dbo.vMember M 
       ON DD.MemberID = M.MemberID
  LEFT OUTER JOIN dbo.vEmployee E
       ON DA.Closeemployeeid = E.EmployeeID
  LEFT OUTER JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  LEFT OUTER JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
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
-- WHERE DD.DrawerActivityID = @DrawerActivityID
 ORDER BY DD.ReceiptNumber, DD.Sort

DROP TABLE #DrawerActivityIDs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

