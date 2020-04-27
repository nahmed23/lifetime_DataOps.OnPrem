




-- EXEC mmsTranddt_Trandt_HouseAccount '141', 'Apr 1, 2011', 'Apr 12, 2011', 'All', 'Refund'

CREATE   PROC [dbo].[mmsTranddt_Trandt_HouseAccount](
            @ClubList VARCHAR(8000),
            @StartDate SMALLDATETIME,
            @EndDate SMALLDATETIME,
            @TranTypeList VARCHAR(1000),
            @DepartmentList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-----       05/18/2010 MLL New stored procedure that is a copy of mmsTranddt_Trandt
-----                      with the new parameter of @DepartmentList and
-----                      LastName hard-coded value of "House Account".

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID INT)
       IF @ClubList <> 'All'
       BEGIN
           --INSERT INTO #Club EXEC procParseStringList @ClubList
         EXEC procParseStringList @ClubList
         INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END

CREATE TABLE #TranType (Description VARCHAR(50))
       IF @TranTypeList <> 'All'
       BEGIN
           --INSERT INTO #TranType EXEC procParseStringList @TranTypeList
         EXEC procParseStringList @TranTypeList
         INSERT INTO #TranType (Description) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
         ELSE
   INSERT INTO #TranType SELECT Description FROM dbo.Vvaltrantype

CREATE TABLE #Department (DepartmentID VARCHAR(50))
       IF @DepartmentList <> 'All'
       BEGIN
           --INSERT INTO #Department EXEC procParseStringList @DepartmentList
         EXEC procParseStringList @DepartmentList
         INSERT INTO #Department (DepartmentID) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/


SELECT --VR1.Description AS Region, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VR1.Description ELSE TranItemRegion.Description END ELSE VR1.Description END AS Region,
       --C1.ClubName, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubName ELSE TranItemClub.ClubName END ELSE C1.ClubName END AS ClubName,
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       MMST.MemberID, MMST.TranAmount * #PlanRate.PlanRate as TranAmount, MMST.TranAmount as LocalCurrency_TranAmount,
	   MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
	   MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    		
	   MMST.PostDateTime AS Postdate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as Postdate,           
	   P.DepartmentID,
       MMST.MMSTranID, TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount, 
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   TI.ItemSalesTax as LocalCurrency_ItemSalesTax, TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,	
       MMST.POSAmount * #PlanRate.PlanRate as POSAmount, MMST.POSAmount as LocalCurrency_POSAmount, 
	   MMST.POSAmount * #ToUSDPlanRate.PlanRate as USD_POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, 
       --MMST.ClubID,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubID ELSE TranItemClub.ClubID END ELSE C1.ClubID END AS ClubID,
       --VR1.Description AS TranRegionDescription, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VR1.Description ELSE TranItemRegion.Description END ELSE VR1.Description END AS TranRegionDescription,
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
       VRC.description,
       MMST.ReceiptComment,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/
  FROM dbo.vClub C1
  JOIN dbo.vMMSTran MMST
       ON C1.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vClub TranItemClub
       ON TI.ClubID = TranItemClub.ClubID
  LEFT JOIN dbo.vValRegion TranItemRegion
       ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
 WHERE VTT.Description IN (SELECT Description FROM #TranType) AND
       (C1.ClubID IN (SELECT ClubID FROM #Clubs) OR
       @ClubList = 'All') AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND C1.ClubID not in (13)
       AND M.LastName = 'House Account'
       AND (D.DepartmentID IN (SELECT DepartmentID FROM #Department) OR
       @DepartmentList = 'All')

UNION ALL

SELECT VR2.Description AS Region, 
       C2.ClubName, 
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       M.MemberID, 
	   MMST.TranAmount * #PlanRate.PlanRate as TranAmount, MMST.TranAmount as LocalCurrency_TranAmount,
	   MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
	   MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    		
	   MMST.PostDateTime AS Postdate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as Postdate,           
	   D.DepartmentID,
       MMST.MMSTranID, TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount, 
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   TI.ItemSalesTax as LocalCurrency_ItemSalesTax, TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,	
       MMST.POSAmount * #PlanRate.PlanRate as POSAmount, MMST.POSAmount as LocalCurrency_POSAmount, 
	   MMST.POSAmount * #ToUSDPlanRate.PlanRate as USD_POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, C1.ClubID,
       VR1.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
	   VRC.description,
       MMST.ReceiptComment,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/
  FROM dbo.vClub C1
  JOIN dbo.vMMSTran MMST
       ON C1.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
 WHERE MMST.ClubID in (13) AND
       (C2.ClubID IN (SELECT ClubID FROM #Clubs) OR
       @ClubList = 'All') AND
       VTT.Description IN (SELECT Description FROM #TranType) AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
       AND M.LastName = 'House Account'
       AND (D.DepartmentID IN (SELECT DepartmentID FROM #Department) OR
       @DepartmentList = 'All')

DROP TABLE #Clubs
DROP TABLE #TranType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

